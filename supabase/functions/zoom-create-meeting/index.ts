// supabase/functions/zoom-create-meeting/index.ts
// Creates a Zoom meeting using the organization's licensed host
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// ============================================================================
// CONFIGURATION: Update this to your licensed Zoom user's email
// ============================================================================
const DEFAULT_HOST_EMAIL = "info@moyoungdemocrats.org";
// ============================================================================
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

// Wave 4 access-audit 2026-04-24: require user JWT + is_staff() gate.
async function requireStaffUser(req) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } }
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — staff access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { userId: userData.user.id };
}

// Get Zoom access token using Server-to-Server OAuth
async function getZoomAccessToken() {
  const clientId = Deno.env.get("ZOOM_CLIENT_ID");
  const clientSecret = Deno.env.get("ZOOM_CLIENT_SECRET");
  const accountId = Deno.env.get("ZOOM_ACCOUNT_ID");
  const credentials = btoa(`${clientId}:${clientSecret}`);
  const response = await fetch("https://zoom.us/oauth/token", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: `grant_type=account_credentials&account_id=${accountId}`
  });
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to get Zoom access token: ${error}`);
  }
  const data = await response.json();
  return data.access_token;
}
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({
      error: "Method not allowed"
    }), {
      status: 405,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const body = await req.json();
    // Validate required fields
    if (!body.title || !body.start_time || !body.duration) {
      return new Response(JSON.stringify({
        error: "Missing required fields: title, start_time, duration"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const accessToken = await getZoomAccessToken();
    // Create meeting payload
    const meetingPayload = {
      topic: body.title,
      type: 2,
      start_time: body.start_time,
      duration: body.duration,
      timezone: body.timezone || "America/Chicago",
      agenda: body.description || "",
      settings: {
        host_video: true,
        participant_video: true,
        join_before_host: false,
        mute_upon_entry: true,
        waiting_room: true,
        meeting_authentication: false,
        auto_recording: "none"
      }
    };
    // Create meeting for the default licensed host
    const response = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(DEFAULT_HOST_EMAIL)}/meetings`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(meetingPayload)
    });
    if (!response.ok) {
      const error = await response.text();
      console.error("Zoom API error:", error);
      try {
        const errorJson = JSON.parse(error);
        if (errorJson.code === 1001) {
          throw new Error(`Host user not found. Ensure ${DEFAULT_HOST_EMAIL} is a licensed user on your Zoom account.`);
        }
        throw new Error(`Zoom API error: ${errorJson.message || error}`);
      } catch (e) {
        if (e.message.includes("Host user not found")) throw e;
        throw new Error(`Zoom API error: ${error}`);
      }
    }
    const meeting = await response.json();
    // Audit log (non-blocking)
    supabaseAdmin.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:zoom-create-meeting",
      row_id: null,
      context: {
        event: "zoom-create-meeting",
        zoom_meeting_id: meeting.id,
        topic: body.title,
        start_time: body.start_time,
        duration: body.duration
      }
    }).then(() => {}).catch((e) => console.error("[zoom-create-meeting] audit_log insert failed:", e));
    // Return the meeting details
    return new Response(JSON.stringify({
      zoom_meeting_id: meeting.id,
      join_url: meeting.join_url,
      start_url: meeting.start_url,
      password: meeting.password || null,
      host_email: meeting.host_email,
      host_name: "Missouri Young Democrats",
      topic: meeting.topic,
      start_time: meeting.start_time,
      duration: meeting.duration,
      timezone: meeting.timezone
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error creating Zoom meeting:", error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
