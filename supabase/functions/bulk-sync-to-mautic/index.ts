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

const SEGMENT_ALL_CONTACTS = parseInt(cleanEnv(Deno.env.get("MAUTIC_SEGMENT_ALL_CONTACTS")) || "0");
const SEGMENT_MEMBERS = parseInt(cleanEnv(Deno.env.get("MAUTIC_SEGMENT_MEMBERS")) || "0");
const SEGMENT_NON_MEMBER_SUBSCRIBERS = parseInt(cleanEnv(Deno.env.get("MAUTIC_SEGMENT_NON_MEMBER_SUBS")) || "0");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// US State mapping - returns FULL STATE NAMES for Mautic
const STATE_NAMES: Record<string, string> = {
  // Abbreviations to full names
  "al": "Alabama", "ak": "Alaska", "az": "Arizona", "ar": "Arkansas",
  "ca": "California", "co": "Colorado", "ct": "Connecticut", "de": "Delaware",
  "fl": "Florida", "ga": "Georgia", "hi": "Hawaii", "id": "Idaho",
  "il": "Illinois", "in": "Indiana", "ia": "Iowa", "ks": "Kansas",
  "ky": "Kentucky", "la": "Louisiana", "me": "Maine", "md": "Maryland",
  "ma": "Massachusetts", "mi": "Michigan", "mn": "Minnesota", "ms": "Mississippi",
  "mo": "Missouri", "mt": "Montana", "ne": "Nebraska", "nv": "Nevada",
  "nh": "New Hampshire", "nj": "New Jersey", "nm": "New Mexico", "ny": "New York",
  "nc": "North Carolina", "nd": "North Dakota", "oh": "Ohio", "ok": "Oklahoma",
  "or": "Oregon", "pa": "Pennsylvania", "ri": "Rhode Island", "sc": "South Carolina",
  "sd": "South Dakota", "tn": "Tennessee", "tx": "Texas", "ut": "Utah",
  "vt": "Vermont", "va": "Virginia", "wa": "Washington", "wv": "West Virginia",
  "wi": "Wisconsin", "wy": "Wyoming", "dc": "District of Columbia",
  // Full names to full names (for validation)
  "alabama": "Alabama", "alaska": "Alaska", "arizona": "Arizona", "arkansas": "Arkansas",
  "california": "California", "colorado": "Colorado", "connecticut": "Connecticut", "delaware": "Delaware",
  "florida": "Florida", "georgia": "Georgia", "hawaii": "Hawaii", "idaho": "Idaho",
  "illinois": "Illinois", "indiana": "Indiana", "iowa": "Iowa", "kansas": "Kansas",
  "kentucky": "Kentucky", "louisiana": "Louisiana", "maine": "Maine", "maryland": "Maryland",
  "massachusetts": "Massachusetts", "michigan": "Michigan", "minnesota": "Minnesota", "mississippi": "Mississippi",
  "missouri": "Missouri", "montana": "Montana", "nebraska": "Nebraska", "nevada": "Nevada",
  "new hampshire": "New Hampshire", "new jersey": "New Jersey", "new mexico": "New Mexico", "new york": "New York",
  "north carolina": "North Carolina", "north dakota": "North Dakota", "ohio": "Ohio", "oklahoma": "Oklahoma",
  "oregon": "Oregon", "pennsylvania": "Pennsylvania", "rhode island": "Rhode Island", "south carolina": "South Carolina",
  "south dakota": "South Dakota", "tennessee": "Tennessee", "texas": "Texas", "utah": "Utah",
  "vermont": "Vermont", "virginia": "Virginia", "washington": "Washington", "west virginia": "West Virginia",
  "wisconsin": "Wisconsin", "wyoming": "Wyoming", "district of columbia": "District of Columbia",
};

function normalizeState(state: string | null | undefined): string | null {
  if (!state) return null;
  
  const cleaned = state.trim().toLowerCase();
  if (!cleaned) return null;
  
  // Look up in our mapping - returns full state name
  const fullName = STATE_NAMES[cleaned];
  if (fullName) {
    console.log(`State "${state}" normalized to "${fullName}"`);
    return fullName;
  }
  
  // Not found - log it and return null to skip this field
  console.warn(`⚠️ Could not normalize state: "${state}" - skipping state field`);
  return null;
}

function getAuthHeader(): string {
  return `Basic ${btoa(`${MAUTIC_USERNAME}:${MAUTIC_PASSWORD}`)}`;
}

async function mauticRequest(endpoint: string, method: string = "GET", body?: any): Promise<any> {
  const url = `${MAUTIC_URL}/api/${endpoint}`;
  const options: RequestInit = {
    method,
    headers: {
      "Authorization": getAuthHeader(),
      "Content-Type": "application/json",
    },
  };
  if (body) {
    options.body = JSON.stringify(body);
    console.log(`Mautic request body: ${JSON.stringify(body, null, 2)}`);
  }

  const response = await fetch(url, options);
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Mautic API error (${response.status}): ${errorText}`);
  }
  return response.json();
}

async function findContactByEmail(email: string): Promise<number | null> {
  try {
    const result = await mauticRequest(`contacts?search=email:${encodeURIComponent(email)}`);
    const contacts = result.contacts || {};
    const contactIds = Object.keys(contacts);
    return contactIds.length > 0 ? parseInt(contactIds[0]) : null;
  } catch {
    return null;
  }
}

async function upsertContact(data: any, existingId?: number): Promise<number> {
  const endpoint = existingId ? `contacts/${existingId}/edit` : "contacts/new";
  const method = existingId ? "PATCH" : "POST";
  const result = await mauticRequest(endpoint, method, data);
  return result.contact.id;
}

async function addToSegment(contactId: number, segmentId: number): Promise<void> {
  if (!segmentId || segmentId === 0) return;
  try {
    await mauticRequest(`segments/${segmentId}/contact/${contactId}/add`, "POST");
  } catch (err) {
    console.error(`Error adding to segment ${segmentId}:`, err);
  }
}

async function removeFromSegment(contactId: number, segmentId: number): Promise<void> {
  if (!segmentId || segmentId === 0) return;
  try {
    await mauticRequest(`segments/${segmentId}/contact/${contactId}/remove`, "POST");
  } catch (err) {
    console.error(`Error removing from segment ${segmentId}:`, err);
  }
}

async function addTag(contactId: number, tag: string): Promise<void> {
  try {
    await mauticRequest(`contacts/${contactId}/edit`, "PATCH", { tags: [tag] });
  } catch (err) {
    console.error(`Error adding tag ${tag}:`, err);
  }
}

function parseName(fullName: string | null | undefined): { firstname: string; lastname: string } {
  const parts = (fullName || "").trim().split(/\s+/);
  if (parts.length === 0 || (parts.length === 1 && parts[0] === "")) {
    return { firstname: "", lastname: "" };
  }
  if (parts.length === 1) return { firstname: parts[0], lastname: "" };
  return { firstname: parts[0], lastname: parts.slice(1).join(" ") };
}

function mapRecordToMautic(record: any, type: string): any {
  const { firstname, lastname } = parseName(record.name);
  
  // Start with required fields only
  const mapped: Record<string, any> = {
    email: record.email,
  };
  
  // Only add fields that have valid values
  if (firstname) mapped.firstname = firstname;
  if (lastname) mapped.lastname = lastname;

  if (record.phone_e164 || record.phone) {
    mapped.phone = record.phone_e164 || record.phone;
    mapped.mobile = record.phone_e164 || record.phone;
  }
  
  if (record.address) mapped.address1 = record.address;
  if (record.city) mapped.city = record.city;
  
  // State - normalized to full name (e.g., "Missouri" not "MO")
  const normalizedState = normalizeState(record.state);
  if (normalizedState) {
    mapped.state = normalizedState;
    mapped.country = "United States";
  }
  
  if (record.zip_code) mapped.zipcode = record.zip_code;
  if (record.county) mapped.county = record.county;
  if (record.congressional_district) mapped.congressional_district = record.congressional_district;
  if (record.senate_district) mapped.senate_district = record.senate_district;
  if (record.house_district) mapped.house_district = record.house_district;
  if (record.date_of_birth) mapped.date_of_birth = record.date_of_birth;

  if (type === "member") {
    const schoolName = record.school_name || record.college || record.high_school;
    if (schoolName) mapped.school_name = schoolName;
    if (record.employer) mapped.company = record.employer;
    if (record.chapter_position) mapped.position = record.chapter_position;
  }

  return mapped;
}

async function syncRecord(record: any, type: string): Promise<{ success: boolean; mauticId?: number; error?: string }> {
  try {
    console.log(`\n--- Syncing ${type}: ${record.email} ---`);
    console.log(`Raw state value: "${record.state}"`);
    
    const existingId = await findContactByEmail(record.email);
    if (existingId) {
      console.log(`Found existing Mautic contact: ${existingId}`);
    }
    
    const mauticData = mapRecordToMautic(record, type);
    const mauticId = await upsertContact(mauticData, existingId || undefined);

    await addToSegment(mauticId, SEGMENT_ALL_CONTACTS);

    if (type === "member") {
      await addToSegment(mauticId, SEGMENT_MEMBERS);
      await removeFromSegment(mauticId, SEGMENT_NON_MEMBER_SUBSCRIBERS);
      await addTag(mauticId, "member");
      await supabase.from("members").update({ mautic_id: mauticId }).eq("id", record.id);
    } else {
      await addToSegment(mauticId, SEGMENT_NON_MEMBER_SUBSCRIBERS);
      await supabase.from("subscribers").update({ mautic_id: mauticId }).eq("id", record.id);
    }

    return { success: true, mauticId };
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : "Unknown error";
    return { success: false, error: errorMessage };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const { type = "both", limit = 50 } = await req.json();

    console.log("=".repeat(60));
    console.log(`BULK SYNC TO MAUTIC`);
    console.log(`Type: ${type}`);
    console.log(`Limit: ${limit}`);
    console.log(`Mautic URL: ${MAUTIC_URL}`);
    console.log("=".repeat(60));

    const results = {
      subscribers: { total: 0, synced: 0, failed: 0, errors: [] as string[] },
      members: { total: 0, synced: 0, failed: 0, errors: [] as string[] },
    };

    // Sync subscribers
    if (type === "subscribers" || type === "both") {
      const { data: subscribers, error } = await supabase
        .from("subscribers")
        .select("*")
        .is("mautic_id", null)
        .eq("subscribed", true)
        .not("email", "is", null)
        .limit(limit);

      if (error) {
        console.error("Error fetching subscribers:", error);
      } else if (subscribers) {
        results.subscribers.total = subscribers.length;
        console.log(`\nFound ${subscribers.length} subscribers to sync\n`);

        for (const subscriber of subscribers) {
          const result = await syncRecord(subscriber, "subscriber");
          
          if (result.success) {
            results.subscribers.synced++;
            console.log(`✓ Synced ${subscriber.email} -> Mautic ID ${result.mauticId}`);
          } else {
            results.subscribers.failed++;
            results.subscribers.errors.push(`${subscriber.email}: ${result.error}`);
            console.error(`✗ Failed ${subscriber.email}: ${result.error}`);
          }

          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
    }

    // Sync members
    if (type === "members" || type === "both") {
      const { data: members, error } = await supabase
        .from("members")
        .select("*")
        .is("mautic_id", null)
        .not("email", "is", null)
        .limit(limit);

      if (error) {
        console.error("Error fetching members:", error);
      } else if (members) {
        results.members.total = members.length;
        console.log(`\nFound ${members.length} members to sync\n`);

        for (const member of members) {
          const result = await syncRecord(member, "member");
          
          if (result.success) {
            results.members.synced++;
            console.log(`✓ Synced ${member.email} -> Mautic ID ${result.mauticId}`);
          } else {
            results.members.failed++;
            results.members.errors.push(`${member.email}: ${result.error}`);
            console.error(`✗ Failed ${member.email}: ${result.error}`);
          }

          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
    }

    // Log results
    await supabase.from("mautic_sync_log").insert({
      direction: "to_mautic",
      entity_type: "bulk_sync",
      entity_id: "bulk",
      action: "bulk_sync",
      payload: results,
      success: true,
    });

    console.log("\n" + "=".repeat(60));
    console.log("BULK SYNC COMPLETE");
    console.log(`Subscribers: ${results.subscribers.synced}/${results.subscribers.total} synced, ${results.subscribers.failed} failed`);
    console.log(`Members: ${results.members.synced}/${results.members.total} synced, ${results.members.failed} failed`);
    console.log("=".repeat(60));

    return new Response(
      JSON.stringify({
        success: true,
        results,
        message: `Synced ${results.subscribers.synced} subscribers and ${results.members.synced} members`,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("BULK SYNC ERROR:", error);
    const errorMessage = error instanceof Error ? error.message : "Unknown error";

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});