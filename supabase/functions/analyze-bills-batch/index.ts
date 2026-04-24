// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
// analyze-bills-batch iterates and re-invokes analyze-bill internally via x-cron-secret.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};

async function requireAuthorized(req) {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { actorId: null, actorRole: "service_role" };
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header or x-cron-secret" }), {
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
  return { actorId: userData.user.id, actorRole: "authenticated" };
}

serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  try {
    const { batchSize = 5, onlyUnanalyzed = true, session = null, prioritizeBillText = true } = await req.json();
    // Build query for bills to analyze
    let query = supabase.from("legislation_tracked_bills").select("id, bill_identifier").eq("is_archived", false).eq("ai_analysis_pending", false);
    if (onlyUnanalyzed) {
      query = query.is("ai_analyzed_at", null);
    }
    if (session) {
      query = query.eq("session", session);
    }
    // Prioritize bills with full text
    if (prioritizeBillText) {
      query = query.order("current_bill_text", {
        ascending: false,
        nullsFirst: false
      });
    }
    query = query.limit(batchSize);
    const { data: bills, error: queryError } = await query;
    if (queryError) {
      throw new Error(`Query failed: ${queryError.message}`);
    }
    if (!bills || bills.length === 0) {
      return new Response(JSON.stringify({
        success: true,
        message: "No bills to analyze",
        processed: 0
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Process each bill
    const cronSecretForInternalCall = Deno.env.get("CRON_SECRET") ?? "";
    const results = [];
    for (const bill of bills){
      try {
        // Call the analyze-bill function with x-cron-secret for internal server-to-server call
        const response = await fetch(`${supabaseUrl}/functions/v1/analyze-bill`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${supabaseServiceRoleKey}`,
            "x-cron-secret": cronSecretForInternalCall
          },
          body: JSON.stringify({
            billId: bill.id
          })
        });
        const result = await response.json();
        results.push({
          billId: bill.id,
          identifier: bill.bill_identifier,
          success: response.ok,
          result: response.ok ? result : null,
          error: response.ok ? null : result.error
        });
        // Rate limiting - wait between requests
        await new Promise((resolve)=>setTimeout(resolve, 2000));
      } catch (err) {
        results.push({
          billId: bill.id,
          identifier: bill.bill_identifier,
          success: false,
          error: err.message
        });
      }
    }
    const successful = results.filter((r)=>r.success).length;
    const failed = results.filter((r)=>!r.success).length;
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:analyze-bills-batch",
      row_id: null,
      context: {
        event: "analyze-bills-batch",
        batch_size: batchSize,
        processed: results.length,
        successful,
        failed
      }
    }).then(() => {}).catch((e) => console.error("[analyze-bills-batch] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      processed: results.length,
      successful,
      failed,
      results
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
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
