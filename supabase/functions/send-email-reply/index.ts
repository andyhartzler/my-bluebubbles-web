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
  const { data: memberRow } = await supabase.from("members").select("executive_committee").eq("id", userData.user.id).maybeSingle();
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
    userId: userData.user.id
  };
}
async function auditLogAction(params) {
  try {
    await supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: params.actor_id,
      actor_role: params.actor_id ? "authenticated" : "service_role",
      schema_name: "public",
      table_name: "edge_fn:send-email-reply",
      row_id: null,
      context: {
        event: params.event,
        details: params.details ?? {}
      }
    });
  } catch (e) {
    console.error("[send-email-reply] audit_log insert failed:", e);
  }
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
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const { originalMessageId, threadId, to, subject, htmlBody, textBody, cc, fromEmail, fromName, messageId, references } = await req.json();
    // --- Validation ---
    if (!threadId || !to || !subject || !htmlBody) {
      return new Response("Missing required fields: threadId, to, subject, htmlBody", {
        status: 400,
        headers: corsHeaders
      });
    }
    // --- Validate and set sender email ---
    const senderEmail = fromEmail || "info@moyoungdemocrats.org";
    if (!VALID_SENDER_EMAILS.includes(senderEmail)) {
      return new Response(`Invalid fromEmail. Must be one of: ${VALID_SENDER_EMAILS.join(", ")}`, {
        status: 400,
        headers: corsHeaders
      });
    }
    // --- Determine display name ---
    const displayName = fromName || "Missouri Young Democrats";
    // --- Gmail Auth ---
    const serviceAccount = JSON.parse(Deno.env.get("SERVICE_ACCOUNT_JSON"));
    const impersonateUser = Deno.env.get("GMAIL_IMPERSONATE_USER");
    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: [
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.compose",
        "https://www.googleapis.com/auth/gmail.readonly"
      ],
      clientOptions: {
        subject: impersonateUser
      }
    });
    const gmail = google.gmail({
      version: "v1",
      auth
    });
    // --- Fetch original message to get headers ---
    let inReplyTo = messageId;
    let referenceChain = references;
    if (originalMessageId && !messageId) {
      try {
        const originalMsg = await gmail.users.messages.get({
          userId: "me",
          id: originalMessageId,
          format: "metadata",
          metadataHeaders: [
            "Message-ID",
            "References"
          ]
        });
        const headers = originalMsg.data.payload?.headers || [];
        inReplyTo = headers.find((h)=>h.name === "Message-ID")?.value || "";
        const originalRefs = headers.find((h)=>h.name === "References")?.value || "";
        // Build reference chain
        referenceChain = originalRefs ? `${originalRefs} ${inReplyTo}`.trim() : inReplyTo;
      } catch (err) {
        console.error("Failed to fetch original message headers:", err);
      }
    }
    // --- Build MIME message ---
    const boundary = "reply-boundary";
    const lines = [];
    // Use dynamic sender email and display name
    lines.push(`From: ${displayName} <${senderEmail}>`);
    lines.push(`To: ${Array.isArray(to) ? to.join(", ") : to}`);
    if (cc) lines.push(`Cc: ${Array.isArray(cc) ? cc.join(", ") : cc}`);
    lines.push(`Subject: ${subject}`);
    // Threading headers
    if (inReplyTo) {
      lines.push(`In-Reply-To: ${inReplyTo}`);
    }
    if (referenceChain) {
      lines.push(`References: ${referenceChain}`);
    }
    lines.push(`MIME-Version: 1.0`);
    lines.push(`Content-Type: multipart/alternative; boundary="${boundary}"`);
    lines.push("");
    // Text version
    if (textBody) {
      lines.push(`--${boundary}`);
      lines.push(`Content-Type: text/plain; charset="UTF-8"`);
      lines.push("");
      lines.push(textBody);
      lines.push("");
    }
    // HTML version
    lines.push(`--${boundary}`);
    lines.push(`Content-Type: text/html; charset="UTF-8"`);
    lines.push("");
    lines.push(htmlBody);
    lines.push("");
    lines.push(`--${boundary}--`);
    // --- Encode message ---
    const encodedMessage = btoa(unescape(encodeURIComponent(lines.join("\r\n")))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    // --- Send reply ---
    const gmailResponse = await gmail.users.messages.send({
      userId: "me",
      requestBody: {
        raw: encodedMessage,
        threadId: threadId
      }
    });
    const sentMessageId = gmailResponse.data.id || null;
    const sentThreadId = gmailResponse.data.threadId || null;
    // --- Find member by recipient email ---
    const recipientEmails = Array.isArray(to) ? to : [
      to
    ];
    const { data: members } = await supabase.from("members").select("id").or(`email.in.(${recipientEmails.join(",")}),school_email.in.(${recipientEmails.join(",")})`);
    const memberIds = members?.map((m)=>m.id) || [];
    // --- Log the reply ---
    const { data: logData, error: logError } = await supabase.from("email_logs").insert({
      subject,
      body: htmlBody,
      html: true,
      sender: senderEmail,
      cc,
      gmail_message_id: sentMessageId,
      gmail_thread_id: sentThreadId,
      in_reply_to: inReplyTo,
      recipient_emails: recipientEmails,
      member_ids: memberIds,
      status: "sent"
    }).select("id").single();
    if (logError) {
      console.error("Failed to log reply:", logError);
    } else if (memberIds.length && logData) {
      // Link to members
      const rows = memberIds.map((mid)=>({
          email_log_id: logData.id,
          member_id: mid
        }));
      await supabase.from("email_log_members").insert(rows);
    }
    auditLogAction({
      actor_id: actorId,
      event: "send-email-reply",
      details: {
        sender: senderEmail,
        subject,
        thread_id: threadId,
        recipient_count: recipientEmails.length,
        email_log_id: logData?.id ?? null
      }
    });
    // --- Success ---
    return new Response(JSON.stringify({
      success: true,
      gmail_message_id: sentMessageId,
      gmail_thread_id: sentThreadId,
      email_log_id: logData?.id,
      from_email: senderEmail,
      from_display_name: displayName
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Reply send failed:", err);
    await supabase.from("email_logs").insert({
      subject: "FAILED REPLY",
      body: JSON.stringify(err),
      html: false,
      sender: "info@moyoungdemocrats.org",
      status: "failed",
      error_message: err.message
    });
    auditLogAction({
      actor_id: actorId,
      event: "send-email-reply:error",
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
