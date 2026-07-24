import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

serve(async (req) => {
  const url = new URL(req.url);
  const trackingToken = url.searchParams.get("t");
  const recipientId = url.searchParams.get("r");

  if (!trackingToken) {
    return new Response("Invalid tracking link", { status: 400 });
  }

  try {
    // Get link details
    const { data: link } = await supabase
      .from("campaign_links")
      .select("id, campaign_id, original_url, click_count, unique_click_count")
      .eq("tracking_token", trackingToken)
      .single();

    if (!link) {
      return new Response("Link not found", { status: 404 });
    }

    // Get recipient email
    let recipientEmail = null;
    let isUniqueClick = false;
    
    if (recipientId) {
      const { data: recipient } = await supabase
        .from("campaign_recipients")
        .select("email, clicked_at, click_count")
        .eq("id", recipientId)
        .single();

      if (recipient) {
        recipientEmail = recipient.email;
        isUniqueClick = !recipient.clicked_at;

        // Update recipient
        const now = new Date().toISOString();
        await supabase
          .from("campaign_recipients")
          .update({
            clicked_at: recipient.clicked_at || now,
            click_count: (recipient.click_count || 0) + 1,
            last_clicked_at: now,
            delivered_at: recipient.delivered_at || now, // Mark as delivered
          })
          .eq("id", recipientId);
      }
    }

    // Record click event
    await supabase.from("campaign_clicks").insert({
      campaign_id: link.campaign_id,
      link_id: link.id,
      recipient_id: recipientId || null,
      email: recipientEmail || "unknown",
      ip_address: req.headers.get("x-forwarded-for") || req.headers.get("cf-connecting-ip"),
      user_agent: req.headers.get("user-agent"),
      referer: req.headers.get("referer"),
    });

    // Update link stats
    await supabase
      .from("campaign_links")
      .update({
        click_count: link.click_count + 1,
        unique_click_count: isUniqueClick ? link.unique_click_count + 1 : link.unique_click_count,
      })
      .eq("id", link.id);

    // Redirect to original URL
    return Response.redirect(link.original_url, 302);
  } catch (err) {
    console.error("Failed to track click:", err);
    return new Response("Tracking error", { status: 500 });
  }
});