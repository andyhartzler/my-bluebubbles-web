// supabase/functions/openstates-get-legislators/index.ts
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
    console.log(`[Key ${keyInfo.key_id}] Fetching: ${endpoint}`);
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
// ============================================================
// MAIN HANDLER
// ============================================================
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
    const { lat, lng, name, chamber, party } = await req.json();
    let endpoint;
    const queryParams = new URLSearchParams();
    if (lat && lng) {
      // Geo lookup
      endpoint = "/people.geo";
      queryParams.append("lat", String(lat));
      queryParams.append("lng", String(lng));
    } else {
      // Search
      endpoint = "/people";
      queryParams.append("jurisdiction", "mo");
      if (name) queryParams.append("name", name);
      if (chamber) queryParams.append("org_classification", chamber);
      if (party) queryParams.append("party", party);
    }
    queryParams.append("include", "offices");
    queryParams.append("include", "links");
    console.log("Fetching legislators:", endpoint, Object.fromEntries(queryParams));
    const result = await fetchOpenStates(endpoint, queryParams);
    if (!result.success) {
      throw new Error(result.error || "Failed to fetch legislators");
    }
    const data = result.data;
    // Transform results
    const legislators = (data.results || []).map((p)=>({
        openstates_id: p.id,
        openstates_person_id: p.id,
        name: p.name,
        given_name: p.given_name,
        family_name: p.family_name,
        first_name: p.given_name,
        last_name: p.family_name,
        suffix: p.suffix || null,
        party: p.party,
        chamber: p.current_role?.org_classification || null,
        district: p.current_role?.district || null,
        division_id: p.current_role?.division_id || null,
        title: p.current_role?.title || null,
        image: p.image,
        photo_url: p.image,
        email: p.email,
        offices: p.offices?.map((o)=>({
            name: o.name,
            address: o.address,
            voice: o.voice,
            fax: o.fax,
            classification: o.classification
          })) || [],
        capitol_address: p.offices?.find((o)=>o.classification === "capitol")?.address || null,
        capitol_phone: p.offices?.find((o)=>o.classification === "capitol")?.voice || null,
        capitol_email: p.email,
        district_address: p.offices?.find((o)=>o.classification === "district")?.address || null,
        district_phone: p.offices?.find((o)=>o.classification === "district")?.voice || null,
        links: p.links?.map((l)=>({
            url: l.url,
            note: l.note
          })) || [],
        website_url: p.links?.find((l)=>l.note?.toLowerCase().includes("website") || l.note?.toLowerCase().includes("homepage"))?.url || null,
        twitter: p.links?.find((l)=>l.url?.includes("twitter.com") || l.url?.includes("x.com"))?.url || null,
        facebook: p.links?.find((l)=>l.url?.includes("facebook.com"))?.url || null,
        openstates_url: p.openstates_url,
        other_identifiers: p.other_identifiers || [],
        extras: p.extras || {},
        sources: p.sources || []
      }));
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:openstates-get-legislators",
      row_id: null,
      context: {
        event: "openstates-get-legislators",
        lookup: lat && lng ? "geo" : "search",
        result_count: legislators.length
      }
    }).then(() => {}).catch((e) => console.error("[openstates-get-legislators] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      legislators,
      count: legislators.length,
      pagination: data.pagination
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Get legislators error:", err);
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
