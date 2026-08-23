// Revoke Executive Session Edge Function
// Immediately revokes an executive's access to the MOYD CRM.
//
// Flow (per /tmp/moyd-access-audit/05-plan.md §2.6):
//   1. Verify caller JWT + superadmin status via current_user_is_superadmin() RPC.
//   2. Validate target_user_id is a UUID + refers to an existing member.
//   3. Refuse self-revocation (prevents superadmin lockout).
//   4. Flip members.executive_committee = false and demote any superadmin
//      role row for the target to 'executive'.
//   5. Call supabaseAdmin.auth.admin.signOut(target_user_id) to invalidate
//      refresh tokens + sessions. Their next request returns 401.
//   6. Insert audit_log row with action='AUTH'.
//   7. Return 200 with confirmation (or a soft warning if signOut failed).
//
// Environment variables (set via Supabase Dashboard → Edge Functions → Secrets):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://moyd.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("[revoke-executive-session] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return jsonResponse({ error: "Configuration error" }, 500);
  }

  // ── 1. Extract + verify caller JWT ──
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!jwt) {
    return jsonResponse({ error: "Missing Authorization bearer token" }, 401);
  }

  // Admin client — used for all privileged operations.
  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Resolve caller identity from their JWT.
  const { data: callerRes, error: callerErr } = await supabaseAdmin.auth.getUser(jwt);
  if (callerErr || !callerRes?.user) {
    console.warn("[revoke-executive-session] getUser failed:", callerErr?.message);
    return jsonResponse({ error: "Invalid or expired token" }, 401);
  }
  const callerId = callerRes.user.id;

  // Caller-scoped client (RLS applies) so current_user_is_superadmin() resolves
  // against the caller's auth.uid(), not service_role.
  const supabaseAsCaller = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: isSuper, error: rpcErr } = await supabaseAsCaller.rpc("current_user_is_superadmin");
  if (rpcErr) {
    console.error("[revoke-executive-session] RPC current_user_is_superadmin error:", rpcErr);
    return jsonResponse({ error: "Authorization check failed" }, 403);
  }
  if (isSuper !== true) {
    return jsonResponse({ error: "Forbidden — superadmin only" }, 403);
  }

  // ── 2. Parse + validate input ──
  let body: { target_user_id?: string };
  try {
    body = await req.json();
  } catch (_e) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const targetId = (body?.target_user_id ?? "").trim();
  if (!targetId || !UUID_RE.test(targetId)) {
    return jsonResponse({ error: "target_user_id must be a valid UUID" }, 400);
  }

  // ── 3. Refuse self-revocation ──
  if (targetId === callerId) {
    return jsonResponse(
      { error: "Refusing to revoke your own session (would lock out superadmin)" },
      400,
    );
  }

  // ── 4. Verify target exists ──
  const { data: member, error: memberErr } = await supabaseAdmin
    .from("members")
    .select("id, email, executive_committee")
    .eq("id", targetId)
    .maybeSingle();

  if (memberErr) {
    console.error("[revoke-executive-session] members lookup error:", memberErr);
    return jsonResponse({ error: "Database error while locating member" }, 500);
  }
  if (!member) {
    return jsonResponse({ error: "Target member not found" }, 404);
  }

  const wasExecutive = member.executive_committee === true;

  // ── 5. Mutate DB state (access revoked) ──
  // REVOKE BY REMOVING THE COMMITTEE ENTRY, NOT BY SETTING THE BOOLEAN.
  //
  // members.executive_committee is DERIVED from the committee array by
  // update_executive_committee_flag(). Writing the boolean directly used to appear
  // to work and then silently reverse: the trigger was scoped to UPDATE OF committee,
  // so it stayed quiet here, and the next write that touched committee for any reason
  // recomputed the flag from an array that still said 'Executive Committee' and handed
  // the access back. Measured on the live database: start true, after this revoke
  // false, after any later committee write TRUE again.
  //
  // 20260824_04 removed that column scope, so the boolean is now recomputed on every
  // update and a direct write to it is a no-op. That makes the old line here inert
  // rather than deceptive, which is better, but it still does not revoke. The array is
  // the source of truth for CRM access, so revocation has to remove the entry.
  //
  // array_remove is used through an RPC rather than read-modify-write on the client
  // because a SELECT-then-UPDATE would lose a concurrent committee change, and this is
  // the security path.
  const { error: updErr } = await supabaseAdmin
    .rpc("slack_remove_committee_force", {
      p_member_id: targetId,
      p_committee: "Executive Committee",
    });
  if (updErr) {
    console.error("[revoke-executive-session] members update error:", updErr);
    return jsonResponse({ error: "Failed to update member row" }, 500);
  }

  // Demote superadmin → executive if applicable. Silent if no row.
  const { error: demoteErr } = await supabaseAdmin
    .from("member_roles")
    .update({ role: "executive" })
    .eq("user_id", targetId)
    .eq("role", "superadmin");
  if (demoteErr) {
    // Non-fatal — log + continue. Access is still revoked via executive_committee=false.
    console.warn("[revoke-executive-session] member_roles demote warning:", demoteErr.message);
  }

  // ── 6. Invalidate auth sessions ──
  let signOutWarning: string | null = null;
  try {
    const { error: signOutErr } = await supabaseAdmin.auth.admin.signOut(targetId);
    if (signOutErr) {
      console.warn("[revoke-executive-session] signOut error:", signOutErr.message);
      signOutWarning =
        "Database access revoked, but active sessions may take up to 1 hour to expire naturally.";
    }
  } catch (e) {
    console.warn("[revoke-executive-session] signOut threw:", e);
    signOutWarning =
      "Database access revoked, but active sessions may take up to 1 hour to expire naturally.";
  }

  // ── 7. Audit trail ──
  const { error: auditErr } = await supabaseAdmin.from("audit_log").insert({
    actor_id: callerId,
    actor_role: "authenticated",
    actor_email: callerRes.user.email ?? null,
    action: "AUTH",
    schema_name: "public",
    table_name: "members",
    row_id: targetId,
    context: {
      event: "revoke",
      revoked_user_id: targetId,
      revoked_user_email: member.email ?? null,
      revoked_by: callerId,
      was_executive: wasExecutive,
      signout_warning: signOutWarning,
    },
  });
  if (auditErr) {
    // Non-fatal — revocation already happened, but surface it in logs.
    console.error("[revoke-executive-session] audit_log insert error:", auditErr);
  }

  return jsonResponse({
    success: true,
    target_user_id: targetId,
    was_executive: wasExecutive,
    noop: !wasExecutive,
    warning: signOutWarning,
    message: wasExecutive
      ? "Access revoked."
      : "Target was not currently on the executive committee — no access change needed, but any active sessions have been signed out.",
  });
});
