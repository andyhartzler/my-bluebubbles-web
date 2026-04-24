import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

// Wave 2 access-audit 2026-04-24: require staff user JWT.
async function requireStaffUser(req) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({
        error: "Missing Authorization header"
      }), {
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
      error: new Response(JSON.stringify({
        error: "Invalid or expired JWT"
      }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const { data: memberRow } = await supabase
    .from("members")
    .select("executive_committee")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (!memberRow?.executive_committee) {
    return {
      error: new Response(JSON.stringify({
        error: "Forbidden — executive_committee required"
      }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { userId: userData.user.id };
}

serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  try {
    // Call the discover function
    const { data, error } = await supabase.rpc("discover_new_tables");
    if (error) throw error;
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: gate.userId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:discover-tables",
      row_id: null,
      context: { event: "discover-tables", table_count: data?.length ?? 0 }
    }).then(() => {}).catch((e) => console.error("[discover-tables] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      discovered_tables: data || [],
      message: data?.length ? `Found ${data.length} unconfigured tables` : "All tables are already configured"
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Error:", err);
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
