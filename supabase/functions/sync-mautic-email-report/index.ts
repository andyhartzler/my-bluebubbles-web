import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * sync-mautic-email-report
 * 
 * Uses the Mautic Reports API to get individual recipient data.
 * Handles large datasets with timeout protection and resume capability.
 * 
 * Usage:
 *   POST { "emailId": 6 }                    - Sync recipients for specific email
 *   POST {}                                  - Sync all emails
 *   POST { "startPage": 5 }                  - Resume from page 5
 *   POST { "emailId": 6, "startPage": 10 }   - Resume specific email from page 10
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

// Timeout protection - stop 10 seconds before edge function limit
const MAX_EXECUTION_MS = 50000; // 50 seconds (edge functions timeout at 60s)
const startTime = Date.now();

function isTimeLimitApproaching(): boolean {
  return (Date.now() - startTime) > MAX_EXECUTION_MS;
}

function getMauticAuth(): string {
  return `Basic ${btoa(`${mauticUsername}:${mauticPassword}`)}`;
}

const REPORT_NAME = "MOYD Email Stats Sync Report";

// Find or create the email stats report
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
  
  console.log("Creating new email stats report...");
  
  const reportConfig = {
    name: REPORT_NAME,
    description: "Report for syncing email recipient data to MOYD CRM",
    system: true,
    isScheduled: false,
    source: "email.stats",
    columns: [
      "e.id", "e.name", "e.subject",
      "es.email_address", "es.date_sent", "es.date_read",
      "es.is_read", "es.is_failed", "es.retry_count",
      "l.id", "l.email", "l.firstname", "l.lastname",
    ],
    filters: [],
    tableOrder: [{ column: "es.date_sent", direction: "DESC" }],
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
    throw new Error(`Failed to create report: ${createRes.status} - ${await createRes.text()}`);
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

// Get column value from row
function getCol(row: any, dataColumns: Record<string, string>, target: string): any {
  for (const [key, value] of Object.entries(dataColumns)) {
    if (value === target) return row[key];
  }
  return row[target];
}

// Cache for subscribers and campaigns
const subscriberCache = new Map<string, string | null>();
const campaignCache = new Map<string, string | null>();

// Find subscriber (with caching)
async function findSubscriber(mauticLeadId: number | null, email: string): Promise<string | null> {
  const cacheKey = `${mauticLeadId || ''}-${email.toLowerCase()}`;
  if (subscriberCache.has(cacheKey)) {
    return subscriberCache.get(cacheKey)!;
  }
  
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

// Find campaign (with caching)
async function findCampaign(mauticEmailId: string): Promise<string | null> {
  if (campaignCache.has(mauticEmailId)) {
    return campaignCache.get(mauticEmailId)!;
  }
  
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

// Process rows in batch
async function processRowBatch(
  rows: any[],
  dataColumns: Record<string, string>,
  emailIdFilter?: string
): Promise<{ success: number; skipped: number; campaignIds: Set<string> }> {
  const recipients: any[] = [];
  const campaignIds = new Set<string>();
  let skipped = 0;
  
  for (const row of rows) {
    const emailId = getCol(row, dataColumns, "e.id");
    const recipientEmail = getCol(row, dataColumns, "es.email_address") || getCol(row, dataColumns, "l.email");
    
    // Filter by emailId if specified
    if (emailIdFilter && emailId && emailId.toString() !== emailIdFilter) {
      continue;
    }
    
    if (!emailId || !recipientEmail) {
      skipped++;
      continue;
    }
    
    const campaignId = await findCampaign(emailId.toString());
    if (!campaignId) {
      skipped++;
      continue;
    }
    
    const leadId = getCol(row, dataColumns, "l.id");
    const firstName = getCol(row, dataColumns, "l.firstname");
    const lastName = getCol(row, dataColumns, "l.lastname");
    const dateSent = getCol(row, dataColumns, "es.date_sent");
    const dateRead = getCol(row, dataColumns, "es.date_read");
    const isRead = getCol(row, dataColumns, "es.is_read");
    const isFailed = getCol(row, dataColumns, "es.is_failed");
    const retryCount = getCol(row, dataColumns, "es.retry_count");
    
    const mauticLeadIdInt = leadId ? parseInt(leadId) : null;
    const subscriberId = await findSubscriber(mauticLeadIdInt, recipientEmail);
    
    const isOpened = isRead === true || isRead === 1 || isRead === "1";
    const hasFailed = isFailed === true || isFailed === 1 || isFailed === "1";
    
    recipients.push({
      campaign_id: campaignId,
      source: "mautic",
      email: recipientEmail.toLowerCase(),
      first_name: firstName || null,
      last_name: lastName || null,
      full_name: firstName && lastName ? `${firstName} ${lastName}`.trim() : (firstName || lastName || null),
      mautic_lead_id: mauticLeadIdInt,
      subscriber_id: subscriberId,
      sent_at: dateSent ? new Date(dateSent).toISOString() : null,
      opened: isOpened,
      first_opened_at: dateRead ? new Date(dateRead).toISOString() : null,
      last_opened_at: dateRead ? new Date(dateRead).toISOString() : null,
      open_count: isOpened ? 1 : 0,
      failed: hasFailed,
      retry_count: retryCount ? parseInt(retryCount) : 0,
      updated_at: new Date().toISOString(),
    });
    
    campaignIds.add(campaignId);
  }
  
  // Batch upsert
  if (recipients.length > 0) {
    const { error } = await supabase
      .from("email_campaign_recipients")
      .upsert(recipients, { onConflict: "campaign_id,email" });
    
    if (error) {
      console.error("Batch upsert error:", error.message);
      return { success: 0, skipped: skipped + recipients.length, campaignIds };
    }
  }
  
  return { success: recipients.length, skipped, campaignIds };
}

// Update campaign stats
async function updateCampaignStats(campaignId: string): Promise<void> {
  const { data: recipients } = await supabase
    .from("email_campaign_recipients")
    .select("sent_at, opened, open_count, failed, bounced, clicked, click_count, unsubscribed")
    .eq("campaign_id", campaignId);
  
  if (!recipients || recipients.length === 0) return;
  
  const stats = {
    total_recipients: recipients.length,
    total_sent: recipients.filter(r => r.sent_at).length,
    unique_opens: recipients.filter(r => r.opened).length,
    total_opens: recipients.reduce((sum, r) => sum + (r.open_count || 0), 0),
    total_failed: recipients.filter(r => r.failed).length,
    total_bounces: recipients.filter(r => r.bounced).length,
    unique_clicks: recipients.filter(r => r.clicked).length,
    total_clicks: recipients.reduce((sum, r) => sum + (r.click_count || 0), 0),
    total_unsubscribes: recipients.filter(r => r.unsubscribed).length,
  };
  
  const openRate = stats.total_sent > 0 ? (stats.unique_opens / stats.total_sent) * 100 : 0;
  const clickRate = stats.total_sent > 0 ? (stats.unique_clicks / stats.total_sent) * 100 : 0;
  
  await supabase
    .from("email_campaigns")
    .update({
      ...stats,
      open_rate: Math.round(openRate * 100) / 100,
      click_rate: Math.round(clickRate * 100) / 100,
      updated_at: new Date().toISOString(),
    })
    .eq("id", campaignId);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  
  try {
    if (!mauticUrl || !mauticUsername || !mauticPassword) {
      throw new Error("Mautic credentials not configured");
    }
    
    const body = await req.json().catch(() => ({}));
    const { emailId, dateFrom, dateTo, startPage = 1, limit = 100 } = body;
    
    const authHeader = getMauticAuth();
    const reportId = await findOrCreateReport(authHeader);
    
    // Date range
    const fromDate = dateFrom || (() => {
      const d = new Date();
      d.setFullYear(d.getFullYear() - 2);
      return d.toISOString().split('T')[0];
    })();
    const toDate = dateTo || new Date().toISOString().split('T')[0];
    
    let page = startPage;
    let totalProcessed = 0;
    let totalSuccess = 0;
    let totalSkipped = 0;
    const allCampaignIds = new Set<string>();
    let totalRows = 0;
    let timedOut = false;
    
    while (true) {
      // Check time limit before fetching next page
      if (isTimeLimitApproaching()) {
        console.log(`Time limit approaching at page ${page}, stopping gracefully`);
        timedOut = true;
        break;
      }
      
      console.log(`Fetching report page ${page}...`);
      const result = await fetchReportData(authHeader, reportId, page, limit, fromDate, toDate);
      totalRows = result.total;
      
      console.log(`Page ${page}: ${result.data.length} rows (total: ${result.total})`);
      
      if (result.data.length === 0) break;
      
      const batchResult = await processRowBatch(
        result.data,
        result.dataColumns,
        emailId?.toString()
      );
      
      totalProcessed += result.data.length;
      totalSuccess += batchResult.success;
      totalSkipped += batchResult.skipped;
      batchResult.campaignIds.forEach(id => allCampaignIds.add(id));
      
      if (result.data.length < limit || page * limit >= result.total) break;
      page++;
      if (page > 500) break; // Safety limit
    }
    
    // Update stats for affected campaigns (if we have time)
    if (!isTimeLimitApproaching()) {
      console.log(`Updating stats for ${allCampaignIds.size} campaigns...`);
      for (const campaignId of allCampaignIds) {
        if (isTimeLimitApproaching()) break;
        await updateCampaignStats(campaignId);
      }
    }
    
    const response: any = {
      success: true,
      reportId,
      totalRows,
      pagesProcessed: page - startPage + 1,
      lastPage: page,
      totalProcessed,
      totalSuccess,
      totalSkipped,
      campaignsUpdated: allCampaignIds.size,
      dateRange: { from: fromDate, to: toDate },
      executionTimeMs: Date.now() - startTime,
    };
    
    // If we timed out, tell the user how to resume
    if (timedOut) {
      response.timedOut = true;
      response.resumeWith = {
        ...body,
        startPage: page,
      };
      response.message = `Processed pages ${startPage}-${page - 1}. Run again with startPage: ${page} to continue.`;
    } else {
      response.complete = true;
      response.message = `Completed! Imported ${totalSuccess} recipients across ${allCampaignIds.size} campaigns.`;
    }
    
    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ 
        error: error.message,
        executionTimeMs: Date.now() - startTime,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});