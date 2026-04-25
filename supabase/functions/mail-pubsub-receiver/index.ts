// Pub/Sub push handler for Gmail history notifications. Verifies the
// Google-signed OIDC token (review §C5), then walks users.history.list
// from our persisted floor and upserts new INBOX messages into
// mail_messages_cache, classified by alias via exact-match RFC 5322
// (review §C2-C4).

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { verifyPubsubOidc } from "../_shared/oidc-verify.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const RECEIVER_URL =
  "https://faajpcarasilbfndzkmd.functions.supabase.co/mail-pubsub-receiver";
const PUSH_SA_EMAIL =
  "moyd-ai-agent@backend-everything.iam.gserviceaccount.com";

Deno.serve(async (req) => {
  const failed = await verifyPubsubOidc(req, {
    expectedAudience: RECEIVER_URL,
    expectedEmail: PUSH_SA_EMAIL,
  });
  if (failed) return failed;

  const env = await req.json().catch(() => ({}));
  const dataB64 = env?.message?.data;
  if (!dataB64) {
    return new Response(JSON.stringify({ ack: true }), {
      headers: { "Content-Type": "application/json" },
    });
  }
  const data = JSON.parse(atob(dataB64));
  const newHistoryId: string = String(data.historyId);

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: state } = await sb
    .from("mail_pubsub_state")
    .select("history_id")
    .eq("id", 1)
    .maybeSingle();
  const startHistoryId = state?.history_id;
  if (!startHistoryId) {
    // First push — establish baseline only. Backfill >7d isn't possible
    // (Gmail rejects expired startHistoryId).
    await sb.from("mail_pubsub_state").upsert({
      id: 1,
      history_id: newHistoryId,
      watch_expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
      last_event_at: new Date().toISOString(),
    });
    return new Response(JSON.stringify({ ack: true, baseline: newHistoryId }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // Loop on users.history.list pagination until exhausted (review §H3).
  // Persist the historyId returned by Gmail (floor of pages processed),
  // not the push envelope's newHistoryId — otherwise we may persist
  // ahead of what we actually processed and silently drop messages.
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
      // 404 means startHistoryId expired (>7d). Reset baseline.
      // KNOWN LIMITATION: messages between expired watermark and reset
      // are not backfilled — full reconciliation lives in Phase 5.
      if (histRes.status === 404) {
        await sb
          .from("mail_pubsub_state")
          .update({
            history_id: newHistoryId,
            last_event_at: new Date().toISOString(),
          })
          .eq("id", 1);
        return new Response(JSON.stringify({ ack: true, reset: true }), {
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({ error: "history_failed" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
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

  // Per-message classification using the exact-match helper.
  const { data: aliases } = await sb
    .from("mail_aliases")
    .select("alias_email")
    .is("revoked_at", null)
    .eq("gmail_send_as_verified", true);
  const aliasList: string[] = (aliases ?? []).map((r: { alias_email: string }) =>
    r.alias_email.toLowerCase()
  );

  for (const mid of messageIds) {
    const r = await fetch(
      `${GMAIL_API}/messages/${mid}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) continue;
    const m = await r.json();
    const headers = Object.fromEntries(
      (m.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
      ),
    );

    let alias = "";
    for (const a of aliasList) {
      if (messageMatchesAlias(headers, a)) {
        alias = a;
        break;
      }
    }
    if (!alias) continue; // not for any provisioned exec — skip

    await sb.from("mail_messages_cache").upsert({
      gmail_message_id: m.id,
      thread_id: m.threadId,
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
      snippet: m.snippet ?? "",
      internal_date: new Date(Number(m.internalDate)).toISOString(),
      labels: m.labelIds ?? [],
      delivered_to: headers["delivered-to"] ?? null,
    });
  }

  await sb
    .from("mail_pubsub_state")
    .update({
      history_id: lastResponseHistoryId ?? newHistoryId,
      last_event_at: new Date().toISOString(),
    })
    .eq("id", 1);

  return new Response(
    JSON.stringify({ ack: true, processed: messageIds.size }),
    { headers: { "Content-Type": "application/json" } },
  );
});
