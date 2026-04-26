// Pub/Sub push handler for Gmail history notifications. Verifies the
// Google-signed OIDC token (review §C5), routes to the right mailbox
// using the push payload's `emailAddress`, then walks
// users.history.list from that mailbox's persisted floor and upserts
// new INBOX messages into mail_messages_cache.
//
// Mailbox routing:
//   - The push payload has shape `{ emailAddress, historyId }`. We look
//     up the matching row in mail_pubsub_state (PK = mailbox_email).
//   - For shared_alias mailboxes (crm@), we classify each new message by
//     alias via exact-match RFC 5322 headers (mailbox holds 15 execs'
//     mail).
//   - For self_owned mailboxes (andrew@/dustin@/landon@), every message
//     in INBOX is for the owning alias by definition; no classification
//     needed.
//
// Phase 6 vacation auto-reply pipeline runs after cache write (per-message)
// for shared_alias mailboxes. Self_owned mailboxes can opt into it the same
// way — vacation prefs key on user_id, not on mailbox_kind.
//
// Three layers of loop prevention keep us out of mail-bot pile-ons:
//   1. Skip if the inbound message has any RFC-3834 / mailing-list header
//      (Auto-Submitted, Precedence: bulk/list/auto_reply, X-Autoreply,
//      List-Id, List-Unsubscribe).
//   2. Skip if mail_messages_cache shows we've already auto-replied to
//      this (alias_email, from_addr) pair in the last 24h.
//   3. Always set Auto-Submitted: auto-replied on outbound replies so
//      other RFC-3834-aware responders won't reply to ours.

import { getGoogleAccessToken } from "../_shared/google-auth.ts";
import { verifyPubsubOidc } from "../_shared/oidc-verify.ts";
import { messageMatchesAlias } from "../_shared/email-utils.ts";
import {
  enumerateWatchedMailboxes,
  type MailboxKind,
} from "../_shared/mailbox-registry.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

function inboundIsAutoOrList(
  headers: Record<string, string>,
): { skip: boolean; reason?: string } {
  const autoSubmitted = (headers["auto-submitted"] ?? "").trim().toLowerCase();
  if (autoSubmitted && autoSubmitted !== "no") {
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
  const pushedMailbox: string | undefined = data.emailAddress
    ? String(data.emailAddress).toLowerCase()
    : undefined;
  if (!pushedMailbox) {
    // Old-style payload without emailAddress — shouldn't happen in
    // current Gmail API, but bail safely rather than guessing.
    return new Response(
      JSON.stringify({ ack: true, error: "no_mailbox_in_payload" }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Resolve the mailbox kind + alias roster from the registry.
  const mailboxes = await enumerateWatchedMailboxes(sb);
  const mailbox = mailboxes.find(
    (m) => m.mailboxEmail.toLowerCase() === pushedMailbox,
  );
  if (!mailbox) {
    // Push for a mailbox we don't track (revoked alias, stale watch, etc.)
    // — ack and move on rather than 502'ing the push (which would retry
    // indefinitely).
    return new Response(
      JSON.stringify({ ack: true, error: "unknown_mailbox", pushedMailbox }),
      { headers: { "Content-Type": "application/json" } },
    );
  }
  const mailboxKind: MailboxKind = mailbox.mailboxKind;

  const { data: state } = await sb
    .from("mail_pubsub_state")
    .select("history_id")
    .eq("mailbox_email", pushedMailbox)
    .maybeSingle();
  const startHistoryId = state?.history_id;
  if (!startHistoryId) {
    // First push for this mailbox — establish baseline only. Gmail rejects
    // expired startHistoryId so we can't backfill >7d.
    await sb
      .from("mail_pubsub_state")
      .upsert(
        {
          mailbox_email: pushedMailbox,
          history_id: newHistoryId,
          watch_expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
          last_event_at: new Date().toISOString(),
        },
        { onConflict: "mailbox_email" },
      );
    return new Response(
      JSON.stringify({ ack: true, baseline: newHistoryId, mailbox: pushedMailbox }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  const tok = await getGoogleAccessToken({
    subject: pushedMailbox,
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
      // are not backfilled — full reconciliation lives in
      // mail-reconcile-nightly.
      if (histRes.status === 404) {
        await sb
          .from("mail_pubsub_state")
          .update({
            history_id: newHistoryId,
            last_event_at: new Date().toISOString(),
          })
          .eq("mailbox_email", pushedMailbox);
        return new Response(
          JSON.stringify({ ack: true, reset: true, mailbox: pushedMailbox }),
          { headers: { "Content-Type": "application/json" } },
        );
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

  // Per-message classification.
  // - shared_alias: walk headers, match against the 15 aliases.
  // - self_owned: every message belongs to the single owning alias.
  const aliasList: string[] = mailbox.aliases.map((a) =>
    a.aliasEmail.toLowerCase()
  );
  const aliasMeta = new Map(mailbox.aliases.map((a) => [a.aliasEmail, a]));

  let autoRepliesSent = 0;
  let autoRepliesSkipped = 0;

  for (const mid of messageIds) {
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
    if (mailboxKind === "self_owned") {
      // Single-alias mailbox — the message is theirs by definition.
      alias = aliasList[0] ?? "";
    } else {
      for (const a of aliasList) {
        if (messageMatchesAlias(headers, a)) {
          alias = a;
          break;
        }
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
      const labels: string[] = m.labelIds ?? [];
      if (labels.includes("SENT") || !labels.includes("INBOX")) {
        continue;
      }

      const autoCheck = inboundIsAutoOrList(headers);
      if (autoCheck.skip) {
        autoRepliesSkipped++;
        console.log(
          `[autoreply] skip ${m.id} alias=${alias}: ${autoCheck.reason}`,
        );
        continue;
      }

      const fromEmail = extractEmail(fromAddr);
      if (!fromEmail || fromEmail === alias) continue;
      // Don't auto-reply to any of our provisioned aliases (across all
      // mailboxes). Re-query is overkill; aliasList here is per-mailbox
      // but we accept the cross-mailbox edge case and skip the check
      // beyond the local alias set.
      if (aliasList.includes(fromEmail)) continue;

      const aliasRow = aliasMeta.get(alias);
      if (!aliasRow) {
        autoRepliesSkipped++;
        continue;
      }

      const { data: vacationPref } = await sb
        .from("mail_vacation_prefs")
        .select(
          "is_enabled, from_date, to_date, subject, text_body, html_body",
        )
        .eq("user_id", aliasRow.userId)
        .maybeSingle();

      if (!vacationPref || vacationPref.is_enabled !== true) continue;

      const today = new Date().toISOString().slice(0, 10);
      const fromDateOk = !vacationPref.from_date ||
        today >= vacationPref.from_date;
      const toDateOk = !vacationPref.to_date ||
        today <= vacationPref.to_date;
      if (!fromDateOk || !toDateOk) continue;

      const { data: thisMsg } = await sb
        .from("mail_messages_cache")
        .select("auto_replied_at")
        .eq("gmail_message_id", m.id)
        .maybeSingle();
      if (thisMsg?.auto_replied_at) {
        autoRepliesSkipped++;
        continue;
      }

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
        autoRepliesSkipped++;
        console.log(`[autoreply] skip ${m.id}: no Message-ID header`);
        continue;
      }

      const replyMessageId = genMessageId(alias);
      const rfc822 = buildAutoReplyRfc822({
        fromName: aliasRow.displayName ?? "",
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

      await sb
        .from("mail_messages_cache")
        .update({ auto_replied_at: new Date().toISOString() })
        .eq("gmail_message_id", m.id);

      await sb.from("mail_send_log").insert({
        sender_user_id: aliasRow.userId,
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
    .eq("mailbox_email", pushedMailbox);

  return new Response(
    JSON.stringify({
      ack: true,
      mailbox: pushedMailbox,
      processed: messageIds.size,
      autoRepliesSent,
      autoRepliesSkipped,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
