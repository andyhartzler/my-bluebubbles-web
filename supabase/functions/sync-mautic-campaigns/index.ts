import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * sync-mautic-campaigns
 * 
 * Syncs email campaign metadata from Mautic to Supabase.
 * 
 * Usage:
 *   POST { "emailId": 6 }       - Sync a specific email by ID
 *   POST { "syncAll": true }    - Sync all emails (upserts, updates existing)
 *   POST { "syncNew": true }    - Sync only NEW emails (skips existing campaigns)
 * 
 * The syncNew option is ideal for scheduled/automated runs - it only imports
 * campaigns that don't already exist in the email_campaigns table.
 */

// Helper to clean env vars (remove quotes if present)
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

// Get Mautic auth token
function getMauticAuth(): string {
  const credentials = btoa(`${mauticUsername}:${mauticPassword}`);
  return `Basic ${credentials}`;
}

// Fetch emails (campaigns) from Mautic
async function fetchMauticEmails(authHeader: string, start: number = 0, limit: number = 100) {
  const url = `${mauticUrl}/api/emails?start=${start}&limit=${limit}&orderBy=id&orderByDir=desc`;
  console.log("Fetching emails from:", url);
  
  const response = await fetch(url, {
    headers: { Authorization: authHeader },
  });
  
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Mautic API error: ${response.status} - ${text}`);
  }
  
  return response.json();
}

// Fetch a single email from Mautic
async function fetchMauticEmail(authHeader: string, emailId: number) {
  const url = `${mauticUrl}/api/emails/${emailId}`;
  console.log("Fetching email from:", url);
  
  const response = await fetch(url, {
    headers: { Authorization: authHeader },
  });
  
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Mautic API error: ${response.status} - ${text}`);
  }
  
  return response.json();
}

// Import a Mautic email as a campaign
// NOTE: Mautic API does NOT have an endpoint for individual recipient stats.
// The sentCount and readCount are available on the email object itself.
async function importMauticCampaign(email: any): Promise<string | null> {
  console.log(`Importing email ${email.id}: ${email.name || email.subject}`);
  console.log(`  - sentCount: ${email.sentCount}, readCount: ${email.readCount}`);
  
  const { data, error } = await supabase
    .from("email_campaigns")
    .upsert({
      source: "mautic",
      source_campaign_id: email.id.toString(),
      name: email.name || email.subject,
      subject: email.subject,
      from_name: email.fromName,
      from_email: email.fromAddress,
      reply_to: email.replyToAddress,
      html_content: email.customHtml,
      text_content: email.plainText,
      // Use publishUp as sent date if available
      sent_at: email.publishUp ? new Date(email.publishUp).toISOString() : null,
      // Stats available directly on email object
      total_sent: email.sentCount || 0,
      unique_opens: email.readCount || 0,
      total_opens: email.readCount || 0,
      // Additional metadata
      updated_at: new Date().toISOString(),
    }, {
      onConflict: "source,source_campaign_id",
    })
    .select("id")
    .single();
  
  if (error) {
    console.error("Error importing campaign:", error);
    return null;
  }
  
  console.log(`  - Imported as campaign ID: ${data.id}`);
  return data.id;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  
  try {
    // Validate environment variables
    if (!mauticUrl) {
      throw new Error("MAUTIC_URL environment variable is not set");
    }
    if (!mauticUsername || !mauticPassword) {
      throw new Error("MAUTIC_USERNAME or MAUTIC_PASSWORD environment variable is not set");
    }
    
    console.log("Using Mautic URL:", mauticUrl);
    
    const { emailId, syncAll = false, syncNew = false, limit = 100 } = await req.json();
    
    const authHeader = getMauticAuth();
    let totalCampaigns = 0;
    let skippedExisting = 0;
    
    if (emailId) {
      // Sync a specific email
      console.log(`Syncing single email ID: ${emailId}`);
      
      const emailData = await fetchMauticEmail(authHeader, emailId);
      
      if (emailData.email) {
        const campaignId = await importMauticCampaign(emailData.email);
        if (campaignId) {
          totalCampaigns = 1;
          
          // Link to subscribers by email if we have any existing data
          try {
            await supabase.rpc("link_recipients_to_subscribers", { p_campaign_id: campaignId });
          } catch (e) {
            console.log("link_recipients_to_subscribers not available or failed:", e);
          }
        }
      } else {
        throw new Error(`Email ${emailId} not found in Mautic`);
      }
    } else if (syncAll || syncNew) {
      // Sync all emails (or just new ones)
      console.log(syncNew ? "Syncing NEW emails from Mautic..." : "Syncing ALL emails from Mautic...");
      
      // Get existing campaign source IDs if syncNew mode
      let existingSourceIds: Set<string> = new Set();
      if (syncNew) {
        const { data: existing } = await supabase
          .from("email_campaigns")
          .select("source_campaign_id")
          .eq("source", "mautic");
        
        existingSourceIds = new Set((existing || []).map(e => e.source_campaign_id));
        console.log(`Found ${existingSourceIds.size} existing Mautic campaigns in database`);
      }
      
      let start = 0;
      let hasMore = true;
      
      while (hasMore) {
        const emailsResponse = await fetchMauticEmails(authHeader, start, limit);
        const emails = Object.values(emailsResponse.emails || {});
        
        console.log(`Fetched ${emails.length} emails (start: ${start})`);
        
        for (const email of emails as any[]) {
          // Skip if syncNew and already exists
          if (syncNew && existingSourceIds.has(email.id.toString())) {
            skippedExisting++;
            continue;
          }
          
          const campaignId = await importMauticCampaign(email);
          if (campaignId) {
            totalCampaigns++;
          }
        }
        
        start += emails.length;
        hasMore = emails.length === limit;
      }
    } else {
      throw new Error("Either emailId, syncAll, or syncNew must be provided");
    }
    
    return new Response(
      JSON.stringify({
        success: true,
        campaigns_synced: totalCampaigns,
        skipped_existing: skippedExisting,
        message: `Successfully synced ${totalCampaigns} campaign(s) from Mautic${skippedExisting > 0 ? ` (skipped ${skippedExisting} existing)` : ''}. Note: Mautic API does not provide individual recipient stats - only aggregate sentCount/readCount are available.`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Sync error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});