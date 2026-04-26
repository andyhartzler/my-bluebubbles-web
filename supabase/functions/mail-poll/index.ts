// Pub/Sub silent-detection fallback for the Gmail history pipeline.
// Cron fires every 5 min. For each mailbox we track in mail_pubsub_state,
// if the receiver hasn't been pinged recently (last_event_at within the
// last 5 min) we no-op. Otherwise we run the same users.history.list walk
// the receiver runs on a real push, catching up any messages we missed
// because Pub/Sub had an outage or the watch lapsed.
//
// Per-mailbox: shared_alias (crm@) is one entry; each self_owned mailbox
// is its own entry. Each mailbox has its own history watermark.
//
// Deployed --no-verify-jwt because pg_cron hits us URL-only with no
// caller-controlled inputs.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import {
  enumerateWatchedMailboxes,
  type WatchedMailbox,
} from "../_shared/mailbox-registry.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const FRESH_WINDOW_MS = 5 * 60 * 1000;

interface MailboxResult {
  mailbox: string;
  status:
    | "fresh"
    | "no_baseline"
    | "reset"
    | "ok"
    | "history_failed"
    | "no_state";
  processed?: number;
  detail?: string;
}

async function pollOne(
  sb: ReturnType<typeof createClient>,
  m: WatchedMailbox,
): Promise<MailboxResult> {
  const { data: state } = await sb
    .from("mail_pubsub_state")
    .select("history_id, last_event_at")
    .eq("mailbox_email", m.mailboxEmail)
    .maybeSingle();

  if (!state?.history_id) {
    // No baseline yet — first push (or watch-renew) will establish it.
    return { mailbox: m.mailboxEmail, status: "no_baseline" };
  }

  if (state.last_event_at) {
    const ageMs = Date.now() - new Date(state.last_event_at).getTime();
    if (ageMs < FRESH_WINDOW_MS) {
      return { mailbox: m.mailboxEmail, status: "fresh" };
    }
  }

  const startHistoryId = String(state.history_id);
  const tok = await getGoogleAccessToken({
    subject: m.mailboxEmail,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const messageIds = new Set<string>();
  let pageToken: string | undefined;
  let lastResponseHistoryId: string | undefined;

  do {
    const url = new URL(`${GMAIL_API}/history`);
    url.searchParams.set("startHistoryId", startHistoryId);
    url.searchParams.set("historyTypes", "messageAdded");
    if (pageToken) url.searchParams.set("pageToken", pageToken);

    const histRes = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${tok}` },
    });

    if (!histRes.ok) {
      if (histRes.status === 404) {
        // startHistoryId expired (>7d). Reset baseline to current Gmail
        // historyId via users.messages.list — same recovery path the
        // receiver uses on a 404.
        const listRes = await fetch(
          `${GMAIL_API}/messages?maxResults=1`,
          { headers: { Authorization: `Bearer ${tok}` } },
        );
        let resetHistoryId: string | undefined;
        if (listRes.ok) {
          const lj = await listRes.json();
          const firstId = lj.messages?.[0]?.id;
          if (firstId) {
            const mr = await fetch(
              `${GMAIL_API}/messages/${firstId}?format=minimal`,
              { headers: { Authorization: `Bearer ${tok}` } },
            );
            if (mr.ok) {
              const mj = await mr.json();
              if (mj.historyId) resetHistoryId = String(mj.historyId);
            }
          }
        }
        await sb
          .from("mail_pubsub_state")
          .update({
            ...(resetHistoryId ? { history_id: resetHistoryId } : {}),
            last_event_at: new Date().toISOString(),
          })
          .eq("mailbox_email", m.mailboxEmail);
        console.log(
          `mail-poll[${m.mailboxEmail}]: history reset (404 expired)`,
          { from: startHistoryId, to: resetHistoryId ?? "unchanged" },
        );
        return { mailbox: m.mailboxEmail, status: "reset" };
      }
      return {
        mailbox: m.mailboxEmail,
        status: "history_failed",
        detail: `${histRes.status}`,
      };
    }

    const hist = await histRes.json();
    if (hist.historyId) lastResponseHistoryId = String(hist.historyId);
    for (const h of (hist.history ?? [])) {
      for (const ma of (h.messagesAdded ?? [])) {
        if (ma.message?.id) messageIds.add(ma.message.id);
      }
    }
    pageToken = hist.nextPageToken;
  } while (pageToken);

  // Per-message classification.
  const aliasList: string[] = m.aliases.map((a) => a.aliasEmail.toLowerCase());
  const isSelfOwned = m.mailboxKind === "self_owned";

  for (const mid of messageIds) {
    const r = await fetch(
      `${GMAIL_API}/messages/${mid}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) continue;
    const msg = await r.json();
    const headers = Object.fromEntries(
      (msg.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
      ),
    );

    let alias = "";
    if (isSelfOwned) {
      alias = aliasList[0] ?? "";
    } else {
      for (const a of aliasList) {
        if (messageMatchesAlias(headers, a)) {
          alias = a;
          break;
        }
      }
    }
    if (!alias) continue;

    await sb.from("mail_messages_cache").upsert({
      gmail_message_id: msg.id,
      thread_id: msg.threadId,
      alias_email: alias,
      from_addr: headers["from"] ?? "",
      to_addrs: (headers["to"] ?? "")
        .split(",")
        .map((s: string) => s.trim())
        .filter(Boolean),
      cc_addrs: (headers["cc"] ?? "")
        .split(",")
        .map((s: string) => s.trim())
        .filter(Boolean),
      subject: headers["subject"] ?? "",
      snippet: msg.snippet ?? "",
      internal_date: new Date(Number(msg.internalDate)).toISOString(),
      labels: msg.labelIds ?? [],
      delivered_to: headers["delivered-to"] ?? null,
    });
  }

  await sb
    .from("mail_pubsub_state")
    .update({
      ...(lastResponseHistoryId ? { history_id: lastResponseHistoryId } : {}),
      last_event_at: new Date().toISOString(),
    })
    .eq("mailbox_email", m.mailboxEmail);

  return {
    mailbox: m.mailboxEmail,
    status: "ok",
    processed: messageIds.size,
  };
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

  const results: MailboxResult[] = [];
  for (const m of mailboxes) {
    try {
      results.push(await pollOne(sb, m));
    } catch (e) {
      results.push({
        mailbox: m.mailboxEmail,
        status: "history_failed",
        detail: String(e),
      });
    }
  }

  return new Response(
    JSON.stringify({ ok: true, results }),
    { headers: { "Content-Type": "application/json" } },
  );
});
