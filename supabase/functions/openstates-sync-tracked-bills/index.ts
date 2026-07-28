// supabase/functions/openstates-sync-tracked-bills/index.ts
// SELF-CONTAINED VERSION - Works with Supabase Dashboard
// Includes inline API key rotation (no external _shared imports)
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const OPEN_STATES_BASE_URL = "https://v3.openstates.org";
const RATE_LIMIT_DELAY_MS = 6500;
const BATCH_SIZE = 10;
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

// Wave 4 access-audit: accept either staff user JWT OR x-cron-secret header (for pg_cron invocation).
async function requireAuthorized(req) {
  // Path A: cron shared secret
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { actorId: null, actorRole: "service_role" };
  }
  // Path B: user JWT + is_staff()
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

// Get the next available API key from the database
async function getApiKey() {
  const { data, error } = await supabase.rpc('get_available_api_key');
  if (error) {
    console.error("Error getting API key:", error);
    // Fallback: try to get any key directly
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
  if (!data || data.length === 0) {
    console.log("No API keys available - all exhausted or rate limited");
    return null;
  }
  return {
    api_key: data[0].api_key,
    key_id: data[0].key_id,
    key_name: data[0].key_name,
    calls_remaining: data[0].calls_remaining
  };
}
// Log an API call result
async function logApiCall(keyId, success, wasRateLimited = false) {
  try {
    await supabase.rpc('log_api_key_call', {
      p_key_id: keyId,
      p_success: success,
      p_was_rate_limited: wasRateLimited
    });
  } catch (err) {
    // Fallback: update directly
    await supabase.from('legislation_api_keys').update({
      calls_today: supabase.rpc('increment_calls_today'),
      is_rate_limited: wasRateLimited || undefined,
      rate_limited_until: wasRateLimited ? new Date(Date.now() + 3600000).toISOString() : undefined,
      last_call_at: new Date().toISOString()
    }).eq('id', keyId);
  }
}
// Fetch from OpenStates API with automatic key rotation
async function fetchOpenStates(endpoint, params) {
  const maxAttempts = 6;
  let attempts = 0;
  while(attempts < maxAttempts){
    const keyInfo = await getApiKey();
    if (!keyInfo) {
      return {
        success: false,
        error: "All API keys exhausted or rate limited",
        rateLimited: true
      };
    }
    const queryString = params ? `?${params.toString()}` : "";
    const url = `${OPEN_STATES_BASE_URL}${endpoint}${queryString}`;
    console.log(`[Key ${keyInfo.key_id}/${keyInfo.key_name}] Fetching: ${endpoint} (${keyInfo.calls_remaining} remaining)`);
    try {
      const response = await fetch(url, {
        headers: {
          "X-API-KEY": keyInfo.api_key,
          "Accept": "application/json"
        }
      });
      if (response.status === 429) {
        console.log(`[Key ${keyInfo.key_id}] Rate limited (429), switching to next key...`);
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }
      if (!response.ok) {
        const errorText = await response.text().catch(()=>"Unknown error");
        await logApiCall(keyInfo.key_id, false);
        return {
          success: false,
          error: `API error ${response.status}: ${errorText.substring(0, 200)}`,
          keyId: keyInfo.key_id
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
      console.error(`[Key ${keyInfo.key_id}] Fetch error:`, err.message);
      if (err.message?.includes("429") || err.message?.toLowerCase().includes("rate limit")) {
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }
      await logApiCall(keyInfo.key_id, false);
      return {
        success: false,
        error: err.message,
        keyId: keyInfo.key_id
      };
    }
  }
  return {
    success: false,
    error: "Exhausted all API key attempts",
    rateLimited: true
  };
}
// Convenience method for fetching a single bill with all includes
async function fetchBill(openstatesBillId) {
  const params = new URLSearchParams();
  params.append("include", "sponsorships");
  params.append("include", "actions");
  params.append("include", "votes");
  params.append("include", "documents");
  params.append("include", "versions");
  params.append("include", "sources");
  return fetchOpenStates(`/bills/${openstatesBillId}`, params);
}
// Collapse sponsor rows that would collide with each other under
// legislation_bill_sponsors_unique, whose columns are inferred from the
// ON CONFLICT clause in 20260423_01_backfill_orphan_rpcs.sql to be
// (bill_id, name, sponsorship_classification). The DDL is not in this repo.
// OpenStates routinely returns two sponsorship entries for the same person with
// the same classification on one bill, each with its own sponsorship id. A plain
// bulk insert of that array trips the unique constraint against itself, Postgres
// rolls back the whole statement, and the bill is left with no sponsors at all.
//
// A row is only a dedupe candidate when both name and classification are
// present. A NULL in either column is distinct as far as a unique constraint is
// concerned, so Postgres stores those rows happily and dropping them here would
// silently lose data that the old code kept.
function dedupeSponsorRecords(records: any[]): any[] {
  const seen = new Set();
  const deduped = [];
  for (const record of records){
    if (record.name == null || record.sponsorship_classification == null) {
      deduped.push(record);
      continue;
    }
    const key = JSON.stringify([
      record.bill_id,
      record.name,
      record.sponsorship_classification
    ]);
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(record);
  }
  return deduped;
}
// ============================================================
// MAIN SYNC LOGIC (preserved from original)
// ============================================================
async function syncSingleBill(trackedBill) {
  const result = await fetchBill(trackedBill.openstates_bill_id);
  if (!result.success) {
    return {
      updated: false,
      newActions: 0,
      newVotes: 0,
      newDocuments: 0,
      error: result.error
    };
  }
  const bill = result.data;
  let newActionsCount = 0;
  let newVotesCount = 0;
  let newDocumentsCount = 0;
  // ========================================
  // UPDATE MAIN BILL RECORD - ALL API FIELDS
  // ========================================
  const primarySponsor = bill.sponsorships?.find((s)=>s.primary);
  // Detect passage through chambers
  const passedLower = bill.actions?.some((a)=>a.classification?.includes("passage") && a.organization?.classification === "lower");
  const passedUpper = bill.actions?.some((a)=>a.classification?.includes("passage") && a.organization?.classification === "upper");
  const signedByGovernor = bill.actions?.some((a)=>a.classification?.includes("executive-signature"));
  const vetoed = bill.actions?.some((a)=>a.classification?.includes("executive-veto"));
  // Build comprehensive update data - ALL API FIELDS
  const updateData = {
    // Core metadata
    title: bill.title,
    classification: bill.classification || [],
    subjects: bill.subject || [],
    // From organization
    from_organization_id: bill.from_organization?.id || null,
    from_organization_name: bill.from_organization?.name || null,
    from_organization_classification: bill.from_organization?.classification || null,
    // Abstracts
    abstracts: bill.abstracts || [],
    primary_abstract: bill.abstracts?.[0]?.abstract || null,
    // Other titles and identifiers
    other_titles: bill.other_titles || [],
    other_identifiers: bill.other_identifiers || [],
    // Related bills
    related_bills: bill.related_bills?.map((rb)=>({
        identifier: rb.identifier,
        legislative_session: rb.legislative_session,
        relation_type: rb.relation_type
      })) || [],
    // Timeline dates
    first_action_date: bill.first_action_date,
    latest_action_date: bill.latest_action_date,
    latest_action_description: bill.latest_action_description,
    latest_passage_date: bill.latest_passage_date,
    // Open States timestamps
    openstates_created_at: bill.created_at,
    openstates_updated_at: bill.updated_at,
    // External links
    openstates_url: bill.openstates_url,
    sources: bill.sources || [],
    // Extras
    extras: bill.extras || {},
    // Passage tracking
    passed_lower: passedLower,
    passed_upper: passedUpper,
    signed_by_governor: signedByGovernor,
    vetoed: vetoed,
    // Cached counts
    sponsor_count: bill.sponsorships?.length || 0,
    action_count: bill.actions?.length || 0,
    vote_count: bill.votes?.length || 0,
    version_count: bill.versions?.length || 0,
    document_count: bill.documents?.length || 0,
    // Primary sponsor info
    primary_sponsor_name: primarySponsor?.name || null,
    primary_sponsor_party: primarySponsor?.person?.party || null,
    primary_sponsor_district: primarySponsor?.person?.current_role?.district || null,
    // Full cached data
    openstates_data: bill,
    last_synced_at: new Date().toISOString(),
    sync_error: null
  };
  // Find passage dates
  if (passedLower) {
    const passageAction = bill.actions?.find((a)=>a.classification?.includes("passage") && a.organization?.classification === "lower");
    if (passageAction) updateData.passed_lower_date = passageAction.date;
  }
  if (passedUpper) {
    const passageAction = bill.actions?.find((a)=>a.classification?.includes("passage") && a.organization?.classification === "upper");
    if (passageAction) updateData.passed_upper_date = passageAction.date;
  }
  if (signedByGovernor) {
    const signAction = bill.actions?.find((a)=>a.classification?.includes("executive-signature"));
    if (signAction) updateData.signed_date = signAction.date;
  }
  if (vetoed) {
    const vetoAction = bill.actions?.find((a)=>a.classification?.includes("executive-veto"));
    if (vetoAction) updateData.veto_date = vetoAction.date;
  }
  // Latest vote info
  if (bill.votes?.length > 0) {
    const latestVote = bill.votes.sort((a, b)=>new Date(b.start_date).getTime() - new Date(a.start_date).getTime())[0];
    updateData.latest_vote_result = latestVote.result;
    updateData.latest_vote_date = latestVote.start_date;
  }
  await supabase.from("legislation_tracked_bills").update(updateData).eq("id", trackedBill.id);
  // ========================================
  // SYNC ACTIONS - FULL API FIELDS
  // ========================================
  if (bill.actions?.length > 0) {
    for (const action of bill.actions){
      const { data: existing } = await supabase.from("legislation_bill_actions").select("id").eq("bill_id", trackedBill.id).eq("action_date", action.date).eq("action_description", action.description).maybeSingle();
      if (!existing) {
        await supabase.from("legislation_bill_actions").insert({
          bill_id: trackedBill.id,
          openstates_action_id: action.id,
          action_date: action.date,
          action_description: action.description,
          action_classification: action.classification || [],
          action_order: action.order,
          organization_id: action.organization?.id || null,
          organization_name: action.organization?.name || null,
          organization_classification: action.organization?.classification || null,
          chamber: action.organization?.classification || null,
          related_entities: action.related_entities?.map((re)=>({
              name: re.name,
              entity_type: re.entity_type,
              organization: re.organization || null,
              person: re.person || null
            })) || [],
          is_new: true
        });
        newActionsCount++;
      }
    }
  }
  // ========================================
  // SYNC SPONSORS - FULL API FIELDS
  // ========================================
  const { error: deleteError } = await supabase.from("legislation_bill_sponsors").delete().eq("bill_id", trackedBill.id);
  if (deleteError) {
    console.error(`Failed to delete existing sponsors for ${trackedBill.bill_identifier}, skipping sponsor write:`, deleteError);
  }
  let sponsorsInserted = 0;
  // The insert below is a plain INSERT, and it is safe only because the DELETE
  // immediately above cleared this bill's rows. When that DELETE fails we no
  // longer know the bill is empty, and inserting anyway collides with the
  // surviving rows on legislation_bill_sponsors_unique, which aborts the whole
  // multi-row statement and emits the "duplicate key value violates unique
  // constraint" line that SUPABASE-PLATFORM-1 rolls up. Skipping the sponsor
  // write leaves the bill on its previous sponsors, which is the same data this
  // sync was about to rewrite from the same OpenStates payload, so nothing is
  // lost by waiting for the next run.
  //
  // This closes the deterministic case only. Two overlapping invocations can
  // still interleave delete and insert on the same bill and collide on the same
  // constraint, and that path is not addressed here.
  if (!deleteError && bill.sponsorships?.length > 0) {
    const sponsorRecords = bill.sponsorships.map((s)=>({
        bill_id: trackedBill.id,
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
        organization_id: s.organization?.id || null,
        organization_name: s.organization?.name || null,
        organization_classification: s.organization?.classification || null
      }));
    const deduped = dedupeSponsorRecords(sponsorRecords);
    const { data: insertedSponsors, error: insertError } = await supabase.from("legislation_bill_sponsors").insert(deduped).select();
    if (insertError) {
      console.error(`Failed to insert sponsors for ${trackedBill.bill_identifier}:`, insertError);
    } else {
      sponsorsInserted = insertedSponsors?.length || 0;
      console.log(`Inserted ${sponsorsInserted} sponsors for ${trackedBill.bill_identifier}`);
    }
  }
  // ========================================
  // SYNC VOTES - FULL API FIELDS
  // ========================================
  if (bill.votes?.length > 0) {
    for (const vote of bill.votes){
      const { data: existing } = await supabase.from("legislation_bill_votes").select("id").eq("openstates_vote_id", vote.id).maybeSingle();
      if (!existing) {
        const voteCounts = vote.counts?.reduce((acc, c)=>{
          acc[c.option.toLowerCase()] = c.value;
          return acc;
        }, {}) || {};
        await supabase.from("legislation_bill_votes").insert({
          bill_id: trackedBill.id,
          openstates_vote_id: vote.id,
          vote_identifier: vote.identifier,
          vote_date: vote.start_date,
          motion_text: vote.motion_text,
          motion_classification: vote.motion_classification || [],
          result: vote.result,
          organization_id: vote.organization?.id || null,
          organization_name: vote.organization?.name || null,
          organization_classification: vote.organization?.classification || null,
          chamber: vote.organization?.classification || null,
          yes_count: voteCounts.yes || 0,
          no_count: voteCounts.no || 0,
          abstain_count: voteCounts.abstain || 0,
          not_voting_count: voteCounts["not voting"] || voteCounts.not_voting || 0,
          absent_count: voteCounts.absent || 0,
          excused_count: voteCounts.excused || 0,
          other_count: voteCounts.other || 0,
          counts_detail: vote.counts || [],
          votes_detail: vote.votes?.map((pv)=>({
              id: pv.id,
              voter_name: pv.voter_name,
              option: pv.option,
              party: pv.voter?.party || null,
              voter_id: pv.voter?.id || null,
              voter_name_full: pv.voter?.name || null,
              current_role: pv.voter?.current_role || null
            })),
          sources: vote.sources || [],
          extras: vote.extras || {},
          is_new: true
        });
        newVotesCount++;
      }
    }
  }
  // ========================================
  // SYNC DOCUMENTS & VERSIONS
  // ========================================
  if (bill.versions?.length > 0) {
    for (const version of bill.versions){
      const { data: existing } = await supabase.from("legislation_bill_documents").select("id").eq("bill_id", trackedBill.id).eq("document_type", "version").eq("note", version.note).maybeSingle();
      if (!existing) {
        await supabase.from("legislation_bill_documents").insert({
          bill_id: trackedBill.id,
          openstates_document_id: version.id,
          document_type: "version",
          note: version.note,
          document_date: version.date,
          classification: version.classification,
          links: version.links?.map((l)=>({
              url: l.url,
              media_type: l.media_type
            })) || [],
          primary_link: version.links?.[0]?.url || null,
          primary_media_type: version.links?.[0]?.media_type || null,
          is_new: true
        });
        newDocumentsCount++;
      }
    }
  }
  if (bill.documents?.length > 0) {
    for (const doc of bill.documents){
      const { data: existing } = await supabase.from("legislation_bill_documents").select("id").eq("bill_id", trackedBill.id).eq("document_type", "document").eq("note", doc.note).maybeSingle();
      if (!existing) {
        await supabase.from("legislation_bill_documents").insert({
          bill_id: trackedBill.id,
          openstates_document_id: doc.id,
          document_type: "document",
          note: doc.note,
          document_date: doc.date,
          classification: doc.classification,
          links: doc.links?.map((l)=>({
              url: l.url,
              media_type: l.media_type
            })) || [],
          primary_link: doc.links?.[0]?.url || null,
          primary_media_type: doc.links?.[0]?.media_type || null,
          is_new: true
        });
        newDocumentsCount++;
      }
    }
  }
  // ========================================
  // UPDATE SYNC STATUS (if table exists)
  // ========================================
  try {
    await supabase.rpc('mark_bill_detail_synced', {
      p_bill_id: trackedBill.id,
      p_action_count: bill.actions?.length || 0,
      p_vote_count: bill.votes?.length || 0,
      p_version_count: bill.versions?.length || 0,
      p_api_updated_at: bill.updated_at,
      p_error: null
    });
  } catch (err) {
    // Sync status table might not exist yet, that's ok
    console.log("Note: mark_bill_detail_synced not available");
  }
  return {
    updated: true,
    newActions: newActionsCount,
    newVotes: newVotesCount,
    newDocuments: newDocumentsCount
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
  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  const startTime = Date.now();
  // Create sync log entry
  const { data: syncLog } = await supabase.from("legislation_sync_log").insert({
    sync_type: "incremental",
    status: "running",
    started_at: new Date().toISOString()
  }).select().single();
  try {
    const { bill_id, mode = "normal", limit = BATCH_SIZE } = await req.json().catch(()=>({}));
    let billsToSync = [];
    if (bill_id) {
      // Sync single bill
      const { data } = await supabase.from("legislation_tracked_bills").select("*").eq("id", bill_id).single();
      if (data) billsToSync = [
        data
      ];
    } else if (mode === "missing_sponsors") {
      // Get bills missing sponsors
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
      const { data: billsWithSponsors } = await supabase.from("legislation_bill_sponsors").select("bill_id");
      const billIdsWithSponsors = new Set((billsWithSponsors || []).map((s)=>s.bill_id));
      const { data: allBills } = await supabase.from("legislation_tracked_bills").select("*").eq("session", "2026").or("is_archived.eq.false,is_archived.is.null").is("sync_error", null).or(`last_synced_at.is.null,last_synced_at.lt.${oneHourAgo}`).order("last_synced_at", {
        ascending: true,
        nullsFirst: true
      }).limit(100);
      const billsWithoutSponsors = (allBills || []).filter((bill)=>!billIdsWithSponsors.has(bill.id));
      billsToSync = billsWithoutSponsors.slice(0, limit);
      console.log(`[missing_sponsors mode] Found ${billsWithoutSponsors.length} bills missing sponsors, processing ${billsToSync.length}`);
    } else {
      // Normal mode: bills needing sync
      const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
      const { data } = await supabase.from("legislation_tracked_bills").select("*").or("is_archived.eq.false,is_archived.is.null").is("sync_error", null).or(`last_synced_at.is.null,last_synced_at.lt.${sixHoursAgo}`).order("last_synced_at", {
        ascending: true,
        nullsFirst: true
      }).limit(limit);
      billsToSync = data || [];
      console.log(`[normal mode] Found ${billsToSync.length} bills needing sync`);
    }
    let totalUpdated = 0;
    let totalNewActions = 0;
    let totalNewVotes = 0;
    let totalNewDocuments = 0;
    let apiCallsMade = 0;
    const errors = [];
    for(let i = 0; i < billsToSync.length; i++){
      const bill = billsToSync[i];
      const billStartTime = Date.now();
      try {
        console.log(`[${i + 1}/${billsToSync.length}] Syncing ${bill.bill_identifier}...`);
        const result = await syncSingleBill(bill);
        apiCallsMade++;
        if (result.error) {
          throw new Error(result.error);
        }
        if (result.updated) totalUpdated++;
        totalNewActions += result.newActions;
        totalNewVotes += result.newVotes;
        totalNewDocuments += result.newDocuments;
        console.log(`[${i + 1}/${billsToSync.length}] ✓ ${bill.bill_identifier} synced`);
      } catch (err) {
        console.error(`[${i + 1}/${billsToSync.length}] ✗ Error syncing ${bill.bill_identifier}:`, err.message);
        errors.push({
          bill_id: bill.id,
          bill_identifier: bill.bill_identifier,
          error: err.message
        });
        // Mark permanent errors
        if (!err.message?.includes("429") && !err.message?.includes("rate limit")) {
          await supabase.from("legislation_tracked_bills").update({
            sync_error: err.message?.substring(0, 500)
          }).eq("id", bill.id);
        }
      }
      // Rate limiting between API calls
      if (i < billsToSync.length - 1) {
        console.log(`Waiting ${RATE_LIMIT_DELAY_MS}ms before next request...`);
        await new Promise((resolve)=>setTimeout(resolve, RATE_LIMIT_DELAY_MS));
      }
    }
    const duration = Date.now() - startTime;
    // Update sync log
    await supabase.from("legislation_sync_log").update({
      status: errors.length > 0 ? "partial" : "success",
      bills_checked: billsToSync.length,
      bills_updated: totalUpdated,
      new_actions_found: totalNewActions,
      new_votes_found: totalNewVotes,
      error_message: errors.length > 0 ? `${errors.length} bills failed to sync` : null,
      error_details: errors.length > 0 ? errors : null,
      completed_at: new Date().toISOString(),
      duration_ms: duration
    }).eq("id", syncLog.id);
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:openstates-sync-tracked-bills",
      row_id: null,
      context: {
        event: "openstates-sync-tracked-bills",
        mode,
        bills_checked: billsToSync.length,
        bills_updated: totalUpdated,
        error_count: errors.length
      }
    }).then(() => {}).catch((e) => console.error("[openstates-sync-tracked-bills] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      mode,
      bills_checked: billsToSync.length,
      bills_updated: totalUpdated,
      new_actions_found: totalNewActions,
      new_votes_found: totalNewVotes,
      new_documents_found: totalNewDocuments,
      api_calls_made: apiCallsMade,
      errors: errors.length > 0 ? errors : undefined,
      duration_ms: duration
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    const duration = Date.now() - startTime;
    await supabase.from("legislation_sync_log").update({
      status: "failed",
      error_message: err.message,
      completed_at: new Date().toISOString(),
      duration_ms: duration
    }).eq("id", syncLog?.id);
    console.error("Sync failed:", err);
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
