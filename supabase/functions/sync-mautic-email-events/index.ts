import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "https://deno.land/std@0.168.0/node/crypto.ts";

/**
 * sync-mautic-email-events
 * 
 * Handles real-time webhook events from Mautic:
 * - mautic.email_on_send: Email sent to contact
 * - mautic.email_on_open: Email opened by contact
 * - mautic.page_on_hit: Page/link clicked (for email link tracking)
 * - mautic.lead_post_save_new: New contact created
 * - mautic.lead_post_save_update: Contact updated
 * 
 * IMPORTANT: Mautic sends contact fields in nested structure:
 * contact.fields.core.email.value (NOT contact.email)
 * 
 * AUTO-CREATES campaigns if they don't exist in email_campaigns table.
 */

function cleanEnvVar(value: string | undefined): string {
  if (!value) return "";
  return value.replace(/^["']|["']$/g, "").trim();
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const webhookSecret = Deno.env.get("MAUTIC_EMAIL_WEBHOOK_SECRET") || "";
const mauticUrl = cleanEnvVar(Deno.env.get("MAUTIC_URL"));
const mauticUsername = cleanEnvVar(Deno.env.get("MAUTIC_USERNAME"));
const mauticPassword = cleanEnvVar(Deno.env.get("MAUTIC_PASSWORD"));

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, webhook-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function getMauticAuth(): string {
  return `Basic ${btoa(`${mauticUsername}:${mauticPassword}`)}`;
}

// ============================================================================
// MAUTIC PAYLOAD EXTRACTION HELPERS
// Mautic sends contact data in nested structure: fields.core.fieldname.value
// ============================================================================

/**
 * Extract email from Mautic contact/lead object
 * Tries multiple possible locations where Mautic might put the email
 */
function extractEmail(obj: any): string | null {
  if (!obj) return null;
  
  // Try direct email property first (sometimes Mautic sends it directly)
  if (typeof obj.email === 'string' && obj.email) {
    return obj.email.toLowerCase();
  }
  
  // Try fields.core.email.value (standard Mautic webhook format)
  if (obj.fields?.core?.email?.value) {
    return obj.fields.core.email.value.toLowerCase();
  }
  
  // Try fields.all.email (alternative format)
  if (obj.fields?.all?.email) {
    return obj.fields.all.email.toLowerCase();
  }
  
  // Try ipAddress.email (sometimes included in stat objects)
  if (obj.ipAddress?.email) {
    return obj.ipAddress.email.toLowerCase();
  }
  
  return null;
}

/**
 * Extract first name from Mautic contact/lead object
 */
function extractFirstName(obj: any): string | null {
  if (!obj) return null;
  
  if (typeof obj.firstname === 'string') return obj.firstname;
  if (obj.fields?.core?.firstname?.value) return obj.fields.core.firstname.value;
  if (obj.fields?.all?.firstname) return obj.fields.all.firstname;
  
  return null;
}

/**
 * Extract last name from Mautic contact/lead object
 */
function extractLastName(obj: any): string | null {
  if (!obj) return null;
  
  if (typeof obj.lastname === 'string') return obj.lastname;
  if (obj.fields?.core?.lastname?.value) return obj.fields.core.lastname.value;
  if (obj.fields?.all?.lastname) return obj.fields.all.lastname;
  
  return null;
}

/**
 * Extract contact ID from Mautic contact/lead object
 */
function extractContactId(obj: any): number | null {
  if (!obj) return null;
  
  if (obj.id) return parseInt(obj.id);
  
  return null;
}

/**
 * Extract email ID from various event structures
 */
function extractEmailId(event: any): number | null {
  // Direct email object
  if (event.email?.id) return parseInt(event.email.id);
  
  // Stat object (for email_on_open)
  if (event.stat?.email?.id) return parseInt(event.stat.email.id);
  
  // Redirect object (for page hits from email links)
  if (event.redirect?.email?.id) return parseInt(event.redirect.email.id);
  
  // Hit object
  if (event.hit?.email?.id) return parseInt(event.hit.email.id);
  
  return null;
}

/**
 * Extract contact/lead from various event structures
 */
function extractContact(event: any): any {
  // Direct contact property
  if (event.contact) return event.contact;
  
  // Lead property (old naming)
  if (event.lead) return event.lead;
  
  // Stat object (for email_on_open)
  if (event.stat?.lead) return event.stat.lead;
  if (event.stat?.contact) return event.stat.contact;
  
  // Hit object (for page_on_hit)
  if (event.hit?.lead) return event.hit.lead;
  if (event.hit?.contact) return event.hit.contact;
  
  return null;
}

// ============================================================================
// SIGNATURE VERIFICATION
// ============================================================================

function verifySignature(payload: string, signature: string | null): boolean {
  if (!webhookSecret || !signature) {
    console.log("No webhook secret configured or no signature provided, skipping verification");
    return true;
  }
  
  try {
    const hmac = createHmac("sha256", webhookSecret);
    hmac.update(payload);
    const expectedSignature = hmac.digest("base64");
    return signature === expectedSignature;
  } catch (e) {
    console.error("Signature verification error:", e);
    return false;
  }
}

// ============================================================================
// DATABASE HELPERS
// ============================================================================

async function findSubscriber(mauticLeadId: number | null, email: string | null): Promise<string | null> {
  if (mauticLeadId) {
    const { data } = await supabase
      .from("subscribers")
      .select("id")
      .eq("mautic_id", mauticLeadId)
      .maybeSingle();
    if (data) return data.id;
  }
  
  if (email) {
    const { data } = await supabase
      .from("subscribers")
      .select("id")
      .eq("email", email.toLowerCase())
      .maybeSingle();
    if (data) return data.id;
  }
  
  return null;
}

async function fetchMauticEmail(mauticEmailId: number | string): Promise<any | null> {
  if (!mauticUrl || !mauticUsername || !mauticPassword) {
    console.log("Mautic API credentials not configured, cannot fetch email details");
    return null;
  }
  
  try {
    const res = await fetch(`${mauticUrl}/api/emails/${mauticEmailId}`, {
      headers: { Authorization: getMauticAuth() },
    });
    
    if (!res.ok) {
      console.error(`Failed to fetch Mautic email ${mauticEmailId}: ${res.status}`);
      return null;
    }
    
    const data = await res.json();
    return data.email || null;
  } catch (e) {
    console.error(`Error fetching Mautic email ${mauticEmailId}:`, e);
    return null;
  }
}

async function createCampaignFromMautic(mauticEmailId: number | string, mauticEmail?: any): Promise<string | null> {
  if (!mauticEmail) {
    mauticEmail = await fetchMauticEmail(mauticEmailId);
  }
  
  const campaignData: any = {
    source: "mautic",
    source_campaign_id: mauticEmailId.toString(),
    name: mauticEmail?.name || mauticEmail?.subject || `Mautic Email ${mauticEmailId}`,
    subject: mauticEmail?.subject || "",
    from_name: mauticEmail?.fromName || null,
    from_email: mauticEmail?.fromAddress || null,
    reply_to: mauticEmail?.replyToAddress || null,
    html_content: mauticEmail?.customHtml || null,
    text_content: mauticEmail?.plainText || null,
    total_recipients: mauticEmail?.sentCount || 0,
    total_sent: mauticEmail?.sentCount || 0,
    total_opens: mauticEmail?.readCount || 0,
    unique_opens: mauticEmail?.readCount || 0,
  };
  
  if (mauticEmail?.category?.title) {
    campaignData.segment_name = mauticEmail.category.title;
  }
  
  const { data, error } = await supabase
    .from("email_campaigns")
    .insert(campaignData)
    .select("id")
    .single();
  
  if (error) {
    console.error(`Error creating campaign for Mautic email ${mauticEmailId}:`, error);
    return null;
  }
  
  console.log(`Auto-created campaign ${data.id} for Mautic email ${mauticEmailId}`);
  return data.id;
}

async function findOrCreateCampaign(mauticEmailId: number | string, mauticEmailData?: any): Promise<string | null> {
  if (!mauticEmailId) return null;
  
  const { data } = await supabase
    .from("email_campaigns")
    .select("id")
    .eq("source", "mautic")
    .eq("source_campaign_id", mauticEmailId.toString())
    .maybeSingle();
  
  if (data) return data.id;
  
  console.log(`Campaign not found for Mautic email ${mauticEmailId}, auto-creating...`);
  return await createCampaignFromMautic(mauticEmailId, mauticEmailData);
}

async function findRecipient(campaignId: string, email: string): Promise<any | null> {
  const { data } = await supabase
    .from("email_campaign_recipients")
    .select("*")
    .eq("campaign_id", campaignId)
    .eq("email", email.toLowerCase())
    .maybeSingle();
  return data;
}

async function findOrCreateLink(campaignId: string, url: string): Promise<string | null> {
  const { data: existing } = await supabase
    .from("email_campaign_links")
    .select("id")
    .eq("campaign_id", campaignId)
    .eq("url", url)
    .maybeSingle();
  
  if (existing) return existing.id;
  
  const { data: created, error } = await supabase
    .from("email_campaign_links")
    .insert({
      campaign_id: campaignId,
      url: url,
      source: "mautic",
    })
    .select("id")
    .single();
  
  if (error) {
    console.error("Error creating link:", error);
    return null;
  }
  
  return created.id;
}

// ============================================================================
// EVENT HANDLERS
// ============================================================================

async function handleEmailSend(event: any): Promise<void> {
  console.log("Processing email_on_send event");
  console.log("Event structure:", JSON.stringify(event, null, 2).substring(0, 500));
  
  const contact = extractContact(event);
  const contactEmail = extractEmail(contact);
  const mauticEmailId = extractEmailId(event);
  
  console.log(`Extracted - Email: ${contactEmail}, EmailId: ${mauticEmailId}`);
  
  if (!contactEmail) {
    console.log("No contact email found in event, skipping");
    return;
  }
  
  if (!mauticEmailId) {
    console.log("No email ID in event, skipping");
    return;
  }
  
  const campaignId = await findOrCreateCampaign(mauticEmailId, event.email);
  
  if (!campaignId) {
    console.log(`Could not find or create campaign for Mautic email ${mauticEmailId}, skipping`);
    return;
  }
  
  const mauticLeadId = extractContactId(contact);
  const subscriberId = await findSubscriber(mauticLeadId, contactEmail);
  const firstName = extractFirstName(contact);
  const lastName = extractLastName(contact);
  
  const recipientData = {
    campaign_id: campaignId,
    source: "mautic",
    email: contactEmail,
    first_name: firstName,
    last_name: lastName,
    full_name: firstName && lastName 
      ? `${firstName} ${lastName}`.trim() 
      : (firstName || lastName || null),
    mautic_lead_id: mauticLeadId,
    mautic_tracking_hash: event.idHash || null,
    subscriber_id: subscriberId,
    sent_at: event.timestamp ? new Date(event.timestamp).toISOString() : new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  
  const { error } = await supabase
    .from("email_campaign_recipients")
    .upsert(recipientData, { onConflict: "campaign_id,email" });
  
  if (error) {
    console.error("Error upserting recipient:", error);
  } else {
    console.log(`Recorded email send to ${contactEmail}`);
  }
}

async function handleEmailOpen(event: any): Promise<void> {
  console.log("Processing email_on_open event");
  console.log("Event structure:", JSON.stringify(event, null, 2).substring(0, 500));
  
  // For email_on_open, contact data might be in event.stat.lead or event.contact
  const contact = extractContact(event);
  const contactEmail = extractEmail(contact);
  const mauticEmailId = extractEmailId(event);
  
  console.log(`Extracted - Email: ${contactEmail}, EmailId: ${mauticEmailId}`);
  
  if (!contactEmail) {
    console.log("No contact email found in event, skipping");
    return;
  }
  
  if (!mauticEmailId) {
    console.log("No email ID found, skipping");
    return;
  }
  
  const campaignId = await findOrCreateCampaign(mauticEmailId, event.email || event.stat?.email);
  if (!campaignId) {
    console.log(`Could not find or create campaign for Mautic email ${mauticEmailId}`);
    return;
  }
  
  const recipient = await findRecipient(campaignId, contactEmail);
  const mauticLeadId = extractContactId(contact);
  const now = new Date().toISOString();
  
  if (recipient) {
    const openCount = (recipient.open_count || 0) + 1;
    
    await supabase
      .from("email_campaign_recipients")
      .update({
        opened: true,
        first_opened_at: recipient.first_opened_at || now,
        last_opened_at: now,
        open_count: openCount,
        updated_at: now,
      })
      .eq("id", recipient.id);
    
    console.log(`Updated open for ${contactEmail} (count: ${openCount})`);
  } else {
    const subscriberId = await findSubscriber(mauticLeadId, contactEmail);
    const firstName = extractFirstName(contact);
    const lastName = extractLastName(contact);
    
    await supabase
      .from("email_campaign_recipients")
      .insert({
        campaign_id: campaignId,
        source: "mautic",
        email: contactEmail,
        first_name: firstName,
        last_name: lastName,
        mautic_lead_id: mauticLeadId,
        subscriber_id: subscriberId,
        opened: true,
        first_opened_at: now,
        last_opened_at: now,
        open_count: 1,
        updated_at: now,
      });
    
    console.log(`Created recipient with open for ${contactEmail}`);
  }
}

async function handlePageHit(event: any): Promise<void> {
  console.log("Processing page_on_hit event");
  console.log("Event structure:", JSON.stringify(event, null, 2).substring(0, 500));
  
  const hit = event.hit || event;
  const redirect = hit.redirect || event.redirect;
  
  // Only process if this is an email redirect (link click from email)
  if (!redirect?.url) {
    console.log("Not a redirect/link click, skipping");
    return;
  }
  
  const mauticEmailId = redirect.email?.id;
  if (!mauticEmailId) {
    console.log("Not an email link click (no email ID in redirect), skipping");
    return;
  }
  
  const contact = extractContact(event) || extractContact(hit);
  const contactEmail = extractEmail(contact);
  const clickedUrl = redirect.url;
  
  console.log(`Extracted - Email: ${contactEmail}, URL: ${clickedUrl}, EmailId: ${mauticEmailId}`);
  
  if (!contactEmail) {
    console.log("No contact email found, skipping");
    return;
  }
  
  const campaignId = await findOrCreateCampaign(mauticEmailId, redirect.email);
  if (!campaignId) {
    console.log(`Could not find or create campaign for Mautic email ${mauticEmailId}`);
    return;
  }
  
  const linkId = await findOrCreateLink(campaignId, clickedUrl);
  const recipient = await findRecipient(campaignId, contactEmail);
  const mauticLeadId = extractContactId(contact);
  const subscriberId = await findSubscriber(mauticLeadId, contactEmail);
  const now = new Date().toISOString();
  
  // Record click event
  const clickData = {
    campaign_id: campaignId,
    link_id: linkId,
    recipient_id: recipient?.id || null,
    subscriber_id: subscriberId,
    email: contactEmail,
    url: clickedUrl,
    clicked_at: event.timestamp ? new Date(event.timestamp).toISOString() : now,
    ip_address: hit.ipAddress?.ipAddress || hit.ipAddress || null,
    user_agent: hit.userAgent || null,
    referer: hit.referer || null,
  };
  
  const { error: clickError } = await supabase
    .from("email_campaign_link_clicks")
    .insert(clickData);
  
  if (clickError) {
    console.error("Error recording click:", clickError);
  }
  
  // Update recipient click stats
  if (recipient) {
    const clickCount = (recipient.click_count || 0) + 1;
    
    await supabase
      .from("email_campaign_recipients")
      .update({
        clicked: true,
        first_clicked_at: recipient.first_clicked_at || now,
        last_clicked_at: now,
        click_count: clickCount,
        updated_at: now,
      })
      .eq("id", recipient.id);
    
    console.log(`Updated click for ${contactEmail} on ${clickedUrl}`);
  } else {
    const firstName = extractFirstName(contact);
    const lastName = extractLastName(contact);
    
    await supabase
      .from("email_campaign_recipients")
      .insert({
        campaign_id: campaignId,
        source: "mautic",
        email: contactEmail,
        first_name: firstName,
        last_name: lastName,
        mautic_lead_id: mauticLeadId,
        subscriber_id: subscriberId,
        clicked: true,
        first_clicked_at: now,
        last_clicked_at: now,
        click_count: 1,
        updated_at: now,
      });
    
    console.log(`Created recipient with click for ${contactEmail}`);
  }
}

async function handleContactChange(event: any, isNew: boolean): Promise<void> {
  console.log(`Processing contact ${isNew ? 'create' : 'update'} event`);
  
  const contact = extractContact(event) || event;
  const contactEmail = extractEmail(contact);
  
  if (!contactEmail) {
    console.log("No contact email found, skipping");
    return;
  }
  
  const mauticId = extractContactId(contact);
  
  const { data: existing } = await supabase
    .from("subscribers")
    .select("id, mautic_id")
    .eq("email", contactEmail)
    .maybeSingle();
  
  if (existing) {
    if (!existing.mautic_id && mauticId) {
      await supabase
        .from("subscribers")
        .update({ 
          mautic_id: mauticId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", existing.id);
      console.log(`Linked subscriber ${existing.id} to Mautic contact ${mauticId}`);
    }
  }
}

// ============================================================================
// MAIN SERVER
// ============================================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }
  
  try {
    const rawBody = await req.text();
    const signature = req.headers.get("Webhook-Signature");
    
    // Verify signature
    if (!verifySignature(rawBody, signature)) {
      console.error("Invalid webhook signature");
      return new Response("Invalid signature", { status: 401, headers: corsHeaders });
    }
    
    const payload = JSON.parse(rawBody);
    console.log("Received webhook payload with events:", Object.keys(payload));
    
    // Log first 1000 chars of payload for debugging
    console.log("Payload preview:", JSON.stringify(payload, null, 2).substring(0, 1000));
    
    let processedEvents = 0;
    
    // Process each event type
    // Mautic sends: { "mautic.event_name": [ {...event1}, {...event2} ] }
    for (const [eventType, events] of Object.entries(payload)) {
      if (!Array.isArray(events)) {
        console.log(`Event type ${eventType} is not an array, skipping`);
        continue;
      }
      
      for (const event of events) {
        try {
          switch (eventType) {
            case "mautic.email_on_send":
              await handleEmailSend(event);
              processedEvents++;
              break;
              
            case "mautic.email_on_open":
              await handleEmailOpen(event);
              processedEvents++;
              break;
              
            case "mautic.page_on_hit":
              await handlePageHit(event);
              processedEvents++;
              break;
              
            case "mautic.lead_post_save_new":
              await handleContactChange(event, true);
              processedEvents++;
              break;
              
            case "mautic.lead_post_save_update":
              await handleContactChange(event, false);
              processedEvents++;
              break;
              
            case "mautic.lead_points_change":
              console.log("Ignoring points change event");
              break;
              
            default:
              console.log(`Unknown event type: ${eventType}`);
          }
        } catch (eventError) {
          console.error(`Error processing ${eventType}:`, eventError);
        }
      }
    }
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        processedEvents,
        message: `Processed ${processedEvents} events` 
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});