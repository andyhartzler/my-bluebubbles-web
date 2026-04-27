import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { google } from "npm:googleapis@130";
import { handleCors, corsHeaders } from "../_shared/cors.ts";
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
// --- Template variable replacement helper ---
function mergeTemplate(text, variables) {
  if (!variables) return text;
  let merged = text;
  for (const [key, value] of Object.entries(variables)){
    const regex = new RegExp(`{{\\s*${key}\\s*}}`, "g");
    merged = merged.replace(regex, value || "");
  }
  return merged;
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
  // Headers
  lines.push(`From: ${displayName} <${senderEmail}>`);
  lines.push(`To: ${to}`);
  if (cc && cc.length) lines.push(`Cc: ${Array.isArray(cc) ? cc.join(", ") : cc}`);
  if (bcc && bcc.length) lines.push(`Bcc: ${Array.isArray(bcc) ? bcc.join(", ") : bcc}`);
  if (replyTo) lines.push(`Reply-To: ${replyTo}`);
  // Threading headers
  if (inReplyTo) lines.push(`In-Reply-To: ${inReplyTo}`);
  if (references) lines.push(`References: ${references}`);
  lines.push(`Subject: ${subject}`);
  lines.push(`MIME-Version: 1.0`);
  lines.push(`Content-Type: multipart/mixed; boundary="${boundaryOuter}"`);
  lines.push("");
  // Inner multipart (text/plain + text/html)
  lines.push(`--${boundaryOuter}`);
  lines.push(`Content-Type: multipart/alternative; boundary="${boundaryInner}"`);
  lines.push("");
  if (textBody) {
    lines.push(`--${boundaryInner}`);
    lines.push(`Content-Type: text/plain; charset="UTF-8"`);
    lines.push(`Content-Transfer-Encoding: 7bit`);
    lines.push("");
    lines.push(textBody);
    lines.push("");
  }
  lines.push(`--${boundaryInner}`);
  lines.push(`Content-Type: text/html; charset="UTF-8"`);
  lines.push(`Content-Transfer-Encoding: 7bit`);
  lines.push("");
  lines.push(htmlBody);
  lines.push("");
  lines.push(`--${boundaryInner}--`);
  lines.push("");
  // Attachments
  if (attachments && Array.isArray(attachments)) {
    for (const att of attachments){
      lines.push(`--${boundaryOuter}`);
      lines.push(`Content-Type: ${att.mimeType || "application/octet-stream"}; name="${att.filename}"`);
      lines.push(`Content-Disposition: attachment; filename="${att.filename}"`);
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
          const mergedHtml = mergeTemplate(htmlBody, recipientVars);
          const mergedText = textBody ? mergeTemplate(textBody, recipientVars) : undefined;
          const mergedSubject = mergeTemplate(subject, recipientVars);
          // Send individual email
          const { gmail_message_id, gmail_thread_id } = await sendSingleEmail({
            gmail,
            to: recipientEmail,
            cc: null,
            bcc: null,
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
      const mergedHtml = mergeTemplate(htmlBody, variables);
      const mergedText = textBody ? mergeTemplate(textBody, variables) : undefined;
      const mergedSubject = mergeTemplate(subject, variables);
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
