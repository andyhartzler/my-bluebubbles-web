import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
// MUST match what's configured in Mautic's local.php.
// Fail-closed if env missing — no hardcoded fallback.
const JWT_SECRET = Deno.env.get("MAUTIC_JWT_SECRET");
const MAUTIC_BASE_URL = Deno.env.get("MAUTIC_BASE_URL") || "https://email.moyd.app";
if (!JWT_SECRET) {
  console.error("mautic-auth: missing required env. Set MAUTIC_JWT_SECRET.");
}
// Mapping of Supabase user emails to Mautic admin emails
// This ensures only authorized CRM users can access Mautic
const AUTHORIZED_USERS = {
};
serve(async (req)=>{
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
  try {
    // Verify the user is authenticated with Supabase
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({
        error: "No authorization header"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Create Supabase client to verify the user
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    // Get the authenticated user
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({
        error: "Unauthorized - invalid session"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Wave 4 access-audit 2026-04-24: staff gate. Anyone authenticated used to be
    // able to mint Mautic admin tokens; plan §2 calls for staff-only.
    const { data: staffCheck, error: staffErr } = await supabase.rpc("is_staff");
    if (staffErr || staffCheck !== true) {
      return new Response(JSON.stringify({
        error: "Forbidden — staff access required"
      }), {
        status: 403,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Get optional redirect path from request body
    const body = await req.json().catch(()=>({}));
    const redirect = body.redirect || "/s/dashboard";
    // Determine Mautic email (either mapped or same as Supabase)
    const mauticEmail = AUTHORIZED_USERS[user.email] || user.email;
    // Create a signed JWT token for Mautic
    const encoder = new TextEncoder();
    const keyData = encoder.encode(JWT_SECRET);
    const key = await crypto.subtle.importKey("raw", keyData, {
      name: "HMAC",
      hash: "SHA-256"
    }, false, [
      "sign",
      "verify"
    ]);
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      // Standard JWT claims
      iss: "moyd-crm",
      sub: user.id,
      iat: now,
      exp: now + 60,
      // Custom claims
      email: mauticEmail,
      supabase_email: user.email,
      // Random nonce to prevent replay attacks
      nonce: crypto.randomUUID()
    };
    const token = await create({
      alg: "HS256",
      typ: "JWT"
    }, payload, key);
    // Wave 2 access-audit 2026-04-24: audit log (non-blocking).
    try {
      const adminClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
      adminClient.from("audit_log").insert({
        action: "EDGE_FN",
        actor_id: user.id,
        actor_role: "authenticated",
        schema_name: "public",
        table_name: "edge_fn:mautic-auth",
        row_id: null,
        context: { event: "mautic-auth", email: user.email, redirect }
      }).then(() => {}).catch((e) => console.error("[mautic-auth] audit_log insert failed:", e));
    } catch (e) {
      console.error("[mautic-auth] audit_log setup failed:", e);
    }
    // Build the auto-login URL
    const loginUrl = `${MAUTIC_BASE_URL}/crm-login?token=${encodeURIComponent(token)}&redirect=${encodeURIComponent(redirect)}`;
    return new Response(JSON.stringify({
      success: true,
      login_url: loginUrl,
      expires_in: 60
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Error generating auth token:", err);
    return new Response(JSON.stringify({
      error: "Internal server error"
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
