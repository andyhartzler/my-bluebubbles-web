// Watch-renew failure detector. The daily mail-watch-renew cron
// (jobid 86, 09:15 UTC) refreshes the Gmail users.watch on crm@,
// which Gmail expires within 7 days. If that cron silently fails,
// we lose Pub/Sub notifications and the silent-detection poll
// fallback eventually starts seeing 404s.
//
// This function checks once an hour: if the watch is within 24h
// of expiring AND mail_pubsub_state hasn't been updated in >23h
// (i.e. the daily renew cron didn't tick), we post a Slack alert.
// Slack is best-effort — never fail the function on Slack post
// failure, the point is alerting, not blocking the cron.

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (_req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: state, error } = await sb
    .from("mail_pubsub_state")
    .select("watch_expires_at, updated_at")
    .eq("id", 1)
    .maybeSingle();

  if (error) {
    return new Response(
      JSON.stringify({ ok: true, alerted: false, reason: "state_read_error" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }
  if (!state?.watch_expires_at) {
    return new Response(
      JSON.stringify({ ok: true, alerted: false, reason: "no_watch" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const now = Date.now();
  const expiresAtMs = new Date(state.watch_expires_at).getTime();
  const hoursToExpiry = (expiresAtMs - now) / 3_600_000;
  const expiresInLabel = `${hoursToExpiry.toFixed(1)} hours`;

  const updatedAtMs = state.updated_at
    ? new Date(state.updated_at).getTime()
    : 0;
  const hoursSinceUpdate = (now - updatedAtMs) / 3_600_000;

  const inDangerWindow = hoursToExpiry <= 24;
  const renewIsStale = hoursSinceUpdate > 23;
  const shouldAlert = inDangerWindow && renewIsStale;

  if (!shouldAlert) {
    return new Response(
      JSON.stringify({
        ok: true,
        alerted: false,
        expiresIn: expiresInLabel,
        hoursSinceUpdate: hoursSinceUpdate.toFixed(1),
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const webhook = Deno.env.get("MAIL_WATCH_HEALTH_SLACK_WEBHOOK");
  const text =
    `⚠️ Gmail watch on crm@ expires in ${expiresInLabel}. ` +
    `Last successful renewal: ${state.updated_at}. ` +
    `cron 'mail-watch-renew-daily' (jobid 86) may not be running.`;

  if (!webhook) {
    console.warn("mail-watch-health alert (no webhook configured):", text);
    return new Response(
      JSON.stringify({
        ok: true,
        alerted: false,
        reason: "no_webhook",
        expiresIn: expiresInLabel,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // Best-effort Slack post. Never throw / never fail the cron.
  try {
    const r = await fetch(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    if (!r.ok) {
      console.error(
        "mail-watch-health: slack post non-OK",
        r.status,
        await r.text().catch(() => ""),
      );
    }
  } catch (e) {
    console.error("mail-watch-health: slack post threw", String(e));
  }

  return new Response(
    JSON.stringify({ ok: true, alerted: true, expiresIn: expiresInLabel }),
    { headers: { "Content-Type": "application/json" } },
  );
});
