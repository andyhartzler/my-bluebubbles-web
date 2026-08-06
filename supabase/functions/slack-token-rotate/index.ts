// ============================================
// EDGE FUNCTION: slack-token-rotate
// Renews the Slack app-configuration token pair (xoxe.xoxp-... / xoxe-1-...)
// and stores the result in the Supabase Vault.
// ============================================
//
// THE HAZARD THIS FUNCTION IS BUILT AROUND
// POSTing to tooling.tokens.rotate returns a NEW access token AND a NEW refresh
// token, and INVALIDATES THE OLD REFRESH TOKEN THE INSTANT IT ANSWERS. Slack will
// not tell you the pair again. So the failure that matters is not "rotation
// errored" (harmless, the old pair survives) but "rotation succeeded and we did
// not write the answer down" (fatal, a human must mint a new token by hand).
//
// The ordering below exists to make that second case as close to impossible as
// two systems without a shared transaction can get:
//
//   1. Write an attempt row FIRST. This costs a round trip, and it buys two
//      things: proof that the database is reachable and writable milliseconds
//      before we make the irreversible call, and a durable marker that says "a
//      rotation was in flight" if this process dies.
//   2. Only then call Slack.
//   3. Persist the new pair with slack_config_token_put, which writes the Vault
//      secret and closes the attempt row in ONE transaction, retried hard.
//
// The residual window is step 2 returning to step 3 committing. It cannot be
// closed, only shrunk and made visible. If the process dies inside it, the
// attempt row stays at status='started', v_slack_token_rotation_health reports
// STUCK, and the watchdog says so out loud.
//
// Never log a token. Fingerprints only.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const SLACK_ROTATE_URL = "https://slack.com/api/tooling.tokens.rotate";
const SLACK_AUTH_TEST_URL = "https://slack.com/api/auth.test";

// Retry the persist for roughly half a minute before giving up. A brief
// Postgres blip must not cost us the pair.
const PERSIST_BACKOFF_MS = [0, 500, 1000, 2000, 4000, 8000, 15000];

async function fingerprint(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 16);
}

async function sendTelegram(text: string) {
  try {
    const token = Deno.env.get("TELEGRAM_ALERT_BOT_TOKEN");
    const chatId = Deno.env.get("TELEGRAM_ALERT_CHAT_ID");
    if (!token || !chatId) {
      console.error("[slack-token-rotate] telegram secrets not set — alert not sent");
      return;
    }
    const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
    if (!res.ok) {
      console.error(`[slack-token-rotate] telegram non-2xx: ${res.status}`);
    }
  } catch (e) {
    console.error("[slack-token-rotate] telegram failed:", String((e as Error)?.message ?? e));
  }
}

// Mirror the Telegram alert credentials into the Vault so the SQL-only watchdog
// can shout even when this runtime is the thing that is broken. Only ever
// creates; never overwrites. The values move edge-secret to Vault without
// passing through a human, a shell, or a transcript.
async function seedAlertCredentials(admin: ReturnType<typeof createClient>) {
  const pairs: Array<[string, string | undefined]> = [
    ["telegram_alert_bot_token", Deno.env.get("TELEGRAM_ALERT_BOT_TOKEN")],
    ["telegram_alert_chat_id", Deno.env.get("TELEGRAM_ALERT_CHAT_ID")],
  ];
  for (const [name, value] of pairs) {
    if (!value) continue;
    const { error } = await admin.rpc("ops_alert_credential_seed", {
      p_name: name,
      p_value: value,
    });
    if (error) console.error(`[slack-token-rotate] seed ${name} failed: ${error.message}`);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (!cronSecret || !presented || presented !== cronSecret) {
    return json({ error: "Forbidden" }, 403);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const body = await req.json().catch(() => ({} as Record<string, unknown>));
  const mode = String((body as { mode?: string }).mode ?? "rotate");
  const force = (body as { force?: boolean }).force === true;
  const source = String((body as { source?: string }).source ?? "cron");

  // ----- health: report, do not touch anything -----
  if (mode === "health") {
    const { data, error } = await admin
      .from("v_slack_token_rotation_health")
      .select("*")
      .maybeSingle();
    if (error) return json({ ok: false, error: error.message }, 500);
    return json({ ok: true, health: data });
  }

  // ----- verify: prove the stored access token still works -----
  if (mode === "verify") {
    const { data: pair, error } = await admin.rpc("slack_config_token_get");
    if (error || !pair?.access_token) {
      return json({ ok: false, error: error?.message ?? "no stored pair" }, 500);
    }
    const res = await fetch(SLACK_AUTH_TEST_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${pair.access_token}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    });
    const auth = await res.json();
    return json({
      ok: auth.ok === true,
      team: auth.team ?? null,
      team_id: auth.team_id ?? null,
      user: auth.user ?? null,
      slack_error: auth.error ?? null,
      access_fp: await fingerprint(pair.access_token),
      refresh_fp: await fingerprint(pair.refresh_token),
      expires_at: pair.expires_at ?? null,
    });
  }

  if (mode !== "rotate") return json({ error: `unknown mode ${mode}` }, 400);

  await seedAlertCredentials(admin);

  // Guard against a wedged scheduler hammering the endpoint. Every rotation is
  // one more trip through the irreversible window, so do not take them for free.
  if (!force) {
    const { data: health } = await admin
      .from("v_slack_token_rotation_health")
      .select("last_success_at, status")
      .maybeSingle();
    const last = health?.last_success_at ? Date.parse(health.last_success_at) : 0;
    if (last && Date.now() - last < 60 * 60 * 1000) {
      return json({
        ok: true,
        skipped: "rotated less than an hour ago",
        health,
      });
    }
  }

  // ---- STEP 1: durable attempt row, before Slack is touched ----
  const { data: attemptId, error: beginErr } = await admin.rpc(
    "slack_token_rotation_begin",
    { p_source: source },
  );
  if (beginErr || !attemptId) {
    // The database is not writable. Do NOT call Slack: rotating now would
    // certainly lose the new pair. Leaving the old pair alone is the safe move.
    const msg = `[slack-token-rotate] ABORTED BEFORE ROTATING: cannot write attempt row (${beginErr?.message}). Old token pair left intact.`;
    console.error(msg);
    await sendTelegram(`MOYD Slack token rotation aborted before calling Slack.\n${beginErr?.message ?? "no attempt id"}\nThe existing token pair is untouched and still valid.`);
    return json({ ok: false, error: "database not writable; refused to rotate" }, 503);
  }

  // ---- read the current pair ----
  const { data: current, error: getErr } = await admin.rpc("slack_config_token_get");
  if (getErr || !current?.refresh_token) {
    await admin.rpc("slack_token_rotation_fail", {
      p_attempt_id: attemptId,
      p_status: "slack_error",
      p_error: `no stored refresh token: ${getErr?.message ?? "vault empty"}`,
    });
    await sendTelegram("MOYD Slack token rotation: no refresh token stored in the Vault. Nothing to rotate.");
    return json({ ok: false, error: "no stored refresh token" }, 500);
  }
  const oldRefreshFp = await fingerprint(current.refresh_token);

  // ---- STEP 2: the irreversible call ----
  let rotated: Record<string, unknown>;
  try {
    const res = await fetch(SLACK_ROTATE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ refresh_token: current.refresh_token }),
    });
    rotated = await res.json();
  } catch (e) {
    // Network failure. We cannot tell whether Slack rotated. Treat as suspect.
    const msg = String((e as Error)?.message ?? e);
    await admin.rpc("slack_token_rotation_fail", {
      p_attempt_id: attemptId,
      p_status: "persist_failed",
      p_error: `transport failure, rotation outcome unknown: ${msg}`,
    });
    await sendTelegram(`MOYD Slack token rotation: transport failure calling Slack. It is UNKNOWN whether the token rotated, so the stored refresh token may now be dead. Check v_slack_token_rotation_health.\n${msg}`);
    return json({ ok: false, error: "transport failure, outcome unknown" }, 502);
  }

  if (rotated.ok !== true) {
    // Slack refused. Nothing rotated, the old pair is still good.
    const slackError = String(rotated.error ?? "unknown");
    await admin.rpc("slack_token_rotation_fail", {
      p_attempt_id: attemptId,
      p_status: "slack_error",
      p_error: slackError,
    });
    await sendTelegram(`MOYD Slack app-config token rotation FAILED: Slack said "${slackError}".\nThe previous pair is untouched. If this says invalid_refresh_token the stored pair is dead and a new token must be minted by hand at api.slack.com/authentication/config-tokens.`);
    return json({ ok: false, slack_error: slackError }, 502);
  }

  const newAccess = String(rotated.token ?? "");
  const newRefresh = String(rotated.refresh_token ?? "");
  const expiresAt = rotated.exp
    ? new Date(Number(rotated.exp) * 1000).toISOString()
    : null;

  // ---- STEP 3: persist, hard ----
  let persisted: Record<string, unknown> | null = null;
  let lastErr = "";
  for (const wait of PERSIST_BACKOFF_MS) {
    if (wait) await new Promise((r) => setTimeout(r, wait));
    const { data, error } = await admin.rpc("slack_config_token_put", {
      p_access: newAccess,
      p_refresh: newRefresh,
      p_expires_at: expiresAt,
      p_attempt_id: attemptId,
      p_note: `rotated via ${source}`,
    });
    if (!error) {
      persisted = data;
      break;
    }
    lastErr = error.message;
    console.error(`[slack-token-rotate] persist attempt failed: ${lastErr}`);
  }

  if (!persisted) {
    // This is the bad one. Slack has rotated, the old refresh token is dead, and
    // we could not write the new pair. Say so as loudly as possible. The token
    // itself is deliberately NOT included in the alert.
    console.error("[slack-token-rotate] PERSIST FAILED AFTER SUCCESSFUL ROTATION — ACCESS LOST");
    await admin
      .rpc("slack_token_rotation_fail", {
        p_attempt_id: attemptId,
        p_status: "persist_failed",
        p_error: `rotation succeeded at Slack but the Vault write failed: ${lastErr}`,
      })
      .catch(() => {});
    await sendTelegram(
      "MOYD Slack app-config token: ROTATION SUCCEEDED BUT THE NEW PAIR COULD NOT BE STORED.\n" +
        "Programmatic Slack app-config access is now LOST. Generate a fresh config token by hand at " +
        "api.slack.com/authentication/config-tokens and re-seed it, then the schedule will take over again.\n" +
        `db error: ${lastErr}`,
    );
    return json({ ok: false, error: "rotated but not persisted", detail: lastErr }, 500);
  }

  // ---- prove the stored token actually works, after the fact ----
  let authOk = false;
  let team: string | null = null;
  try {
    const res = await fetch(SLACK_AUTH_TEST_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${newAccess}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    });
    const auth = await res.json();
    authOk = auth.ok === true;
    team = auth.team ?? null;
  } catch (_) { /* the pair is stored either way; verification is a bonus */ }

  if (!authOk) {
    await sendTelegram("MOYD Slack token rotation stored a new pair, but auth.test on the new access token did not return ok. Worth a look.");
  }

  return json({
    ok: true,
    attempt_id: attemptId,
    old_refresh_fp: oldRefreshFp,
    new_access_fp: persisted.access_fp,
    new_refresh_fp: persisted.refresh_fp,
    refresh_changed: oldRefreshFp !== persisted.refresh_fp,
    expires_at: expiresAt,
    auth_test_ok: authOk,
    team,
  });
});
