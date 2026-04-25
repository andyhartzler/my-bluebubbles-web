// Phase 4: list drafts owned by the caller's alias.
//
// Drafts don't have Delivered-To headers (they're never delivered), so the
// alias-clamp-by-Gmail-query approach used in mail-list won't work. We list
// all drafts on the shared mailbox, then post-filter via messageMatchesAlias
// against the From: header (which mail-draft-create pinned to the caller's
// alias). This is the same trust boundary the rest of the mail client uses.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const META_CONCURRENCY = 10;

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

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const params = new URLSearchParams({ maxResults: String(maxResults) });
  if (pageToken) params.set("pageToken", pageToken);
  const listRes = await fetch(`${GMAIL_API}/drafts?${params}`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!listRes.ok) {
    return new Response(
      JSON.stringify({ error: "list_failed", detail: await listRes.text() }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }
  const list = await listRes.json();
  const draftIds: string[] = (list.drafts ?? []).map(
    (d: { id: string }) => d.id,
  );

  // Concurrency-capped metadata fetch — Gmail API quota = 250 units/sec/user,
  // drafts.get = 5 units. 10 concurrent -> ~50 units/burst, comfortable.
  const drafts = await chunkedMap(draftIds, META_CONCURRENCY, async (id) => {
    const r = await fetch(
      `${GMAIL_API}/drafts/${id}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) return null;
    const d = await r.json();
    const headers = Object.fromEntries(
      (d.message?.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
      ),
    );
    // TRUST BOUNDARY: exact-match alias check on From: header.
    if (!messageMatchesAlias(headers, caller.aliasEmail)) return null;
    return {
      id: d.id,
      message: {
        id: d.message?.id,
        threadId: d.message?.threadId,
        from: headers["from"] ?? "",
        to: (headers["to"] ?? "").split(",").map((s: string) => s.trim()).filter(
          Boolean,
        ),
        cc: (headers["cc"] ?? "").split(",").map((s: string) => s.trim()).filter(
          Boolean,
        ),
        subject: headers["subject"] ?? "",
        snippet: d.message?.snippet ?? "",
        internalDate: d.message?.internalDate,
        labels: d.message?.labelIds ?? [],
      },
    };
  });

  return new Response(
    JSON.stringify({
      drafts: drafts.filter(Boolean),
      nextPageToken: list.nextPageToken ?? null,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
