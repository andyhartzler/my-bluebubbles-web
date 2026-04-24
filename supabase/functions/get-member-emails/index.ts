// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { google } from "npm:googleapis@130";
import { createClient } from "npm:@supabase/supabase-js@2";
// --- CORS Headers ---
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
// --- Supabase Client ---
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

async function requireStaffUser(req) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } }
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — staff access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { userId: userData.user.id };
}
// --- Organizational email addresses ---
const ORG_EMAILS = [
  "info@moyoungdemocrats.org",
  "andrew@moyoungdemocrats.org",
  "collegedems@moyoungdemocrats.org",
  "comms@moyoungdemocrats.org",
  "creators@moyoungdemocrats.org",
  "events@moyoungdemocrats.org",
  "eboard@moyoungdemocrats.org",
  "fundraising@moyoungdemocrats.org",
  "highschool@moyoungdemocrats.org",
  "members@moyoungdemocrats.org",
  "membership@moyoungdemocrats.org",
  "policy@moyoungdemocrats.org",
  "political-affairs@moyoungdemocrats.org"
];
// --- Helper Functions ---
function coerceLimit(value, defaultValue = 50, max = 500) {
  const raw = typeof value === "number" ? value : Number(value ?? NaN);
  if (!Number.isFinite(raw) || raw <= 0) {
    return defaultValue;
  }
  return Math.min(Math.max(1, Math.trunc(raw)), max);
}
function coerceBoolean(value, defaultValue = false) {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return [
      "1",
      "true",
      "yes",
      "on"
    ].includes(normalized);
  }
  return defaultValue;
}
function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}
function decodeBody(encodedBody) {
  try {
    const base64 = encodedBody.replace(/-/g, "+").replace(/_/g, "/");
    return decodeURIComponent(escape(atob(base64)));
  } catch (err) {
    console.error("Failed to decode body:", err);
    return "";
  }
}
function extractBody(payload) {
  let html = "";
  let text = "";
  if (payload.body?.data) {
    const decoded = decodeBody(payload.body.data);
    if (payload.mimeType === "text/html") {
      html = decoded;
    } else {
      text = decoded;
    }
  }
  if (payload.parts) {
    for (const part of payload.parts){
      if (part.mimeType === "text/html" && part.body?.data) {
        html = decodeBody(part.body.data);
      } else if (part.mimeType === "text/plain" && part.body?.data) {
        text = decodeBody(part.body.data);
      } else if (part.parts) {
        const nested = extractBody(part);
        if (nested.html) html = nested.html;
        if (nested.text) text = nested.text;
      }
    }
  }
  return {
    html,
    text
  };
}
function getHeader(headers, name) {
  const header = headers?.find((h)=>h.name.toLowerCase() === name.toLowerCase());
  return header?.value || "";
}
function extractEmail(fullAddress) {
  const match = fullAddress.match(/<(.+?)>/);
  return match ? match[1] : fullAddress;
}
// --- Member Resolution ---
async function resolveMember(payload) {
  const memberId = payload.memberId || payload.member_id;
  const email = payload.email;
  if (!memberId && !email) {
    return null;
  }
  try {
    let query = supabase.from("members").select("id, name, email, school_email");
    if (memberId) {
      query = query.eq("id", memberId);
    } else if (email) {
      query = query.or(`email.eq.${email},school_email.eq.${email}`);
    }
    const { data, error } = await query.maybeSingle();
    if (error) {
      console.error("Failed to resolve member:", error);
      return null;
    }
    return data;
  } catch (err) {
    console.error("Exception resolving member:", err);
    return null;
  }
}
// --- Database Fetching ---
async function fetchStoredEmails(memberId, limit) {
  try {
    const { data, error } = await supabase.from("email_inbox").select("*").eq("member_id", memberId).order("date", {
      ascending: false
    }).limit(limit);
    if (error) {
      console.error("Failed to fetch stored emails:", error);
      return [];
    }
    return data || [];
  } catch (err) {
    console.error("Exception fetching stored emails:", err);
    return [];
  }
}
async function fetchSentEmails(memberId, limit) {
  try {
    // First, check if the member has any sent emails by querying member_ids array
    const { data, error } = await supabase.from("email_logs").select(`
        id,
        created_at,
        subject,
        body,
        html,
        sender,
        reply_to,
        cc,
        bcc,
        recipient_emails,
        gmail_message_id,
        gmail_thread_id,
        in_reply_to,
        status
      `).contains("member_ids", [
      memberId
    ]).order("created_at", {
      ascending: false
    }).limit(limit);
    if (error) {
      console.error("Failed to fetch sent emails:", error);
      return [];
    }
    // Normalize sent emails to match inbox format
    return (data || []).map((email)=>({
        id: email.gmail_message_id || email.id,
        gmail_message_id: email.gmail_message_id || email.id,
        gmail_thread_id: email.gmail_thread_id || "",
        from_address: email.sender || "",
        to_address: Array.isArray(email.recipient_emails) ? email.recipient_emails.join(", ") : email.recipient_emails || "",
        cc_address: Array.isArray(email.cc) ? email.cc.join(", ") : null,
        bcc_address: Array.isArray(email.bcc) ? email.bcc.join(", ") : null,
        subject: email.subject || "",
        date: email.created_at,
        snippet: email.body?.substring(0, 200) || "",
        body_html: email.html ? email.body : null,
        body_text: email.html ? null : email.body,
        message_id: email.gmail_message_id || null,
        in_reply_to: email.in_reply_to || null,
        references_header: null,
        label_ids: [
          "SENT"
        ],
        member_id: memberId,
        synced_at: email.created_at,
        status: email.status,
        direction: "sent"
      }));
  } catch (err) {
    console.error("Exception fetching sent emails:", err);
    return [];
  }
}
// --- Gmail Fetching ---
async function fetchGmailEmails(member, maxResults) {
  const serviceAccount = JSON.parse(Deno.env.get("SERVICE_ACCOUNT_JSON"));
  const impersonateUser = Deno.env.get("GMAIL_IMPERSONATE_USER");
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: [
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
  const memberEmails = [
    member.email,
    member.school_email
  ].filter(Boolean);
  if (memberEmails.length === 0) {
    console.log("Member has no email addresses");
    return [];
  }
  // Build search query for emails to/from member and org addresses
  const fromQuery = ORG_EMAILS.map((e)=>`from:${e}`).join(" OR ");
  const toQuery = memberEmails.map((e)=>`to:${e}`).join(" OR ");
  const query = `(${fromQuery}) (${toQuery})`;
  console.log("Gmail search query:", query);
  const searchResponse = await gmail.users.messages.list({
    userId: "me",
    q: query,
    maxResults: maxResults
  });
  const messages = searchResponse.data.messages || [];
  if (messages.length === 0) {
    console.log("No emails found for member");
    return [];
  }
  const emailDetails = [];
  for (const msg of messages){
    try {
      const messageResponse = await gmail.users.messages.get({
        userId: "me",
        id: msg.id,
        format: "full"
      });
      const message = messageResponse.data;
      const headers = message.payload?.headers || [];
      const from = getHeader(headers, "from");
      const to = getHeader(headers, "to");
      const cc = getHeader(headers, "cc");
      const subject = getHeader(headers, "subject");
      const date = getHeader(headers, "date");
      const messageId = getHeader(headers, "message-id");
      const inReplyTo = getHeader(headers, "in-reply-to");
      const references = getHeader(headers, "references");
      const { html, text } = extractBody(message.payload);
      emailDetails.push({
        id: message.id,
        threadId: message.threadId,
        from,
        to,
        cc,
        subject,
        date,
        snippet: message.snippet,
        bodyHtml: html,
        bodyText: text,
        messageId,
        inReplyTo,
        references,
        labelIds: message.labelIds || []
      });
    } catch (err) {
      console.error(`Failed to fetch message ${msg.id}:`, err);
    }
  }
  return emailDetails;
}
// --- Database Caching ---
async function cacheEmailsToDatabase(emailDetails, memberId) {
  if (emailDetails.length === 0) {
    return {
      success: 0,
      errors: 0
    };
  }
  console.log(`Starting to cache ${emailDetails.length} emails...`);
  const emailRecords = emailDetails.map((email)=>({
      gmail_message_id: email.id,
      gmail_thread_id: email.threadId,
      from_address: email.from,
      to_address: extractEmail(email.to),
      cc_address: email.cc || null,
      subject: email.subject,
      date: email.date,
      snippet: email.snippet,
      body_html: email.bodyHtml || null,
      body_text: email.bodyText || null,
      message_id: email.messageId || null,
      in_reply_to: email.inReplyTo || null,
      references_header: email.references || null,
      label_ids: email.labelIds,
      member_id: memberId,
      synced_at: new Date().toISOString()
    }));
  const BATCH_SIZE = 10;
  let successCount = 0;
  let errorCount = 0;
  for(let i = 0; i < emailRecords.length; i += BATCH_SIZE){
    const batch = emailRecords.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(emailRecords.length / BATCH_SIZE);
    console.log(`Processing batch ${batchNum}/${totalBatches} (${batch.length} emails)...`);
    try {
      const { error: batchError } = await supabase.from("email_inbox").upsert(batch, {
        onConflict: "gmail_message_id",
        ignoreDuplicates: false
      });
      if (batchError) {
        console.error(`Batch ${batchNum} failed:`, batchError);
        errorCount += batch.length;
      } else {
        console.log(`Batch ${batchNum} succeeded (${batch.length} emails)`);
        successCount += batch.length;
      }
    } catch (batchErr) {
      console.error(`Batch ${batchNum} exception:`, batchErr);
      errorCount += batch.length;
    }
    // Small delay between batches
    if (i + BATCH_SIZE < emailRecords.length) {
      await new Promise((resolve)=>setTimeout(resolve, 100));
    }
  }
  console.log(`Caching complete: ${successCount} succeeded, ${errorCount} failed`);
  return {
    success: successCount,
    errors: errorCount
  };
}
// --- Main Handler ---
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
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
    const payload = await req.json();
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:get-member-emails",
      row_id: null,
      context: {
        event: "get-member-emails",
        target_member_id: payload?.memberId ?? payload?.member_id ?? null,
        limit: payload?.limit ?? payload?.maxResults ?? null
      }
    }).then(() => {}).catch((e) => console.error("[get-member-emails] audit_log insert failed:", e));
    // Resolve member
    const member = await resolveMember(payload);
    if (!member) {
      return new Response(JSON.stringify({
        error: "Member not found",
        message: "Please provide a valid memberId or email"
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const limit = coerceLimit(payload.limit || payload.maxResults || payload.max_results, 50, 500);
    const syncToDatabase = coerceBoolean(payload.syncToDatabase ?? payload.sync_to_database, true);
    const forceRefresh = coerceBoolean(payload.forceRefresh ?? payload.force_refresh, false);
    let emails = [];
    let source = "cache";
    let syncStats = null;
    // If forceRefresh or no cached emails, fetch from Gmail
    if (forceRefresh) {
      console.log("Force refresh requested, fetching from Gmail...");
      const gmailEmails = await fetchGmailEmails(member, limit);
      emails = gmailEmails;
      source = "gmail";
      if (syncToDatabase && gmailEmails.length > 0) {
        syncStats = await cacheEmailsToDatabase(gmailEmails, member.id);
      }
    } else {
      // Try to fetch from database first (faster!)
      console.log("Fetching from database...");
      const cachedInbox = await fetchStoredEmails(member.id, limit);
      const cachedSent = await fetchSentEmails(member.id, limit);
      if (cachedInbox.length > 0 || cachedSent.length > 0) {
        // Combine and sort by date
        const combined = [
          ...cachedInbox.map((e)=>({
              ...e,
              direction: "received"
            })),
          ...cachedSent
        ];
        combined.sort((a, b)=>{
          const aDate = new Date(a.date || a.synced_at).getTime();
          const bDate = new Date(b.date || b.synced_at).getTime();
          return bDate - aDate;
        });
        emails = combined.slice(0, limit);
        source = "cache";
      } else {
        // No cached emails, fetch from Gmail
        console.log("No cached emails found, fetching from Gmail...");
        const gmailEmails = await fetchGmailEmails(member, limit);
        emails = gmailEmails;
        source = "gmail";
        if (syncToDatabase && gmailEmails.length > 0) {
          syncStats = await cacheEmailsToDatabase(gmailEmails, member.id);
        }
      }
    }
    return new Response(JSON.stringify({
      success: true,
      memberId: member.id,
      memberName: member.name,
      memberEmails: [
        member.email,
        member.school_email
      ].filter(Boolean),
      emailCount: emails.length,
      emails: emails,
      source: source,
      limit: limit,
      sync: syncStats,
      timestamp: new Date().toISOString()
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Failed to fetch member emails:", err);
    return new Response(JSON.stringify({
      error: err.message,
      details: err.stack
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
