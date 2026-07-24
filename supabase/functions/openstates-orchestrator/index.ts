// supabase/functions/openstates-orchestrator/index.ts
// SELF-CONTAINED VERSION - Works with Supabase Dashboard
// Coordinates all sync tasks, allocates API budget

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface TaskResult {
  task: string;
  success: boolean;
  details: any;
  api_calls_used: number;
  duration_ms: number;
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

async function getSystemStatus(): Promise<{
  callsRemaining: number;
  billsNeedingDetailSync: number;
  billsNeedingTextExtract: number;
  billsMissingSponsors: number;
}> {
  // Get API calls remaining
  const { data: apiKeys } = await supabase
    .from('legislation_api_keys')
    .select('calls_today, calls_limit')
    .eq('is_active', true)
    .eq('is_rate_limited', false);
  
  const callsRemaining = (apiKeys || []).reduce(
    (sum, key) => sum + (key.calls_limit - key.calls_today), 
    0
  );
  
  // Get bills needing detail sync
  const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
  const { count: needSync } = await supabase
    .from('legislation_tracked_bills')
    .select('id', { count: 'exact', head: true })
    .eq('session', '2026')
    .or('is_archived.eq.false,is_archived.is.null')
    .is('sync_error', null)
    .or(`last_synced_at.is.null,last_synced_at.lt.${sixHoursAgo}`);
  
  // Get bills needing text extract
  const { count: needText } = await supabase
    .from('legislation_tracked_bills')
    .select('id', { count: 'exact', head: true })
    .eq('session', '2026')
    .is('current_bill_text', null)
    .is('sync_error', null);
  
  // Get bills missing sponsors
  const { data: billsWithSponsors } = await supabase
    .from('legislation_bill_sponsors')
    .select('bill_id');
  
  const sponsorBillIds = new Set((billsWithSponsors || []).map(s => s.bill_id));
  
  const { data: allBills } = await supabase
    .from('legislation_tracked_bills')
    .select('id')
    .eq('session', '2026');
  
  const missingSponsors = (allBills || []).filter(b => !sponsorBillIds.has(b.id)).length;
  
  return {
    callsRemaining,
    billsNeedingDetailSync: needSync || 0,
    billsNeedingTextExtract: needText || 0,
    billsMissingSponsors: missingSponsors,
  };
}

// Task 1: Import new bills
async function runImportTask(maxPages: number): Promise<TaskResult> {
  const startTime = Date.now();
  
  try {
    const response = await supabase.functions.invoke("openstates-import-session", {
      body: { session: "2026", max_pages: maxPages, start_page: 1 },
    });
    
    if (response.error) throw new Error(response.error.message);
    
    return {
      task: "import_session",
      success: true,
      details: response.data,
      api_calls_used: response.data?.api_calls || maxPages,
      duration_ms: Date.now() - startTime,
    };
  } catch (err: any) {
    return {
      task: "import_session",
      success: false,
      details: { error: err.message },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  }
}

// Task 2: Sync bill details
async function runDetailSyncTask(limit: number): Promise<TaskResult> {
  const startTime = Date.now();
  
  try {
    const response = await supabase.functions.invoke("openstates-sync-tracked-bills", {
      body: { mode: "normal", limit: limit },
    });
    
    if (response.error) throw new Error(response.error.message);
    
    return {
      task: "detail_sync",
      success: true,
      details: response.data,
      api_calls_used: response.data?.api_calls_made || response.data?.bills_checked || limit,
      duration_ms: Date.now() - startTime,
    };
  } catch (err: any) {
    return {
      task: "detail_sync",
      success: false,
      details: { error: err.message },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  }
}

// Task 3: Extract bill text
async function runTextExtractTask(limit: number): Promise<TaskResult> {
  const startTime = Date.now();
  
  try {
    const response = await supabase.functions.invoke("extract-bill-text-openstates", {
      body: { session: "2026", limit: limit },
    });
    
    if (response.error) throw new Error(response.error.message);
    
    return {
      task: "text_extract",
      success: true,
      details: response.data,
      api_calls_used: response.data?.api_calls || 0,
      duration_ms: Date.now() - startTime,
    };
  } catch (err: any) {
    return {
      task: "text_extract",
      success: false,
      details: { error: err.message },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  }
}

// Task 4: Extract sponsors from cached data (NO API calls)
async function runSponsorsFromCacheTask(): Promise<TaskResult> {
  const startTime = Date.now();
  
  try {
    // Get bills missing sponsors that have cached data
    const { data: billsWithoutSponsors } = await supabase
      .from('legislation_tracked_bills')
      .select('id, bill_identifier, openstates_data')
      .eq('session', '2026')
      .not('openstates_data', 'is', null)
      .limit(100);
    
    // Filter to those actually missing sponsors
    const { data: existingSponsors } = await supabase
      .from('legislation_bill_sponsors')
      .select('bill_id');
    
    const billsWithSponsors = new Set((existingSponsors || []).map(s => s.bill_id));
    
    const billsToProcess = (billsWithoutSponsors || []).filter(
      b => !billsWithSponsors.has(b.id) && 
           b.openstates_data?.sponsorships?.length > 0
    );
    
    let extracted = 0;
    
    for (const bill of billsToProcess) {
      const sponsorships = bill.openstates_data.sponsorships;
      
      if (!sponsorships?.length) continue;
      
      const sponsorRecords = sponsorships.map((s: any) => ({
        bill_id: bill.id,
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
        chamber: s.person?.current_role?.org_classification || null,
      }));
      
      const { error } = await supabase
        .from('legislation_bill_sponsors')
        .insert(sponsorRecords);
      
      if (!error) {
        extracted += sponsorRecords.length;
      }
    }
    
    return {
      task: "sponsors_from_cache",
      success: true,
      details: { 
        bills_processed: billsToProcess.length,
        sponsors_extracted: extracted 
      },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  } catch (err: any) {
    return {
      task: "sponsors_from_cache",
      success: false,
      details: { error: err.message },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  }
}

// Task 5: Link sponsors to legislators (NO API calls)
async function runSponsorLinkingTask(): Promise<TaskResult> {
  const startTime = Date.now();
  
  try {
    // Link sponsors to legislators by openstates_person_id
    const { data, error } = await supabase.rpc('link_sponsors_to_legislators');
    
    if (error) {
      // Fallback: do it manually
      const { data: unlinked } = await supabase
        .from('legislation_bill_sponsors')
        .select('id, openstates_person_id')
        .is('legislator_id', null)
        .not('openstates_person_id', 'is', null)
        .limit(500);
      
      let linked = 0;
      
      for (const sponsor of unlinked || []) {
        const { data: legislator } = await supabase
          .from('legislation_legislators')
          .select('id')
          .eq('openstates_person_id', sponsor.openstates_person_id)
          .single();
        
        if (legislator) {
          await supabase
            .from('legislation_bill_sponsors')
            .update({ legislator_id: legislator.id })
            .eq('id', sponsor.id);
          linked++;
        }
      }
      
      return {
        task: "sponsor_linking",
        success: true,
        details: { sponsors_linked: linked },
        api_calls_used: 0,
        duration_ms: Date.now() - startTime,
      };
    }
    
    return {
      task: "sponsor_linking",
      success: true,
      details: { sponsors_linked: data || 0 },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  } catch (err: any) {
    return {
      task: "sponsor_linking",
      success: false,
      details: { error: err.message },
      api_calls_used: 0,
      duration_ms: Date.now() - startTime,
    };
  }
}

// ============================================================
// MAIN HANDLER
// ============================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  
  const startTime = Date.now();
  
  // Create orchestration log entry
  const { data: orchLog } = await supabase
    .from("legislation_sync_log")
    .insert({
      sync_type: "orchestrator",
      status: "running",
      started_at: new Date().toISOString(),
    })
    .select()
    .single();
  
  try {
    const body = await req.json().catch(() => ({}));
    const { mode = "auto", dry_run = false } = body;
    
    // Get current system status
    const status = await getSystemStatus();
    console.log("System status:", status);
    
    // Budget allocation (with 6 keys, we have ~1500 calls/day)
    // - 20% for import (~300 calls = ~15 pages)
    // - 60% for detail sync (~900 calls)
    // - 20% for text extract (~300 calls, but uses cache)
    
    const importBudget = Math.floor(status.callsRemaining * 0.20);
    const detailSyncBudget = Math.floor(status.callsRemaining * 0.60);
    const textExtractBudget = Math.floor(status.callsRemaining * 0.20);
    
    const plan = {
      total_calls_available: status.callsRemaining,
      import_pages: Math.min(Math.floor(importBudget / 1), 4),
      detail_sync_bills: Math.min(detailSyncBudget, status.billsNeedingDetailSync, 50),
      text_extract_bills: Math.min(textExtractBudget, status.billsNeedingTextExtract, 20),
    };
    
    console.log("Execution plan:", plan);
    
    if (dry_run) {
      return new Response(
        JSON.stringify({ success: true, dry_run: true, status, plan }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    
    // Execute tasks
    const results: TaskResult[] = [];
    let totalApiCallsUsed = 0;
    
    // Task 1: Import new bills
    if (plan.import_pages > 0) {
      console.log(`Running import task (${plan.import_pages} pages)...`);
      const result = await runImportTask(plan.import_pages);
      results.push(result);
      totalApiCallsUsed += result.api_calls_used;
      console.log(`Import complete: ${result.details.total_imported || 0} imported`);
    }
    
    // Task 2: Detail sync
    if (plan.detail_sync_bills > 0 && totalApiCallsUsed < status.callsRemaining) {
      console.log(`Running detail sync task (${plan.detail_sync_bills} bills)...`);
      const result = await runDetailSyncTask(plan.detail_sync_bills);
      results.push(result);
      totalApiCallsUsed += result.api_calls_used;
      console.log(`Detail sync complete: ${result.details.bills_updated || 0} updated`);
    }
    
    // Task 3: Text extraction
    if (plan.text_extract_bills > 0 && totalApiCallsUsed < status.callsRemaining) {
      console.log(`Running text extract task (${plan.text_extract_bills} bills)...`);
      const result = await runTextExtractTask(plan.text_extract_bills);
      results.push(result);
      totalApiCallsUsed += result.api_calls_used;
      console.log(`Text extract complete: ${result.details.extracted || 0} extracted`);
    }
    
    // Task 4: Extract sponsors from cache (FREE)
    console.log("Running sponsors from cache task...");
    const sponsorCacheResult = await runSponsorsFromCacheTask();
    results.push(sponsorCacheResult);
    console.log(`Sponsors from cache: ${sponsorCacheResult.details.sponsors_extracted || 0} extracted`);
    
    // Task 5: Link sponsors (FREE)
    console.log("Running sponsor linking task...");
    const linkResult = await runSponsorLinkingTask();
    results.push(linkResult);
    console.log(`Sponsors linked: ${linkResult.details.sponsors_linked || 0}`);
    
    const duration = Date.now() - startTime;
    
    // Summary
    const summary = {
      tasks_run: results.length,
      tasks_succeeded: results.filter(r => r.success).length,
      tasks_failed: results.filter(r => !r.success).length,
      total_api_calls_used: totalApiCallsUsed,
      total_duration_ms: duration,
      bills_imported: results.find(r => r.task === "import_session")?.details?.total_imported || 0,
      bills_synced: results.find(r => r.task === "detail_sync")?.details?.bills_updated || 0,
      bills_text_extracted: results.find(r => r.task === "text_extract")?.details?.extracted || 0,
      sponsors_extracted: results.find(r => r.task === "sponsors_from_cache")?.details?.sponsors_extracted || 0,
      sponsors_linked: results.find(r => r.task === "sponsor_linking")?.details?.sponsors_linked || 0,
    };
    
    // Update orchestration log
    await supabase
      .from("legislation_sync_log")
      .update({
        status: summary.tasks_failed > 0 ? "partial" : "success",
        bills_checked: summary.bills_imported + summary.bills_synced,
        bills_updated: summary.bills_synced + summary.bills_text_extracted,
        completed_at: new Date().toISOString(),
        duration_ms: duration,
        error_details: { plan, results, summary },
      })
      .eq("id", orchLog.id);
    
    return new Response(
      JSON.stringify({ success: true, mode, initial_status: status, plan, results, summary }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (err: any) {
    const duration = Date.now() - startTime;
    
    await supabase
      .from("legislation_sync_log")
      .update({
        status: "failed",
        error_message: err.message,
        completed_at: new Date().toISOString(),
        duration_ms: duration,
      })
      .eq("id", orchLog?.id);
    
    console.error("Orchestrator error:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
