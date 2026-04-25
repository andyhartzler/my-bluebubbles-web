// Pub/Sub push handler for Gmail history notifications. Verifies the
// Google-signed OIDC token (review §C5), then walks users.history.list
// from our persisted floor and upserts new INBOX messages into
// mail_messages_cache, classified by alias via exact-match RFC 5322
// (review §C2-C4).
//
// Phase 6 follow-up: after classifying each inbound message we check
// mail_vacation_prefs for the alias's owning user, and if a vacation
// pref is enabled + active, fire an auto-reply via Gmail
// users.messages.send. Three layers of loop prevention keep us from
// joining a mail-bot pile-on:
//   1. Skip if the inbound message has any RFC-3834 / mailing-list
//      header (Auto-Submitted, Precedence: bulk/list/auto_reply,
//      X-Autoreply, List-Id, List-Unsubscribe).
//   2. Skip if mail_messages_cache shows we've already auto-replied
//      to this (alias_email, from_addr) pair in the last 24h.
//   3. Always set Auto-Submitted: auto-replied on outbound replies
//      so other RFC-3834-aware responders won't reply to ours.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { verifyPubsubOidc } from "../_shared/oidc-verify.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SHARED_MAILBOX = "crm@moyoungdemocrats.org";
const GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me";
const RECEIVER_URL =
  "https://faajpcarasilbfndzkmd.functions.supabase.co/mail-pubsub-receiver";
const PUSH_SA_EMAIL =
  "moyd-ai-agent@backend-everything.iam.gserviceaccount.com";

// ---------------------------------------------------------------------
// RFC 822 helpers (mirrored from mail-send so the receiver can build
// outbound auto-reply messages without hitting the mail-send edge fn —
// auto-replies are system actions, not user actions, and the alias's
// owning user may not even have a live session.)
// ---------------------------------------------------------------------
function b64url(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function genMessageId(alias: string): string {
  const rand = crypto.getRandomValues(new Uint8Array(16));
  const hex = Array.from(rand)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  const domain = alias.split("@")[1] ?? "moyoungdemocrats.org";
  return `<${hex}.${Date.now()}@${domain}>`;
}

interface AutoReplyRfc822Opts {
  fromName: string;
  fromAddr: string;
  toAddr: string;
  subject: string;
  bodyText?: string;
  bodyHtml?: string;
  messageId: string;
  inReplyTo: string;
  references: string[];
}

function buildAutoReplyRfc822(opts: AutoReplyRfc822Opts): string {
  const headers: string[] = [];
  headers.push(
    `From: ${opts.fromName ? `"${opts.fromName}" ` : ""}<${opts.fromAddr}>`,
  );
  headers.push(`To: ${opts.toAddr}`);
  headers.push(`Subject: ${opts.subject}`);
  headers.push(`Message-ID: ${opts.messageId}`);
  headers.push(`Date: ${new Date().toUTCString()}`);
  headers.push(`MIME-Version: 1.0`);
  // RFC 3834: signal that this is an automatic reply so other
  // responders don't reply to us. "auto-replied" is the canonical
  // value for vacation responders.
  headers.push(`Auto-Submitted: auto-replied`);
  headers.push(`X-Auto-Response-Suppress: All`);
  headers.push(`Precedence: auto_reply`);
  headers.push(`In-Reply-To: ${opts.inReplyTo}`);
  if (opts.references.length) {
    headers.push(`References: ${opts.references.join(" ")}`);
  }

  const hasText = !!opts.bodyText;
  const hasHtml = !!opts.bodyHtml;

  if (hasText && hasHtml) {
    const boundary =
      `=_boundary_${crypto.randomUUID().replace(/-/g, "").slice(0, 16)}`;
    headers.push(
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
    );
    const lines = [headers.join("\r\n"), "", `--${boundary}`];
    lines.push(
      'Content-Type: text/plain; charset="UTF-8"',
      "Content-Transfer-Encoding: 7bit",
      "",
      opts.bodyText!,
      "",
      `--${boundary}`,
    );
    lines.push(
      'Content-Type: text/html; charset="UTF-8"',
      "Content-Transfer-Encoding: 7bit",
      "",
      opts.bodyHtml!,
      "",
      `--${boundary}--`,
    );
    return lines.join("\r\n");
  } else if (hasHtml) {
    headers.push('Content-Type: text/html; charset="UTF-8"');
    headers.push("Content-Transfer-Encoding: 7bit");
    return [headers.join("\r\n"), "", opts.bodyHtml].join("\r\n");
  } else {
    headers.push('Content-Type: text/plain; charset="UTF-8"');
    headers.push("Content-Transfer-Encoding: 7bit");
    return [headers.join("\r\n"), "", opts.bodyText ?? ""].join("\r\n");
  }
}

// ---------------------------------------------------------------------
// Loop-prevention: any of these headers on the inbound message means
// don't auto-reply. (RFC 3834 §2 + standard mailing-list signals.)
// ---------------------------------------------------------------------
function inboundIsAutoOrList(
  headers: Record<string, string>,
): { skip: boolean; reason?: string } {
  const autoSubmitted = (headers["auto-submitted"] ?? "").trim().toLowerCase();
  if (autoSubmitted && autoSubmitted !== "no") {
    // RFC 3834: any value other than "no" (including "auto-generated",
    // "auto-replied", "auto-notified") means automatic — skip.
    return { skip: true, reason: `auto-submitted: ${autoSubmitted}` };
  }
  const precedence = (headers["precedence"] ?? "").trim().toLowerCase();
  if (
    precedence === "bulk" ||
    precedence === "list" ||
    precedence === "auto_reply" ||
    precedence === "junk"
  ) {
    return { skip: true, reason: `precedence: ${precedence}` };
  }
  const xAutoreply = (headers["x-autoreply"] ?? "").trim().toLowerCase();
  if (xAutoreply && xAutoreply !== "no") {
    return { skip: true, reason: `x-autoreply: ${xAutoreply}` };
  }
  if (headers["list-id"]) {
    return { skip: true, reason: "list-id header present" };
  }
  if (headers["list-unsubscribe"]) {
    return { skip: true, reason: "list-unsubscribe header present" };
  }
  if (headers["x-auto-response-suppress"]) {
    return {
      skip: true,
      reason: `x-auto-response-suppress: ${headers["x-auto-response-suppress"]}`,
    };
  }
  return { skip: false };
}

// Strip "<addr>" / "Name <addr>" / "addr" -> bare lowercased addr.
function extractEmail(raw: string): string {
  if (!raw) return "";
  const m = raw.match(/<([^>]+)>/);
  const addr = (m ? m[1] : raw).trim().toLowerCase();
  return addr;
}

Deno.serve(async (req) => {
  const failed = await verifyPubsubOidc(req, {
    expectedAudience: RECEIVER_URL,
    expectedEmail: PUSH_SA_EMAIL,
  });
  if (failed) return failed;

  const env = await req.json().catch(() => ({}));
  const dataB64 = env?.message?.data;
  if (!dataB64) {
    return new Response(JSON.stringify({ ack: true }), {
      headers: { "Content-Type": "application/json" },
    });
  }
  const data = JSON.parse(atob(dataB64));
  const newHistoryId: string = String(data.historyId);

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: state } = await sb
    .from("mail_pubsub_state")
    .select("history_id")
    .eq("id", 1)
    .maybeSingle();
  const startHistoryId = state?.history_id;
  if (!startHistoryId) {
    // First push — establish baseline only. Backfill >7d isn't possible
    // (Gmail rejects expired startHistoryId).
    await sb.from("mail_pubsub_state").upsert({
      id: 1,
      history_id: newHistoryId,
      watch_expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
      last_event_at: new Date().toISOString(),
    });
    return new Response(JSON.stringify({ ack: true, baseline: newHistoryId }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const tok = await getGoogleAccessToken({
    subject: SHARED_MAILBOX,
    scopes: [
      "https://www.googleapis.com/auth/gmail.modify",
      "https://www.googleapis.com/auth/gmail.send",
    ],
  });

  // Loop on users.history.list pagination until exhausted (review §H3).
  // Persist the historyId returned by Gmail (floor of pages processed),
  // not the push envelope's newHistoryId — otherwise we may persist
  // ahead of what we actually processed and silently drop messages.
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
      // 404 means startHistoryId expired (>7d). Reset baseline.
      // KNOWN LIMITATION: messages between expired watermark and reset
      // are not backfilled — full reconciliation lives in Phase 5.
      if (histRes.status === 404) {
        await sb
          .from("mail_pubsub_state")
          .update({
            history_id: newHistoryId,
            last_event_at: new Date().toISOString(),
          })
          .eq("id", 1);
        return new Response(JSON.stringify({ ack: true, reset: true }), {
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({ error: "history_failed" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
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

  // Per-message classification using the exact-match helper.
  const { data: aliases } = await sb
    .from("mail_aliases")
    .select("user_id, alias_email, display_name")
    .is("revoked_at", null)
    .eq("gmail_send_as_verified", true);
  type AliasRow = {
    user_id: string;
    alias_email: string;
    display_name: string;
  };
  const aliasRows: AliasRow[] = (aliases ?? []) as AliasRow[];
  const aliasList: string[] = aliasRows.map((r) => r.alias_email.toLowerCase());
  const aliasMeta = new Map<string, AliasRow>(
    aliasRows.map((r) => [r.alias_email.toLowerCase(), r]),
  );

  let autoRepliesSent = 0;
  let autoRepliesSkipped = 0;

  for (const mid of messageIds) {
    // We need more headers than before to do RFC-3834 loop-prevention,
    // plus the original Message-ID for In-Reply-To/References.
    const r = await fetch(
      `${GMAIL_API}/messages/${mid}?format=metadata` +
        `&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc` +
        `&metadataHeaders=Subject&metadataHeaders=Date` +
        `&metadataHeaders=Delivered-To&metadataHeaders=Message-ID` +
        `&metadataHeaders=References&metadataHeaders=In-Reply-To` +
        `&metadataHeaders=Auto-Submitted&metadataHeaders=Precedence` +
        `&metadataHeaders=X-Autoreply&metadataHeaders=List-Id` +
        `&metadataHeaders=List-Unsubscribe` +
        `&metadataHeaders=X-Auto-Response-Suppress`,
      { headers: { Authorization: `Bearer ${tok}` } },
    );
    if (!r.ok) continue;
    const m = await r.json();
    const headers = Object.fromEntries(
      (m.payload?.headers ?? []).map(
        (h: { name: string; value: string }) => [h.name.toLowerCase(), h.value],
      ),
    ) as Record<string, string>;

    let alias = "";
    for (const a of aliasList) {
      if (messageMatchesAlias(headers, a)) {
        alias = a;
        break;
      }
    }
    if (!alias) continue; // not for any provisioned exec — skip

    const fromAddr = headers["from"] ?? "";
    await sb.from("mail_messages_cache").upsert({
      gmail_message_id: m.id,
      thread_id: m.threadId,
      alias_email: alias,
      from_addr: fromAddr,
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

    // ---------------------------------------------------------------
    // Vacation auto-reply pipeline. Fail-soft: any error here logs
    // and continues to the next message — we never want a busted
    // auto-reply to lose us the cache write or the historyId update.
    // ---------------------------------------------------------------
    try {
      // Skip outbound (SENT label) — these are messages WE sent. Some
      // of them may be addressed to ourselves, but we never want the
      // receiver to auto-reply to outbound mail.
      const labels: string[] = m.labelIds ?? [];
      if (labels.includes("SENT") || !labels.includes("INBOX")) {
        continue;
      }

      // Loop-prevention layer 1: RFC 3834 + mailing list headers.
      const autoCheck = inboundIsAutoOrList(headers);
      if (autoCheck.skip) {
        autoRepliesSkipped++;
        console.log(
          `[autoreply] skip ${m.id} alias=${alias}: ${autoCheck.reason}`,
        );
        continue;
      }

      // Sender — if we can't extract an email, we can't reply.
      const fromEmail = extractEmail(fromAddr);
      if (!fromEmail || fromEmail === alias) continue;
      // Don't auto-reply to crm@ itself or any of our own aliases.
      if (aliasList.includes(fromEmail)) continue;

      // Find the alias's owning user.
      const aliasRow = aliasMeta.get(alias);
      if (!aliasRow) {
        // Edge case: alias exists in aliasList from earlier query but
        // metadata map doesn't have it — shouldn't happen given they
        // come from the same query, but bail safely.
        autoRepliesSkipped++;
        continue;
      }

      // Look up vacation pref for this user.
      const { data: vacationPref } = await sb
        .from("mail_vacation_prefs")
        .select(
          "is_enabled, from_date, to_date, subject, text_body, html_body",
        )
        .eq("user_id", aliasRow.user_id)
        .maybeSingle();

      if (!vacationPref || vacationPref.is_enabled !== true) continue;

      const today = new Date().toISOString().slice(0, 10);
      const fromDateOk = !vacationPref.from_date ||
        today >= vacationPref.from_date;
      const toDateOk = !vacationPref.to_date ||
        today <= vacationPref.to_date;
      if (!fromDateOk || !toDateOk) continue;

      // Loop-prevention layer 2: idempotent on (this message) +
      // rate-limited per (alias, from) pair.
      // First check: have we already auto-replied to THIS message?
      const { data: thisMsg } = await sb
        .from("mail_messages_cache")
        .select("auto_replied_at")
        .eq("gmail_message_id", m.id)
        .maybeSingle();
      if (thisMsg?.auto_replied_at) {
        autoRepliesSkipped++;
        continue;
      }

      // Second check: rate-limit per (alias, from_addr) -> 1 per 24h.
      const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
      const { data: recentReply } = await sb
        .from("mail_messages_cache")
        .select("gmail_message_id, auto_replied_at")
        .eq("alias_email", alias)
        .eq("from_addr", fromAddr)
        .gt("auto_replied_at", since)
        .order("auto_replied_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (recentReply?.auto_replied_at) {
        autoRepliesSkipped++;
        console.log(
          `[autoreply] skip ${m.id} alias=${alias} from=${fromAddr}: ` +
            `rate-limited (last reply ${recentReply.auto_replied_at})`,
        );
        continue;
      }

      // Build the reply.
      const origSubject = (headers["subject"] ?? "").trim();
      const baseSubject = (vacationPref.subject ?? "").trim() ||
        (origSubject || "Out of office");
      const replySubject = /^re:\s/i.test(baseSubject)
        ? baseSubject
        : `Re: ${baseSubject}`;

      const origMessageId = (headers["message-id"] ?? "").trim();
      const origReferences = (headers["references"] ?? "").trim();
      const refChain: string[] = [];
      if (origReferences) {
        for (const ref of origReferences.split(/\s+/)) {
          if (ref) refChain.push(ref);
        }
      }
      if (origMessageId && !refChain.includes(origMessageId)) {
        refChain.push(origMessageId);
      }

      if (!origMessageId) {
        // No Message-ID on the inbound — without it threading is
        // broken and loop-prevention on the receiver's side gets
        // shaky. Skip rather than send a malformed reply.
        autoRepliesSkipped++;
        console.log(`[autoreply] skip ${m.id}: no Message-ID header`);
        continue;
      }

      const replyMessageId = genMessageId(alias);
      const rfc822 = buildAutoReplyRfc822({
        fromName: aliasRow.display_name ?? "",
        fromAddr: alias,
        toAddr: fromEmail,
        subject: replySubject,
        bodyText: vacationPref.text_body ?? undefined,
        bodyHtml: vacationPref.html_body ?? undefined,
        messageId: replyMessageId,
        inReplyTo: origMessageId,
        references: refChain,
      });
      const raw = b64url(new TextEncoder().encode(rfc822));

      const sendRes = await fetch(`${GMAIL_API}/messages/send`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${tok}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ raw, threadId: m.threadId }),
      });
      if (!sendRes.ok) {
        const detail = await sendRes.text();
        console.error(
          `[autoreply] send failed ${m.id} alias=${alias}: ` +
            `${sendRes.status} ${detail.slice(0, 400)}`,
        );
        continue;
      }
      const sent = await sendRes.json();

      // Mark as auto-replied so any replay of this history page
      // (e.g. on watermark reset) won't double-send.
      await sb
        .from("mail_messages_cache")
        .update({ auto_replied_at: new Date().toISOString() })
        .eq("gmail_message_id", m.id);

      // Audit row in mail_send_log so the auto-reply shows up in the
      // same audit surface as user-initiated sends.
      await sb.from("mail_send_log").insert({
        sender_user_id: aliasRow.user_id,
        alias_email: alias,
        rfc822_message_id: replyMessageId,
        thread_id: sent.threadId ?? m.threadId,
        gmail_message_id: sent.id,
        recipients: { to: [fromEmail], cc: [], bcc: [] },
        subject: replySubject,
        status: "sent",
        related_entity_type: "mail_vacation_auto_reply",
        related_entity_id: m.id,
      });

      autoRepliesSent++;
      console.log(
        `[autoreply] sent ${sent.id} alias=${alias} -> ${fromEmail} ` +
          `(in reply to ${m.id})`,
      );
    } catch (e) {
      console.error(`[autoreply] error on ${m.id}: ${String(e)}`);
    }
  }

  await sb
    .from("mail_pubsub_state")
    .update({
      history_id: lastResponseHistoryId ?? newHistoryId,
      last_event_at: new Date().toISOString(),
    })
    .eq("id", 1);

  return new Response(
    JSON.stringify({
      ack: true,
      processed: messageIds.size,
      autoRepliesSent,
      autoRepliesSkipped,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
