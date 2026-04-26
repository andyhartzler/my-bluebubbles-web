// Phase 4: send a draft owned by the caller's alias.
//
// Trust boundary:
// 1. resolveCaller establishes caller identity from JWT.
// 2. We fetch the draft, parse its From: header, exact-match against caller's
//    alias via messageMatchesAlias. Mismatch -> 403.
// 3. mail_send_log row is appended with status='sent' once Gmail confirms
//    delivery; the original 'queued' row from mail-draft-create remains for
//    full audit history.
// 4. Eager-upsert into mail_messages_cache so the SENT message appears in
//    the inbox UI before the Pub/Sub receiver catches up.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface SendDraftBody {
  draftId: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Use POST", { status: 405 });
  }
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = (await req.json().catch(() => ({}))) as Partial<SendDraftBody>;
  const draftId = (body.draftId ?? "").toString();
  if (!draftId) {
    return new Response(JSON.stringify({ error: "missing_draftId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // 1. Fetch existing draft, verify ownership.
  const getRes = await fetch(`${GMAIL_API}/drafts/${draftId}?format=full`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!getRes.ok) {
    return new Response(
      JSON.stringify({ error: "draft_not_found", detail: await getRes.text() }),
      { status: getRes.status, headers: { "Content-Type": "application/json" } },
    );
  }
  const existing = await getRes.json();
  const existingHeaders = Object.fromEntries(
    (existing.message?.payload?.headers ?? []).map(
      (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
    ),
  );
  // Self_owned: every draft in the mailbox is the caller's. Shared_alias:
  // From: must match caller's alias.
  if (
    caller.mailboxKind !== "self_owned" &&
    !messageMatchesAlias(existingHeaders, caller.aliasEmail)
  ) {
    return new Response(JSON.stringify({ error: "not_yours" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Pull useful fields from the existing draft for the audit row + cache.
  const subject = (existingHeaders["subject"] ?? "").toString();
  const fromHeader = (existingHeaders["from"] ?? "").toString();
  const toAddrs = (existingHeaders["to"] ?? "")
    .split(",")
    .map((s: string) => s.trim())
    .filter(Boolean);
  const ccAddrs = (existingHeaders["cc"] ?? "")
    .split(",")
    .map((s: string) => s.trim())
    .filter(Boolean);
  const bccAddrs = (existingHeaders["bcc"] ?? "")
    .split(",")
    .map((s: string) => s.trim())
    .filter(Boolean);
  const rfc822MessageId = (existingHeaders["message-id"] ?? "").toString() ||
    null;

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 2. Send the draft.
  const sendRes = await fetch(`${GMAIL_API}/drafts/send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tok}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ id: draftId }),
  });
  if (!sendRes.ok) {
    const detail = await sendRes.text();
    // Append a 'failed' audit row.
    await sb.from("mail_send_log").insert({
      sender_user_id: caller.userId,
      alias_email: caller.aliasEmail,
      rfc822_message_id: rfc822MessageId,
      thread_id: existing.message?.threadId ?? null,
      recipients: { to: toAddrs, cc: ccAddrs, bcc: bccAddrs },
      subject,
      status: "failed",
      error_detail: detail.slice(0, 1000),
    });
    return new Response(
      JSON.stringify({ error: "draft_send_failed", detail }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  const sent = await sendRes.json();

  // 3. Append a 'sent' audit row referencing the gmail_message_id. The
  //    original 'queued' row from mail-draft-create stays for full history.
  //    Use upsert on gmail_message_id since the create row may already have
  //    that id (we updated it post-create) — but the unique index will allow
  //    only one row per gmail_message_id, so we update-or-insert via
  //    a select-then-write pattern.
  const { data: existingLog } = await sb
    .from("mail_send_log")
    .select("id")
    .eq("gmail_message_id", sent.id)
    .maybeSingle();
  if (existingLog) {
    await sb
      .from("mail_send_log")
      .update({
        status: "sent",
        thread_id: sent.threadId,
        sent_at: new Date().toISOString(),
      })
      .eq("id", existingLog.id);
  } else {
    await sb.from("mail_send_log").insert({
      sender_user_id: caller.userId,
      alias_email: caller.aliasEmail,
      gmail_message_id: sent.id,
      rfc822_message_id: rfc822MessageId,
      thread_id: sent.threadId,
      recipients: { to: toAddrs, cc: ccAddrs, bcc: bccAddrs },
      subject,
      status: "sent",
    });
  }

  // 4. Eager-upsert into messages cache so the SENT message appears in the
  //    UI before the Pub/Sub receiver catches up.
  const snippet = (existing.message?.snippet ?? "").toString().slice(0, 200);
  await sb.from("mail_messages_cache").upsert({
    gmail_message_id: sent.id,
    thread_id: sent.threadId,
    alias_email: caller.aliasEmail,
    from_addr: fromHeader || caller.aliasEmail,
    to_addrs: toAddrs,
    cc_addrs: ccAddrs,
    subject,
    snippet,
    internal_date: new Date().toISOString(),
    labels: sent.labelIds ?? ["SENT"],
    delivered_to: null,
  });

  return new Response(
    JSON.stringify({
      ok: true,
      gmailMessageId: sent.id,
      threadId: sent.threadId,
      rfc822MessageId,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
