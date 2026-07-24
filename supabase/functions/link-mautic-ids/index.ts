import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

function cleanEnv(value: string | undefined): string {
  if (!value) return "";
  return value.replace(/^["']|["']$/g, "").trim();
}

const MAUTIC_URL = cleanEnv(Deno.env.get("MAUTIC_URL"));
const MAUTIC_USERNAME = cleanEnv(Deno.env.get("MAUTIC_USERNAME"));
const MAUTIC_PASSWORD = cleanEnv(Deno.env.get("MAUTIC_PASSWORD"));

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function getAuthHeader(): string {
  return `Basic ${btoa(`${MAUTIC_USERNAME}:${MAUTIC_PASSWORD}`)}`;
}

async function findMauticIdByEmail(email: string): Promise<number | null> {
  try {
    const url = `${MAUTIC_URL}/api/contacts?search=email:${encodeURIComponent(email)}`;
    const response = await fetch(url, {
      headers: {
        "Authorization": getAuthHeader(),
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      console.error(`Mautic API error for ${email}: ${response.status}`);
      return null;
    }

    const result = await response.json();
    const contacts = result.contacts || {};
    const contactIds = Object.keys(contacts);
    
    return contactIds.length > 0 ? parseInt(contactIds[0]) : null;
  } catch (err) {
    console.error(`Error searching for ${email}:`, err);
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const { type = "both", limit = 100 } = await req.json();

    console.log("=".repeat(60));
    console.log(`LINK MAUTIC IDs`);
    console.log(`Type: ${type}`);
    console.log(`Limit: ${limit}`);
    console.log(`Mautic URL: ${MAUTIC_URL}`);
    console.log("=".repeat(60));

    const results = {
      subscribers: { total: 0, linked: 0, notFound: 0, notFoundEmails: [] as string[] },
      members: { total: 0, linked: 0, notFound: 0, notFoundEmails: [] as string[] },
    };

    // Link subscribers
    if (type === "subscribers" || type === "both") {
      const { data: subscribers, error } = await supabase
        .from("subscribers")
        .select("id, email")
        .is("mautic_id", null)
        .not("email", "is", null)
        .limit(limit);

      if (error) {
        console.error("Error fetching subscribers:", error);
      } else if (subscribers) {
        results.subscribers.total = subscribers.length;
        console.log(`Found ${subscribers.length} subscribers to link`);

        for (const sub of subscribers) {
          const mauticId = await findMauticIdByEmail(sub.email);
          
          if (mauticId) {
            await supabase
              .from("subscribers")
              .update({ mautic_id: mauticId })
              .eq("id", sub.id);
            
            results.subscribers.linked++;
            console.log(`✓ ${sub.email} -> Mautic ID ${mauticId}`);
          } else {
            results.subscribers.notFound++;
            results.subscribers.notFoundEmails.push(sub.email);
            console.log(`✗ ${sub.email} - NOT FOUND in Mautic`);
          }

          // Small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 50));
        }
      }
    }

    // Link members
    if (type === "members" || type === "both") {
      const { data: members, error } = await supabase
        .from("members")
        .select("id, email")
        .is("mautic_id", null)
        .not("email", "is", null)
        .limit(limit);

      if (error) {
        console.error("Error fetching members:", error);
      } else if (members) {
        results.members.total = members.length;
        console.log(`Found ${members.length} members to link`);

        for (const mem of members) {
          const mauticId = await findMauticIdByEmail(mem.email);
          
          if (mauticId) {
            await supabase
              .from("members")
              .update({ mautic_id: mauticId })
              .eq("id", mem.id);
            
            results.members.linked++;
            console.log(`✓ ${mem.email} -> Mautic ID ${mauticId}`);
          } else {
            results.members.notFound++;
            results.members.notFoundEmails.push(mem.email);
            console.log(`✗ ${mem.email} - NOT FOUND in Mautic`);
          }

          await new Promise(resolve => setTimeout(resolve, 50));
        }
      }
    }

    // Log results
    await supabase.from("mautic_sync_log").insert({
      direction: "to_mautic",
      entity_type: "link_ids",
      entity_id: "bulk",
      action: "link_mautic_ids",
      payload: results,
      success: true,
    });

    console.log("=".repeat(60));
    console.log("LINKING COMPLETE");
    console.log(`Subscribers: ${results.subscribers.linked}/${results.subscribers.total} linked, ${results.subscribers.notFound} not found`);
    console.log(`Members: ${results.members.linked}/${results.members.total} linked, ${results.members.notFound} not found`);
    console.log("=".repeat(60));

    return new Response(
      JSON.stringify({
        success: true,
        results,
        message: `Linked ${results.subscribers.linked} subscribers and ${results.members.linked} members`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("LINK ERROR:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error";

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});