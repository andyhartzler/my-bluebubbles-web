// supabase/functions/invite-executive/index.ts
// ============================================================================
// INVITE EXECUTIVE
// ============================================================================
// Superadmin-gated Edge Function that invites a new executive committee member.
//
// Flow:
//   1. Verify caller JWT + superadmin status (via current_user_is_superadmin RPC).
//   2. Reject if email already exists in public.members.
//   3. INSERT public.members row with executive_committee=true (service-role).
//      The auto_create_auth_user_from_member trigger creates the auth.users row
//      with a matching uuid.
//   4. Mint a magic link via supabaseAdmin.auth.admin.generateLink().
//   5. Send a welcome email via Gmail SMTP (pattern copied from
//      send-executive-email/index.ts).
//   6. INSERT audit_log row (action='AUTH', event='invite').
//
// Env vars required:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GMAIL_USER, GMAIL_APP_PASSWORD
// ============================================================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const GMAIL_USER = Deno.env.get("GMAIL_USER");
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REDIRECT_TO = "https://moyd.app/auth/callback";

// ---------------------------------------------------------------------------
// Gmail SMTP helper — copy-pasted from send-executive-email/index.ts.
// Extended to accept a plain-text body so the message is multipart/alternative.
// Original author: Andrew Hartzler (send-executive-email).
// ---------------------------------------------------------------------------
async function sendViaSMTP(
  to: string,
  subject: string,
  htmlBody: string,
  textBody: string,
  fromDisplay: string,
  fromAddress: string
): Promise<boolean> {
  const conn = await Deno.connect({ hostname: "smtp.gmail.com", port: 587 });
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  async function send(data: string) {
    await conn.write(encoder.encode(data + "\r\n"));
  }
  async function read() {
    const buf = new Uint8Array(1024);
    const n = await conn.read(buf);
    return decoder.decode(buf.subarray(0, n || 0));
  }

  try {
    await read();
    await send("EHLO localhost");
    await read();
    await send("STARTTLS");
    await read();

    const tlsConn = await Deno.startTls(conn, { hostname: "smtp.gmail.com" });

    async function tlsSend(data: string) {
      await tlsConn.write(encoder.encode(data + "\r\n"));
    }
    async function tlsRead() {
      const buf = new Uint8Array(1024);
      const n = await tlsConn.read(buf);
      return decoder.decode(buf.subarray(0, n || 0));
    }

    await tlsSend("EHLO localhost");
    await tlsRead();
    await tlsSend("AUTH LOGIN");
    await tlsRead();
    await tlsSend(btoa(GMAIL_USER!));
    await tlsRead();
    await tlsSend(btoa(GMAIL_APP_PASSWORD!));
    const authResponse = await tlsRead();
    if (!authResponse.includes("235")) {
      throw new Error("SMTP authentication failed");
    }

    await tlsSend(`MAIL FROM:<${fromAddress}>`);
    await tlsRead();
    await tlsSend(`RCPT TO:<${to}>`);
    await tlsRead();
    await tlsSend("DATA");
    await tlsRead();

    const boundary = `moyd_invite_${Date.now()}`;
    const emailContent = [
      `From: ${fromDisplay} <${fromAddress}>`,
      `To: ${to}`,
      `Subject: ${subject}`,
      "MIME-Version: 1.0",
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
      "",
      `--${boundary}`,
      "Content-Type: text/plain; charset=UTF-8",
      "",
      textBody,
      "",
      `--${boundary}`,
      "Content-Type: text/html; charset=UTF-8",
      "",
      htmlBody,
      "",
      `--${boundary}--`,
      ".",
    ].join("\r\n");

    await tlsSend(emailContent);
    await tlsRead();
    await tlsSend("QUIT");
    tlsConn.close();
    return true;
  } catch (error) {
    try { conn.close(); } catch (_) { /* ignore */ }
    throw error;
  }
}

// Retry SMTP once on failure (timeout / transient TLS errors).
async function sendWithRetry(
  to: string,
  subject: string,
  htmlBody: string,
  textBody: string,
  fromDisplay: string,
  fromAddress: string
): Promise<void> {
  try {
    await sendViaSMTP(to, subject, htmlBody, textBody, fromDisplay, fromAddress);
  } catch (firstErr) {
    console.warn("SMTP first attempt failed, retrying:", firstErr);
    await sendViaSMTP(to, subject, htmlBody, textBody, fromDisplay, fromAddress);
  }
}

// ---------------------------------------------------------------------------
// Email templates
// ---------------------------------------------------------------------------
function buildEmailBodies(name: string, magicLink: string): { html: string; text: string } {
  const firstName = (name || "").trim().split(/\s+/)[0] || "there";
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; background: #f9fafc; border: 1px solid #e0e0e0; border-radius: 8px;">
      <h2 style="color: #004aad; text-align: center; margin-bottom: 20px;">Welcome to the MOYD CRM</h2>
      <p style="font-size: 16px; color: #333;">Hi ${firstName},</p>
      <p style="font-size: 16px; color: #333;">
        You've been added to the Missouri Young Democrats executive team CRM. Click the button below to sign in for the first time:
      </p>
      <p style="text-align: center; margin: 32px 0;">
        <a href="${magicLink}" style="background: #004aad; color: #fff; text-decoration: none; padding: 14px 28px; font-size: 16px; font-weight: bold; border-radius: 6px; display: inline-block;">
          Sign in to MOYD CRM
        </a>
      </p>
      <p style="font-size: 14px; color: #666;">
        This link will expire in 1 hour for security reasons. If it expires, visit
        <a href="https://moyd.app" style="color: #004aad;">moyd.app</a> and request a new login link with this same email address.
      </p>
      <p style="font-size: 14px; color: #666;">
        If you weren't expecting this invitation, you can safely ignore this email.
      </p>
      <hr style="margin: 24px 0; border: none; border-top: 1px solid #ddd;">
      <p style="font-size: 13px; color: #555;">
        — Andrew Hartzler<br/>
        MOYD President
      </p>
      <p style="font-size: 12px; color: #999; text-align: center;">
        Missouri Young Democrats • <a href="https://moyoungdemocrats.org" style="color: #004aad; text-decoration: none;">moyoungdemocrats.org</a>
      </p>
    </div>
  `;
  const text = [
    `Hi ${firstName},`,
    "",
    "You've been added to the Missouri Young Democrats executive team CRM.",
    "Click the link below to sign in for the first time:",
    "",
    magicLink,
    "",
    "This link will expire in 1 hour for security reasons. If it expires,",
    "visit https://moyd.app and request a new login link with this same email.",
    "",
    "If you weren't expecting this invitation, you can safely ignore this email.",
    "",
    "— Andrew Hartzler",
    "MOYD President",
  ].join("\n");
  return { html, text };
}

// ---------------------------------------------------------------------------
// Audit log helper — best-effort (logs a warning on failure, never throws).
// ---------------------------------------------------------------------------
async function logAudit(
  supabaseAdmin: ReturnType<typeof createClient>,
  actorId: string | null,
  rowId: string | null,
  context: Record<string, unknown>
): Promise<void> {
  try {
    const { error } = await supabaseAdmin.from("audit_log").insert({
      action: "AUTH",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "members",
      row_id: rowId,
      context,
    });
    if (error) console.warn("audit_log insert failed:", error.message);
  } catch (err) {
    console.warn("audit_log insert threw:", err);
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !GMAIL_USER || !GMAIL_APP_PASSWORD) {
    return new Response(
      JSON.stringify({ error: "Server misconfigured — missing required env vars" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // --- 1. Auth: parse bearer token ----------------------------------------
  const authHeader = req.headers.get("Authorization") || req.headers.get("authorization");
  if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing Authorization: Bearer <jwt> header" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  const callerJwt = authHeader.slice(7).trim();

  // Resolve caller identity via service-role client
  const { data: userResult, error: userErr } = await supabaseAdmin.auth.getUser(callerJwt);
  if (userErr || !userResult?.user) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired caller JWT" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  const callerId = userResult.user.id;
  const callerEmail = userResult.user.email;

  // Superadmin check via PostgREST with the caller's JWT (so the RPC sees auth.uid())
  const supabaseAsCaller = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: `Bearer ${callerJwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: isSuper, error: rpcErr } = await supabaseAsCaller.rpc("current_user_is_superadmin");
  if (rpcErr) {
    console.error("current_user_is_superadmin RPC error:", rpcErr);
    return new Response(
      JSON.stringify({ error: "Authorization check failed" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  if (isSuper !== true) {
    return new Response(
      JSON.stringify({ error: "Forbidden — superadmin required" }),
      { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // --- 2. Parse + validate input ------------------------------------------
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return new Response(
      JSON.stringify({ error: "Body must be valid JSON" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const emailRaw = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const executiveTitle = typeof body.executive_title === "string" ? body.executive_title.trim() : null;
  const executiveRole = typeof body.executive_role === "string" ? body.executive_role.trim() : null;
  const committee = Array.isArray(body.committee)
    ? body.committee.filter((c): c is string => typeof c === "string" && c.trim().length > 0)
    : null;

  if (!emailRaw || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailRaw)) {
    return new Response(
      JSON.stringify({ error: "Valid email is required" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  if (!name) {
    return new Response(
      JSON.stringify({ error: "Name is required" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // --- 3. Conflict check: email already in public.members -----------------
  const { data: existing, error: existingErr } = await supabaseAdmin
    .from("members")
    .select("id, executive_committee")
    .ilike("email", emailRaw)
    .maybeSingle();

  if (existingErr) {
    console.error("members lookup error:", existingErr);
    return new Response(
      JSON.stringify({ error: "Database error checking existing member" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  if (existing) {
    return new Response(
      JSON.stringify({
        error: "Email already registered as a member",
        member_id: existing.id,
        executive_committee: existing.executive_committee === true,
      }),
      { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // --- 4. Insert members row (trigger creates auth.users row) -------------
  const insertPayload: Record<string, unknown> = {
    email: emailRaw,
    name,
    executive_committee: true,
  };
  if (executiveTitle) insertPayload.executive_title = executiveTitle;
  if (executiveRole) insertPayload.executive_role = executiveRole;
  if (committee && committee.length > 0) insertPayload.committee = committee;

  const { data: newMember, error: insertErr } = await supabaseAdmin
    .from("members")
    .insert(insertPayload)
    .select("id")
    .single();

  if (insertErr || !newMember) {
    console.error("members insert error:", insertErr);
    await logAudit(supabaseAdmin, callerId, null, {
      event: "invite_failed",
      stage: "members_insert",
      invited_email: emailRaw,
      invited_name: name,
      error: insertErr?.message,
    });
    // If auth.users already had the email, the trigger may fail. Surface clearly.
    const msg = insertErr?.message || "Failed to create member row";
    const status = msg.toLowerCase().includes("duplicate") || msg.toLowerCase().includes("already") ? 409 : 500;
    return new Response(
      JSON.stringify({
        error: "Could not create member record",
        detail: msg,
        hint: status === 409
          ? "Email may already exist in auth.users without a matching members row — manual cleanup required."
          : undefined,
      }),
      { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  const newMemberId = newMember.id as string;

  // --- 5. Generate magic link ---------------------------------------------
  let actionLink: string | null = null;
  try {
    const { data: linkData, error: linkErr } = await supabaseAdmin.auth.admin.generateLink({
      type: "magiclink",
      email: emailRaw,
      options: { redirectTo: REDIRECT_TO },
    });
    if (linkErr) throw linkErr;
    actionLink = linkData?.properties?.action_link ?? null;
    if (!actionLink) throw new Error("generateLink returned no action_link");
  } catch (err) {
    console.error("generateLink error:", err);
    await logAudit(supabaseAdmin, callerId, newMemberId, {
      event: "invite_failed",
      stage: "generate_link",
      invited_email: emailRaw,
      invited_name: name,
      error: err instanceof Error ? err.message : String(err),
    });
    return new Response(
      JSON.stringify({
        error: "Member created but magic link generation failed",
        member_id: newMemberId,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // --- 6. Send welcome email ----------------------------------------------
  const subject = "Welcome to the MOYD CRM — your sign-in link";
  const { html, text } = buildEmailBodies(name, actionLink);
  const fromAddress = GMAIL_USER;
  const fromDisplay = "Andrew Hartzler (MOYD President)";

  try {
    await sendWithRetry(emailRaw, subject, html, text, fromDisplay, fromAddress);
  } catch (err) {
    console.error("SMTP send failed after retry:", err);
    await logAudit(supabaseAdmin, callerId, newMemberId, {
      event: "invite_failed",
      stage: "smtp_send",
      invited_email: emailRaw,
      invited_name: name,
      error: err instanceof Error ? err.message : String(err),
    });
    return new Response(
      JSON.stringify({
        error: "Member created but welcome email failed to send",
        member_id: newMemberId,
        hint: "Link may still be deliverable manually via the Supabase dashboard.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // --- 7. Audit log success ------------------------------------------------
  await logAudit(supabaseAdmin, callerId, newMemberId, {
    event: "invite",
    invited_email: emailRaw,
    invited_name: name,
    invited_by_email: callerEmail ?? null,
  });

  // --- 8. Success ----------------------------------------------------------
  return new Response(
    JSON.stringify({
      success: true,
      member_id: newMemberId,
      message: "Magic link sent",
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
