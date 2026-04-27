// mail-permanent-delete: hard-deletes Gmail messages on the shared crm@
// mailbox via users.messages.delete after per-message alias verification
// AND a "must be in TRASH/SPAM" safety gate.
//
// TRUST BOUNDARY: For each requested messageId we fetch metadata headers +
// labelIds and confirm:
//   1. The caller's alias appears in From/To/Cc/Bcc/Delivered-To
//      (`messageMatchesAlias`).
//   2. The message is currently labeled TRASH or SPAM (NOT INBOX).
//
// users.messages.delete is permanent and bypasses Gmail's 30-day Trash
// recovery. To prevent accidental loss we require the caller to have
// already trashed the message — the UI flow is "trash, then empty trash."
// This mirrors tmail's own UI: the only path that batch-permanent-deletes
// is the "Empty Trash" button.
//
// Wire-shape:
//   POST { messageIds: string[] }
//   200  { ok: true, deleted: string[], skipped: string[], errors: {<id>: msg} }
//
// Per-message error codes surfaced via `errors`:
//   verify_failed_<status>   — metadata fetch failed
//   not_in_trash             — message has INBOX label, refuse to hard-delete
//   delete_failed_<status>   — users.messages.delete returned non-2xx

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { resolveCaller } from "../_shared/alias-resolver.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";

import { handleCors, corsHeaders } from "../_shared/cors.ts";
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
  // Distinguish "alias mismatch" (silent skip) from "not in trash"
  // (per-message error) from "fetch failed" (per-message error).
  reason?: "alias_mismatch" | "not_in_trash" | string;
}

Deno.serve(async (req) => {
  const _cors = handleCors(req);
  if (_cors) return _cors;
  if (req.method !== "POST") return new Response("Use POST", { status: 405 });

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  const body = await req.json().catch(() => ({}));
  const messageIds: string[] = Array.isArray(body.messageIds)
    ? body.messageIds.filter((s: unknown): s is string =>
      typeof s === "string" && s.length > 0
    )
    : [];

  if (messageIds.length === 0) {
    return new Response(
      JSON.stringify({ error: "missing_messageIds" }),
      { status: 400, headers: { ...corsHeaders(), "Content-Type": "application/json" } },
    );
  }

  const tok = await getGoogleAccessToken({
    subject: caller.impersonationSubject,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const errors: Record<string, string> = {};
  const isSelfOwned = caller.mailboxKind === "self_owned";

  // PHASE 1: per-message verification.
  // - shared_alias: alias-match + trash-gate (both required).
  // - self_owned: alias-match skipped (caller owns the mailbox), but the
  //   trash-gate stays — it's a safety property, not an alias property.
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
          reason: `verify_failed_${r.status}`,
        };
      }
      const m = await r.json();
      if (!isSelfOwned) {
        const headers = Object.fromEntries(
          (m.payload?.headers ?? []).map(
            (h: { name: string; value: string }) => [
              h.name.toLowerCase(),
              h.value,
            ],
          ),
        );
        const aliasOk = messageMatchesAlias(headers, caller.aliasEmail);
        if (!aliasOk) {
          return { id, authorized: false, reason: "alias_mismatch" };
        }
      }

      // Safety gate: refuse to permanent-delete unless the message is
      // currently in TRASH or SPAM. UI flow: trash first (mail-mutation add
      // TRASH), then permanent-delete. Same gate for both mailbox kinds.
      const labelIds: string[] = Array.isArray(m.labelIds) ? m.labelIds : [];
      const inTrashOrSpam =
        labelIds.includes("TRASH") || labelIds.includes("SPAM");
      if (!inTrashOrSpam) {
        return { id, authorized: false, reason: "not_in_trash" };
      }
      return { id, authorized: true };
    },
  );

  const authorizedIds: string[] = [];
  const skippedIds: string[] = [];
  for (const v of verifyResults) {
    if (v.authorized) {
      authorizedIds.push(v.id);
      continue;
    }
    // Alias-mismatch is a silent skip (no error surfaced) — same pattern
    // as mail-mutation. Other reasons (verify_failed, not_in_trash) are
    // user-actionable so we DO surface them in `errors`.
    skippedIds.push(v.id);
    if (v.reason && v.reason !== "alias_mismatch") {
      errors[v.id] = v.reason;
    }
  }

  // PHASE 2: hard-delete verified IDs via users.messages.delete.
  // messages.delete = 10 quota units. 10 concurrent ~ 100 u/burst. Returns
  // 204 No Content on success.
  const deleted: string[] = [];
  await chunkedMap(authorizedIds, CONCURRENCY, async (id) => {
    const r = await fetch(`${GMAIL_API}/messages/${id}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${tok}` },
    });
    if (!r.ok) {
      const detail = await r.text().catch(() => "");
      errors[id] = `delete_failed_${r.status}${detail ? `: ${detail}` : ""}`;
      return;
    }
    deleted.push(id);
  });

  return new Response(
    JSON.stringify({
      ok: true,
      deleted,
      skipped: skippedIds,
      errors,
    }),
    { headers: { ...corsHeaders(), "Content-Type": "application/json" } },
  );
});
