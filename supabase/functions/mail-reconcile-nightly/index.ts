// Nightly drift reconciliation for the Gmail-backed mail client.
//
// The Pub/Sub pipeline (mail-pubsub-receiver) is best-effort: pushes can
// be lost, watches can lapse, history.list can 404 if the floor expires.
// The 5-min mail-poll fallback closes most gaps, but if both fail
// simultaneously we still drift. This nightly pass catches the long-tail
// residue.
//
// For each watched mailbox:
//   - shared_alias: per-alias `(deliveredto:X OR from:X)` query, diff
//     against the cached last-7-days for that alias, upsert the missing
//     ones with messageMatchesAlias re-verification.
//   - self_owned: list the newest 100 INBOX messages on the mailbox (no
//     query clamp — the whole inbox is theirs), diff against the alias's
//     cached last-7-days, upsert missing.
//
// Deployed --no-verify-jwt because pg_cron hits us URL-only with no
// caller-controlled inputs.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import {
  enumerateWatchedMailboxes,
  type WatchedMailbox,
} from "../_shared/mailbox-registry.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const META_CONCURRENCY = 10;
const LIST_MAX_RESULTS = 100;
const CACHE_WINDOW_DAYS = 7;

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

interface UpsertCandidate {
  gmailId: string;
  aliasEmail: string;
}

async function upsertMissing(
  sb: ReturnType<typeof createClient>,
  tok: string,
  candidates: UpsertCandidate[],
  /** When set, re-verify each message's headers match this alias before
   * upserting (shared_alias defense-in-depth). When omitted, trust the
   * caller's classification (self_owned — the whole mailbox is the alias's). */
  verifyAlias: string | null,
): Promise<number> {
  let upserted = 0;
  await chunkedMap(candidates, META_CONCURRENCY, async (c) => {
    const r = await fetch(
      `${GMAIL_API}/messages/${c.gmailId}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Bcc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) {
      console.warn(
        `mail-reconcile-nightly: meta fetch failed for ${c.gmailId} status=${r.status}`,
      );
      return null;
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
    if (verifyAlias && !messageMatchesAlias(headers, verifyAlias)) {
      console.warn(
        `mail-reconcile-nightly: q-clamp mismatch for ${c.gmailId} alias=${verifyAlias}`,
      );
      return null;
    }
    const { error: upsertErr } = await sb
      .from("mail_messages_cache")
      .upsert({
        gmail_message_id: m.id,
        thread_id: m.threadId,
        alias_email: c.aliasEmail,
        from_addr: headers["from"] ?? "",
        to_addrs: (headers["to"] ?? "")
          .split(",")
          .map((s: string) => s.trim())
          .filter(Boolean),
        cc_addrs: (headers["cc"] ?? "")
          .split(",")
          .map((s: string) => s.trim())
          .filter(Boolean),
        subject: headers["subject"] ?? "",
        snippet: m.snippet ?? "",
        internal_date: new Date(Number(m.internalDate)).toISOString(),
        labels: m.labelIds ?? [],
        delivered_to: headers["delivered-to"] ?? null,
      });
    if (upsertErr) {
      console.error(
        `mail-reconcile-nightly: upsert failed for ${c.gmailId}`,
        upsertErr,
      );
      return null;
    }
    upserted++;
    return c.gmailId;
  });
  return upserted;
}

async function reconcileSharedAlias(
  sb: ReturnType<typeof createClient>,
  m: WatchedMailbox,
): Promise<{ aliasDrift: Record<string, number>; total: number }> {
  const tok = await getGoogleAccessToken({
    subject: m.mailboxEmail,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const sinceIso = new Date(
    Date.now() - CACHE_WINDOW_DAYS * 86400000,
  ).toISOString();

  const aliasDrift: Record<string, number> = {};
  let total = 0;

  for (const a of m.aliases) {
    const alias = a.aliasEmail.toLowerCase();
    try {
      const q = `(deliveredto:${alias} OR from:${alias})`;
      const params = new URLSearchParams({
        q,
        maxResults: String(LIST_MAX_RESULTS),
      });
      const listRes = await fetch(`${GMAIL_API}/messages?${params}`, {
        headers: { Authorization: `Bearer ${tok}` },
      });
      if (!listRes.ok) {
        console.error(
          `mail-reconcile-nightly: list failed for ${alias}`,
          listRes.status,
          await listRes.text(),
        );
        aliasDrift[alias] = 0;
        continue;
      }
      const list = await listRes.json();
      const gmailIds: string[] = (list.messages ?? []).map(
        (mm: { id: string }) => mm.id,
      );

      const { data: cachedRows, error: cacheErr } = await sb
        .from("mail_messages_cache")
        .select("gmail_message_id")
        .eq("alias_email", alias)
        .gt("internal_date", sinceIso);
      if (cacheErr) {
        console.error(
          `mail-reconcile-nightly: cache query failed for ${alias}`,
          cacheErr,
        );
        aliasDrift[alias] = 0;
        continue;
      }
      const cachedSet = new Set(
        (cachedRows ?? []).map((r: { gmail_message_id: string }) =>
          r.gmail_message_id
        ),
      );

      const missing = gmailIds
        .filter((id) => !cachedSet.has(id))
        .map<UpsertCandidate>((id) => ({ gmailId: id, aliasEmail: alias }));

      if (missing.length === 0) {
        aliasDrift[alias] = 0;
        continue;
      }

      const n = await upsertMissing(sb, tok, missing, alias);
      aliasDrift[alias] = n;
      total += n;
    } catch (err) {
      console.error(
        `mail-reconcile-nightly: unhandled error for ${alias}`,
        err,
      );
      aliasDrift[alias] = aliasDrift[alias] ?? 0;
    }
  }

  return { aliasDrift, total };
}

async function reconcileSelfOwned(
  sb: ReturnType<typeof createClient>,
  m: WatchedMailbox,
): Promise<{ aliasDrift: Record<string, number>; total: number }> {
  const alias = m.aliases[0]?.aliasEmail.toLowerCase();
  if (!alias) return { aliasDrift: {}, total: 0 };

  const tok = await getGoogleAccessToken({
    subject: m.mailboxEmail,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });
  const sinceIso = new Date(
    Date.now() - CACHE_WINDOW_DAYS * 86400000,
  ).toISOString();

  try {
    // No q-clamp — the whole mailbox is the caller's. Restrict to INBOX so
    // we don't pull every Sent/Drafts message every night.
    const params = new URLSearchParams({
      q: "in:inbox",
      maxResults: String(LIST_MAX_RESULTS),
    });
    const listRes = await fetch(`${GMAIL_API}/messages?${params}`, {
      headers: { Authorization: `Bearer ${tok}` },
    });
    if (!listRes.ok) {
      console.error(
        `mail-reconcile-nightly: list failed for ${m.mailboxEmail}`,
        listRes.status,
        await listRes.text(),
      );
      return { aliasDrift: { [alias]: 0 }, total: 0 };
    }
    const list = await listRes.json();
    const gmailIds: string[] = (list.messages ?? []).map(
      (mm: { id: string }) => mm.id,
    );

    const { data: cachedRows, error: cacheErr } = await sb
      .from("mail_messages_cache")
      .select("gmail_message_id")
      .eq("alias_email", alias)
      .gt("internal_date", sinceIso);
    if (cacheErr) {
      console.error(
        `mail-reconcile-nightly: cache query failed for ${alias}`,
        cacheErr,
      );
      return { aliasDrift: { [alias]: 0 }, total: 0 };
    }
    const cachedSet = new Set(
      (cachedRows ?? []).map((r: { gmail_message_id: string }) =>
        r.gmail_message_id
      ),
    );

    const missing = gmailIds
      .filter((id) => !cachedSet.has(id))
      .map<UpsertCandidate>((id) => ({ gmailId: id, aliasEmail: alias }));

    if (missing.length === 0) return { aliasDrift: { [alias]: 0 }, total: 0 };

    // No alias re-verify — every message in this mailbox is theirs.
    const n = await upsertMissing(sb, tok, missing, null);
    return { aliasDrift: { [alias]: n }, total: n };
  } catch (err) {
    console.error(
      `mail-reconcile-nightly: unhandled error for ${m.mailboxEmail}`,
      err,
    );
    return { aliasDrift: { [alias]: 0 }, total: 0 };
  }
}

Deno.serve(async (_req) => {
  const startedAt = Date.now();

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let mailboxes: WatchedMailbox[];
  try {
    mailboxes = await enumerateWatchedMailboxes(sb);
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const perAliasDrift: Record<string, number> = {};
  let totalDrift = 0;

  for (const m of mailboxes) {
    const r = m.mailboxKind === "self_owned"
      ? await reconcileSelfOwned(sb, m)
      : await reconcileSharedAlias(sb, m);
    Object.assign(perAliasDrift, r.aliasDrift);
    totalDrift += r.total;
  }

  const durationMs = Date.now() - startedAt;
  const result = {
    ok: true,
    mailboxesChecked: mailboxes.length,
    totalDrift,
    perAliasDrift,
    durationMs,
  };
  console.log("mail-reconcile-nightly:", result);

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
