// Phase 4: create a draft from the caller's alias via Gmail API.
//
// Trust boundary:
// 1. resolveCaller pins From: to caller's mail_aliases.alias_email — clients
//    cannot draft as someone else (the From: header in the request body is
//    ignored; we always overwrite from auth.uid()'s alias).
// 2. mail_send_log row is inserted with status: 'queued' so the audit trail
//    records intent; mail-draft-send will later insert a 'sent' row.
// 3. RFC 822 builder generates rfc822_message_id deterministically; unique
//    index on mail_send_log catches dupes.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { resolveSendAsForSelfOwned } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface DraftBody {
  to: string[];
  cc?: string[];
  bcc?: string[];
  subject: string;
  bodyText?: string;
  bodyHtml?: string;
  threadId?: string;
  inReplyTo?: string;
  references?: string[];
  relatedEntityType?: string;
  relatedEntityId?: string;
  /** Self_owned-only: verified sendAs address. Ignored for shared_alias. */
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
  if (req.method !== "POST") {
    return new Response("Use POST", { status: 405 });
  }
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = (await req.json().catch(() => ({}))) as Partial<DraftBody>;
  const to = sanitizeAddrList(body.to);
  const cc = sanitizeAddrList(body.cc);
  const bcc = sanitizeAddrList(body.bcc);
  const subject = (body.subject ?? "").toString();
  const bodyText = body.bodyText?.toString();
  const bodyHtml = body.bodyHtml?.toString();

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

  // Mint Google token early so we can validate the requested fromAddr
  // (self_owned only) before logging the audit row.
  let tok: string;
  try {
    tok = await getGoogleAccessToken({
      subject: caller.impersonationSubject,
      scopes: [
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.settings.basic",
      ],
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "token_failed", detail: String(e) }),
      { status: 502, headers: { "Content-Type": "application/json" } },
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
        { status: 403, headers: { "Content-Type": "application/json" } },
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

  // Insert audit row with status 'queued' — drafts are pre-send intent.
  // alias_email records the actual From: used.
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
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const draftRes = await fetch(`${GMAIL_API}/drafts`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tok}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: body.threadId
        ? { raw, threadId: body.threadId }
        : { raw },
    }),
  });
  if (!draftRes.ok) {
    const detail = await draftRes.text();
    await sb
      .from("mail_send_log")
      .update({ status: "failed", error_detail: detail.slice(0, 1000) })
      .eq("id", logRow!.id);
    return new Response(
      JSON.stringify({ error: "draft_create_failed", detail }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  const draft = await draftRes.json();
  const gmailMessageId = draft.message?.id as string | undefined;
  const threadId = draft.message?.threadId as string | undefined;

  // Update the audit row with the draft's gmail_message_id (still 'queued').
  await sb
    .from("mail_send_log")
    .update({
      gmail_message_id: gmailMessageId ?? null,
      thread_id: threadId ?? body.threadId ?? null,
    })
    .eq("id", logRow!.id);

  return new Response(
    JSON.stringify({
      ok: true,
      draftId: draft.id,
      gmailMessageId,
      threadId,
      rfc822MessageId: messageId,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
