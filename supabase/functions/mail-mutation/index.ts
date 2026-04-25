// mail-mutation: applies Gmail label mutations (read/unread, star/unstar,
// archive, trash, untrash, custom labels) on the shared crm@ mailbox after
// per-message alias verification.
//
// TRUST BOUNDARY: For each requested messageId we fetch metadata headers and
// confirm the caller's alias appears in From/To/Cc/Bcc/Delivered-To via
// `messageMatchesAlias` BEFORE issuing any users.messages.modify. Verified
// IDs are mutated; unauthorized IDs are silently skipped (returned in
// `skipped`) so a caller cannot mutate someone else's mail by guessing IDs.
//
// Wire-shape:
//   POST { messageIds: string[], addLabelIds?: string[], removeLabelIds?: string[] }
//   200  { ok: true, mutated: string[], skipped: string[], errors: Record<id,msg> }

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const CONCURRENCY = 10;

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

interface VerifyResult {
  id: string;
  authorized: boolean;
  error?: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const messageIds: string[] = Array.isArray(body.messageIds)
    ? body.messageIds.filter((s: unknown): s is string =>
      typeof s === "string" && s.length > 0
    )
    : [];
  const addLabelIds: string[] = Array.isArray(body.addLabelIds)
    ? body.addLabelIds.filter((s: unknown): s is string =>
      typeof s === "string" && s.length > 0
    )
    : [];
  const removeLabelIds: string[] = Array.isArray(body.removeLabelIds)
    ? body.removeLabelIds.filter((s: unknown): s is string =>
      typeof s === "string" && s.length > 0
    )
    : [];

  if (messageIds.length === 0) {
    return new Response(
      JSON.stringify({ error: "missing_messageIds" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
  if (addLabelIds.length === 0 && removeLabelIds.length === 0) {
    return new Response(
      JSON.stringify({ error: "missing_label_changes" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const errors: Record<string, string> = {};

  // PHASE 1: per-message alias verification.
  // messages.get?format=metadata = 5 quota units. 10 concurrent ~ 50 u/burst.
  const verifyResults: VerifyResult[] = await chunkedMap(
    messageIds,
    CONCURRENCY,
    async (id): Promise<VerifyResult> => {
      const r = await fetch(
        `${GMAIL_API}/messages/${id}?format=metadata` +
          `&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc` +
          `&metadataHeaders=Bcc&metadataHeaders=Delivered-To`,
        { headers: { Authorization: `Bearer ${tok}` } },
      );
      if (!r.ok) {
        return {
          id,
          authorized: false,
          error: `verify_failed_${r.status}`,
        };
      }
      const m = await r.json();
      const headers = Object.fromEntries(
        (m.payload?.headers ?? []).map(
          (h: { name: string; value: string }) => [
            h.name.toLowerCase(),
            h.value,
          ],
        ),
      );
      const ok = messageMatchesAlias(headers, caller.aliasEmail);
      return { id, authorized: ok };
    },
  );

  const authorizedIds: string[] = [];
  const skippedIds: string[] = [];
  for (const v of verifyResults) {
    if (v.authorized) {
      authorizedIds.push(v.id);
    } else {
      skippedIds.push(v.id);
      if (v.error) errors[v.id] = v.error;
    }
  }

  // PHASE 2: apply mutations to verified IDs.
  // messages.modify = 5 quota units. 10 concurrent ~ 50 u/burst.
  const modifyBody: Record<string, string[]> = {};
  if (addLabelIds.length) modifyBody.addLabelIds = addLabelIds;
  if (removeLabelIds.length) modifyBody.removeLabelIds = removeLabelIds;
  const modifyJson = JSON.stringify(modifyBody);

  const mutated: string[] = [];
  await chunkedMap(authorizedIds, CONCURRENCY, async (id) => {
    const r = await fetch(`${GMAIL_API}/messages/${id}/modify`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${tok}`,
        "Content-Type": "application/json",
      },
      body: modifyJson,
    });
    if (!r.ok) {
      const detail = await r.text().catch(() => "");
      errors[id] = `modify_failed_${r.status}${detail ? `: ${detail}` : ""}`;
      return;
    }
    mutated.push(id);
  });

  return new Response(
    JSON.stringify({
      ok: true,
      mutated,
      skipped: skippedIds,
      errors,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
