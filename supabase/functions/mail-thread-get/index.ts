import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });
  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const threadId: string = body.threadId;
  if (!threadId) {
    return new Response(JSON.stringify({ error: "missing_threadId" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const r = await fetch(`${GMAIL_API}/threads/${threadId}?format=full`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!r.ok) {
    return new Response(JSON.stringify({ error: "thread_get_failed" }), {
      status: r.status,
      headers: { "Content-Type": "application/json" },
    });
  }
  const thread = await r.json();

  // TRUST BOUNDARY: exact-match alias against parsed addresses (review §C2-C4).
  // Self_owned mailboxes skip — every message in their mailbox is theirs.
  const isSelfOwned = caller.mailboxKind === "self_owned";
  const allMessages = thread.messages ?? [];
  const messages = isSelfOwned
    ? allMessages
    : allMessages.filter(
      (m: { payload?: { headers?: { name: string; value: string }[] } }) => {
        const headers = Object.fromEntries(
          (m.payload?.headers ?? []).map((h) => [
            h.name.toLowerCase(),
            h.value,
          ]),
        );
        return messageMatchesAlias(headers, caller.aliasEmail);
      },
    );

  if (messages.length === 0) {
    return new Response(JSON.stringify({ error: "thread_not_yours" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ id: thread.id, messages }), {
    headers: { "Content-Type": "application/json" },
  });
});
