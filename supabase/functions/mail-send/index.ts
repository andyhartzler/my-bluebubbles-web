// Phase 2: send a message from the caller's alias via Gmail API.
//
// Trust boundary:
// 1. resolveCaller pins From: to caller's mail_aliases.alias_email — clients
//    cannot send as someone else (the From: header in the request body is
//    ignored; we always overwrite from auth.uid()'s alias).
// 2. mail_send_log row is inserted on every attempt (status: queued -> sent
//    or failed) so the audit trail records intent + outcome.
// 3. RFC 822 builder generates rfc822_message_id deterministically; unique
//    index on mail_send_log catches dupes.
// 4. eager-upsert into mail_messages_cache so SENT message appears in the
//    inbox UI before the Pub/Sub receiver catches up.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { resolveSendAsForSelfOwned } from "../_shared/email-utils.ts";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface SendBody {
  to: string[];
  cc?: string[];
  bcc?: string[];
  subject: string;
  bodyText?: string;
  bodyHtml?: string;
  threadId?: string;
  inReplyTo?: string; // RFC 822 Message-ID of the message being replied to
  references?: string[]; // Full References header chain
  relatedEntityType?: string;
  relatedEntityId?: string;
  /** Self_owned-only: verified sendAs address to use in From:. Ignored
   *  for shared_alias (always pinned to the caller's alias). */
  fromAddr?: string;
}

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function sanitizeAddrList(arr: unknown): string[] {
  if (!Array.isArray(arr)) return [];
  return arr
    .filter((x): x is string => typeof x === "string")
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && /^[^\s<>"]+@[^\s<>"]+\.[^\s<>"]+$/.test(s));
}

function genMessageId(alias: string): string {
  const rand = crypto.getRandomValues(new Uint8Array(16));
  const hex = Array.from(rand)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  const domain = alias.split("@")[1] ?? "moyoungdemocrats.org";
  return `<${hex}.${Date.now()}@${domain}>`;
}

function buildRfc822(opts: {
  fromName: string;
  fromAddr: string;
  to: string[];
  cc: string[];
  bcc: string[];
  subject: string;
  bodyText?: string;
  bodyHtml?: string;
  messageId: string;
  inReplyTo?: string;
  references?: string[];
}): string {
  const headers: string[] = [];
  headers.push(
    `From: ${opts.fromName ? `"${opts.fromName}" ` : ""}<${opts.fromAddr}>`,
  );
  headers.push(`To: ${opts.to.join(", ")}`);
  if (opts.cc.length) headers.push(`Cc: ${opts.cc.join(", ")}`);
  if (opts.bcc.length) headers.push(`Bcc: ${opts.bcc.join(", ")}`);
  headers.push(`Subject: ${opts.subject}`);
  headers.push(`Message-ID: ${opts.messageId}`);
  headers.push(`Date: ${new Date().toUTCString()}`);
  headers.push(`MIME-Version: 1.0`);
  if (opts.inReplyTo) headers.push(`In-Reply-To: ${opts.inReplyTo}`);
  if (opts.references?.length) {
    headers.push(`References: ${opts.references.join(" ")}`);
  }

  const hasText = !!opts.bodyText;
  const hasHtml = !!opts.bodyHtml;

  if (hasText && hasHtml) {
    const boundary =
      `=_boundary_${crypto.randomUUID().replace(/-/g, "").slice(0, 16)}`;
    headers.push(
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
    );
    const lines = [headers.join("\r\n"), "", `--${boundary}`];
    lines.push(
      'Content-Type: text/plain; charset="UTF-8"',
      "Content-Transfer-Encoding: 7bit",
      "",
      opts.bodyText!,
      "",
      `--${boundary}`,
    );
    lines.push(
      'Content-Type: text/html; charset="UTF-8"',
      "Content-Transfer-Encoding: 7bit",
      "",
      opts.bodyHtml!,
      "",
      `--${boundary}--`,
    );
    return lines.join("\r\n");
  } else if (hasHtml) {
    headers.push('Content-Type: text/html; charset="UTF-8"');
    headers.push("Content-Transfer-Encoding: 7bit");
    return [headers.join("\r\n"), "", opts.bodyHtml].join("\r\n");
  } else {
    headers.push('Content-Type: text/plain; charset="UTF-8"');
    headers.push("Content-Transfer-Encoding: 7bit");
    return [headers.join("\r\n"), "", opts.bodyText ?? ""].join("\r\n");
  }
}

Deno.serve(async (req) => {
  const _cors = handleCors(req);
  if (_cors) return _cors;
  if (req.method !== "POST") {
    return new Response("Use POST", { status: 405 });
  }
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = (await req.json().catch(() => ({}))) as Partial<SendBody>;
  const to = sanitizeAddrList(body.to);
  if (to.length === 0) {
    return new Response(JSON.stringify({ error: "missing_to" }), {
      status: 400,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }
  const cc = sanitizeAddrList(body.cc);
  const bcc = sanitizeAddrList(body.bcc);
  const subject = (body.subject ?? "").toString();
  const bodyText = body.bodyText?.toString();
  const bodyHtml = body.bodyHtml?.toString();
  if (!bodyText && !bodyHtml) {
    return new Response(JSON.stringify({ error: "missing_body" }), {
      status: 400,
      headers: { ...corsHeaders(), "Content-Type": "application/json" },
    });
  }

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Look up display_name for the alias so the From: header looks right.
  const { data: aliasRow } = await sb
    .from("mail_aliases")
    .select("display_name")
    .eq("alias_email", caller.aliasEmail)
    .maybeSingle();
  const aliasDisplayName = (aliasRow?.display_name as string | undefined) ??
    "";

  // Mint the Google access token early — we need it to validate the
  // requested fromAddr against sendAs.list (self_owned only) before we
  // log the audit row.
  let tok: string;
  try {
    tok = await getGoogleAccessToken({
      subject: caller.impersonationSubject,
      scopes: [
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.settings.basic",
      ],
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "token_failed", detail: String(e) }),
      { status: 502, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }

  // Resolve the From: identity. shared_alias always pins to the alias.
  // self_owned can request any verified sendAs identity on their seat.
  let fromAddr = caller.aliasEmail;
  let fromName = aliasDisplayName;
  if (caller.mailboxKind === "self_owned" && body.fromAddr) {
    const resolved = await resolveSendAsForSelfOwned(
      tok,
      caller.impersonationSubject,
      body.fromAddr,
      aliasDisplayName,
    );
    if (!resolved) {
      return new Response(
        JSON.stringify({
          error: "from_addr_not_authorized",
          detail:
            "Requested From: address is not a verified sendAs identity on this mailbox.",
        }),
        { status: 403, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
      );
    }
    fromAddr = resolved.email;
    fromName = resolved.displayName;
  }

  const messageId = genMessageId(fromAddr);
  const rfc822 = buildRfc822({
    fromName,
    fromAddr,
    to,
    cc,
    bcc,
    subject,
    bodyText,
    bodyHtml,
    messageId,
    inReplyTo: body.inReplyTo,
    references: body.references,
  });
  const raw = b64url(new TextEncoder().encode(rfc822));

  // Insert audit row pre-send so we always have a trail. alias_email
  // records the *actual* From: used — for self_owned this may differ
  // from the caller's primary alias when a sendAs identity was picked.
  const { data: logRow, error: logErr } = await sb
    .from("mail_send_log")
    .insert({
      sender_user_id: caller.userId,
      alias_email: fromAddr,
      rfc822_message_id: messageId,
      thread_id: body.threadId ?? null,
      recipients: { to, cc, bcc },
      subject,
      status: "queued",
      related_entity_type: body.relatedEntityType ?? null,
      related_entity_id: body.relatedEntityId ?? null,
    })
    .select()
    .single();
  if (logErr) {
    return new Response(
      JSON.stringify({ error: "log_failed", detail: logErr.message }),
      { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }

  const sendRes = await fetch(`${GMAIL_API}/messages/send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tok}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(
      body.threadId
        ? { raw, threadId: body.threadId }
        : { raw },
    ),
  });
  if (!sendRes.ok) {
    const detail = await sendRes.text();
    await sb
      .from("mail_send_log")
      .update({ status: "failed", error_detail: detail.slice(0, 1000) })
      .eq("id", logRow!.id);
    return new Response(
      JSON.stringify({ error: "send_failed", detail }),
      { status: 502, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }
  const sent = await sendRes.json();

  await sb
    .from("mail_send_log")
    .update({
      status: "sent",
      gmail_message_id: sent.id,
      thread_id: sent.threadId,
    })
    .eq("id", logRow!.id);

  // Eager-upsert into messages cache so the SENT message appears in the
  // UI before the Pub/Sub receiver catches up. Cache rows are keyed by
  // alias_email = the inbox owner. For shared_alias that's the caller's
  // alias (each exec sees only their own SENT). For self_owned that's
  // the primary mailbox (the whole mailbox is theirs regardless of which
  // sendAs identity was used in From:).
  const cacheAliasEmail = caller.mailboxKind === "self_owned"
    ? caller.impersonationSubject.toLowerCase()
    : caller.aliasEmail;
  await sb.from("mail_messages_cache").upsert({
    gmail_message_id: sent.id,
    thread_id: sent.threadId,
    alias_email: cacheAliasEmail,
    from_addr: fromName ? `${fromName} <${fromAddr}>` : fromAddr,
    to_addrs: to,
    cc_addrs: cc,
    subject,
    snippet: (bodyText ?? bodyHtml ?? "").slice(0, 200).replace(/<[^>]+>/g, ""),
    internal_date: new Date().toISOString(),
    labels: sent.labelIds ?? ["SENT"],
    delivered_to: null,
  });

  return new Response(
    JSON.stringify({
      ok: true,
      gmailMessageId: sent.id,
      threadId: sent.threadId,
      rfc822MessageId: messageId,
    }),
    { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
});
