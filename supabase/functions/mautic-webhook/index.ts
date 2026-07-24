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

const MAUTIC_WEBHOOK_SECRET = cleanEnv(Deno.env.get("MAUTIC_WEBHOOK_SECRET"));

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, webhook-signature",
};

// Verify Mautic webhook signature
async function verifySignature(payload: string, signature: string): Promise<boolean> {
  if (!MAUTIC_WEBHOOK_SECRET) {
    console.warn("MAUTIC_WEBHOOK_SECRET not set, skipping signature verification");
    return true;
  }

  if (!signature) {
    console.warn("No signature provided in webhook request");
    return false;
  }

  try {
    console.log(`Verifying signature...`);
    console.log(`Received signature: ${signature}`);
    
    const encoder = new TextEncoder();
    const keyData = encoder.encode(MAUTIC_WEBHOOK_SECRET);
    const data = encoder.encode(payload);
    
    const key = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    
    const signatureBuffer = await crypto.subtle.sign("HMAC", key, data);
    const expectedSignature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)));
    
    console.log(`Expected signature: ${expectedSignature}`);
    
    const isValid = signature === expectedSignature;
    console.log(`Signature valid: ${isValid}`);
    
    return isValid;
  } catch (err) {
    console.error("Signature verification error:", err);
    return false;
  }
}

// Parse contact data from Mautic webhook payload
function parseContactFromMautic(contact: any): {
  email: string;
  name: string;
  phone: string | null;
  address: string | null;
  city: string | null;
  state: string | null;
  zip_code: string | null;
  county: string | null;
  congressional_district: string | null;
  senate_district: string | null;
  house_district: string | null;
  date_of_birth: string | null;
  mautic_id: number;
} {
  const fields = contact.fields || {};
  const core = fields.core || {};
  
  // Helper to safely get field value
  const getField = (fieldName: string): string | null => {
    const field = core[fieldName];
    return field?.value || null;
  };

  const firstname = getField("firstname") || "";
  const lastname = getField("lastname") || "";
  const name = `${firstname} ${lastname}`.trim();

  const parsed = {
    email: getField("email") || contact.email || "",
    name,
    phone: getField("phone") || getField("mobile"),
    address: getField("address1"),
    city: getField("city"),
    state: getField("state"),
    zip_code: getField("zipcode"),
    county: getField("county"),
    congressional_district: getField("congressional_district"),
    senate_district: getField("senate_district"),
    house_district: getField("house_district"),
    date_of_birth: getField("date_of_birth"),
    mautic_id: contact.id,
  };

  console.log(`Parsed contact from Mautic: ${JSON.stringify(parsed, null, 2)}`);
  return parsed;
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
    console.log(`Logged sync operation: ${direction} ${action} ${entityType} (Mautic ID: ${mauticId})`);
  } catch (err) {
    console.error("Failed to log sync operation:", err);
  }
}

// Handle new contact from Mautic
async function handleNewContact(contact: any): Promise<void> {
  console.log("=".repeat(60));
  console.log("Handling NEW CONTACT from Mautic");
  console.log("=".repeat(60));
  
  const contactData = parseContactFromMautic(contact);
  
  if (!contactData.email) {
    console.log("No email in contact, skipping");
    return;
  }

  const email = contactData.email.toLowerCase();
  console.log(`Processing new contact: ${email} (Mautic ID: ${contactData.mautic_id})`);

  // Check if already exists in members
  const { data: existingMember, error: memberError } = await supabase
    .from("members")
    .select("id, mautic_id, email")
    .ilike("email", email)
    .single();

  if (existingMember && !memberError) {
    console.log(`Contact ${email} already exists as member (ID: ${existingMember.id})`);
    
    // Update mautic_id if not set
    if (!existingMember.mautic_id) {
      const { error: updateError } = await supabase
        .from("members")
        .update({ mautic_id: contactData.mautic_id })
        .eq("id", existingMember.id);
      
      if (updateError) {
        console.error("Error updating member mautic_id:", updateError);
      } else {
        console.log(`Updated member ${existingMember.id} with mautic_id ${contactData.mautic_id}`);
      }
      
      await logSync(
        "from_mautic",
        "member",
        existingMember.id,
        contactData.mautic_id,
        "link_existing",
        contactData,
        { linked: true },
        null,
        true
      );
    }
    return;
  }

  // Check if already exists in subscribers
  const { data: existingSubscriber, error: subError } = await supabase
    .from("subscribers")
    .select("id, mautic_id, email")
    .ilike("email", email)
    .single();

  if (existingSubscriber && !subError) {
    console.log(`Contact ${email} already exists as subscriber (ID: ${existingSubscriber.id})`);
    
    // Update mautic_id if not set
    if (!existingSubscriber.mautic_id) {
      const { error: updateError } = await supabase
        .from("subscribers")
        .update({ mautic_id: contactData.mautic_id })
        .eq("id", existingSubscriber.id);
      
      if (updateError) {
        console.error("Error updating subscriber mautic_id:", updateError);
      } else {
        console.log(`Updated subscriber ${existingSubscriber.id} with mautic_id ${contactData.mautic_id}`);
      }
      
      await logSync(
        "from_mautic",
        "subscriber",
        existingSubscriber.id,
        contactData.mautic_id,
        "link_existing",
        contactData,
        { linked: true },
        null,
        true
      );
    }
    return;
  }

  // Create new subscriber
  console.log(`Creating new subscriber from Mautic contact: ${email}`);
  
  const { data: newSubscriber, error: insertError } = await supabase
    .from("subscribers")
    .insert({
      email: email,
      name: contactData.name,
      phone: contactData.phone,
      address: contactData.address,
      city: contactData.city,
      state: contactData.state,
      zip_code: contactData.zip_code,
      county: contactData.county,
      congressional_district: contactData.congressional_district,
      senate_district: contactData.senate_district,
      house_district: contactData.house_district,
      date_of_birth: contactData.date_of_birth,
      mautic_id: contactData.mautic_id,
      subscription_status: "subscribed",
      subscribed: true,
      source: "mautic",
      optin_date: new Date().toISOString(),
    })
    .select()
    .single();

  if (insertError) {
    console.error("Error creating subscriber:", insertError);
    
    await logSync(
      "from_mautic",
      "subscriber",
      "new",
      contactData.mautic_id,
      "create_failed",
      contactData,
      null,
      insertError.message,
      false
    );
    
    throw insertError;
  }

  console.log(`Successfully created new subscriber: ${email} (ID: ${newSubscriber.id})`);
  
  await logSync(
    "from_mautic",
    "subscriber",
    newSubscriber.id,
    contactData.mautic_id,
    "create",
    contactData,
    { subscriber_id: newSubscriber.id },
    null,
    true
  );
}

// Handle unsubscribe/DNC from Mautic
async function handleUnsubscribe(contact: any, channel: string, reason: string): Promise<void> {
  console.log("=".repeat(60));
  console.log("Handling UNSUBSCRIBE from Mautic");
  console.log("=".repeat(60));
  
  const email = contact.email?.toLowerCase();
  const mauticId = contact.id;
  
  console.log(`Processing unsubscribe for: ${email} (Mautic ID: ${mauticId})`);
  console.log(`Channel: ${channel}`);
  console.log(`Reason: ${reason}`);
  
  if (!email) {
    console.log("No email in unsubscribe event, skipping");
    return;
  }

  const now = new Date().toISOString();
  const reasonText = reason || "Unsubscribed via Mautic";

  // Update members table
  const { data: member, error: memberFetchError } = await supabase
    .from("members")
    .select("id, email, opt_out")
    .ilike("email", email)
    .single();

  if (member && !memberFetchError) {
    console.log(`Found member: ${member.email} (ID: ${member.id})`);
    
    if (!member.opt_out) {
      const { error: memberUpdateError } = await supabase
        .from("members")
        .update({
          opt_out: true,
          opt_out_date: now,
          opt_out_reason: reasonText,
        })
        .eq("id", member.id);
      
      if (memberUpdateError) {
        console.error("Error updating member opt_out:", memberUpdateError);
      } else {
        console.log(`Updated member ${member.id} as opted out`);
      }
      
      await logSync(
        "from_mautic",
        "member",
        member.id,
        mauticId,
        "unsubscribe",
        { email, channel, reason },
        { opt_out: true },
        memberUpdateError?.message || null,
        !memberUpdateError
      );
    } else {
      console.log(`Member ${member.id} already opted out, skipping update`);
    }
  } else {
    console.log(`No member found with email: ${email}`);
  }

  // Update subscribers table by email
  const { data: subscribersByEmail, error: subEmailFetchError } = await supabase
    .from("subscribers")
    .select("id, email, subscription_status")
    .ilike("email", email);

  if (subscribersByEmail && subscribersByEmail.length > 0 && !subEmailFetchError) {
    console.log(`Found ${subscribersByEmail.length} subscriber(s) by email`);
    
    for (const subscriber of subscribersByEmail) {
      if (subscriber.subscription_status !== "unsubscribed") {
        const { error: subUpdateError } = await supabase
          .from("subscribers")
          .update({
            subscription_status: "unsubscribed",
            subscribed: false,
          })
          .eq("id", subscriber.id);
        
        if (subUpdateError) {
          console.error(`Error updating subscriber ${subscriber.id}:`, subUpdateError);
        } else {
          console.log(`Updated subscriber ${subscriber.id} as unsubscribed`);
        }
        
        await logSync(
          "from_mautic",
          "subscriber",
          subscriber.id,
          mauticId,
          "unsubscribe",
          { email, channel, reason },
          { subscription_status: "unsubscribed" },
          subUpdateError?.message || null,
          !subUpdateError
        );
      } else {
        console.log(`Subscriber ${subscriber.id} already unsubscribed, skipping`);
      }
    }
  }

  // Also update by mautic_id if available (catches any that might have different email)
  if (mauticId) {
    const { data: subscribersByMauticId, error: subMauticFetchError } = await supabase
      .from("subscribers")
      .select("id, email, subscription_status")
      .eq("mautic_id", mauticId);

    if (subscribersByMauticId && subscribersByMauticId.length > 0 && !subMauticFetchError) {
      console.log(`Found ${subscribersByMauticId.length} subscriber(s) by mautic_id`);
      
      for (const subscriber of subscribersByMauticId) {
        if (subscriber.subscription_status !== "unsubscribed") {
          const { error: subUpdateError } = await supabase
            .from("subscribers")
            .update({
              subscription_status: "unsubscribed",
              subscribed: false,
            })
            .eq("id", subscriber.id);
          
          if (subUpdateError) {
            console.error(`Error updating subscriber ${subscriber.id} by mautic_id:`, subUpdateError);
          } else {
            console.log(`Updated subscriber ${subscriber.id} (by mautic_id) as unsubscribed`);
          }
        }
      }
    }

    // Also check members by mautic_id
    const { data: memberByMauticId, error: memberMauticFetchError } = await supabase
      .from("members")
      .select("id, email, opt_out")
      .eq("mautic_id", mauticId)
      .single();

    if (memberByMauticId && !memberMauticFetchError && !memberByMauticId.opt_out) {
      console.log(`Found member by mautic_id: ${memberByMauticId.email}`);
      
      const { error: memberUpdateError } = await supabase
        .from("members")
        .update({
          opt_out: true,
          opt_out_date: now,
          opt_out_reason: reasonText,
        })
        .eq("id", memberByMauticId.id);
      
      if (memberUpdateError) {
        console.error(`Error updating member ${memberByMauticId.id} by mautic_id:`, memberUpdateError);
      } else {
        console.log(`Updated member ${memberByMauticId.id} (by mautic_id) as opted out`);
      }
    }
  }

  console.log(`Completed unsubscribe processing for: ${email}`);
}

// Handle contact update from Mautic (for email changes)
async function handleContactUpdate(contact: any, oldContact: any): Promise<void> {
  console.log("=".repeat(60));
  console.log("Handling CONTACT UPDATE from Mautic");
  console.log("=".repeat(60));
  
  const newEmail = contact.email?.toLowerCase();
  const oldEmail = oldContact?.email?.toLowerCase();
  const mauticId = contact.id;

  console.log(`Mautic ID: ${mauticId}`);
  console.log(`Old email: ${oldEmail}`);
  console.log(`New email: ${newEmail}`);

  // If email hasn't changed or we don't have both emails, check for mautic_id linking
  if (!oldEmail || newEmail === oldEmail) {
    console.log("Email unchanged, checking if mautic_id needs linking...");
    
    if (newEmail && mauticId) {
      // Try to link mautic_id to existing records that don't have it
      const { data: member } = await supabase
        .from("members")
        .select("id, mautic_id")
        .ilike("email", newEmail)
        .single();
      
      if (member && !member.mautic_id) {
        await supabase
          .from("members")
          .update({ mautic_id: mauticId })
          .eq("id", member.id);
        console.log(`Linked mautic_id ${mauticId} to member ${member.id}`);
      }
      
      const { data: subscriber } = await supabase
        .from("subscribers")
        .select("id, mautic_id")
        .ilike("email", newEmail)
        .single();
      
      if (subscriber && !subscriber.mautic_id) {
        await supabase
          .from("subscribers")
          .update({ mautic_id: mauticId })
          .eq("id", subscriber.id);
        console.log(`Linked mautic_id ${mauticId} to subscriber ${subscriber.id}`);
      }
    }
    
    return;
  }

  console.log(`Email changed in Mautic from ${oldEmail} to ${newEmail}`);

  // Update members table by mautic_id
  const { data: memberToUpdate, error: memberFetchError } = await supabase
    .from("members")
    .select("id, email")
    .eq("mautic_id", mauticId)
    .single();

  if (memberToUpdate && !memberFetchError) {
    console.log(`Updating member ${memberToUpdate.id} email from ${memberToUpdate.email} to ${newEmail}`);
    
    const { error: memberUpdateError } = await supabase
      .from("members")
      .update({ email: newEmail })
      .eq("id", memberToUpdate.id);
    
    if (memberUpdateError) {
      console.error("Error updating member email:", memberUpdateError);
    } else {
      console.log(`Successfully updated member email`);
    }
    
    await logSync(
      "from_mautic",
      "member",
      memberToUpdate.id,
      mauticId,
      "email_update",
      { old_email: oldEmail, new_email: newEmail },
      { updated: !memberUpdateError },
      memberUpdateError?.message || null,
      !memberUpdateError
    );
  }

  // Update subscribers table by mautic_id
  const { data: subscriberToUpdate, error: subFetchError } = await supabase
    .from("subscribers")
    .select("id, email")
    .eq("mautic_id", mauticId)
    .single();

  if (subscriberToUpdate && !subFetchError) {
    console.log(`Updating subscriber ${subscriberToUpdate.id} email from ${subscriberToUpdate.email} to ${newEmail}`);
    
    const { error: subUpdateError } = await supabase
      .from("subscribers")
      .update({ email: newEmail })
      .eq("id", subscriberToUpdate.id);
    
    if (subUpdateError) {
      console.error("Error updating subscriber email:", subUpdateError);
    } else {
      console.log(`Successfully updated subscriber email`);
    }
    
    await logSync(
      "from_mautic",
      "subscriber",
      subscriberToUpdate.id,
      mauticId,
      "email_update",
      { old_email: oldEmail, new_email: newEmail },
      { updated: !subUpdateError },
      subUpdateError?.message || null,
      !subUpdateError
    );
  }

  console.log(`Completed email update processing`);
}

serve(async (req) => {
  console.log("=".repeat(60));
  console.log("MAUTIC WEBHOOK RECEIVED");
  console.log(`Method: ${req.method}`);
  console.log(`Time: ${new Date().toISOString()}`);
  console.log("=".repeat(60));

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    console.log(`Rejected: Method ${req.method} not allowed`);
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const rawBody = await req.text();
    const signature = req.headers.get("Webhook-Signature") || "";

    console.log(`Raw body length: ${rawBody.length} chars`);
    console.log(`Signature header present: ${!!signature}`);

    // Verify signature (optional but recommended)
    if (MAUTIC_WEBHOOK_SECRET) {
      const isValid = await verifySignature(rawBody, signature);
      if (!isValid) {
        console.error("Invalid webhook signature - rejecting request");
        
        await logSync(
          "from_mautic",
          "webhook",
          "auth_failed",
          null,
          "signature_invalid",
          { body_preview: rawBody.substring(0, 200) },
          null,
          "Invalid signature",
          false
        );
        
        return new Response("Invalid signature", { status: 401, headers: corsHeaders });
      }
      console.log("Signature verified successfully");
    } else {
      console.warn("MAUTIC_WEBHOOK_SECRET not set - skipping signature verification");
    }

    const payload = JSON.parse(rawBody);
    console.log("Parsed webhook payload:");
    console.log(JSON.stringify(payload, null, 2));

    // Track what events we processed
    const processedEvents: string[] = [];

    // Process different event types
    // Mautic sends events in format: { "mautic.event_name": [{ contact: {...}, ... }] }

    // Handle new contacts
    if (payload["mautic.lead_post_save_new"]) {
      console.log(`Processing ${payload["mautic.lead_post_save_new"].length} new contact event(s)`);
      
      for (const event of payload["mautic.lead_post_save_new"]) {
        try {
          await handleNewContact(event.contact);
          processedEvents.push("lead_post_save_new");
        } catch (err) {
          console.error("Error handling new contact:", err);
        }
      }
    }

    // Handle contact updates
    if (payload["mautic.lead_post_save_update"]) {
      console.log(`Processing ${payload["mautic.lead_post_save_update"].length} contact update event(s)`);
      
      for (const event of payload["mautic.lead_post_save_update"]) {
        try {
          await handleContactUpdate(event.contact, event.old_contact);
          processedEvents.push("lead_post_save_update");
        } catch (err) {
          console.error("Error handling contact update:", err);
        }
      }
    }

    // Handle channel subscription changes (unsubscribes/DNC)
    if (payload["mautic.lead_channel_subscription_changed"]) {
      console.log(`Processing ${payload["mautic.lead_channel_subscription_changed"].length} subscription change event(s)`);
      
      for (const event of payload["mautic.lead_channel_subscription_changed"]) {
        try {
          const contact = event.contact;
          const channel = event.channel || "email";
          const oldStatus = event.old_status;
          const newStatus = event.new_status;

          console.log(`Subscription change: ${oldStatus} -> ${newStatus} (channel: ${channel})`);

          // Check if this is an unsubscribe (contactable -> unsubscribed/bounced/manual)
          // Mautic uses: contactable, unsubscribed, bounced, manual
          if (newStatus !== "contactable") {
            await handleUnsubscribe(contact, channel, newStatus);
            processedEvents.push("lead_channel_subscription_changed");
          } else {
            console.log("Contact became contactable again - no action needed");
          }
        } catch (err) {
          console.error("Error handling subscription change:", err);
        }
      }
    }

    // Log the webhook receipt
    await logSync(
      "from_mautic",
      "webhook",
      "received",
      null,
      "webhook_received",
      payload,
      { processed_events: processedEvents },
      null,
      true
    );

    console.log("=".repeat(60));
    console.log("WEBHOOK PROCESSING COMPLETE");
    console.log(`Processed events: ${processedEvents.join(", ") || "none"}`);
    console.log("=".repeat(60));

    return new Response(
      JSON.stringify({ 
        success: true,
        processed_events: processedEvents,
        message: `Processed ${processedEvents.length} event(s)`
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("=".repeat(60));
    console.error("WEBHOOK PROCESSING ERROR:");
    console.error(err);
    console.error("=".repeat(60));
    
    const errorMessage = err instanceof Error ? err.message : "Unknown error";
    
    await logSync(
      "from_mautic",
      "webhook",
      "error",
      null,
      "webhook_error",
      null,
      null,
      errorMessage,
      false
    );
    
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});