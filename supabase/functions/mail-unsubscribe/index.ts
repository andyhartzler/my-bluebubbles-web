// mail-unsubscribe: handles RFC 8058 (one-click) + RFC 2369 (List-Unsubscribe)
// header-driven unsubscribe flows.
//
// Trust boundary:
// 1. resolveCaller authenticates the request and pulls the caller's alias_email.
// 2. We refuse to act unless messageMatchesAlias() confirms the message was
//    addressed to or sent from this caller's alias. This prevents an exec
//    from unsubscribing another exec's mailing-list subscriptions just by
//    knowing a Gmail message id.
//
// Decision tree (post-verification):
//   1. List-Unsubscribe-Post: List-Unsubscribe=One-Click  (+ https URL present)
//      -> POST `List-Unsubscribe=One-Click` to that URL  (RFC 8058 one-click)
//   2. https URL present (no one-click marker)
//      -> GET the URL                                    (RFC 2369 fallback)
//   3. mailto: URL present
//      -> Send empty email to that mailto via Gmail API   (RFC 2369 fallback)
//   4. None of the above -> 422 no_unsubscribe_header
//
// All outbound network calls have a 5s timeout. HTTP 4xx/5xx surfaces as a
// descriptive `unsubscribe_failed` error.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

import { handleCors, corsHeaders } from "../_shared/cors.ts";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const NETWORK_TIMEOUT_MS = 5000;

// Gmail returns header values verbatim per RFC; folding lines (CRLF + WSP)
// can show up. Normalize to a single space before parsing.
function unfoldHeader(v: string): string {
  return v.replace(/\r?\n[ \t]+/g, " ").trim();
}

interface ParsedUnsubscribe {
  https: string | null;
  mailto: string | null;
}

/**
 * Parses an RFC 2369 List-Unsubscribe header value into the (first) https URL
 * and the (first) mailto URL it lists. Format:
 *   <https://example.com/unsub>, <mailto:unsub@example.com>
 *
 * RFC interpretation calls:
 *   - We only accept https URLs (not http) — POSTing one-click tokens over
 *     plaintext defeats the security guarantees senders rely on (RFC 8058 §4).
 *   - We accept multiple URLs and pick first-of-each-scheme. RFC 2369 says
 *     URIs are listed in order of preference, so first https wins, first
 *     mailto wins.
 *   - We tolerate (but ignore) any non-https/non-mailto URIs (ftp:, etc.).
 */
function parseListUnsubscribe(raw: string | undefined): ParsedUnsubscribe {
  if (!raw) return { https: null, mailto: null };
  const v = unfoldHeader(raw);
  // Match every <...> bracketed URI in order.
  const matches = v.matchAll(/<\s*([^<>\s]+)\s*>/g);
  let https: string | null = null;
  let mailto: string | null = null;
  for (const m of matches) {
    const uri = m[1].trim();
    if (!https && /^https:\/\//i.test(uri)) https = uri;
    else if (!mailto && /^mailto:/i.test(uri)) mailto = uri;
    if (https && mailto) break;
  }
  return { https, mailto };
}

/**
 * Returns true iff the List-Unsubscribe-Post header value declares this
 * sender supports RFC 8058 one-click (`List-Unsubscribe=One-Click`).
 * Tolerates surrounding whitespace + case variants per RFC 8058 §3.1.
 */
function isOneClick(raw: string | undefined): boolean {
  if (!raw) return false;
  const v = unfoldHeader(raw).toLowerCase();
  // RFC 8058 fixes the value as exactly "List-Unsubscribe=One-Click".
  return v === "list-unsubscribe=one-click";
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/**
 * Builds a minimal RFC 822 message: `From: <alias>` to `<recipient>` with
 * an empty body and an "Unsubscribe" subject. RFC 2369 doesn't actually
 * mandate any specific subject/body — most ESPs trigger off the From: address
 * being the subscriber's address. We add a clear subject so the unsubscribe
 * row in the operator's outbox is human-readable.
 */
function buildUnsubscribeRfc822(
  fromAddr: string,
  toAddr: string,
  subject: string,
): string {
  const lines = [
    `From: <${fromAddr}>`,
    `To: <${toAddr}>`,
    `Subject: ${subject}`,
    `Date: ${new Date().toUTCString()}`,
    `MIME-Version: 1.0`,
    `Content-Type: text/plain; charset="UTF-8"`,
    `Content-Transfer-Encoding: 7bit`,
    "",
    "",
  ];
  return lines.join("\r\n");
}

Deno.serve(async (req) => {
  const _cors = handleCors(req);
  if (_cors) return _cors;
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const messageId: string | undefined = body.messageId;
  if (!messageId || typeof messageId !== "string") {
    return jsonResponse(400, { error: "missing_messageId" });
  }

  // gmail.modify lets us read the headers; gmail.send is required for the
  // mailto fallback path. Mint both up front (token is cached per scope set,
  // so requesting both here doesn't waste anything if we end up only needing
  // modify).
  let tok: string;
  try {
    tok = await getGoogleAccessToken({
      subject: caller.impersonationSubject,
      scopes: [
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.send",
      ],
    });
  } catch (e) {
    return jsonResponse(502, { error: "token_failed", detail: String(e) });
  }

  // Phase 1: pull just enough headers to a) verify alias ownership, and
  // b) read the List-Unsubscribe headers. We need delivered-to/to/cc/bcc/from
  // for the trust boundary check + the two list-unsubscribe* headers.
  const headerNames = [
    "Delivered-To",
    "To",
    "Cc",
    "Bcc",
    "From",
    "List-Unsubscribe",
    "List-Unsubscribe-Post",
  ];
  const metadataUrl =
    `${GMAIL_API}/messages/${messageId}?format=metadata&` +
    headerNames.map((h) => `metadataHeaders=${encodeURIComponent(h)}`).join("&");

  const metaRes = await fetch(metadataUrl, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!metaRes.ok) {
    return jsonResponse(metaRes.status, {
      error: "get_failed",
      detail: (await metaRes.text()).slice(0, 500),
    });
  }
  const meta = await metaRes.json();

  const headers: Record<string, string> = Object.fromEntries(
    (meta.payload?.headers ?? []).map(
      (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
    ),
  );

  // TRUST BOUNDARY: caller must be a participant of this message. Without
  // this a shared_alias exec could unsubscribe another exec's mailing-list
  // subscriptions just by knowing a message id. Self_owned skips — caller
  // owns the mailbox.
  if (
    caller.mailboxKind !== "self_owned" &&
    !messageMatchesAlias(headers, caller.aliasEmail)
  ) {
    return jsonResponse(403, { error: "not_yours" });
  }

  const parsed = parseListUnsubscribe(headers["list-unsubscribe"]);
  const oneClick = isOneClick(headers["list-unsubscribe-post"]);

  // Path 1: RFC 8058 one-click POST.
  if (oneClick && parsed.https) {
    let res: Response;
    try {
      res = await fetchWithTimeout(
        parsed.https,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: "List-Unsubscribe=One-Click",
        },
        NETWORK_TIMEOUT_MS,
      );
    } catch (e) {
      return jsonResponse(502, {
        error: "unsubscribe_failed",
        method: "one-click-post",
        url: parsed.https,
        detail: `network: ${String(e)}`,
      });
    }
    if (!res.ok) {
      return jsonResponse(502, {
        error: "unsubscribe_failed",
        method: "one-click-post",
        url: parsed.https,
        detail: `http ${res.status}`,
      });
    }
    return jsonResponse(200, {
      ok: true,
      method: "one-click-post",
      url: parsed.https,
    });
  }

  // Path 2: HTTP GET on the https URL. This is what a browser does when the
  // user clicks the "Unsubscribe" link Gmail surfaces — most senders accept
  // a plain GET as a confirmation that the recipient wants out.
  if (parsed.https) {
    let res: Response;
    try {
      res = await fetchWithTimeout(
        parsed.https,
        { method: "GET" },
        NETWORK_TIMEOUT_MS,
      );
    } catch (e) {
      return jsonResponse(502, {
        error: "unsubscribe_failed",
        method: "http-get",
        url: parsed.https,
        detail: `network: ${String(e)}`,
      });
    }
    if (!res.ok) {
      return jsonResponse(502, {
        error: "unsubscribe_failed",
        method: "http-get",
        url: parsed.https,
        detail: `http ${res.status}`,
      });
    }
    return jsonResponse(200, {
      ok: true,
      method: "http-get",
      url: parsed.https,
    });
  }

  // Path 3: mailto: fallback. RFC 2369 says senders MAY include a mailto:
  // URL; the recipient sends an empty email there to unsubscribe. We use
  // Gmail's users.messages.send so the From: header is the caller's alias
  // (matches what the sender's list software is keyed off).
  if (parsed.mailto) {
    // mailto:foo@bar  -> foo@bar  (strip ?subject=... params if any)
    const mailtoTarget = parsed.mailto.slice("mailto:".length).split("?")[0];
    if (!mailtoTarget || !/^[^\s<>"]+@[^\s<>"]+$/.test(mailtoTarget)) {
      return jsonResponse(422, {
        error: "unsubscribe_failed",
        method: "mailto",
        url: parsed.mailto,
        detail: "could not parse mailto target",
      });
    }
    // Some senders embed `?subject=unsubscribe` in the mailto. Honor it
    // when present; otherwise default to "unsubscribe".
    const mailtoQuery = parsed.mailto.includes("?")
      ? parsed.mailto.slice(parsed.mailto.indexOf("?") + 1)
      : "";
    const subjectParam = new URLSearchParams(mailtoQuery).get("subject");
    const subject = subjectParam ?? "unsubscribe";
    const rfc822 = buildUnsubscribeRfc822(
      caller.aliasEmail,
      mailtoTarget,
      subject,
    );
    const raw = b64url(new TextEncoder().encode(rfc822));

    let sendRes: Response;
    try {
      sendRes = await fetchWithTimeout(
        `${GMAIL_API}/messages/send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${tok}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ raw }),
        },
        NETWORK_TIMEOUT_MS,
      );
    } catch (e) {
      return jsonResponse(502, {
        error: "unsubscribe_failed",
        method: "mailto",
        url: parsed.mailto,
        detail: `network: ${String(e)}`,
      });
    }
    if (!sendRes.ok) {
      return jsonResponse(502, {
        error: "unsubscribe_failed",
        method: "mailto",
        url: parsed.mailto,
        detail: `gmail send: ${(await sendRes.text()).slice(0, 500)}`,
      });
    }
    return jsonResponse(200, {
      ok: true,
      method: "mailto",
      url: parsed.mailto,
    });
  }

  // Path 4: nothing actionable on the message.
  return jsonResponse(422, { error: "no_unsubscribe_header" });
});
