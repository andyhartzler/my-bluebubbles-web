import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

interface GmailHeader {
  name: string;
  value: string;
}

/**
 * Decodes Gmail's base64url-encoded raw message body. Gmail uses URL-safe
 * base64 (- and _ instead of + and /) and omits padding — atob() needs the
 * standard alphabet plus padding restored.
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
 * Sanitizes a subject string for use as a filesystem filename. Strips
 * characters that are illegal on Windows (\\ / : * ? " < > |), control
 * characters, and trims whitespace + trailing dots. Falls back to "message"
 * for empty / fully-stripped inputs. Capped at 120 chars to keep paths sane.
 */
function sanitizeFilename(subject: string | undefined | null): string {
  if (!subject) return "message";
  const cleaned = subject
    // eslint-disable-next-line no-control-regex
    .replace(/[\\\/:*?"<>|\x00-\x1F]/g, "_")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\.+$/, "");
  if (cleaned.length === 0) return "message";
  return cleaned.slice(0, 120);
}

/**
 * RFC 5987 / 6266 safe filename for Content-Disposition. Plain ASCII filenames
 * go in the unquoted slot; non-ASCII names ALSO get the filename* slot with
 * UTF-8 percent-encoding so modern browsers decode them correctly.
 */
function dispositionFilename(name: string): string {
  const safe = name.replace(/[\\"\r\n]/g, "_");
  const ascii = /^[\x20-\x7E]*$/.test(safe);
  if (ascii) return `attachment; filename="${safe}.eml"`;
  const encoded = encodeURIComponent(`${name}.eml`);
  return `attachment; filename="${safe}.eml"; filename*=UTF-8''${encoded}`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const messageId: string = body.messageId;
  if (!messageId) {
    return new Response(JSON.stringify({ error: "missing_messageId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // TRUST BOUNDARY: pre-fetch metadata + alias check BEFORE downloading the
  // raw message bytes. Without this, a shared_alias exec could iterate
  // messageIds and pull other execs' EML bodies. Self_owned skips the alias
  // check (caller owns the mailbox) but we still fetch metadata for Subject
  // → filename and let Gmail return 404 on bad ids.
  const metaParams = new URLSearchParams({ format: "metadata" });
  for (const h of ["From", "To", "Cc", "Bcc", "Delivered-To", "Subject"]) {
    metaParams.append("metadataHeaders", h);
  }
  const metaRes = await fetch(
    `${GMAIL_API}/messages/${messageId}?${metaParams}`,
    { headers: { Authorization: `Bearer ${tok}` } },
  );
  if (!metaRes.ok) {
    return new Response(JSON.stringify({ error: "meta_fetch_failed" }), {
      status: metaRes.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const meta = await metaRes.json();
  const headers = Object.fromEntries(
    (meta.payload?.headers ?? []).map(
      (h: GmailHeader) => [h.name.toLowerCase(), h.value],
    ),
  );
  if (
    caller.mailboxKind !== "self_owned" &&
    !messageMatchesAlias(headers, caller.aliasEmail)
  ) {
    return new Response(JSON.stringify({ error: "not_yours" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Fetch raw RFC 822. Gmail returns it as base64url-encoded text in the
  // `raw` field — we have to decode to bytes here so the response body is
  // an honest message/rfc822 stream callers can save to disk or pipe to
  // an .eml viewer.
  const rawRes = await fetch(
    `${GMAIL_API}/messages/${messageId}?format=raw`,
    { headers: { Authorization: `Bearer ${tok}` } },
  );
  if (!rawRes.ok) {
    return new Response(JSON.stringify({ error: "raw_fetch_failed" }), {
      status: rawRes.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const rawJson = await rawRes.json();
  if (typeof rawJson.raw !== "string") {
    return new Response(JSON.stringify({ error: "raw_missing" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  const bytes = decodeBase64Url(rawJson.raw);
  const subject = (headers["subject"] as string | undefined) ?? "";
  const filename = sanitizeFilename(subject);

  return new Response(bytes, {
    headers: {
      "Content-Type": "message/rfc822",
      "Content-Length": String(bytes.byteLength),
      "Content-Disposition": dispositionFilename(filename),
      "Cache-Control": "private, no-store",
      // Surface the resolved subject so the dart client can use it without
      // re-parsing the EML envelope. Custom header is safe — non-CORS-sensitive
      // for our same-origin Supabase functions endpoint.
      "X-Subject": encodeURIComponent(subject),
    },
  });
});
