import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// Helper to strip quotes from env variables (in case they were stored with quotes)
function cleanEnv(value: string | undefined): string {
  if (!value) return "";
  return value.replace(/^["']|["']$/g, "").trim();
}

// Mautic configuration - strip any accidental quotes
const MAUTIC_URL = cleanEnv(Deno.env.get("MAUTIC_URL"));
const MAUTIC_USERNAME = cleanEnv(Deno.env.get("MAUTIC_USERNAME"));
const MAUTIC_PASSWORD = cleanEnv(Deno.env.get("MAUTIC_PASSWORD"));

// Segment IDs
const SEGMENT_ALL_CONTACTS = parseInt(cleanEnv(Deno.env.get("MAUTIC_SEGMENT_ALL_CONTACTS")) || "0");
const SEGMENT_MEMBERS = parseInt(cleanEnv(Deno.env.get("MAUTIC_SEGMENT_MEMBERS")) || "0");
const SEGMENT_NON_MEMBER_SUBSCRIBERS = parseInt(cleanEnv(Deno.env.get("MAUTIC_SEGMENT_NON_MEMBER_SUBS")) || "0");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================================================
// US state normalization for Mautic.
//
// MAUTIC WANTS THE FULL NAME, NOT THE CODE. This function used to normalize
// "Missouri" DOWN to "MO", and every payload carrying a state came back
// HTTP 400 "state: The selected choice is invalid". Verified on the running
// instance 2026-08-05: mautic.lead_fields.state has type `region`, whose
// accepted choices are the values in
// docroot/app/bundles/CoreBundle/Assets/json/regions.json, and the United
// States entry there is a list of full state names ("Alabama", "Alaska",
// "Missouri", ...). "MO" is not in that list, so Mautic rejects it.
//
// So the map runs the other way now: any input, code or name, resolves to the
// exact spelling Mautic accepts. Anything unrecognized returns null and the
// field is omitted, which is what kept the member sync alive while the
// subscriber sync was failing.
// ============================================================================
const STATE_NAMES: Record<string, string> = {
  AL: "Alabama", AK: "Alaska", AZ: "Arizona", AR: "Arkansas",
  CA: "California", CO: "Colorado", CT: "Connecticut", DE: "Delaware",
  FL: "Florida", GA: "Georgia", HI: "Hawaii", ID: "Idaho",
  IL: "Illinois", IN: "Indiana", IA: "Iowa", KS: "Kansas",
  KY: "Kentucky", LA: "Louisiana", ME: "Maine", MD: "Maryland",
  MA: "Massachusetts", MI: "Michigan", MN: "Minnesota", MS: "Mississippi",
  MO: "Missouri", MT: "Montana", NE: "Nebraska", NV: "Nevada",
  NH: "New Hampshire", NJ: "New Jersey", NM: "New Mexico", NY: "New York",
  NC: "North Carolina", ND: "North Dakota", OH: "Ohio", OK: "Oklahoma",
  OR: "Oregon", PA: "Pennsylvania", RI: "Rhode Island", SC: "South Carolina",
  SD: "South Dakota", TN: "Tennessee", TX: "Texas", UT: "Utah",
  VT: "Vermont", VA: "Virginia", WA: "Washington", WV: "West Virginia",
  WI: "Wisconsin", WY: "Wyoming", DC: "District of Columbia",
};

// name (lowercased) -> the exact spelling Mautic accepts
const STATE_BY_NAME: Record<string, string> = Object.fromEntries(
  Object.values(STATE_NAMES).map((n) => [n.toLowerCase(), n]),
);

function normalizeState(state: string | null | undefined): string | null {
  if (!state) return null;

  const cleaned = state.trim();
  if (!cleaned) return null;

  if (cleaned.length === 2) {
    const name = STATE_NAMES[cleaned.toUpperCase()];
    if (name) return name;
    console.warn(`Invalid 2-letter state code: ${cleaned}`);
    return null;
  }

  const name = STATE_BY_NAME[cleaned.toLowerCase()];
  if (name) return name;

  console.warn(`Could not normalize state: ${cleaned}`);
  return null;
}

// Update mautic_id directly using service role (bypasses RLS)
async function updateMauticId(
  table: "members" | "subscribers",
  recordId: string,
  mauticId: number
): Promise<void> {
  console.log(`Updating ${table} ${recordId} with mautic_id ${mauticId}...`);
  
  const { data, error } = await supabase
    .from(table)
    .update({ mautic_id: mauticId })
    .eq("id", recordId)
    .select("id, mautic_id")
    .single();
  
  if (error) {
    console.error(`Error updating ${table} with mautic_id:`, error);
    throw new Error(`${error.code}: ${error.message}`);
  }
  
  if (data) {
    console.log(`Successfully updated ${table} ${recordId} with mautic_id ${mauticId}`);
  } else {
    console.warn(`No ${table} record found with id ${recordId}`);
  }
}

// Base64 encode credentials for Basic Auth
function getAuthHeader(): string {
  const credentials = btoa(`${MAUTIC_USERNAME}:${MAUTIC_PASSWORD}`);
  return `Basic ${credentials}`;
}

// Make Mautic API request
async function mauticRequest(
  endpoint: string,
  method: string = "GET",
  body?: any
): Promise<any> {
  const url = `${MAUTIC_URL}/api/${endpoint}`;
  
  console.log(`Making Mautic request: ${method} ${url}`);
  
  const options: RequestInit = {
    method,
    headers: {
      "Authorization": getAuthHeader(),
      "Content-Type": "application/json",
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
    console.log(`Request body: ${JSON.stringify(body, null, 2)}`);
  }

  const response = await fetch(url, options);
  
  if (!response.ok) {
    const errorText = await response.text();
    console.error(`Mautic API error: ${response.status} - ${errorText}`);
    throw new Error(`Mautic API error (${response.status}): ${errorText}`);
  }

  const result = await response.json();
  console.log(`Mautic response: ${JSON.stringify(result, null, 2).substring(0, 500)}...`);
  return result;
}

// Search for existing contact by email
async function findContactByEmail(email: string): Promise<number | null> {
  try {
    console.log(`Searching for contact with email: ${email}`);
    const result = await mauticRequest(`contacts?search=email:${encodeURIComponent(email)}`);
    const contacts = result.contacts || {};
    const contactIds = Object.keys(contacts);
    
    if (contactIds.length > 0) {
      const foundId = parseInt(contactIds[0]);
      console.log(`Found existing contact with ID: ${foundId}`);
      return foundId;
    }
    console.log(`No existing contact found for: ${email}`);
    return null;
  } catch (err) {
    console.error("Error searching for contact:", err);
    return null;
  }
}

// Create or update contact in Mautic
async function upsertContact(data: any, existingId?: number): Promise<number> {
  let endpoint = "contacts/new";
  let method = "POST";

  if (existingId) {
    endpoint = `contacts/${existingId}/edit`;
    method = "PATCH";
    console.log(`Updating existing contact ID: ${existingId}`);
  } else {
    console.log(`Creating new contact for: ${data.email}`);
  }

  const result = await mauticRequest(endpoint, method, data);
  console.log(`Contact upsert successful, Mautic ID: ${result.contact.id}`);
  return result.contact.id;
}

// Delete contact from Mautic
async function deleteContact(mauticId: number): Promise<void> {
  console.log(`Deleting Mautic contact ID: ${mauticId}`);
  await mauticRequest(`contacts/${mauticId}/delete`, "DELETE");
  console.log(`Successfully deleted Mautic contact ID: ${mauticId}`);
}

// Add contact to segment
async function addToSegment(contactId: number, segmentId: number): Promise<void> {
  if (!segmentId || segmentId === 0) {
    console.log(`Skipping segment add - segment ID not configured`);
    return;
  }
  
  try {
    console.log(`Adding contact ${contactId} to segment ${segmentId}`);
    await mauticRequest(
      `segments/${segmentId}/contact/${contactId}/add`,
      "POST"
    );
    console.log(`Successfully added contact ${contactId} to segment ${segmentId}`);
  } catch (err) {
    console.error(`Error adding contact ${contactId} to segment ${segmentId}:`, err);
  }
}

// Remove contact from segment
async function removeFromSegment(contactId: number, segmentId: number): Promise<void> {
  if (!segmentId || segmentId === 0) {
    console.log(`Skipping segment remove - segment ID not configured`);
    return;
  }
  
  try {
    console.log(`Removing contact ${contactId} from segment ${segmentId}`);
    await mauticRequest(
      `segments/${segmentId}/contact/${contactId}/remove`,
      "POST"
    );
    console.log(`Successfully removed contact ${contactId} from segment ${segmentId}`);
  } catch (err) {
    console.error(`Error removing contact ${contactId} from segment ${segmentId}:`, err);
  }
}

// Add tag to contact
async function addTag(contactId: number, tag: string): Promise<void> {
  try {
    console.log(`Adding tag "${tag}" to contact ${contactId}`);
    await mauticRequest(`contacts/${contactId}/edit`, "PATCH", {
      tags: [tag],
    });
    console.log(`Successfully added tag "${tag}" to contact ${contactId}`);
  } catch (err) {
    console.error(`Error adding tag ${tag} to contact ${contactId}:`, err);
  }
}

// Parse name into first/last
function parseName(fullName: string | null | undefined): { firstname: string; lastname: string } {
  const parts = (fullName || "").trim().split(/\s+/);
  if (parts.length === 0 || (parts.length === 1 && parts[0] === "")) {
    return { firstname: "", lastname: "" };
  }
  if (parts.length === 1) {
    return { firstname: parts[0], lastname: "" };
  }
  const firstname = parts[0];
  const lastname = parts.slice(1).join(" ");
  return { firstname, lastname };
}

// Map member to Mautic contact fields
function mapMemberToMautic(member: any): any {
  const { firstname, lastname } = parseName(member.name);
  
  const mapped: Record<string, any> = {
    firstname,
    lastname,
    email: member.email,
    country: "United States",
    // The one legacy zap side effect with real substance. Six state=on zaps
    // fired off this form and nothing replaced them; five of the six are
    // genuinely gone with no owner asking for them (a Google Contact, a
    // district spreadsheet superseded by the district triggers, a student
    // spreadsheet whose only purpose was the chair alert that member-onboard
    // now sends properly, a Notion mirror and an attendance sheet). This one is
    // different: the payload is a raw row with no tag or segment field, so
    // every member has been landing in Mautic untagged and indistinguishable
    // from a newsletter subscriber. The MailChimp zap tagged them 'Member'.
    // Verified against the live instance 2026-08-05: the tag is accepted on
    // POST /api/contacts/new (HTTP 201) and tag id 2 'Member' already exists.
    // Subscribers deliberately do NOT get this; that is the whole distinction.
    tags: ["Member"],
  };

  if (member.phone_e164 || member.phone) {
    mapped.phone = member.phone_e164 || member.phone;
    mapped.mobile = member.phone_e164 || member.phone;
  }
  if (member.address) mapped.address1 = member.address;
  if (member.city) mapped.city = member.city;

  const normalizedState = normalizeState(member.state);
  if (normalizedState) mapped.state = normalizedState;

  if (member.zip_code) mapped.zipcode = member.zip_code;
  if (member.county) mapped.county = member.county;
  if (member.congressional_district) mapped.congressional_district = member.congressional_district;
  if (member.senate_district) mapped.senate_district = member.senate_district;
  if (member.house_district) mapped.house_district = member.house_district;
  if (member.date_of_birth) mapped.date_of_birth = member.date_of_birth;
  
  const schoolName = member.school_name || member.college || member.high_school;
  if (schoolName) mapped.school_name = schoolName;
  
  if (member.employer) mapped.company = member.employer;
  if (member.chapter_position) mapped.position = member.chapter_position;
  
  // Membership eligibility (age-based)
  mapped.membership_eligible = member.membership_eligible ? 1 : 0;
  
  console.log(`Mapped member data: ${JSON.stringify(mapped, null, 2)}`);
  return mapped;
}

// Map subscriber to Mautic contact fields
function mapSubscriberToMautic(subscriber: any): any {
  const { firstname, lastname } = parseName(subscriber.name);
  
  const mapped: Record<string, any> = {
    firstname,
    lastname,
    email: subscriber.email,
    country: "United States",
  };
  
  if (subscriber.phone_e164 || subscriber.phone) {
    mapped.phone = subscriber.phone_e164 || subscriber.phone;
    mapped.mobile = subscriber.phone_e164 || subscriber.phone;
  }
  if (subscriber.address) mapped.address1 = subscriber.address;
  if (subscriber.city) mapped.city = subscriber.city;
  
  const normalizedState = normalizeState(subscriber.state);
  if (normalizedState) mapped.state = normalizedState;
  
  if (subscriber.zip_code) mapped.zipcode = subscriber.zip_code;
  if (subscriber.county) mapped.county = subscriber.county;
  if (subscriber.congressional_district) mapped.congressional_district = subscriber.congressional_district;
  if (subscriber.senate_district) mapped.senate_district = subscriber.senate_district;
  if (subscriber.house_district) mapped.house_district = subscriber.house_district;
  if (subscriber.date_of_birth) mapped.date_of_birth = subscriber.date_of_birth;
  
  console.log(`Mapped subscriber data: ${JSON.stringify(mapped, null, 2)}`);
  return mapped;
}

// Log sync operation to database
async function logSync(
  direction: string,
  entityType: string,
  entityId: string,
  mauticId: number | null,
  action: string,
  payload: any,
  response: any,
  error: string | null,
  success: boolean
): Promise<void> {
  try {
    await supabase.from("mautic_sync_log").insert({
      direction,
      entity_type: entityType,
      entity_id: entityId,
      mautic_id: mauticId,
      action,
      payload,
      response,
      error,
      success,
    });
    console.log(`Logged sync operation: ${action} ${entityType} ${entityId} -> Mautic ${mauticId}`);
  } catch (err) {
    console.error("Failed to log sync operation:", err);
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const { type, record } = await req.json();
    
    console.log("=".repeat(60));
    console.log(`Starting ${type} sync for: ${record.email || record.id}`);
    console.log(`Record ID: ${record.id}`);
    console.log(`Mautic URL: ${MAUTIC_URL}`);
    console.log(`Segments configured: ALL=${SEGMENT_ALL_CONTACTS}, MEMBERS=${SEGMENT_MEMBERS}, NON_MEMBER=${SEGMENT_NON_MEMBER_SUBSCRIBERS}`);
    console.log("=".repeat(60));

    let mauticId: number | null = null;
    let action = "create";
    let mauticData: any;

    // Handle DELETE operations
    if (type === "delete_member" || type === "delete_subscriber") {
      const entityType = type.replace("delete_", "");
      mauticId = record.mautic_id;
      
      if (!mauticId) {
        console.log("No mautic_id found, nothing to delete from Mautic");
        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "No Mautic contact to delete (no mautic_id)" 
          }),
          { 
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200 
          }
        );
      }
      
      await deleteContact(mauticId);
      
      await logSync(
        "to_mautic",
        entityType,
        record.id,
        mauticId,
        "delete",
        { mautic_id: mauticId, email: record.email },
        { deleted: true },
        null,
        true
      );
      
      console.log("=".repeat(60));
      console.log(`Delete completed successfully!`);
      console.log(`Deleted Mautic ID: ${mauticId}`);
      console.log("=".repeat(60));

      return new Response(
        JSON.stringify({ 
          success: true, 
          mauticId, 
          action: "delete",
          message: `Successfully deleted contact from Mautic` 
        }),
        { 
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200 
        }
      );
    }

    // Handle CREATE/UPDATE operations
    const existingId = await findContactByEmail(record.email);
    if (existingId) {
      mauticId = existingId;
      action = "update";
    }

    if (type === "member") {
      mauticData = mapMemberToMautic(record);
      mauticId = await upsertContact(mauticData, existingId || undefined);
      
      await addToSegment(mauticId, SEGMENT_ALL_CONTACTS);
      await addToSegment(mauticId, SEGMENT_MEMBERS);
      await removeFromSegment(mauticId, SEGMENT_NON_MEMBER_SUBSCRIBERS);
      await addTag(mauticId, "member");
      
      // Update mautic_id in Supabase directly
      try {
        await updateMauticId("members", record.id, mauticId);
      } catch (err) {
        console.error("Failed to update mautic_id in members table:", err);
        // Continue anyway - the sync to Mautic was successful
      }
      
      await logSync(
        "to_mautic",
        "member",
        record.id,
        mauticId,
        action,
        mauticData,
        { mautic_id: mauticId },
        null,
        true
      );
      
    } else if (type === "subscriber") {
      mauticData = mapSubscriberToMautic(record);
      mauticId = await upsertContact(mauticData, existingId || undefined);
      
      await addToSegment(mauticId, SEGMENT_ALL_CONTACTS);
      await addToSegment(mauticId, SEGMENT_NON_MEMBER_SUBSCRIBERS);
      
      // Update mautic_id in Supabase directly
      try {
        await updateMauticId("subscribers", record.id, mauticId);
      } catch (err) {
        console.error("Failed to update mautic_id in subscribers table:", err);
        // Continue anyway - the sync to Mautic was successful
      }
      
      await logSync(
        "to_mautic",
        "subscriber",
        record.id,
        mauticId,
        action,
        mauticData,
        { mautic_id: mauticId },
        null,
        true
      );
      
    } else {
      throw new Error(`Unknown type: ${type}`);
    }

    console.log("=".repeat(60));
    console.log(`Sync completed successfully!`);
    console.log(`Action: ${action}`);
    console.log(`Mautic ID: ${mauticId}`);
    console.log("=".repeat(60));

    return new Response(
      JSON.stringify({ 
        success: true, 
        mauticId, 
        action,
        message: `Successfully ${action}d contact in Mautic` 
      }),
      { 
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200 
      }
    );

  } catch (error) {
    console.error("=".repeat(60));
    console.error("SYNC ERROR:", error);
    console.error("=".repeat(60));
    
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    
    try {
      await supabase.from("mautic_sync_log").insert({
        direction: "to_mautic",
        entity_type: "unknown",
        entity_id: "unknown",
        action: "sync_error",
        error: errorMessage,
        success: false,
      });
    } catch (logErr) {
      console.error("Failed to log error:", logErr);
    }
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: errorMessage 
      }),
      { 
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500 
      }
    );
  }
});