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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const { campaignId } = await req.json();

    // Get campaign
    const { data: campaign } = await supabase
      .from("campaigns")
      .select("*")
      .eq("id", campaignId)
      .single();

    if (!campaign) {
      return new Response("Campaign not found", { status: 404, headers: corsHeaders });
    }

    let recipients: any[] = [];

    // Build recipient list based on segment type
    switch (campaign.segment_type) {
      case "all":
        // All subscribers
        const { data: allSubs } = await supabase
          .from("subscribers")
          .select("id, email, name, member_id")
          .eq("subscription_status", "subscribed");
        recipients = allSubs || [];
        break;

      case "members":
        // All current members
        const { data: members } = await supabase
          .from("members")
          .select("id, email, name")
          .eq("current_chapter_member", "Yes")
          .not("email", "is", null);
        recipients = members?.map((m) => ({
          email: m.email,
          name: m.name,
          member_id: m.id,
        })) || [];
        break;

      case "subscribers":
        // Subscribers only (not members)
        const { data: subOnly } = await supabase
          .from("subscribers")
          .select("id, email, name, member_id")
          .eq("subscription_status", "subscribed")
          .is("member_id", null);
        recipients = subOnly || [];
        break;

      case "custom":
        // Custom filters from segment_filters JSON
        const filters = campaign.segment_filters || {};
        
        // Example filter structure:
        // {
        //   "source": "members",
        //   "filters": {
        //     "county": ["Jackson", "Clay"],
        //     "chapter_name": "Kansas City College Democrats"
        //   }
        // }

        let query = supabase.from(filters.source || "subscribers").select("*");

        if (filters.filters) {
          for (const [key, value] of Object.entries(filters.filters)) {
            if (Array.isArray(value)) {
              query = query.in(key, value);
            } else {
              query = query.eq(key, value);
            }
          }
        }

        const { data: customRecipients } = await query;
        recipients = customRecipients || [];
        break;
    }

    // Remove duplicates by email
    const uniqueRecipients = recipients.reduce((acc, curr) => {
      const email = curr.email?.toLowerCase();
      if (email && !acc.some((r: any) => r.email?.toLowerCase() === email)) {
        acc.push(curr);
      }
      return acc;
    }, []);

    // Create campaign_recipients records
    const recipientRecords = uniqueRecipients.map((r) => ({
      campaign_id: campaignId,
      email: r.email,
      member_id: r.member_id || r.id || null,
      subscriber_id: r.id || null,
      variables: {
        first_name: r.name?.split(" ")[0] || "",
        name: r.name || "",
        email: r.email,
      },
      status: "pending",
    }));

    // Batch insert
    const BATCH_SIZE = 100;
    let insertedCount = 0;

    for (let i = 0; i < recipientRecords.length; i += BATCH_SIZE) {
      const batch = recipientRecords.slice(i, i + BATCH_SIZE);
      const { error } = await supabase.from("campaign_recipients").insert(batch);
      if (!error) {
        insertedCount += batch.length;
      }
    }

    // Update campaign total_recipients
    await supabase
      .from("campaigns")
      .update({ total_recipients: insertedCount })
      .eq("id", campaignId);

    return new Response(
      JSON.stringify({
        success: true,
        totalRecipients: insertedCount,
        campaignId,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Failed to process segment:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});