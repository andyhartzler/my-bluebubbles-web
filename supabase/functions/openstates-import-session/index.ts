// supabase/functions/openstates-import-session/index.ts
// Imports bills from OpenStates API for a given session

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const OPEN_STATES_BASE_URL = "https://v3.openstates.org";
const RATE_LIMIT_DELAY_MS = 6500;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================
// INLINE API KEY ROTATION
// ============================================================

interface ApiKeyInfo {
  api_key: string;
  key_id: number;
  key_name: string;
  calls_remaining: number;
}

interface FetchResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  keyId?: number;
  rateLimited?: boolean;
}

async function getApiKey(): Promise<ApiKeyInfo | null> {
  const { data, error } = await supabase.rpc('get_available_api_key');
  
  if (error || !data || data.length === 0) {
    const { data: fallbackKey } = await supabase
      .from('legislation_api_keys')
      .select('api_key, id, name')
      .eq('is_active', true)
      .lt('calls_today', 250)
      .order('calls_today', { ascending: true })
      .limit(1)
      .single();
    
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

async function logApiCall(keyId: number, success: boolean, wasRateLimited: boolean = false): Promise<void> {
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

async function fetchOpenStates<T = any>(endpoint: string, params?: URLSearchParams): Promise<FetchResult<T>> {
  const maxAttempts = 6;
  let attempts = 0;

  while (attempts < maxAttempts) {
    const keyInfo = await getApiKey();
    
    if (!keyInfo) {
      return { success: false, error: "All API keys exhausted", rateLimited: true };
    }

    const queryString = params ? `?${params.toString()}` : "";
    const url = `${OPEN_STATES_BASE_URL}${endpoint}${queryString}`;

    console.log(`[Key ${keyInfo.key_id}/${keyInfo.key_name}] Fetching: ${endpoint}`);

    try {
      const response = await fetch(url, {
        headers: {
          "X-API-KEY": keyInfo.api_key,
          "Accept": "application/json",
        },
      });

      if (response.status === 429) {
        console.log(`[Key ${keyInfo.key_id}] Rate limited, switching...`);
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }

      if (!response.ok) {
        const errorText = await response.text().catch(() => "Unknown error");
        await logApiCall(keyInfo.key_id, false);
        return { success: false, error: `API error ${response.status}: ${errorText.substring(0, 200)}` };
      }

      await logApiCall(keyInfo.key_id, true);
      const data = await response.json();
      return { success: true, data: data as T, keyId: keyInfo.key_id };

    } catch (err: any) {
      if (err.message?.includes("429")) {
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }
      await logApiCall(keyInfo.key_id, false);
      return { success: false, error: err.message };
    }
  }

  return { success: false, error: "Exhausted all API key attempts", rateLimited: true };
}

// ============================================================
// MAIN HANDLER
// ============================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const params = await req.json().catch(() => ({}));
    
    const session = params.session || "2026";
    const defaultPosition = params.default_position || null;
    const defaultPriority = params.default_priority || null;
    const maxPages = params.max_pages || 10;
    const startPage = params.start_page || 1;

    console.log(`Starting import for session: ${session}, pages ${startPage} to ${startPage + maxPages - 1}`);

    // Get existing bill IDs
    const existingIds = new Set<string>();
    let offset = 0;
    const batchSize = 1000;
    
    while (true) {
      const { data: existingBills } = await supabase
        .from("legislation_tracked_bills")
        .select("openstates_bill_id")
        .eq("session", session)
        .range(offset, offset + batchSize - 1);
      
      if (!existingBills || existingBills.length === 0) break;
      
      existingBills.forEach(b => {
        if (b.openstates_bill_id) existingIds.add(b.openstates_bill_id);
      });
      
      if (existingBills.length < batchSize) break;
      offset += batchSize;
    }
    
    console.log(`Found ${existingIds.size} existing tracked bills`);

    let page = startPage;
    let totalImported = 0;
    let totalSkipped = 0;
    let totalPages = 999;
    let apiCalls = 0;
    const errors: any[] = [];

    while (page <= totalPages && page < startPage + maxPages) {
      console.log(`Fetching page ${page}...`);
      
      const searchParams = new URLSearchParams();
      searchParams.append("jurisdiction", "mo");
      searchParams.append("session", session);
      searchParams.append("per_page", "20");
      searchParams.append("page", String(page));
      searchParams.append("include", "sponsorships");

      const result = await fetchOpenStates("/bills", searchParams);
      apiCalls++;

      if (!result.success) {
        if (result.rateLimited) {
          console.log("All API keys exhausted, stopping import");
          break;
        }
        throw new Error(result.error || "Failed to fetch bills");
      }

      const data = result.data;
      totalPages = data.pagination.max_page;

      console.log(`Page ${page}/${totalPages}: ${data.results.length} bills`);

      let pageImported = 0;
      let pageSkipped = 0;

      for (const bill of data.results) {
        if (existingIds.has(bill.id)) {
          totalSkipped++;
          pageSkipped++;
          continue;
        }

        try {
          const primarySponsor = bill.sponsorships?.find((s: any) => s.primary);

          const { data: inserted, error } = await supabase
            .from("legislation_tracked_bills")
            .upsert({
              openstates_bill_id: bill.id,
              jurisdiction: "mo",
              session: bill.session,
              bill_identifier: bill.identifier,
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
              related_bills: bill.related_bills || [],
              first_action_date: bill.first_action_date || null,
              latest_action_date: bill.latest_action_date || null,
              latest_action_description: bill.latest_action_description || null,
              latest_passage_date: bill.latest_passage_date || null,
              openstates_created_at: bill.created_at || null,
              openstates_updated_at: bill.updated_at || null,
              openstates_url: bill.openstates_url || null,
              sources: bill.sources || [],
              primary_sponsor_name: primarySponsor?.name || null,
              primary_sponsor_party: primarySponsor?.person?.party || null,
              primary_sponsor_district: primarySponsor?.person?.current_role?.district || null,
              sponsor_count: bill.sponsorships?.length || 0,
              position: defaultPosition,
              priority: defaultPriority,
              openstates_data: bill,
              last_synced_at: new Date().toISOString(),
            }, {
              onConflict: 'openstates_bill_id',
              ignoreDuplicates: true
            })
            .select('id');

          if (error) {
            if (!error.message?.includes('duplicate')) {
              errors.push({ bill_id: bill.identifier, error: error.message });
            } else {
              totalSkipped++;
              pageSkipped++;
            }
          } else if (inserted && inserted.length > 0) {
            totalImported++;
            pageImported++;
            existingIds.add(bill.id);
            console.log(`  + ${bill.identifier}: ${bill.title.substring(0, 50)}...`);
          } else {
            totalSkipped++;
            pageSkipped++;
          }
        } catch (err: any) {
          if (!err.message?.includes('duplicate')) {
            errors.push({ bill_id: bill.identifier, error: err.message });
          } else {
            totalSkipped++;
            pageSkipped++;
          }
        }
      }

      console.log(`  Page ${page} results: ${pageImported} new, ${pageSkipped} existing`);

      page++;

      if (page <= totalPages && page < startPage + maxPages) {
        await new Promise(r => setTimeout(r, RATE_LIMIT_DELAY_MS));
      }
    }

    const duration = Date.now() - startTime;

    // Log to sync_log
    await supabase.from("legislation_sync_log").insert({
      sync_type: "session_import",
      status: errors.length > 0 ? "partial" : "success",
      bills_checked: totalImported + totalSkipped,
      bills_updated: totalImported,
      started_at: new Date(startTime).toISOString(),
      completed_at: new Date().toISOString(),
      duration_ms: duration,
      error_message: errors.length > 0 ? `${errors.length} bills failed` : null,
      error_details: { 
        session, 
        pages_processed: page - startPage,
        skipped_duplicates: totalSkipped,
        errors: errors.length > 0 ? errors : undefined
      },
    });

    return new Response(
      JSON.stringify({
        success: true,
        session,
        total_imported: totalImported,
        total_skipped: totalSkipped,
        pages_processed: page - startPage,
        total_pages: totalPages,
        next_page: (page <= totalPages) ? page : null,
        api_calls: apiCalls,
        errors: errors.length > 0 ? errors : undefined,
        duration_ms: duration,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("Import failed:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});