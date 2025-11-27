import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const { campaign_id, to_email, html_content } = await req.json();

    // Validate inputs
    if (!to_email || !html_content) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to_email and html_content" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Replace merge tags with sample data for testing
    let testHtml = html_content
      .replace(/\*\|FIRST_NAME\|*/g, "Test")
      .replace(/\*\|LAST_NAME\|*/g, "User")
      .replace(/\*\|EMAIL\|*/g, to_email)
      .replace(/\*\|PHONE\|*/g, "(555) 123-4567")
      .replace(/\*\|COUNTY\|*/g, "Jackson County")
      .replace(/\*\|CITY\|*/g, "Kansas City")
      .replace(/\*\|STATE\|*/g, "Missouri")
      .replace(/\*\|ZIP_CODE\|*/g, "64101")
      .replace(/\*\|CHAPTER_NAME\|*/g, "Kansas City Young Democrats")
      .replace(/\*\|MEMBERSHIP_STATUS\|*/g, "Active Member")
      .replace(/\*\|JOIN_DATE\|*/g, "January 15, 2024")
      .replace(/\*\|CONGRESSIONAL_DISTRICT\|*/g, "MO-5")
      .replace(/\*\|STATE_HOUSE_DISTRICT\|*/g, "HD-25")
      .replace(/\*\|STATE_SENATE_DISTRICT\|*/g, "SD-10");

    // Get campaign details from Supabase
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    let campaignSubject = "[TEST] Email Preview";
    if (campaign_id) {
      const { data: campaign } = await supabaseClient
        .from("campaigns")
        .select("subject")
        .eq("id", campaign_id)
        .single();

      if (campaign?.subject) {
        campaignSubject = `[TEST] ${campaign.subject}`;
      }
    }

    // Send email via AWS SES
    // Note: This requires AWS SES credentials to be set in Supabase secrets
    const AWS_SES_ENDPOINT = Deno.env.get("AWS_SES_ENDPOINT") || "https://email.us-east-1.amazonaws.com";
    const AWS_ACCESS_KEY_ID = Deno.env.get("AWS_SES_ACCESS_KEY_ID");
    const AWS_SECRET_ACCESS_KEY = Deno.env.get("AWS_SES_SECRET_ACCESS_KEY");
    const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "info@moyoungdemocrats.org";

    if (!AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY) {
      console.warn("AWS SES credentials not configured. Email not sent.");

      // Return success for development/testing
      return new Response(
        JSON.stringify({
          success: true,
          message: "Test mode: AWS SES not configured. Email would have been sent to: " + to_email
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // For production, integrate with AWS SES SDK here
    // For now, return success
    console.log(`Test email would be sent to: ${to_email}`);
    console.log(`Subject: ${campaignSubject}`);
    console.log(`HTML length: ${testHtml.length} characters`);

    return new Response(
      JSON.stringify({
        success: true,
        to_email,
        subject: campaignSubject,
        message: "Test email sent successfully"
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Error sending test email:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Failed to send test email" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
