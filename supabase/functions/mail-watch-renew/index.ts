// Refreshes the Gmail users.watch on crm@. Gmail expires the watch within
// 7 days; pg_cron hits this daily so we always have ~6+ days of headroom.
// Deployed with --no-verify-jwt because there are no caller-controlled
// inputs — the cron just hits the URL.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const TOPIC = "projects/backend-everything/topics/gmail-crm";

Deno.serve(async (_req) => {
  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const r = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/watch",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${tok}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        topicName: TOPIC,
        labelIds: ["INBOX"],
        labelFilterBehavior: "INCLUDE",
      }),
    },
  );
  if (!r.ok) {
    return new Response(
      JSON.stringify({ error: "watch_failed", detail: await r.text() }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  const data = await r.json();
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  await sb.from("mail_pubsub_state").upsert({
    id: 1,
    history_id: data.historyId,
    watch_expires_at: new Date(Number(data.expiration)).toISOString(),
  });
  return new Response(
    JSON.stringify({
      ok: true,
      historyId: data.historyId,
      expires: data.expiration,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
