// supabase/functions/openstates-search-bills/index.ts
// SELF-CONTAINED VERSION - Works with Supabase Dashboard
// Includes inline API key rotation (no external _shared imports)
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const OPEN_STATES_BASE_URL = "https://v3.openstates.org";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
};
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
async function getApiKey() {
  const { data, error } = await supabase.rpc('get_available_api_key');
  if (error || !data || data.length === 0) {
    const { data: fallbackKey } = await supabase.from('legislation_api_keys').select('api_key, id, name').eq('is_active', true).lt('calls_today', 250).order('calls_today', {
      ascending: true
    }).limit(1).single();
    if (fallbackKey) {
      return {
        api_key: fallbackKey.api_key,
        key_id: fallbackKey.id,
        key_name: fallbackKey.name,
        calls_remaining: 250
      };
    }
    return null;
  }
  return {
    api_key: data[0].api_key,
    key_id: data[0].key_id,
    key_name: data[0].key_name,
    calls_remaining: data[0].calls_remaining
  };
}
async function logApiCall(keyId, success, wasRateLimited = false) {
  try {
    await supabase.rpc('log_api_key_call', {
      p_key_id: keyId,
      p_success: success,
      p_was_rate_limited: wasRateLimited
    });
  } catch (err) {
    console.log("Note: log_api_key_call not available");
  }
}
async function fetchOpenStates(endpoint, params) {
  const maxAttempts = 6;
  let attempts = 0;
  while(attempts < maxAttempts){
    const keyInfo = await getApiKey();
    if (!keyInfo) {
      return {
        success: false,
        error: "All API keys exhausted",
        rateLimited: true
      };
    }
    const queryString = params ? `?${params.toString()}` : "";
    const url = `${OPEN_STATES_BASE_URL}${endpoint}${queryString}`;
    console.log(`[Key ${keyInfo.key_id}] Searching: ${endpoint}`);
    try {
      const response = await fetch(url, {
        headers: {
          "X-API-KEY": keyInfo.api_key,
          "Accept": "application/json"
        }
      });
      if (response.status === 429) {
        console.log(`[Key ${keyInfo.key_id}] Rate limited, switching...`);
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }
      if (!response.ok) {
        const errorText = await response.text().catch(()=>"Unknown error");
        await logApiCall(keyInfo.key_id, false);
        return {
          success: false,
          error: `API error ${response.status}: ${errorText.substring(0, 200)}`
        };
      }
      await logApiCall(keyInfo.key_id, true);
      const data = await response.json();
      return {
        success: true,
        data: data,
        keyId: keyInfo.key_id
      };
    } catch (err) {
      if (err.message?.includes("429")) {
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }
      await logApiCall(keyInfo.key_id, false);
      return {
        success: false,
        error: err.message
      };
    }
  }
  return {
    success: false,
    error: "Exhausted all API key attempts",
    rateLimited: true
  };
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const params = await req.json();
    // Build query string
    const queryParams = new URLSearchParams();
    queryParams.append("jurisdiction", "mo");
    if (params.query) queryParams.append("q", params.query);
    if (params.session) queryParams.append("session", params.session);
    if (params.chamber) queryParams.append("chamber", params.chamber);
    if (params.classification) queryParams.append("classification", params.classification);
    if (params.subject) queryParams.append("subject", params.subject);
    if (params.sponsor) queryParams.append("sponsor", params.sponsor);
    if (params.updated_since) queryParams.append("updated_since", params.updated_since);
    queryParams.append("page", String(params.page || 1));
    queryParams.append("per_page", String(Math.min(params.per_page || 20, 50)));
    queryParams.append("include", "sponsorships");
    queryParams.append("include", "actions");
    console.log("Searching bills with params:", Object.fromEntries(queryParams));
    const result = await fetchOpenStates("/bills", queryParams);
    if (!result.success) {
      throw new Error(result.error || "Search failed");
    }
    const data = result.data;
    // Transform results for UI
    const transformedResults = data.results.map((bill)=>({
        openstates_bill_id: bill.id,
        jurisdiction: "mo",
        session: bill.session,
        bill_identifier: bill.identifier,
        title: bill.title,
        description: bill.abstracts?.[0]?.abstract || null,
        bill_type: bill.classification?.[0] || "bill",
        chamber: bill.from_organization?.classification || null,
        latest_action_date: bill.latest_action_date,
        latest_action_description: bill.latest_action_description,
        first_action_date: bill.first_action_date,
        primary_sponsor: bill.sponsorships?.find((s)=>s.primary)?.name || null,
        primary_sponsor_party: bill.sponsorships?.find((s)=>s.primary)?.person?.party || null,
        primary_sponsor_district: bill.sponsorships?.find((s)=>s.primary)?.person?.current_role?.district || null,
        sponsor_count: bill.sponsorships?.length || 0,
        sponsors: bill.sponsorships?.map((s)=>({
            name: s.name,
            is_primary: s.primary,
            classification: s.classification,
            party: s.person?.party || null,
            district: s.person?.current_role?.district || null
          })) || [],
        recent_actions: bill.actions?.slice(-5)?.map((a)=>({
            date: a.date,
            description: a.description,
            classification: a.classification || []
          })) || [],
        openstates_url: bill.openstates_url,
        subjects: bill.subject || [],
        classification: bill.classification || []
      }));
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:openstates-search-bills",
      row_id: null,
      context: {
        event: "openstates-search-bills",
        query: params.query ?? null,
        session: params.session ?? null,
        result_count: transformedResults.length
      }
    }).then(() => {}).catch((e) => console.error("[openstates-search-bills] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      results: transformedResults,
      pagination: data.pagination,
      total_results: data.pagination?.total_items || transformedResults.length
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Search bills error:", err);
    return new Response(JSON.stringify({
      success: false,
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
