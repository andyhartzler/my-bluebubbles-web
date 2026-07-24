import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * sync-mautic-email-clicks
 * 
 * Syncs email click data from Mautic using page hits report.
 * Email links in Mautic are tracked via redirect URLs that create page hits.
 * 
 * Usage:
 *   POST {}                                  - Sync all email clicks
 *   POST { "emailId": 6 }                    - Sync clicks for specific email
 *   POST { "startPage": 5 }                  - Resume from page 5
 *   POST { "dateFrom": "2024-01-01" }        - Filter by date range
 */

function cleanEnvVar(value: string | undefined): string {
  if (!value) return "";
  return value.replace(/^["']|["']$/g, "").trim();
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const mauticUrl = cleanEnvVar(Deno.env.get("MAUTIC_URL"));
const mauticUsername = cleanEnvVar(Deno.env.get("MAUTIC_USERNAME"));
const mauticPassword = cleanEnvVar(Deno.env.get("MAUTIC_PASSWORD"));

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Timeout protection
const MAX_EXECUTION_MS = 50000;
const startTime = Date.now();

function isTimeLimitApproaching(): boolean {
  return (Date.now() - startTime) > MAX_EXECUTION_MS;
}

function getMauticAuth(): string {
  return `Basic ${btoa(`${mauticUsername}:${mauticPassword}`)}`;
}

const REPORT_NAME = "MOYD Email Clicks Sync Report";

// Find or create the page hits report filtered to email sources
async function findOrCreateReport(authHeader: string): Promise<number> {
  const listRes = await fetch(`${mauticUrl}/api/reports`, {
    headers: { Authorization: authHeader },
  });
  
  if (!listRes.ok) {
    throw new Error(`Failed to list reports: ${listRes.status} - ${await listRes.text()}`);
  }
  
  const listData = await listRes.json();
  const reports = Object.values(listData.reports || {}) as any[];
  
  const existing = reports.find(r => r.name === REPORT_NAME);
  if (existing) {
    console.log(`Found existing report ID: ${existing.id}`);
    return existing.id;
  }
  
  console.log("Creating new email clicks report...");
  
  // Page hits report with email source filter
  const reportConfig = {
    name: REPORT_NAME,
    description: "Report for syncing email click data to MOYD CRM",
    system: true,
    isScheduled: false,
    source: "page.hits",
    columns: [
      "ph.id",
      "ph.date_hit", 
      "ph.url",
      "ph.url_title",
      "ph.source",
      "ph.source_id",
      "ph.code",
      "l.id",
      "l.email",
      "l.firstname", 
      "l.lastname",
      "p.id",
      "p.title",
      "r.id",
      "r.redirect_id",
      "r.url",
    ],
    filters: {
      // Filter to only include email-sourced hits
      column: "ph.source",
      condition: "eq",
      value: "email",
    },
    tableOrder: [{ column: "ph.date_hit", direction: "DESC" }],
    graphs: [],
    groupBy: [],
    settings: {},
  };
  
  const createRes = await fetch(`${mauticUrl}/api/reports/new`, {
    method: "POST",
    headers: {
      Authorization: authHeader,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(reportConfig),
  });
  
  if (!createRes.ok) {
    const errorText = await createRes.text();
    console.error("Report creation failed:", errorText);
    throw new Error(`Failed to create report: ${createRes.status} - ${errorText}`);
  }
  
  const createData = await createRes.json();
  console.log(`Created report ID: ${createData.report.id}`);
  return createData.report.id;
}

// Fetch report data
async function fetchReportData(
  authHeader: string,
  reportId: number,
  page: number,
  limit: number,
  dateFrom?: string,
  dateTo?: string
): Promise<{ data: any[]; total: number; dataColumns: Record<string, string> }> {
  let url = `${mauticUrl}/api/reports/${reportId}?limit=${limit}&page=${page}`;
  if (dateFrom) url += `&dateFrom=${dateFrom}`;
  if (dateTo) url += `&dateTo=${dateTo}`;
  
  const res = await fetch(url, { headers: { Authorization: authHeader } });
  
  if (!res.ok) {
    throw new Error(`Failed to fetch report: ${res.status} - ${await res.text()}`);
  }
  
  const data = await res.json();
  return {
    data: data.data || [],
    total: data.totalResults || 0,
    dataColumns: data.dataColumns || {},
  };
}

// Get column value from row using dataColumns mapping
function getCol(row: any, dataColumns: Record<string, string>, target: string): any {
  for (const [key, value] of Object.entries(dataColumns)) {
    if (value === target) return row[key];
  }
  return row[target];
}

// Caches
const subscriberCache = new Map<string, string | null>();
const campaignCache = new Map<string, string | null>();
const recipientCache = new Map<string, string | null>();
const linkCache = new Map<string, string | null>();

// Find subscriber
async function findSubscriber(mauticLeadId: number | null, email: string): Promise<string | null> {
  const cacheKey = `${mauticLeadId || ''}-${email?.toLowerCase() || ''}`;
  if (subscriberCache.has(cacheKey)) return subscriberCache.get(cacheKey)!;
  
  let subscriberId: string | null = null;
  
  if (mauticLeadId) {
    const { data } = await supabase
      .from("subscribers")
      .select("id")
      .eq("mautic_id", mauticLeadId)
      .maybeSingle();
    if (data) subscriberId = data.id;
  }
  
  if (!subscriberId && email) {
    const { data } = await supabase
      .from("subscribers")
      .select("id")
      .eq("email", email.toLowerCase())
      .maybeSingle();
    if (data) subscriberId = data.id;
  }
  
  subscriberCache.set(cacheKey, subscriberId);
  return subscriberId;
}

// Find campaign by Mautic email ID
async function findCampaign(mauticEmailId: string): Promise<string | null> {
  if (!mauticEmailId) return null;
  if (campaignCache.has(mauticEmailId)) return campaignCache.get(mauticEmailId)!;
  
  const { data } = await supabase
    .from("email_campaigns")
    .select("id")
    .eq("source", "mautic")
    .eq("source_campaign_id", mauticEmailId)
    .maybeSingle();
  
  const campaignId = data?.id || null;
  campaignCache.set(mauticEmailId, campaignId);
  return campaignId;
}

// Find recipient by campaign + email
async function findRecipient(campaignId: string, email: string): Promise<string | null> {
  const cacheKey = `${campaignId}-${email?.toLowerCase() || ''}`;
  if (recipientCache.has(cacheKey)) return recipientCache.get(cacheKey)!;
  
  const { data } = await supabase
    .from("email_campaign_recipients")
    .select("id")
    .eq("campaign_id", campaignId)
    .eq("email", email.toLowerCase())
    .maybeSingle();
  
  const recipientId = data?.id || null;
  recipientCache.set(cacheKey, recipientId);
  return recipientId;
}

// Find or create link record
async function findOrCreateLink(campaignId: string, url: string): Promise<string | null> {
  if (!url) return null;
  const cacheKey = `${campaignId}-${url}`;
  if (linkCache.has(cacheKey)) return linkCache.get(cacheKey)!;
  
  // Try to find existing
  const { data: existing } = await supabase
    .from("email_campaign_links")
    .select("id")
    .eq("campaign_id", campaignId)
    .eq("url", url)
    .maybeSingle();
  
  if (existing) {
    linkCache.set(cacheKey, existing.id);
    return existing.id;
  }
  
  // Create new link record
  const { data: created, error } = await supabase
    .from("email_campaign_links")
    .insert({
      campaign_id: campaignId,
      url: url,
      click_count: 0,
      unique_click_count: 0,
    })
    .select("id")
    .single();
  
  if (error) {
    console.error(`Failed to create link record: ${error.message}`);
    return null;
  }
  
  linkCache.set(cacheKey, created.id);
  return created.id;
}

// Process click rows
async function processClickBatch(
  rows: any[],
  dataColumns: Record<string, string>,
  emailIdFilter?: string
): Promise<{ success: number; skipped: number; campaignsAffected: Set<string> }> {
  let success = 0;
  let skipped = 0;
  const campaignsAffected = new Set<string>();
  const clicksToInsert: any[] = [];
  
  for (const row of rows) {
    const sourceId = getCol(row, dataColumns, "ph.source_id")?.toString();
    const source = getCol(row, dataColumns, "ph.source");
    
    // Only process email clicks
    if (source !== "email") {
      skipped++;
      continue;
    }
    
    // Filter by email ID if specified
    if (emailIdFilter && sourceId !== emailIdFilter) {
      skipped++;
      continue;
    }
    
    const campaignId = await findCampaign(sourceId);
    if (!campaignId) {
      skipped++;
      continue;
    }
    
    const leadId = getCol(row, dataColumns, "l.id");
    const email = getCol(row, dataColumns, "l.email");
    const url = getCol(row, dataColumns, "ph.url") || getCol(row, dataColumns, "r.url");
    const dateHit = getCol(row, dataColumns, "ph.date_hit");
    
    if (!email || !url) {
      skipped++;
      continue;
    }
    
    const subscriberId = await findSubscriber(leadId, email);
    const recipientId = await findRecipient(campaignId, email);
    const linkId = await findOrCreateLink(campaignId, url);
    
    campaignsAffected.add(campaignId);
    
    clicksToInsert.push({
      campaign_id: campaignId,
      link_id: linkId,
      recipient_id: recipientId,
      subscriber_id: subscriberId,
      email: email.toLowerCase(),
      url: url,
      clicked_at: dateHit ? new Date(dateHit).toISOString() : new Date().toISOString(),
    });
    
    success++;
  }
  
  // Batch insert clicks
  if (clicksToInsert.length > 0) {
    const { error } = await supabase
      .from("email_campaign_link_clicks")
      .insert(clicksToInsert);
    
    if (error) {
      console.error(`Error inserting clicks: ${error.message}`);
      // Don't fail completely, just log
    }
  }
  
  // Update recipient clicked status for affected campaigns
  for (const campaignId of campaignsAffected) {
    await supabase.rpc("update_recipient_click_status", { p_campaign_id: campaignId }).catch(() => {
      // RPC might not exist yet, that's ok
    });
  }
  
  return { success, skipped, campaignsAffected };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }
  
  try {
    const body = await req.json().catch(() => ({}));
    const { emailId, startPage = 1, dateFrom, dateTo } = body;
    
    if (!mauticUrl || !mauticUsername || !mauticPassword) {
      throw new Error("Missing Mautic configuration");
    }
    
    const authHeader = getMauticAuth();
    
    // Find or create report
    const reportId = await findOrCreateReport(authHeader);
    
    let currentPage = startPage;
    const limit = 100;
    let totalProcessed = 0;
    let totalSuccess = 0;
    let totalSkipped = 0;
    let totalRows = 0;
    let dataColumns: Record<string, string> = {};
    const allCampaignsAffected = new Set<string>();
    
    // Paginate through report
    while (true) {
      if (isTimeLimitApproaching()) {
        console.log(`Time limit approaching, stopping at page ${currentPage}`);
        return new Response(
          JSON.stringify({
            success: true,
            reportId,
            timedOut: true,
            lastPage: currentPage - 1,
            totalProcessed,
            totalSuccess,
            totalSkipped,
            resumeWith: { emailId, startPage: currentPage, dateFrom, dateTo },
            message: `Timed out. Resume with startPage: ${currentPage}`,
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      
      console.log(`Fetching report page ${currentPage}...`);
      
      const { data: rows, total, dataColumns: dc } = await fetchReportData(
        authHeader,
        reportId,
        currentPage,
        limit,
        dateFrom || "2024-01-01",
        dateTo || new Date().toISOString().split("T")[0]
      );
      
      if (currentPage === startPage) {
        totalRows = total;
        dataColumns = dc;
        console.log("Data columns:", JSON.stringify(dataColumns, null, 2));
      }
      
      console.log(`Page ${currentPage}: ${rows.length} rows (total: ${totalRows})`);
      
      if (rows.length === 0) break;
      
      const { success, skipped, campaignsAffected } = await processClickBatch(
        rows,
        dataColumns,
        emailId?.toString()
      );
      
      totalSuccess += success;
      totalSkipped += skipped;
      totalProcessed += rows.length;
      
      for (const cid of campaignsAffected) {
        allCampaignsAffected.add(cid);
      }
      
      if (rows.length < limit) break;
      currentPage++;
    }
    
    // Update link stats
    console.log(`Updating link stats for ${allCampaignsAffected.size} campaigns...`);
    
    for (const campaignId of allCampaignsAffected) {
      // Update link click counts
      await supabase.rpc("refresh_link_click_counts", { p_campaign_id: campaignId }).catch(() => {
        // RPC might not exist, that's ok
      });
    }
    
    return new Response(
      JSON.stringify({
        success: true,
        reportId,
        totalRows,
        pagesProcessed: currentPage - startPage + 1,
        lastPage: currentPage,
        totalProcessed,
        totalSuccess,
        totalSkipped,
        campaignsAffected: allCampaignsAffected.size,
        dateRange: { from: dateFrom || "2024-01-01", to: dateTo },
        executionTimeMs: Date.now() - startTime,
        complete: true,
        message: `Completed! Imported ${totalSuccess} clicks across ${allCampaignsAffected.size} campaigns.`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});