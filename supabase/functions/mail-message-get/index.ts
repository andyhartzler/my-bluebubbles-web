import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

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
  const r = await fetch(`${GMAIL_API}/messages/${messageId}?format=full`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!r.ok) {
    return new Response(JSON.stringify({ error: "get_failed" }), {
      status: r.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const m = await r.json();

  // TRUST BOUNDARY: exact-match alias check (review §C2-C4).
  // Self_owned mailboxes skip — every message in their mailbox is theirs.
  if (caller.mailboxKind !== "self_owned") {
    const headers = Object.fromEntries(
      (m.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [
          h.name.toLowerCase(),
          h.value,
        ],
      ),
    );
    if (!messageMatchesAlias(headers, caller.aliasEmail)) {
      return new Response(JSON.stringify({ error: "not_yours" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  return new Response(JSON.stringify(m), {
    headers: { "Content-Type": "application/json" },
  });
});
