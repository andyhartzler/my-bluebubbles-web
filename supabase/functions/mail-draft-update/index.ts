// Phase 4: update an existing draft owned by the caller's alias.
//
// Trust boundary:
// 1. resolveCaller establishes caller identity from JWT.
// 2. We fetch the existing draft, parse its From: header, and exact-match
//    against caller's alias via messageMatchesAlias. Mismatch -> 403.
// 3. We rebuild the RFC 822 with the caller's alias pinned as From, ignoring
//    any client-supplied From in the body.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface UpdateBody {
  draftId: string;
  to: string[];
  cc?: string[];
  bcc?: string[];
  subject: string;
  bodyText?: string;
  bodyHtml?: string;
  threadId?: string;
  inReplyTo?: string;
  references?: string[];
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

  const body = (await req.json().catch(() => ({}))) as Partial<UpdateBody>;
  const draftId = (body.draftId ?? "").toString();
  if (!draftId) {
    return new Response(JSON.stringify({ error: "missing_draftId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
  const to = sanitizeAddrList(body.to);
  const cc = sanitizeAddrList(body.cc);
  const bcc = sanitizeAddrList(body.bcc);
  const subject = (body.subject ?? "").toString();
  const bodyText = body.bodyText?.toString();
  const bodyHtml = body.bodyHtml?.toString();

  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // 1. Fetch the existing draft, full format, to verify ownership and grab
  //    the current threadId.
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
  // TRUST BOUNDARY: shared_alias drafts must match the caller's alias on
  // From: — only the creator can update. Self_owned drafts are all the
  // caller's by definition (their own mailbox).
  if (
    caller.mailboxKind !== "self_owned" &&
    !messageMatchesAlias(existingHeaders, caller.aliasEmail)
  ) {
    return new Response(JSON.stringify({ error: "not_yours" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  const existingThreadId = existing.message?.threadId as string | undefined;
  const threadId = body.threadId ?? existingThreadId;

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: aliasRow } = await sb
    .from("mail_aliases")
    .select("display_name")
    .eq("alias_email", caller.aliasEmail)
    .maybeSingle();
  const fromName = aliasRow?.display_name ?? "";

  const messageId = genMessageId(caller.aliasEmail);
  const rfc822 = buildRfc822({
    fromName,
    fromAddr: caller.aliasEmail,
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

  const updateRes = await fetch(`${GMAIL_API}/drafts/${draftId}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${tok}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: threadId
        ? { raw, threadId }
        : { raw },
    }),
  });
  if (!updateRes.ok) {
    return new Response(
      JSON.stringify({
        error: "draft_update_failed",
        detail: await updateRes.text(),
      }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  const updated = await updateRes.json();

  return new Response(
    JSON.stringify({
      ok: true,
      draftId: updated.id,
      gmailMessageId: updated.message?.id,
      threadId: updated.message?.threadId,
      rfc822MessageId: messageId,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
