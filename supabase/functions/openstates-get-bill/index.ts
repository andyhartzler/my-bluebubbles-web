// supabase/functions/openstates-get-bill/index.ts
// SELF-CONTAINED VERSION - Works with Supabase Dashboard
// Includes inline API key rotation (no external _shared imports)
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
// Wave 2 access-audit 2026-04-24: gate on authenticated user.
async function requireAuthenticatedUser(req) {
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
      if (response.status === 404) {
        await logApiCall(keyInfo.key_id, true);
        return {
          success: false,
          error: "Bill not found"
        };
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
  const gate = await requireAuthenticatedUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const { openstates_bill_id, jurisdiction, session, bill_id } = await req.json();
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:openstates-get-bill",
      row_id: openstates_bill_id ?? bill_id ?? null,
      context: { event: "openstates-get-bill", openstates_bill_id, jurisdiction, session, bill_id }
    }).then(() => {}).catch((e) => console.error("[openstates-get-bill] audit_log insert failed:", e));
    let endpoint;
    const params = new URLSearchParams();
    // Include all details
    params.append("include", "sponsorships");
    params.append("include", "actions");
    params.append("include", "votes");
    params.append("include", "documents");
    params.append("include", "versions");
    params.append("include", "sources");
    if (openstates_bill_id) {
      endpoint = `/bills/${openstates_bill_id}`;
    } else if (jurisdiction && session && bill_id) {
      endpoint = `/bills/${jurisdiction}/${session}/${encodeURIComponent(bill_id)}`;
    } else {
      throw new Error("Must provide either openstates_bill_id or jurisdiction/session/bill_id");
    }
    console.log("Fetching bill:", endpoint);
    const result = await fetchOpenStates(endpoint, params);
    if (!result.success) {
      if (result.error === "Bill not found") {
        return new Response(JSON.stringify({
          success: false,
          error: "Bill not found"
        }), {
          status: 404,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
      throw new Error(result.error || "Failed to fetch bill");
    }
    const bill = result.data;
    // Transform and enrich the data - FULLY CAPTURES ALL API FIELDS
    const transformedBill = {
      // Core Identifiers
      openstates_bill_id: bill.id,
      jurisdiction: bill.jurisdiction?.id || "ocd-jurisdiction/country:us/state:mo/government",
      jurisdiction_name: bill.jurisdiction?.name || "Missouri",
      session: bill.session,
      bill_identifier: bill.identifier,
      // Bill Metadata
      title: bill.title,
      classification: bill.classification || [],
      subjects: bill.subject || [],
      from_organization_id: bill.from_organization?.id || null,
      from_organization_name: bill.from_organization?.name || null,
      from_organization_classification: bill.from_organization?.classification || null,
      abstracts: bill.abstracts || [],
      primary_abstract: bill.abstracts?.[0]?.abstract || null,
      other_titles: bill.other_titles || [],
      other_identifiers: bill.other_identifiers || [],
      related_bills: bill.related_bills?.map((rb)=>({
          identifier: rb.identifier,
          legislative_session: rb.legislative_session,
          relation_type: rb.relation_type
        })) || [],
      // Timeline Dates
      first_action_date: bill.first_action_date,
      latest_action_date: bill.latest_action_date,
      latest_action_description: bill.latest_action_description,
      latest_passage_date: bill.latest_passage_date,
      openstates_created_at: bill.created_at,
      openstates_updated_at: bill.updated_at,
      // External Links
      openstates_url: bill.openstates_url,
      sources: bill.sources || [],
      extras: bill.extras || {},
      // Sponsors - FULL BillSponsorship objects
      sponsors: bill.sponsorships?.map((s)=>({
          openstates_sponsorship_id: s.id,
          name: s.name,
          entity_type: s.entity_type || 'person',
          is_primary: s.primary,
          sponsorship_classification: s.classification,
          openstates_person_id: s.person?.id || null,
          party: s.person?.party || null,
          role_title: s.person?.current_role?.title || null,
          role_org_classification: s.person?.current_role?.org_classification || null,
          district: s.person?.current_role?.district || null,
          division_id: s.person?.current_role?.division_id || null,
          organization_id: s.organization?.id || null,
          organization_name: s.organization?.name || null,
          organization_classification: s.organization?.classification || null
        })) || [],
      // Actions - FULL BillAction objects
      actions: bill.actions?.map((a, index)=>({
          openstates_action_id: a.id,
          action_date: a.date,
          action_description: a.description,
          action_classification: a.classification || [],
          action_order: a.order ?? index,
          organization_id: a.organization?.id || null,
          organization_name: a.organization?.name || null,
          organization_classification: a.organization?.classification || null,
          related_entities: a.related_entities?.map((re)=>({
              name: re.name,
              entity_type: re.entity_type,
              organization: re.organization || null,
              person: re.person || null
            })) || []
        })) || [],
      // Votes - FULL VoteEvent objects
      votes: bill.votes?.map((v)=>({
          openstates_vote_id: v.id,
          vote_identifier: v.identifier,
          vote_date: v.start_date,
          motion_text: v.motion_text,
          motion_classification: v.motion_classification || [],
          result: v.result,
          organization_id: v.organization?.id || null,
          organization_name: v.organization?.name || null,
          organization_classification: v.organization?.classification || null,
          counts: v.counts?.reduce((acc, c)=>{
            acc[c.option] = c.value;
            return acc;
          }, {}) || {},
          counts_detail: v.counts || [],
          votes_detail: v.votes?.map((pv)=>({
              id: pv.id,
              voter_name: pv.voter_name,
              option: pv.option,
              party: pv.voter?.party || null,
              voter_id: pv.voter?.id || null,
              voter_name_full: pv.voter?.name || null,
              current_role: pv.voter?.current_role || null
            })) || [],
          sources: v.sources || [],
          extras: v.extras || {}
        })) || [],
      // Bill Versions
      versions: bill.versions?.map((v)=>({
          openstates_document_id: v.id,
          note: v.note,
          date: v.date,
          classification: v.classification,
          links: v.links?.map((l)=>({
              url: l.url,
              media_type: l.media_type
            })) || []
        })) || [],
      // Documents
      documents: bill.documents?.map((d)=>({
          openstates_document_id: d.id,
          note: d.note,
          date: d.date,
          classification: d.classification,
          links: d.links?.map((l)=>({
              url: l.url,
              media_type: l.media_type
            })) || []
        })) || [],
      // Counts
      sponsor_count: bill.sponsorships?.length || 0,
      action_count: bill.actions?.length || 0,
      vote_count: bill.votes?.length || 0,
      version_count: bill.versions?.length || 0,
      document_count: bill.documents?.length || 0,
      // Raw data
      raw_data: bill
    };
    return new Response(JSON.stringify({
      success: true,
      bill: transformedBill
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Get bill error:", err);
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
