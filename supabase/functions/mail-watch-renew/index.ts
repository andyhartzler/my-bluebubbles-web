// Refreshes Gmail users.watch on every mailbox the mail client tracks.
// Gmail expires watches within 7 days; pg_cron hits this daily so we
// always have ~6+ days of headroom on every mailbox.
//
// Mailboxes:
//   - shared_alias: one watch on crm@moyoungdemocrats.org (covers all 15
//     shared aliases).
//   - self_owned: one watch per row (Andrew/Dustin/Landon — each has their
//     own Workspace seat and own Gmail mailbox).
//
// Deployed --no-verify-jwt because there are no caller-controlled inputs.
// Per-mailbox failures are logged and isolated — one failed renew does not
// halt the rest.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import {
  enumerateWatchedMailboxes,
  type WatchedMailbox,
} from "../_shared/mailbox-registry.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const TOPIC = "projects/backend-everything/topics/gmail-crm";
const GMAIL_API_USERS = "https://gmail.googleapis.com/gmail/v1/users";

interface RenewResult {
  mailbox: string;
  ok: boolean;
  historyId?: string;
  expires?: string;
  error?: string;
}

async function renewOne(
  sb: ReturnType<typeof createClient>,
  m: WatchedMailbox,
): Promise<RenewResult> {
  try {
    const tok = await getGoogleAccessToken({
      subject: m.mailboxEmail,
      scopes: ["https://www.googleapis.com/auth/gmail.modify"],
    });
    const r = await fetch(`${GMAIL_API_USERS}/me/watch`, {
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
    });
    if (!r.ok) {
      const detail = (await r.text()).slice(0, 500);
      return {
        mailbox: m.mailboxEmail,
        ok: false,
        error: `watch_failed_${r.status}: ${detail}`,
      };
    }
    const data = await r.json();
    await sb
      .from("mail_pubsub_state")
      .upsert(
        {
          mailbox_email: m.mailboxEmail,
          history_id: data.historyId,
          watch_expires_at: new Date(Number(data.expiration)).toISOString(),
        },
        { onConflict: "mailbox_email" },
      );
    return {
      mailbox: m.mailboxEmail,
      ok: true,
      historyId: data.historyId,
      expires: data.expiration,
    };
  } catch (e) {
    return {
      mailbox: m.mailboxEmail,
      ok: false,
      error: String(e),
    };
  }
}

Deno.serve(async (_req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let mailboxes: WatchedMailbox[];
  try {
    mailboxes = await enumerateWatchedMailboxes(sb);
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "enumerate_failed", detail: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Renew sequentially — typical N is small (1 shared + 3 self_owned),
  // and Gmail rate-limits per-user anyway. Errors per mailbox are isolated.
  const results: RenewResult[] = [];
  for (const m of mailboxes) {
    results.push(await renewOne(sb, m));
  }

  const allOk = results.every((r) => r.ok);
  return new Response(
    JSON.stringify({ ok: allOk, results }),
    {
      status: allOk ? 200 : 207,
      headers: { "Content-Type": "application/json" },
    },
  );
});
