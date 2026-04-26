// Watch-renew failure detector. The daily mail-watch-renew cron refreshes
// users.watch on every tracked mailbox; Gmail expires watches within 7
// days. If that cron silently fails for any mailbox, we lose Pub/Sub
// notifications for it and the silent-detection poll fallback eventually
// starts seeing 404s.
//
// This function checks once an hour: for every row in mail_pubsub_state,
// if the watch is within 24h of expiring AND the row hasn't been updated
// in >23h (i.e. the daily renew cron didn't tick for that mailbox), we
// post a Slack alert. Slack is best-effort — never fail the function on
// Slack post failure, the point is alerting, not blocking the cron.

import { createClient } from "jsr:@supabase/supabase-js@2";

interface StaleEntry {
  mailbox: string;
  expiresIn: string;
  lastUpdate: string;
}

Deno.serve(async (_req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: states, error } = await sb
    .from("mail_pubsub_state")
    .select("mailbox_email, watch_expires_at, updated_at");

  if (error) {
    return new Response(
      JSON.stringify({ ok: true, alerted: false, reason: "state_read_error" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }
  if (!states || states.length === 0) {
    return new Response(
      JSON.stringify({ ok: true, alerted: false, reason: "no_watches" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const now = Date.now();
  const stale: StaleEntry[] = [];
  for (const s of states) {
    if (!s.watch_expires_at) continue;
    const expiresAtMs = new Date(s.watch_expires_at).getTime();
    const hoursToExpiry = (expiresAtMs - now) / 3_600_000;
    const updatedAtMs = s.updated_at ? new Date(s.updated_at).getTime() : 0;
    const hoursSinceUpdate = (now - updatedAtMs) / 3_600_000;
    if (hoursToExpiry <= 24 && hoursSinceUpdate > 23) {
      stale.push({
        mailbox: s.mailbox_email,
        expiresIn: `${hoursToExpiry.toFixed(1)} hours`,
        lastUpdate: s.updated_at ?? "(never)",
      });
    }
  }

  if (stale.length === 0) {
    return new Response(
      JSON.stringify({
        ok: true,
        alerted: false,
        watches: states.length,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const lines = stale.map((s) =>
    `• ${s.mailbox} expires in ${s.expiresIn} (last update ${s.lastUpdate})`
  );
  const text =
    `⚠️ Gmail watch renewal stale on ${stale.length} mailbox(es). ` +
    `cron 'mail-watch-renew-daily' may not be running.\n${lines.join("\n")}`;

  const webhook = Deno.env.get("MAIL_WATCH_HEALTH_SLACK_WEBHOOK");
  if (!webhook) {
    console.warn("mail-watch-health alert (no webhook configured):", text);
    return new Response(
      JSON.stringify({
        ok: true,
        alerted: false,
        reason: "no_webhook",
        stale,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // Best-effort Slack post.
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
    JSON.stringify({ ok: true, alerted: true, stale }),
    { headers: { "Content-Type": "application/json" } },
  );
});
