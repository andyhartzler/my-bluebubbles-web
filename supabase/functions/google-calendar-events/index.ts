// supabase/functions/google-calendar-events/index.ts
// Google Calendar CRUD via service account.
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS"
};
// Google Calendar API base URL
const CALENDAR_API_BASE = "https://www.googleapis.com/calendar/v3";
// Default calendar ID from environment
const DEFAULT_CALENDAR_ID = Deno.env.get("MOYD_CALENDAR_ID") || "c_6592cac54ba266ece6da65d53f941b3cfa7a465d63cd569e745d3980fdba7a23@group.calendar.google.com";

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

/**
 * Parse the service account JSON from environment
 */ function getServiceAccountCredentials() {
  const serviceAccountJson = Deno.env.get("SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    throw new Error("Missing SERVICE_ACCOUNT_JSON secret");
  }
  try {
    const credentials = JSON.parse(serviceAccountJson);
    if (!credentials.client_email || !credentials.private_key) {
      throw new Error("SERVICE_ACCOUNT_JSON missing required fields (client_email, private_key)");
    }
    return {
      client_email: credentials.client_email,
      private_key: credentials.private_key
    };
  } catch (e) {
    if (e.message.includes("missing required fields")) {
      throw e;
    }
    throw new Error(`Failed to parse SERVICE_ACCOUNT_JSON: ${e.message}`);
  }
}
/**
 * Generate a Google OAuth2 access token using service account credentials
 */ async function getAccessToken() {
  const { client_email, private_key } = getServiceAccountCredentials();
  // Parse the private key (handle escaped newlines)
  const privateKeyFormatted = private_key.replace(/\\n/g, "\n");
  // Import the private key
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKeyFormatted.replace(pemHeader, "").replace(pemFooter, "").replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c)=>c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey("pkcs8", binaryKey, {
    name: "RSASSA-PKCS1-v1_5",
    hash: "SHA-256"
  }, false, [
    "sign"
  ]);
  // Create JWT for Google OAuth
  const now = Math.floor(Date.now() / 1000);
  const jwt = await create({
    alg: "RS256",
    typ: "JWT"
  }, {
    iss: client_email,
    scope: "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600
  }, cryptoKey);
  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt
    })
  });
  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    console.error("Token exchange failed:", error);
    throw new Error(`Failed to get access token: ${error}`);
  }
  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}
/**
 * Make an authenticated request to Google Calendar API
 */ async function calendarApiRequest(endpoint, method = "GET", body) {
  const accessToken = await getAccessToken();
  const options = {
    method,
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json"
    }
  };
  if (body) {
    options.body = JSON.stringify(body);
  }
  const response = await fetch(`${CALENDAR_API_BASE}${endpoint}`, options);
  return response;
}
/**
 * List calendar events
 */ async function listEvents(params) {
  const calendarId = encodeURIComponent(params.calendarId || DEFAULT_CALENDAR_ID);
  const queryParams = new URLSearchParams();
  if (params.timeMin) queryParams.set("timeMin", params.timeMin);
  if (params.timeMax) queryParams.set("timeMax", params.timeMax);
  if (params.maxResults) queryParams.set("maxResults", params.maxResults.toString());
  if (params.singleEvents !== undefined) queryParams.set("singleEvents", params.singleEvents.toString());
  if (params.orderBy) queryParams.set("orderBy", params.orderBy);
  if (params.q) queryParams.set("q", params.q);
  const response = await calendarApiRequest(`/calendars/${calendarId}/events?${queryParams.toString()}`);
  if (!response.ok) {
    const error = await response.text();
    console.error("List events failed:", error);
    throw new Error(`Failed to list events: ${error}`);
  }
  return response.json();
}
/**
 * Create a calendar event
 */ async function createEvent(params) {
  const calendarId = encodeURIComponent(params.calendarId || DEFAULT_CALENDAR_ID);
  let eventData = {
    ...params.event
  };
  // If creating a Zoom meeting, add conferenceData
  if (params.createZoomMeeting) {
    try {
      const zoomMeeting = await createZoomMeeting({
        topic: params.event.summary,
        start_time: params.event.start.dateTime || params.event.start.date,
        duration: calculateDuration(params.event.start, params.event.end),
        agenda: params.event.description
      });
      // Add Zoom link to description
      const zoomInfo = `\n\n🎥 Zoom Meeting\nJoin: ${zoomMeeting.join_url}\nMeeting ID: ${zoomMeeting.id}\nPasscode: ${zoomMeeting.password || 'None'}`;
      eventData.description = (eventData.description || "") + zoomInfo;
      eventData.location = zoomMeeting.join_url;
    } catch (error) {
      console.error("Failed to create Zoom meeting:", error);
    // Continue creating event without Zoom
    }
  }
  const queryParams = new URLSearchParams();
  queryParams.set("sendUpdates", params.sendUpdates || "all");
  const response = await calendarApiRequest(`/calendars/${calendarId}/events?${queryParams.toString()}`, "POST", eventData);
  if (!response.ok) {
    const error = await response.text();
    console.error("Create event failed:", error);
    throw new Error(`Failed to create event: ${error}`);
  }
  return response.json();
}
/**
 * Update a calendar event
 */ async function updateEvent(params) {
  const calendarId = encodeURIComponent(params.calendarId || DEFAULT_CALENDAR_ID);
  const eventId = encodeURIComponent(params.eventId);
  const queryParams = new URLSearchParams();
  queryParams.set("sendUpdates", params.sendUpdates || "all");
  const response = await calendarApiRequest(`/calendars/${calendarId}/events/${eventId}?${queryParams.toString()}`, "PATCH", params.updates);
  if (!response.ok) {
    const error = await response.text();
    console.error("Update event failed:", error);
    throw new Error(`Failed to update event: ${error}`);
  }
  return response.json();
}
/**
 * Delete a calendar event
 */ async function deleteEvent(params) {
  const calendarId = encodeURIComponent(params.calendarId || DEFAULT_CALENDAR_ID);
  const eventId = encodeURIComponent(params.eventId);
  const queryParams = new URLSearchParams();
  queryParams.set("sendUpdates", params.sendUpdates || "all");
  const response = await calendarApiRequest(`/calendars/${calendarId}/events/${eventId}?${queryParams.toString()}`, "DELETE");
  if (!response.ok && response.status !== 204) {
    const error = await response.text();
    console.error("Delete event failed:", error);
    throw new Error(`Failed to delete event: ${error}`);
  }
  return {
    success: true
  };
}
/**
 * Get a single calendar event
 */ async function getEvent(params) {
  const calendarId = encodeURIComponent(params.calendarId || DEFAULT_CALENDAR_ID);
  const eventId = encodeURIComponent(params.eventId);
  const response = await calendarApiRequest(`/calendars/${calendarId}/events/${eventId}`);
  if (!response.ok) {
    const error = await response.text();
    console.error("Get event failed:", error);
    throw new Error(`Failed to get event: ${error}`);
  }
  return response.json();
}
/**
 * Create a Zoom meeting (optional feature)
 */ async function createZoomMeeting(params) {
  const accountId = Deno.env.get("ZOOM_ACCOUNT_ID");
  const clientId = Deno.env.get("ZOOM_CLIENT_ID");
  const clientSecret = Deno.env.get("ZOOM_CLIENT_SECRET");
  if (!accountId || !clientId || !clientSecret) {
    throw new Error("Zoom credentials not configured");
  }
  // Get Zoom access token using Server-to-Server OAuth
  const authString = btoa(`${clientId}:${clientSecret}`);
  const tokenResponse = await fetch(`https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${accountId}`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${authString}`,
      "Content-Type": "application/x-www-form-urlencoded"
    }
  });
  if (!tokenResponse.ok) {
    throw new Error("Failed to get Zoom access token");
  }
  const tokenData = await tokenResponse.json();
  const accessToken = tokenData.access_token;
  // Create the meeting
  const meetingResponse = await fetch("https://api.zoom.us/v2/users/me/meetings", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      topic: params.topic,
      type: 2,
      start_time: params.start_time,
      duration: params.duration || 60,
      agenda: params.agenda,
      settings: {
        host_video: true,
        participant_video: true,
        join_before_host: true,
        mute_upon_entry: false,
        waiting_room: false,
        auto_recording: "none"
      }
    })
  });
  if (!meetingResponse.ok) {
    const error = await meetingResponse.text();
    throw new Error(`Failed to create Zoom meeting: ${error}`);
  }
  return meetingResponse.json();
}
/**
 * Calculate duration in minutes between start and end
 */ function calculateDuration(start, end) {
  const startTime = new Date(start.dateTime || start.date || Date.now());
  const endTime = new Date(end.dateTime || end.date || Date.now());
  return Math.round((endTime.getTime() - startTime.getTime()) / (1000 * 60));
}
/**
 * Main handler
 */ serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  const gate = await requireStaffUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const body = await req.json();
    const { action, ...params } = body;
    let result;
    switch(action){
      case "list":
        result = await listEvents(params);
        break;
      case "get":
        result = {
          event: await getEvent(params)
        };
        break;
      case "create":
        result = {
          event: await createEvent(params)
        };
        break;
      case "update":
        result = {
          event: await updateEvent(params)
        };
        break;
      case "delete":
        result = await deleteEvent(params);
        break;
      default:
        return new Response(JSON.stringify({
          error: `Unknown action: ${action}`
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
    }
    // Audit log (non-blocking)
    supabaseAdmin.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:google-calendar-events",
      row_id: null,
      context: {
        event: "google-calendar-events",
        calendar_action: action,
        event_id: params.eventId ?? null
      }
    }).then(() => {}).catch((e) => console.error("[google-calendar-events] audit_log insert failed:", e));
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Calendar API error:", error);
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
