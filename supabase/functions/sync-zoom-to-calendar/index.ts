import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-zm-signature, x-zm-request-timestamp",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const ZOOM_WEBHOOK_SECRET_TOKEN = Deno.env.get("ZOOM_WEBHOOK_SECRET_TOKEN")!;
const CALENDAR_ID = Deno.env.get("MOYD_CALENDAR_ID") || 
  "c_6592cac54ba266ece6da65d53f941b3cfa7a465d63cd569e745d3980fdba7a23@group.calendar.google.com";

/**
 * Handle Zoom's URL validation challenge (CRC)
 * Zoom sends this when you first add the webhook URL
 */
async function handleUrlValidation(plainToken: string): Promise<Response> {
  // Create HMAC SHA-256 hash of the plainToken using the secret token
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(ZOOM_WEBHOOK_SECRET_TOKEN),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(plainToken)
  );
  
  // Convert to hex string
  const hashArray = Array.from(new Uint8Array(signature));
  const encryptedToken = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  console.log("CRC validation - responding with encrypted token");
  
  return new Response(
    JSON.stringify({
      plainToken: plainToken,
      encryptedToken: encryptedToken,
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    }
  );
}

/**
 * Verify the webhook signature from Zoom
 * This ensures the webhook is actually from Zoom
 */
async function verifyWebhookSignature(
  requestBody: string,
  signature: string,
  timestamp: string
): Promise<boolean> {
  if (!signature || !timestamp) {
    console.error("Missing signature or timestamp headers");
    return false;
  }

  // Construct the message: v0:{timestamp}:{requestBody}
  const message = `v0:${timestamp}:${requestBody}`;
  
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(ZOOM_WEBHOOK_SECRET_TOKEN),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  
  const signatureBytes = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message)
  );
  
  // Convert to hex string
  const hashArray = Array.from(new Uint8Array(signatureBytes));
  const expectedSignature = "v0=" + hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  // Compare signatures (timing-safe comparison would be ideal, but this works)
  const isValid = signature === expectedSignature;
  
  if (!isValid) {
    console.error("Signature mismatch:", { expected: expectedSignature, received: signature });
  }
  
  return isValid;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    // Get the raw body for signature verification
    const rawBody = await req.text();
    const body = JSON.parse(rawBody);
    
    // Check if this is a URL validation challenge (CRC)
    if (body.event === "endpoint.url_validation") {
      const plainToken = body.payload?.plainToken;
      if (plainToken) {
        return await handleUrlValidation(plainToken);
      }
    }

    // For all other events, verify the signature
    const signature = req.headers.get("x-zm-signature");
    const timestamp = req.headers.get("x-zm-request-timestamp");
    
    if (signature && timestamp) {
      const isValid = await verifyWebhookSignature(rawBody, signature, timestamp);
      if (!isValid) {
        console.error("Invalid webhook signature - rejecting request");
        return new Response(
          JSON.stringify({ error: "Invalid signature" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      console.warn("No signature headers present - consider rejecting in production");
      // For now, allow unsigned requests during testing
      // In production, you may want to return 401 here
    }
    
    const event = body.event;
    const payload = body.payload;

    console.log(`Received Zoom webhook: ${event}`);

    if (event === "meeting.created" || event === "meeting.updated") {
      const meeting = payload.object;
      
      console.log(`Processing ${event} for meeting: ${meeting.topic}`);
      
      // Create/update calendar event via the google-calendar-events function
      const response = await supabase.functions.invoke("google-calendar-events", {
        body: {
          action: event === "meeting.created" ? "create" : "update",
          calendarId: CALENDAR_ID,
          event: {
            summary: meeting.topic,
            description: `🎥 Zoom Meeting\n\nJoin: ${meeting.join_url}\nMeeting ID: ${meeting.id}\n\n${meeting.agenda || ""}`,
            location: meeting.join_url,
            start: {
              dateTime: meeting.start_time,
              timeZone: meeting.timezone || "America/Chicago",
            },
            end: {
              dateTime: new Date(
                new Date(meeting.start_time).getTime() + (meeting.duration || 60) * 60000
              ).toISOString(),
              timeZone: meeting.timezone || "America/Chicago",
            },
          },
          ...(event === "meeting.updated" && { eventId: `zoom_${meeting.id}` }),
        },
      });

      if (response.error) {
        console.error("Failed to sync to calendar:", response.error);
        throw response.error;
      }

      console.log(`Successfully synced meeting "${meeting.topic}" to calendar`);

      return new Response(
        JSON.stringify({ success: true, message: `Meeting ${event === "meeting.created" ? "created" : "updated"} in calendar` }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Handle meeting started (optional - could update calendar event)
    if (event === "meeting.started") {
      console.log(`Meeting started: ${payload.object.topic}`);
      return new Response(
        JSON.stringify({ success: true, message: "Meeting started notification received" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Handle meeting ended (optional - could update calendar event)
    if (event === "meeting.ended") {
      console.log(`Meeting ended: ${payload.object.topic}`);
      return new Response(
        JSON.stringify({ success: true, message: "Meeting ended notification received" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Handle meeting deleted
    if (event === "meeting.deleted") {
      const meeting = payload.object;
      console.log(`Meeting deleted: ${meeting.topic}`);
      
      // Note: To delete from calendar, you'd need to store a mapping between 
      // Zoom meeting IDs and Google Calendar event IDs
      // For now, we just acknowledge the deletion
      
      return new Response(
        JSON.stringify({ success: true, message: "Meeting deletion noted" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Unknown event type - acknowledge but don't process
    console.log(`Unhandled event type: ${event}`);
    return new Response(
      JSON.stringify({ success: true, message: `Event type ${event} acknowledged` }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Zoom webhook error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});