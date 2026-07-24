import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

interface LookupResult {
  subscriber_id: string;
  member_id: string | null;
  donor_id: string | null;
  name: string;
  email: string;
  exists_in_members: boolean;
  exists_in_donors: boolean;
  exists_in_event_attendees: boolean;
  exists_in_subscribers: boolean;
  was_created: boolean;
}

async function findOrCreateSubscriber(email: string): Promise<LookupResult> {
  const normalizedEmail = email.toLowerCase().trim();
  
  // Step 1: Check all FOUR tables simultaneously
  // NOTE: event_attendees uses 'guest_email' not 'email'!
  const [subscriberResult, memberResult, donorResult, attendeeResult] = await Promise.all([
    supabase
      .from('subscribers')
      .select('id, member_id, donor_id, name, email')
      .eq('email', normalizedEmail)
      .single(),
    supabase
      .from('members')
      .select('id, name, email')
      .eq('email', normalizedEmail)
      .single(),
    supabase
      .from('donors')
      .select('id, member_id, name, email')
      .eq('email', normalizedEmail)
      .single(),
    supabase
      .from('event_attendees')
      .select('id, guest_name, guest_email, member_id')
      .eq('guest_email', normalizedEmail)  // ← Note: guest_email!
      .limit(1)
      .single()
  ]);

  const existingSubscriber = subscriberResult.data;
  const existingMember = memberResult.data;
  const existingDonor = donorResult.data;
  const existingAttendee = attendeeResult.data;

  // Step 2: If subscriber exists, return it (might need to update links)
  if (existingSubscriber) {
    let needsUpdate = false;
    const updates: any = {};

    if (existingMember && !existingSubscriber.member_id) {
      updates.member_id = existingMember.id;
      needsUpdate = true;
    }

    if (existingDonor && !existingSubscriber.donor_id) {
      updates.donor_id = existingDonor.id;
      needsUpdate = true;
    }

    if (needsUpdate) {
      await supabase
        .from('subscribers')
        .update(updates)
        .eq('id', existingSubscriber.id);
    }

    return {
      subscriber_id: existingSubscriber.id,
      member_id: existingSubscriber.member_id || existingMember?.id || null,
      donor_id: existingSubscriber.donor_id || existingDonor?.id || null,
      name: existingSubscriber.name,
      email: existingSubscriber.email,
      exists_in_members: !!existingMember,
      exists_in_donors: !!existingDonor,
      exists_in_event_attendees: !!existingAttendee,
      exists_in_subscribers: true,
      was_created: false
    };
  }

  // Step 3: Subscriber doesn't exist - create one
  let nameToUse = "A Concerned Missouri Resident";
  let memberId: string | null = null;
  let donorId: string | null = null;

  // Priority: Member > Donor > Event Attendee
  if (existingMember) {
    nameToUse = existingMember.name;
    memberId = existingMember.id;
    
    // If member exists and donor exists, link them
    if (existingDonor) {
      donorId = existingDonor.id;
      
      // Update donor to link to member if not already linked
      if (!existingDonor.member_id) {
        await supabase
          .from('donors')
          .update({ member_id: memberId })
          .eq('id', existingDonor.id);
      }
    }
  } else if (existingDonor) {
    // Only donor exists
    nameToUse = existingDonor.name;
    donorId = existingDonor.id;
    memberId = existingDonor.member_id; // Might already be linked to a member
  } else if (existingAttendee) {
    // Only event attendee exists
    nameToUse = existingAttendee.guest_name || "A Concerned Missouri Resident";
    memberId = existingAttendee.member_id; // Event attendee might be linked to a member
  }

  // Step 4: Create the subscriber record
  const { data: newSubscriber, error: createError } = await supabase
    .from('subscribers')
    .insert({
      email: normalizedEmail,
      name: nameToUse,
      member_id: memberId,
      donor_id: donorId,
      source: 'shortcut_install',
      subscription_status: 'subscribed',
      subscribed: true,
      optin_date: new Date().toISOString()
    })
    .select('id, member_id, donor_id, name, email')
    .single();

  if (createError) {
    throw createError;
  }

  return {
    subscriber_id: newSubscriber.id,
    member_id: memberId,
    donor_id: donorId,
    name: nameToUse,
    email: normalizedEmail,
    exists_in_members: !!existingMember,
    exists_in_donors: !!existingDonor,
    exists_in_event_attendees: !!existingAttendee,
    exists_in_subscribers: false,
    was_created: true
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { 
      status: 405, 
      headers: corsHeaders 
    });
  }

  try {
    const { email } = await req.json();

    // Validation
    if (!email) {
      return new Response(JSON.stringify({
        error: "Email is required"
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return new Response(JSON.stringify({
        error: "Invalid email format"
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    // Find or create subscriber with full linking logic
    const result = await findOrCreateSubscriber(email);

    // Determine status message
    let statusMessage = "";
    if (result.was_created) {
      const sources: string[] = [];
      if (result.exists_in_members) sources.push("member");
      if (result.exists_in_donors) sources.push("donor");
      if (result.exists_in_event_attendees) sources.push("event attendee");
      
      if (sources.length > 0) {
        statusMessage = `Found you in our system! You're a ${sources.join(" and ")}. Account linked!`;
      } else {
        statusMessage = "New subscriber created! Welcome to the movement!";
      }
    } else {
      statusMessage = "Account found! You're all set to install the shortcut.";
    }

    return new Response(JSON.stringify({
      subscriber_id: result.subscriber_id,
      member_id: result.member_id,
      donor_id: result.donor_id,
      name: result.name,
      email: result.email,
      exists: !result.was_created,
      was_created: result.was_created,
      is_member: result.exists_in_members,
      is_donor: result.exists_in_donors,
      is_event_attendee: result.exists_in_event_attendees,
      message: statusMessage,
      account_details: {
        found_in_members: result.exists_in_members,
        found_in_donors: result.exists_in_donors,
        found_in_event_attendees: result.exists_in_event_attendees,
        found_in_subscribers: result.exists_in_subscribers,
        all_tables_linked: !!(result.member_id && result.donor_id)
      }
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (error) {
    console.error("Lookup error:", error);
    return new Response(JSON.stringify({
      error: error.message || "Failed to process request",
      details: error.toString()
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});