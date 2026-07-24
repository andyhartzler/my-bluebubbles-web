import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SESClient, SendEmailCommand } from "https://esm.sh/@aws-sdk/client-ses@3";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const sesClient = new SESClient({
  region: Deno.env.get("AWS_SES_REGION") || "us-east-1",
  credentials: {
    accessKeyId: Deno.env.get("AWS_SES_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("AWS_SES_SECRET_ACCESS_KEY")!,
  },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Generate tracking pixel
function generateTrackingPixel(campaignId: string, recipientId: string): string {
  return `<img src="https://${supabaseUrl}/functions/v1/track-email-open?c=${campaignId}&r=${recipientId}" width="1" height="1" style="display:none;" alt="" />`;
}

// Replace links with tracking links
async function replaceLinksWithTracking(
  html: string,
  campaignId: string,
  recipientId: string
): Promise<string> {
  const linkRegex = /<a\s+(?:[^>]*?\s+)?href="([^"]*)"/gi;
  const links: string[] = [];
  let match;

  while ((match = linkRegex.exec(html)) !== null) {
    const url = match[1];
    if (!url.startsWith("mailto:") && !url.startsWith("#")) {
      links.push(url);
    }
  }

  // Store unique links in database
  for (const url of [...new Set(links)]) {
    const trackingToken = crypto.randomUUID();
    
    await supabase.from("campaign_links").upsert(
      {
        campaign_id: campaignId,
        original_url: url,
        tracking_token: trackingToken,
      },
      { onConflict: "campaign_id,original_url" }
    );

    // Replace in HTML
    const trackingUrl = `https://${supabaseUrl}/functions/v1/track-link-click?t=${trackingToken}&r=${recipientId}`;
    html = html.replace(
      new RegExp(`href="${url}"`, "g"),
      `href="${trackingUrl}"`
    );
  }

  return html;
}

// Merge template variables
function mergeVariables(html: string, variables: Record<string, any>): string {
  let merged = html;
  for (const [key, value] of Object.entries(variables)) {
    const regex = new RegExp(`{{\\s*${key}\\s*}}`, "g");
    merged = merged.replace(regex, value || "");
  }
  return merged;
}

// Send single email via SES
async function sendEmailViaSES(
  to: string,
  from: string,
  fromName: string,
  subject: string,
  htmlBody: string,
  textBody: string | null,
  replyTo: string | null
) {
  const command = new SendEmailCommand({
    Source: `${fromName} <${from}>`,
    Destination: { ToAddresses: [to] },
    ReplyToAddresses: replyTo ? [replyTo] : [],
    Message: {
      Subject: { Data: subject },
      Body: {
        Html: { Data: htmlBody },
        Text: textBody ? { Data: textBody } : undefined,
      },
    },
  });

  const response = await sesClient.send(command);
  return response.MessageId;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { campaignId, batchSize = 50 } = await req.json();

    if (!campaignId) {
      return new Response("Missing campaignId", { status: 400, headers: corsHeaders });
    }

    // Get campaign details
    const { data: campaign, error: campaignError } = await supabase
      .from("campaigns")
      .select("*")
      .eq("id", campaignId)
      .single();

    if (campaignError || !campaign) {
      return new Response("Campaign not found", { status: 404, headers: corsHeaders });
    }

    // Update status to sending
    await supabase
      .from("campaigns")
      .update({ status: "sending" })
      .eq("id", campaignId);

    // Get pending recipients (batch)
    const { data: recipients, error: recipientsError } = await supabase
      .from("campaign_recipients")
      .select("*")
      .eq("campaign_id", campaignId)
      .eq("status", "pending")
      .limit(batchSize);

    if (recipientsError || !recipients || recipients.length === 0) {
      // No more recipients, mark campaign as sent
      await supabase
        .from("campaigns")
        .update({ status: "sent", sent_at: new Date().toISOString() })
        .eq("id", campaignId);

      return new Response(
        JSON.stringify({ success: true, sent: 0, remaining: 0, completed: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let successCount = 0;
    let failCount = 0;

    // Send emails
    for (const recipient of recipients) {
      try {
        // Merge variables
        let html = mergeVariables(campaign.html_content, recipient.variables || {});
        
        // Add tracking pixel
        html = html + generateTrackingPixel(campaignId, recipient.id);
        
        // Replace links with tracking
        html = await replaceLinksWithTracking(html, campaignId, recipient.id);

        // Send via SES
        const messageId = await sendEmailViaSES(
          recipient.email,
          campaign.from_email,
          campaign.from_name,
          campaign.subject,
          html,
          campaign.text_content,
          campaign.reply_to
        );

        // Update recipient status
        await supabase
          .from("campaign_recipients")
          .update({
            status: "sent",
            sent_at: new Date().toISOString(),
            gmail_message_id: messageId,
          })
          .eq("id", recipient.id);

        successCount++;

        // Rate limiting: 50 emails per second max for SES
        await new Promise((resolve) => setTimeout(resolve, 20));
      } catch (err) {
        console.error(`Failed to send to ${recipient.email}:`, err);
        
        await supabase
          .from("campaign_recipients")
          .update({
            status: "failed",
            bounce_reason: err.message,
          })
          .eq("id", recipient.id);

        failCount++;
      }
    }

    // Check if more recipients remain
    const { count: remainingCount } = await supabase
      .from("campaign_recipients")
      .select("*", { count: "exact", head: true })
      .eq("campaign_id", campaignId)
      .eq("status", "pending");

    const completed = (remainingCount || 0) === 0;

    if (completed) {
      await supabase
        .from("campaigns")
        .update({ status: "sent", sent_at: new Date().toISOString() })
        .eq("id", campaignId);
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        failed: failCount,
        remaining: remainingCount || 0,
        completed,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Campaign send failed:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});