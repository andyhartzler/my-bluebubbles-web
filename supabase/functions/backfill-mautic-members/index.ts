import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// Mautic config
const MAUTIC_URL = Deno.env.get("MAUTIC_URL")?.replace(/^["']|["']$/g, "").trim() || "";
const MAUTIC_USERNAME = Deno.env.get("MAUTIC_USERNAME")?.replace(/^["']|["']$/g, "").trim() || "";
const MAUTIC_PASSWORD = Deno.env.get("MAUTIC_PASSWORD")?.replace(/^["']|["']$/g, "").trim() || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function getAuthHeader(): string {
  return `Basic ${btoa(`${MAUTIC_USERNAME}:${MAUTIC_PASSWORD}`)}`;
}

async function updateMauticContact(mauticId: number, membershipEligible: boolean): Promise<boolean> {
  const response = await fetch(`${MAUTIC_URL}/api/contacts/${mauticId}/edit`, {
    method: "PATCH",
    headers: {
      "Authorization": getAuthHeader(),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      membership_eligible: membershipEligible ? 1 : 0,
    }),
  });

  return response.ok;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const startTime = Date.now();
  const MAX_RUNTIME_MS = 50000; // 50 seconds max, leave buffer for response

  try {
    let offset = 0;
    let batchSize = 10; // Smaller batch

    try {
      const body = await req.json();
      if (body && typeof body.offset === "number") offset = body.offset;
      if (body && typeof body.batchSize === "number") batchSize = Math.min(body.batchSize, 15);
    } catch {
      // Empty body is fine
    }

    // Get total count
    const { count: totalCount } = await supabase
      .from("members")
      .select("*", { count: "exact", head: true })
      .not("mautic_id", "is", null);

    // Get batch
    const { data: members, error } = await supabase
      .from("members")
      .select("id, email, mautic_id, membership_eligible")
      .not("mautic_id", "is", null)
      .order("created_at", { ascending: true })
      .range(offset, offset + batchSize - 1);

    if (error) {
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    if (!members || members.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No more members to process",
          progress: { completed: offset, total: totalCount, hasMore: false },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    console.log(`Processing batch: offset ${offset}, size ${members.length}`);

    let successCount = 0;
    let failCount = 0;
    let processedCount = 0;
    const errors: string[] = [];

    for (const member of members) {
      // Check if we're running out of time
      if (Date.now() - startTime > MAX_RUNTIME_MS) {
        console.log("Approaching timeout, stopping early");
        break;
      }

      processedCount++;

      try {
        console.log(`Updating ${member.email} (mautic_id: ${member.mautic_id})`);
        
        const success = await updateMauticContact(
          member.mautic_id,
          member.membership_eligible ?? true
        );

        if (success) {
          console.log(`Updated ${member.email}`);
          successCount++;
        } else {
          throw new Error("Mautic API returned error");
        }

        // Small delay
        await new Promise((r) => setTimeout(r, 50));

      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Failed ${member.email}: ${msg}`);
        failCount++;
        errors.push(`${member.email}: ${msg}`);
      }
    }

    const nextOffset = offset + processedCount;
    const hasMore = nextOffset < (totalCount || 0);

    return new Response(
      JSON.stringify({
        success: true,
        batch: { offset, requested: batchSize, processed: processedCount },
        results: { synced: successCount, failed: failCount, errors: errors.slice(0, 5) },
        progress: {
          completed: nextOffset,
          total: totalCount,
          hasMore,
          nextOffset: hasMore ? nextOffset : null,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );

  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("Backfill error:", msg);
    return new Response(
      JSON.stringify({ success: false, error: msg }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});