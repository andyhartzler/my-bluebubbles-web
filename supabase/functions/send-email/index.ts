import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { google } from "npm:googleapis@130";
import { handleCors } from "../_shared/cors.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
// --- Supabase Client ---
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
// --- Valid sender emails ---
const VALID_SENDER_EMAILS = [
  "andrew@moyoungdemocrats.org",
  "collegedems@moyoungdemocrats.org",
  "comms@moyoungdemocrats.org",
  "creators@moyoungdemocrats.org",
  "eboard@moyoungdemocrats.org",
  "events@moyoungdemocrats.org",
  "fundraising@moyoungdemocrats.org",
  "highschool@moyoungdemocrats.org",
  "info@moyoungdemocrats.org",
  "members@moyoungdemocrats.org",
  "membership@moyoungdemocrats.org",
  "policy@moyoungdemocrats.org",
  "political-affairs@moyoungdemocrats.org"
];
// --- CORS headers ---
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-from-name",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
// --- Auth helper (Wave 2 access-audit 2026-04-24) ---
// Caller must hold a valid user JWT AND be on members.executive_committee.
async function requireStaffUser(req) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({
        error: "Missing Authorization header"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      })
    };
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: `Bearer ${jwt}`
      }
    }
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({
        error: "Invalid or expired JWT"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      })
    };
  }
  const { data: memberRow } = await supabase.from("members").select("executive_committee, email").eq("id", userData.user.id).maybeSingle();
  if (!memberRow?.executive_committee) {
    return {
      error: new Response(JSON.stringify({
        error: "Forbidden — executive_committee required"
      }), {
        status: 403,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      })
    };
  }
  return {
    userId: userData.user.id,
    email: memberRow.email ?? userData.user.email ?? null
  };
}
async function auditLogAction(params) {
  try {
    await supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: params.actor_id,
      actor_role: params.actor_id ? "authenticated" : "service_role",
      schema_name: "public",
      table_name: "edge_fn:send-email",
      row_id: null,
      context: {
        event: params.event,
        details: params.details ?? {}
      }
    });
  } catch (e) {
    console.error("[send-email] audit_log insert failed:", e);
  }
}
// --- Header hygiene ---
// Every header below is built by string interpolation, so a CR or LF anywhere
// in a caller-supplied value injects arbitrary headers. Strip rather than
// reject: a stray newline pasted into a display name should not fail an
// otherwise valid send.
function sanitizeHeader(value) {
  return String(value ?? "").replace(/[\r\n]+/g, " ").trim();
}
// --- Base64 helpers ---
function base64Bytes(bytes) {
  let binary = "";
  for (const byte of bytes){
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}
// RFC 2045 caps encoded lines at 76 characters.
function base64Body(text) {
  return base64Bytes(new TextEncoder().encode(text)).replace(/(.{76})/g, "$1\r\n");
}
// --- RFC 2047 encoded-word ---
// A header is ASCII by definition, so a curly quote, an accented name or an
// emoji in a Subject is only reliable across clients once encoded. ASCII-only
// values are returned untouched so plain subjects stay readable in the raw MIME.
function encodeHeaderWord(value) {
  const clean = sanitizeHeader(value);
  if (!clean || !/[^\x20-\x7E]/.test(clean)) return clean;
  const encoder = new TextEncoder();
  // An encoded word may not exceed 75 characters. "=?UTF-8?B?" plus "?=" costs
  // 12 and base64 grows in quanta of 4, so 45 source bytes is the largest chunk
  // that always fits. Split on CHARACTER boundaries: each encoded word has to
  // decode on its own, so a chunk must never end mid-sequence.
  const chunks = [];
  let current = "";
  let currentBytes = 0;
  for (const char of clean){
    const size = encoder.encode(char).length;
    if (currentBytes + size > 45 && current) {
      chunks.push(current);
      current = "";
      currentBytes = 0;
    }
    current += char;
    currentBytes += size;
  }
  if (current) chunks.push(current);
  // Multiple encoded words fold onto continuation lines rather than running past
  // the line limit.
  return chunks.map((chunk)=>`=?UTF-8?B?${base64Bytes(encoder.encode(chunk))}?=`).join("\r\n ");
}
// --- Template variable replacement helper ---
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
function escapeHtml(value) {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
// escapeValues says which part is being filled. The html body was already
// escaped client-side, so substituting raw there reopens the hole: a member
// named "Ben & Jerry" emits a bare ampersand and a value containing "<" is
// parsed as a tag. The text/plain part must NOT be escaped, which is why the
// caller has to say which one it is filling.
function mergeTemplate(text, variables, escapeValues) {
  if (!variables) return text;
  let merged = text;
  for (const [key, value] of Object.entries(variables)){
    // The key is caller-supplied, so one carrying regex metacharacters would
    // otherwise break or hijack the match.
    const regex = new RegExp(`{{\\s*${escapeRegExp(key)}\\s*}}`, "g");
    // A legitimately falsy value (0, false, "") is a value, not a missing one.
    const raw = value === null || value === undefined ? "" : String(value);
    const replacement = escapeValues ? escapeHtml(raw) : raw;
    // Function form: a value containing "$&" must not be read as a match
    // reference.
    merged = merged.replace(regex, ()=>replacement);
  }
  return merged;
}
// --- Minimal, email-client-safe document wrapper ---
// Composed bodies arrive as bare fragments, which leaves every client guessing
// at the charset. Wrap only when the body is not already a full document, so a
// caller that sends one is never double-wrapped.
function wrapHtmlDocument(html) {
  if (/^\s*(<!doctype\s+html|<html[\s>])/i.test(html)) return html;
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body style="margin:0; padding:0;">${html}</body></html>`;
}
// --- Gmail Auth Setup ---
async function getGmailClient() {
  const serviceAccount = JSON.parse(Deno.env.get("SERVICE_ACCOUNT_JSON"));
  const impersonateUser = Deno.env.get("GMAIL_IMPERSONATE_USER");
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: [
      "https://www.googleapis.com/auth/gmail.send",
      "https://www.googleapis.com/auth/gmail.compose",
      "https://www.googleapis.com/auth/gmail.readonly",
      "https://www.googleapis.com/auth/gmail.modify"
    ],
    clientOptions: {
      subject: impersonateUser
    }
  });
  return google.gmail({
    version: "v1",
    auth
  });
}
// --- Build and send a single email ---
async function sendSingleEmail({ gmail, to, cc, bcc, subject, htmlBody, textBody, replyTo, displayName, senderEmail, threadId, inReplyTo, references, attachments }) {
  const boundaryOuter = "outer-boundary";
  const boundaryInner = "inner-boundary";
  const lines = [];
  const addressList = (value)=>sanitizeHeader(Array.isArray(value) ? value.join(", ") : value);
  // Headers
  lines.push(`From: ${encodeHeaderWord(displayName)} <${sanitizeHeader(senderEmail)}>`);
  lines.push(`To: ${addressList(to)}`);
  if (cc && cc.length) lines.push(`Cc: ${addressList(cc)}`);
  if (bcc && bcc.length) lines.push(`Bcc: ${addressList(bcc)}`);
  if (replyTo) lines.push(`Reply-To: ${sanitizeHeader(replyTo)}`);
  // Threading headers
  if (inReplyTo) lines.push(`In-Reply-To: ${sanitizeHeader(inReplyTo)}`);
  if (references) lines.push(`References: ${sanitizeHeader(references)}`);
  lines.push(`Subject: ${encodeHeaderWord(subject)}`);
  lines.push(`MIME-Version: 1.0`);
  lines.push(`Content-Type: multipart/mixed; boundary="${boundaryOuter}"`);
  lines.push("");
  // Inner multipart (text/plain + text/html)
  lines.push(`--${boundaryOuter}`);
  lines.push(`Content-Type: multipart/alternative; boundary="${boundaryInner}"`);
  lines.push("");
  // Both bodies are UTF-8, so base64 is the honest transfer encoding: declaring
  // 7bit over 8-bit content is a spec violation that survived only because
  // charset="UTF-8" was declared alongside it. This is the PER-PART encoding.
  // The base64 of rawMessage further down is the separate Gmail API layer, so
  // each part body is still encoded exactly once.
  if (textBody) {
    lines.push(`--${boundaryInner}`);
    lines.push(`Content-Type: text/plain; charset="UTF-8"`);
    lines.push(`Content-Transfer-Encoding: base64`);
    lines.push("");
    lines.push(base64Body(textBody));
    lines.push("");
  }
  lines.push(`--${boundaryInner}`);
  lines.push(`Content-Type: text/html; charset="UTF-8"`);
  lines.push(`Content-Transfer-Encoding: base64`);
  lines.push("");
  lines.push(base64Body(wrapHtmlDocument(htmlBody)));
  lines.push("");
  lines.push(`--${boundaryInner}--`);
  lines.push("");
  // Attachments
  if (attachments && Array.isArray(attachments)) {
    for (const att of attachments){
      // A filename is a header parameter like any other: a CR, an LF or a stray
      // quote in it injects headers or breaks out of the quoted string.
      const filename = sanitizeHeader(att.filename).replace(/"/g, "");
      const mimeType = sanitizeHeader(att.mimeType).replace(/[";]/g, "") || "application/octet-stream";
      lines.push(`--${boundaryOuter}`);
      lines.push(`Content-Type: ${mimeType}; name="${filename}"`);
      lines.push(`Content-Disposition: attachment; filename="${filename}"`);
      lines.push(`Content-Transfer-Encoding: base64`);
      lines.push("");
      lines.push(att.content);
      lines.push("");
    }
  }
  lines.push(`--${boundaryOuter}--`);
  const rawMessage = lines.join("\r\n");
  const encodedMessage = btoa(unescape(encodeURIComponent(rawMessage))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const gmailResponse = await gmail.users.messages.send({
    userId: "me",
    requestBody: {
      raw: encodedMessage,
      threadId: threadId || undefined
    }
  });
  return {
    gmail_message_id: gmailResponse.data.id,
    gmail_thread_id: gmailResponse.data.threadId
  };
}
// --- Main handler ---
Deno.serve(async (req)=>{
  const _cors = handleCors(req);
  if (_cors) return _cors;
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders
    });
  }
  // --- Staff gate ---
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const { to, cc, bcc, subject, htmlBody, textBody, variables, attachments, replyTo, fromName, fromEmail, threadId, inReplyTo, references, recipients// NEW: Array of {email, variables} for mail merge
     } = await req.json();
    // --- Validation ---
    if (!to && !recipients) {
      return new Response("Missing required field: to or recipients", {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    if (!subject || !htmlBody) {
      return new Response("Missing required fields: subject, htmlBody", {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // --- Validate and set sender email ---
    const senderEmail = fromEmail || "info@moyoungdemocrats.org";
    if (!VALID_SENDER_EMAILS.includes(senderEmail)) {
      return new Response(`Invalid fromEmail. Must be one of: ${VALID_SENDER_EMAILS.join(", ")}`, {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // --- Determine display name ---
    const headerFromName = req.headers.get("x-from-name");
    const displayName = fromName || headerFromName || "Missouri Young Democrats";
    // --- Get Gmail client ---
    const gmail = await getGmailClient();
    // --- Determine if this is a mail merge operation ---
    const isMailMerge = recipients && Array.isArray(recipients) && recipients.length > 0;
    // A Cc or Bcc only becomes incoherent when MORE THAN ONE message goes out:
    // copying the address on every send buries it under one message per
    // recipient, and copying it on a single arbitrary send is a partial result
    // nobody asked for. The composer offers both fields, so silently discarding
    // them lies to the operator; refuse and say why instead.
    //
    // The condition is deliberately recipients.length > 1, NOT isMailMerge. The
    // Flutter client ALWAYS populates `recipients` (crm_email_service.dart
    // builds it unconditionally), so isMailMerge is true for every send this app
    // makes, including a one-to-one email. Gating on isMailMerge rejected every
    // Cc/Bcc send in the product, which is strictly worse than the silent drop
    // it replaced. One recipient means one message, where a copy means exactly
    // what the operator expects, so it is honoured below.
    const copyRequested = (cc && cc.length) || (bcc && bcc.length);
    if (isMailMerge && recipients.length > 1 && copyRequested) {
      return new Response(JSON.stringify({
        error: "cc and bcc are not supported when sending to more than one recipient. Each recipient gets a separate personalized message, so a copied address would receive one copy per recipient. Remove cc and bcc, or send to a single recipient."
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    let allRecipientEmails = [];
    let sentCount = 0;
    let failedCount = 0;
    const sentDetails = [];
    if (isMailMerge) {
      // --- MAIL MERGE: Send personalized email to each recipient ---
      console.log(`Mail merge: Sending to ${recipients.length} recipients`);
      for (const recipient of recipients){
        try {
          const recipientEmail = recipient.email || recipient.to;
          const recipientVars = recipient.variables || {};
          if (!recipientEmail) {
            console.error("Recipient missing email:", recipient);
            failedCount++;
            continue;
          }
          // Merge variables for this specific recipient
          const mergedHtml = mergeTemplate(htmlBody, recipientVars, true);
          const mergedText = textBody ? mergeTemplate(textBody, recipientVars, false) : undefined;
          const mergedSubject = mergeTemplate(subject, recipientVars, false);
          // Send individual email
          const { gmail_message_id, gmail_thread_id } = await sendSingleEmail({
            gmail,
            to: recipientEmail,
            // Honoured only on a single-recipient send. The guard above rejects
            // a multi-recipient send that asks for a copy, so reaching here with
            // a copy set means there is exactly one message to copy.
            cc,
            bcc,
            subject: mergedSubject,
            htmlBody: mergedHtml,
            textBody: mergedText,
            replyTo,
            displayName,
            senderEmail,
            threadId,
            inReplyTo,
            references,
            attachments
          });
          allRecipientEmails.push(recipientEmail);
          sentCount++;
          sentDetails.push({
            email: recipientEmail,
            gmail_message_id,
            gmail_thread_id,
            success: true
          });
          // Rate limiting
          await new Promise((resolve)=>setTimeout(resolve, 100));
        } catch (err) {
          console.error(`Failed to send to ${recipient.email}:`, err);
          failedCount++;
          sentDetails.push({
            email: recipient.email,
            error: err.message,
            success: false
          });
        }
      }
    } else {
      // --- SINGLE EMAIL: Send to all recipients with same content ---
      console.log("Single email mode: Sending to all recipients at once");
      const toEmails = Array.isArray(to) ? to : [
        to
      ];
      // Merge variables (same for all recipients)
      const mergedHtml = mergeTemplate(htmlBody, variables, true);
      const mergedText = textBody ? mergeTemplate(textBody, variables, false) : undefined;
      const mergedSubject = mergeTemplate(subject, variables, false);
      const { gmail_message_id, gmail_thread_id } = await sendSingleEmail({
        gmail,
        to: toEmails.join(", "),
        cc,
        bcc,
        subject: mergedSubject,
        htmlBody: mergedHtml,
        textBody: mergedText,
        replyTo,
        displayName,
        senderEmail,
        threadId,
        inReplyTo,
        references,
        attachments
      });
      // Build recipient list
      allRecipientEmails = [
        ...toEmails,
        ...Array.isArray(cc) ? cc : cc ? [
          cc
        ] : [],
        ...Array.isArray(bcc) ? bcc : bcc ? [
          bcc
        ] : []
      ].filter(Boolean);
      sentCount = 1;
      sentDetails.push({
        emails: allRecipientEmails,
        gmail_message_id,
        gmail_thread_id,
        success: true
      });
    }
    // --- Find matching members ---
    const emailFilter = allRecipientEmails.map((e)=>`school_email.eq.${e}`).join(",");
    const { data: matchedMembers } = await supabase.from("members").select("id, email, school_email").or(`email.in.(${allRecipientEmails.join(",")}),${emailFilter}`);
    const memberIds = matchedMembers?.map((m)=>m.id) || [];
    // --- Insert email log ---
    const { data: logData, error: logError } = await supabase.from("email_logs").insert({
      subject: isMailMerge ? `${subject} (Mail Merge)` : subject,
      body: htmlBody,
      html: true,
      sender: senderEmail,
      reply_to: replyTo,
      cc: cc || null,
      bcc: bcc || null,
      attachments: attachments || null,
      variables: isMailMerge ? {
        mail_merge: true,
        count: recipients.length
      } : variables,
      gmail_message_id: sentDetails[0]?.gmail_message_id || null,
      gmail_thread_id: sentDetails[0]?.gmail_thread_id || null,
      in_reply_to: inReplyTo || null,
      recipient_emails: allRecipientEmails,
      member_ids: memberIds,
      status: failedCount > 0 ? "partial" : "sent"
    }).select("id, created_at").single();
    if (logError) throw logError;
    // --- Insert into email_log_members ---
    if (memberIds.length) {
      const rows = memberIds.map((mid)=>({
          email_log_id: logData.id,
          member_id: mid
        }));
      await supabase.from("email_log_members").insert(rows);
    }
    // --- audit_log row ---
    auditLogAction({
      actor_id: actorId,
      event: "send-email",
      details: {
        sender: senderEmail,
        subject,
        recipient_count: allRecipientEmails.length,
        mail_merge: isMailMerge,
        email_log_id: logData.id
      }
    });
    // --- Success Response ---
    return new Response(JSON.stringify({
      success: true,
      mail_merge: isMailMerge,
      sent_count: sentCount,
      failed_count: failedCount,
      total_recipients: allRecipientEmails.length,
      email_log_id: logData.id,
      linked_member_ids: memberIds,
      from_display_name: displayName,
      from_email: senderEmail,
      details: sentDetails
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Email send failed:", err);
    // --- Log failure ---
    await supabase.from("email_logs").insert({
      subject: "FAILED SEND",
      body: JSON.stringify(err),
      html: false,
      sender: "info@moyoungdemocrats.org",
      status: "failed",
      error_message: err.message
    });
    auditLogAction({
      actor_id: actorId,
      event: "send-email:error",
      details: {
        error: err.message
      }
    });
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
