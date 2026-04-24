// supabase/functions/zoom-update-meeting/index.ts
// Updates an existing Zoom meeting
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

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
    // Validate required field
    if (!body.zoom_meeting_id) {
      return new Response(JSON.stringify({
        error: "Missing required field: zoom_meeting_id"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const accessToken = await getZoomAccessToken();
    // Build update payload - only include fields that are provided
    const updatePayload = {};
    if (body.title !== undefined) {
      updatePayload.topic = body.title;
    }
    if (body.description !== undefined) {
      updatePayload.agenda = body.description;
    }
    if (body.start_time !== undefined) {
      updatePayload.start_time = body.start_time;
    }
    if (body.duration !== undefined) {
      updatePayload.duration = body.duration;
    }
    if (body.timezone !== undefined) {
      updatePayload.timezone = body.timezone;
    }
    // Update meeting
    const response = await fetch(`https://api.zoom.us/v2/meetings/${body.zoom_meeting_id}`, {
      method: "PATCH",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(updatePayload)
    });
    // Audit log (non-blocking). Fired regardless of Zoom API outcome below; actor is staff-verified.
    const auditContext = {
      event: "zoom-update-meeting",
      zoom_meeting_id: body.zoom_meeting_id,
      fields_updated: Object.keys(updatePayload)
    };
    supabaseAdmin.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:zoom-update-meeting",
      row_id: null,
      context: auditContext
    }).then(() => {}).catch((e) => console.error("[zoom-update-meeting] audit_log insert failed:", e));
    // Zoom returns 204 No Content on successful update
    if (response.status === 204) {
      return new Response(JSON.stringify({
        success: true,
        message: "Meeting updated successfully",
        zoom_meeting_id: body.zoom_meeting_id
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    if (!response.ok) {
      const error = await response.text();
      console.error("Zoom API error:", error);
      try {
        const errorJson = JSON.parse(error);
        if (errorJson.code === 3001) {
          throw new Error("Meeting not found. It may have been deleted.");
        }
        throw new Error(`Zoom API error: ${errorJson.message || error}`);
      } catch (e) {
        if (e.message.includes("Meeting not found")) throw e;
        throw new Error(`Zoom API error: ${error}`);
      }
    }
    return new Response(JSON.stringify({
      success: true,
      zoom_meeting_id: body.zoom_meeting_id
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error updating Zoom meeting:", error);
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
