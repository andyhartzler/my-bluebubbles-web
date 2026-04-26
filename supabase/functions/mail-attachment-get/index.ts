import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface GmailHeader {
  name: string;
  value: string;
}

interface GmailPart {
  partId?: string;
  mimeType?: string;
  filename?: string;
  body?: {
    attachmentId?: string;
    size?: number;
    data?: string;
  };
  parts?: GmailPart[];
}

/**
 * Recursively walks a Gmail message payload tree and returns the first part
 * whose body.attachmentId matches the supplied id. Gmail nests attachments
 * arbitrarily deep — multipart/mixed -> multipart/alternative -> ... — so a
 * flat scan misses them.
 */
function findPartByAttachmentId(
  part: GmailPart | undefined,
  attachmentId: string,
): GmailPart | null {
  if (!part) return null;
  if (part.body?.attachmentId === attachmentId) return part;
  for (const child of part.parts ?? []) {
    const hit = findPartByAttachmentId(child, attachmentId);
    if (hit) return hit;
  }
  return null;
}

/**
 * Decodes Gmail's base64url-encoded attachment data. Gmail uses URL-safe
 * base64 (- and _ instead of + and /) and omits padding — atob() needs
 * the standard alphabet plus padding restored.
 */
function decodeBase64Url(data: string): Uint8Array {
  let b64 = data.replace(/-/g, "+").replace(/_/g, "/");
  const pad = b64.length % 4;
  if (pad) b64 += "=".repeat(4 - pad);
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/**
 * RFC 5987 / 6266 safe filename for Content-Disposition. Plain ASCII filenames
 * go in the unquoted slot; anything with quotes, backslashes, or non-ASCII is
 * also exposed via filename* with UTF-8 percent-encoding so modern browsers
 * decode it correctly.
 */
function dispositionFilename(name: string): string {
  const safe = name.replace(/[\\"\r\n]/g, "_");
  const ascii = /^[\x20-\x7E]*$/.test(safe);
  if (ascii) return `attachment; filename="${safe}"`;
  const encoded = encodeURIComponent(name);
  return `attachment; filename="${safe}"; filename*=UTF-8''${encoded}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const messageId: string = body.messageId;
  const attachmentId: string = body.attachmentId;
  if (!messageId || !attachmentId) {
    return new Response(
      JSON.stringify({ error: "missing_messageId_or_attachmentId" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // TRUST BOUNDARY: pre-fetch metadata + alias check BEFORE downloading bytes.
  // Without this, a shared_alias exec could iterate messageIds and pull
  // other execs' attachments. Self_owned skips — caller owns the mailbox.
  if (caller.mailboxKind !== "self_owned") {
    const metaParams = new URLSearchParams({ format: "metadata" });
    for (const h of ["From", "To", "Cc", "Bcc", "Delivered-To"]) {
      metaParams.append("metadataHeaders", h);
    }
    const metaRes = await fetch(
      `${GMAIL_API}/messages/${messageId}?${metaParams}`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!metaRes.ok) {
      return new Response(
        JSON.stringify({ error: "meta_fetch_failed" }),
        {
          status: metaRes.status,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    const meta = await metaRes.json();
    const headers = Object.fromEntries(
      (meta.payload?.headers ?? []).map(
        (h: GmailHeader) => [h.name.toLowerCase(), h.value],
      ),
    );
    if (!messageMatchesAlias(headers, caller.aliasEmail)) {
      return new Response(JSON.stringify({ error: "not_yours" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  // Need full payload tree to discover the attachment's mimeType + filename.
  // The metadata format above intentionally omits parts to keep the trust
  // check cheap; we re-fetch with format=full only after authorization passes.
  const fullRes = await fetch(
    `${GMAIL_API}/messages/${messageId}?format=full`,
    { headers: { Authorization: `Bearer ${tok}` } },
  );
  if (!fullRes.ok) {
    return new Response(
      JSON.stringify({ error: "full_fetch_failed" }),
      { status: fullRes.status, headers: { "Content-Type": "application/json" } },
    );
  }
  const full = await fullRes.json();
  const part = findPartByAttachmentId(full.payload, attachmentId);
  if (!part) {
    return new Response(
      JSON.stringify({ error: "attachment_not_found" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const attRes = await fetch(
    `${GMAIL_API}/messages/${messageId}/attachments/${attachmentId}`,
    { headers: { Authorization: `Bearer ${tok}` } },
  );
  if (!attRes.ok) {
    return new Response(
      JSON.stringify({ error: "attachment_fetch_failed" }),
      { status: attRes.status, headers: { "Content-Type": "application/json" } },
    );
  }
  const att = await attRes.json();
  if (typeof att.data !== "string") {
    return new Response(
      JSON.stringify({ error: "attachment_no_data" }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  const bytes = decodeBase64Url(att.data);
  const mimeType = part.mimeType || "application/octet-stream";
  const filename = part.filename || `attachment-${attachmentId.slice(0, 8)}`;

  return new Response(bytes, {
    headers: {
      "Content-Type": mimeType,
      "Content-Length": String(bytes.byteLength),
      "Content-Disposition": dispositionFilename(filename),
      "Cache-Control": "private, no-store",
    },
  });
});
