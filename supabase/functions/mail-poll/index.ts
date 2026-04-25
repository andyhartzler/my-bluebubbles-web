// Pub/Sub silent-detection fallback for the Gmail history pipeline.
// Cron fires every 5 min. If the receiver hasn't been pinged recently
// (last_event_at within the last 5 minutes), we no-op. Otherwise we
// run the same users.history.list walk that mail-pubsub-receiver runs
// on a real push, catching up any messages we missed because Pub/Sub
// is having an outage or the watch lapsed.
//
// Deployed with --no-verify-jwt because pg_cron hits us URL-only with
// no caller-controlled inputs.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const FRESH_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

Deno.serve(async (_req) => {
  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: state } = await sb
    .from("mail_pubsub_state")
    .select("history_id, last_event_at")
    .eq("id", 1)
    .maybeSingle();

  // No baseline at all — nothing to walk from. The first real push
  // (or watch-renew) will establish it.
  if (!state?.history_id) {
    return new Response(
      JSON.stringify({ ok: true, fresh: false, reason: "no_baseline" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  // Fast-path: receiver was just pinged, no need to poll.
  if (state.last_event_at) {
    const ageMs = Date.now() - new Date(state.last_event_at).getTime();
    if (ageMs < FRESH_WINDOW_MS) {
      return new Response(JSON.stringify({ ok: true, fresh: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  const startHistoryId: string = String(state.history_id);

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: ["https://www.googleapis.com/auth/gmail.modify"],
  });

  // Same pagination pattern as the receiver. Persist the historyId
  // returned by Gmail (floor of pages processed), NOT a synthetic
  // now-id — otherwise we'd persist ahead of what we actually
  // processed and silently drop messages on the next walk.
  const messageIds = new Set<string>();
  let pageToken: string | undefined;
  let lastResponseHistoryId: string | undefined;

  do {
    const url = new URL(`${GMAIL_API}/history`);
    url.searchParams.set("startHistoryId", startHistoryId);
    url.searchParams.set("historyTypes", "messageAdded");
    if (pageToken) url.searchParams.set("pageToken", pageToken);

    const histRes = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${tok}` },
    });

    if (!histRes.ok) {
      // 404 = startHistoryId expired (>7d). Reset baseline to current
      // Gmail historyId via users.messages.list (same recovery path
      // as the receiver, but discovered via list instead of the push
      // envelope's newHistoryId).
      if (histRes.status === 404) {
        const listRes = await fetch(
          `${GMAIL_API}/messages?maxResults=1`,
          { headers: { Authorization: `Bearer ${tok}` } },
        );
        let resetHistoryId: string | undefined;
        if (listRes.ok) {
          const lj = await listRes.json();
          // /messages.list doesn't return a top-level historyId, so
          // fetch the first message's historyId to use as the new floor.
          const firstId = lj.messages?.[0]?.id;
          if (firstId) {
            const mr = await fetch(
              `${GMAIL_API}/messages/${firstId}?format=minimal`,
              { headers: { Authorization: `Bearer ${tok}` } },
            );
            if (mr.ok) {
              const mj = await mr.json();
              if (mj.historyId) resetHistoryId = String(mj.historyId);
            }
          }
        }
        await sb
          .from("mail_pubsub_state")
          .update({
            ...(resetHistoryId ? { history_id: resetHistoryId } : {}),
            last_event_at: new Date().toISOString(),
          })
          .eq("id", 1);
        console.log(
          "mail-poll: history reset (404 expired)",
          { from: startHistoryId, to: resetHistoryId ?? "unchanged" },
        );
        return new Response(
          JSON.stringify({ ok: true, reset: true, processed: 0 }),
          { headers: { "Content-Type": "application/json" } },
        );
      }
      return new Response(
        JSON.stringify({ error: "history_failed", status: histRes.status }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const hist = await histRes.json();
    if (hist.historyId) lastResponseHistoryId = String(hist.historyId);
    for (const h of (hist.history ?? [])) {
      for (const ma of (h.messagesAdded ?? [])) {
        if (ma.message?.id) messageIds.add(ma.message.id);
      }
    }
    pageToken = hist.nextPageToken;
  } while (pageToken);

  // Per-message classification using the exact-match alias helper.
  const { data: aliases } = await sb
    .from("mail_aliases")
    .select("alias_email")
    .is("revoked_at", null)
    .eq("gmail_send_as_verified", true);
  const aliasList: string[] = (aliases ?? []).map(
    (r: { alias_email: string }) => r.alias_email.toLowerCase(),
  );

  for (const mid of messageIds) {
    const r = await fetch(
      `${GMAIL_API}/messages/${mid}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Subject&metadataHeaders=Date&metadataHeaders=Delivered-To`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) continue;
    const m = await r.json();
    const headers = Object.fromEntries(
      (m.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
      ),
    );

    let alias = "";
    for (const a of aliasList) {
      if (messageMatchesAlias(headers, a)) {
        alias = a;
        break;
      }
    }
    if (!alias) continue; // not for any provisioned exec — skip

    await sb.from("mail_messages_cache").upsert({
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
  }

  await sb
    .from("mail_pubsub_state")
    .update({
      // Persist what Gmail returned, not now() — same invariant as the
      // receiver. If Gmail returned no historyId (empty walk), keep
      // the current floor.
      ...(lastResponseHistoryId ? { history_id: lastResponseHistoryId } : {}),
      last_event_at: new Date().toISOString(),
    })
    .eq("id", 1);

  return new Response(
    JSON.stringify({ ok: true, processed: messageIds.size }),
    { headers: { "Content-Type": "application/json" } },
  );
});
