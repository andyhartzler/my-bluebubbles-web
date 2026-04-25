import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const META_CONCURRENCY = 10;

// Operators stripped from any client-supplied query — these would let a
// caller broaden the implicit alias clamp (review §C1).
const FORBIDDEN_OPERATORS = [
  "deliveredto",
  "from",
  "to",
  "cc",
  "bcc",
  "rfc822msgid",
  "list",
  "label",
];

function sanitizeUserQuery(raw: string): string {
  let q = raw;
  for (const op of FORBIDDEN_OPERATORS) {
    q = q.replace(new RegExp(`\\b${op}:\\S+`, "gi"), "");
  }
  // Strip standalone OR — explicit AND between operands is enforced by the
  // wrap below; OR would let a user re-broaden the query.
  q = q.replace(/\bOR\b/gi, "");
  // Strip parens that could break the wrap.
  q = q.replace(/[()]/g, "");
  return q.trim();
}

async function chunkedMap<T, U>(
  items: T[],
  size: number,
  fn: (t: T) => Promise<U>,
): Promise<U[]> {
  const out: U[] = [];
  for (let i = 0; i < items.length; i += size) {
    const slice = items.slice(i, i + size);
    const part = await Promise.all(slice.map(fn));
    out.push(...part);
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const pageToken: string | undefined = body.pageToken;
  const maxResults: number = Math.min(
    Math.max(body.maxResults ?? 25, 1),
    100,
  );
  // SERVER-INJECTED ALIAS CLAMP — defense layer 1.
  const aliasClamp =
    `(deliveredto:${caller.aliasEmail} OR from:${caller.aliasEmail})`;
  const userQ = sanitizeUserQuery(typeof body.q === "string" ? body.q : "");
  const q = userQ ? `${aliasClamp} AND (${userQ})` : aliasClamp;

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const params = new URLSearchParams({ q, maxResults: String(maxResults) });
  if (pageToken) params.set("pageToken", pageToken);
  const listRes = await fetch(`${GMAIL_API}/messages?${params}`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!listRes.ok) {
    return new Response(
      JSON.stringify({ error: "list_failed", detail: await listRes.text() }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  const list = await listRes.json();
  const ids: string[] = (list.messages ?? []).map((m: { id: string }) => m.id);

  // Concurrency-capped metadata fetch — Gmail API quota = 250 units/sec/user,
  // messages.get = 5 units. 10 concurrent -> ~50 units/burst, comfortable.
  const messages = await chunkedMap(ids, META_CONCURRENCY, async (id) => {
    const r = await fetch(
      `${GMAIL_API}/messages/${id}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) return null;
    const m = await r.json();
    const headers = Object.fromEntries(
      (m.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
      ),
    );
    // TRUST BOUNDARY layer 2: exact-match alias check (review §C2-C4).
    if (!messageMatchesAlias(headers, caller.aliasEmail)) return null;
    return {
      id: m.id,
      threadId: m.threadId,
      from: headers["from"] ?? "",
      to: (headers["to"] ?? "").split(",").map((s: string) => s.trim()).filter(
        Boolean,
      ),
      cc: (headers["cc"] ?? "").split(",").map((s: string) => s.trim()).filter(
        Boolean,
      ),
      subject: headers["subject"] ?? "",
      snippet: m.snippet ?? "",
      internalDate: m.internalDate,
      labels: m.labelIds ?? [],
    };
  });

  return new Response(
    JSON.stringify({
      messages: messages.filter(Boolean),
      nextPageToken: list.nextPageToken ?? null,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
