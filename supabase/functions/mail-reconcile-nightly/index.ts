// Nightly drift reconciliation for the Gmail-backed mail client.
//
// The Pub/Sub pipeline (mail-pubsub-receiver) is best-effort: pushes
// can be lost, watches can lapse, history.list can 404 if the floor
// expires. The 5-min mail-poll fallback closes most gaps, but if both
// fail simultaneously we still drift. This nightly pass catches the
// long-tail residue.
//
// For each provisioned alias we list the newest 100 messages
// addressed-to/from that alias on Gmail's side, diff against
// mail_messages_cache's last-7-days window, and upsert any missing
// ones with the same column shape mail-pubsub-receiver uses.
//
// Deployed with --no-verify-jwt because pg_cron hits us URL-only with
// no caller-controlled inputs (cron job 89, 0 7 * * * UTC = 2am CT).

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
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

Deno.serve(async (_req) => {
  const startedAt = Date.now();

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: aliasRows, error: aliasErr } = await sb
    .from("mail_aliases")
    .select("alias_email")
    .is("revoked_at", null)
    .eq("gmail_send_as_verified", true);

  if (aliasErr) {
    console.error("mail-reconcile-nightly: alias query failed", aliasErr);
    return new Response(
      JSON.stringify({ ok: false, error: "alias_query_failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const aliases: string[] = (aliasRows ?? []).map(
    (r: { alias_email: string }) => r.alias_email.toLowerCase(),
  );

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  const perAliasDrift: Record<string, number> = {};
  let totalDrift = 0;

  for (const alias of aliases) {
    try {
      // 1. Newest 100 Gmail messages addressed to/from this alias.
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
        perAliasDrift[alias] = 0;
        continue;
      }
      const list = await listRes.json();
      const gmailIds: string[] = (list.messages ?? []).map(
        (m: { id: string }) => m.id,
      );

      // 2. Cached IDs for this alias in the last-7-days window.
      const sinceIso = new Date(
        Date.now() - CACHE_WINDOW_DAYS * 86400000,
      ).toISOString();
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
        perAliasDrift[alias] = 0;
        continue;
      }
      const cachedSet = new Set(
        (cachedRows ?? []).map((r: { gmail_message_id: string }) =>
          r.gmail_message_id
        ),
      );

      // 3. Set difference: Gmail IDs not in our cache.
      const missingIds = gmailIds.filter((id) => !cachedSet.has(id));

      if (missingIds.length === 0) {
        perAliasDrift[alias] = 0;
        continue;
      }

      // 4. Fetch metadata + alias-verify + upsert, concurrency 10.
      let aliasUpserted = 0;
      await chunkedMap(missingIds, META_CONCURRENCY, async (mid) => {
        const r = await fetch(
          `${GMAIL_API}/messages/${mid}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Bcc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`,
          { headers: { Authorization: `Bearer ${tok}` } },
        );
        if (!r.ok) {
          console.warn(
            `mail-reconcile-nightly: meta fetch failed for ${mid}`,
            r.status,
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

        // TRUST BOUNDARY: re-verify alias match. Gmail's q-clamp
        // should already have filtered, but never trust just that.
        if (!messageMatchesAlias(headers, alias)) {
          console.warn(
            `mail-reconcile-nightly: q-clamp mismatch for ${mid} alias=${alias}`,
          );
          return null;
        }

        const { error: upsertErr } = await sb
          .from("mail_messages_cache")
          .upsert({
            gmail_message_id: m.id,
            thread_id: m.threadId,
            alias_email: alias,
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
            `mail-reconcile-nightly: upsert failed for ${mid}`,
            upsertErr,
          );
          return null;
        }
        aliasUpserted++;
        return mid;
      });

      perAliasDrift[alias] = aliasUpserted;
      totalDrift += aliasUpserted;
    } catch (err) {
      // Per-alias errors must not halt the rest of the reconciliation.
      console.error(
        `mail-reconcile-nightly: unhandled error for ${alias}`,
        err,
      );
      perAliasDrift[alias] = perAliasDrift[alias] ?? 0;
    }
  }

  const durationMs = Date.now() - startedAt;
  const result = {
    ok: true,
    aliasesChecked: aliases.length,
    totalDrift,
    perAliasDrift,
    durationMs,
  };
  console.log("mail-reconcile-nightly:", result);

  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
