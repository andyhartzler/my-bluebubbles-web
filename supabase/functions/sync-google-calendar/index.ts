import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const CALENDAR_API_BASE = "https://www.googleapis.com/calendar/v3";
const DEFAULT_CALENDAR_ID = Deno.env.get("MOYD_CALENDAR_ID") || "c_6592cac54ba266ece6da65d53f941b3cfa7a465d63cd569e745d3980fdba7a23@group.calendar.google.com";

// Wave 2 access-audit 2026-04-24: fn is invoked from Dart with the caller's
// user JWT (mobile_calendar_view.dart + committee_calendar_widget.dart). Gate
// on authenticated user; anyone authenticated may trigger a calendar sync.
async function requireAuthenticatedUser(req) {
  // Cron path: the hourly pg_cron job can't present a user JWT, so it
  // authenticates with a shared secret instead (same pattern as
  // send-endorsement-thankyou's x-webhook-secret).
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (cronSecret && req.headers.get("x-cron-secret") === cronSecret) {
    return { userId: "cron" };
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({
        error: "Missing Authorization header"
      }), {
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
      error: new Response(JSON.stringify({
        error: "Invalid or expired JWT"
      }), {
        status: 401,
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
    return {
      client_email: credentials.client_email,
      private_key: credentials.private_key
    };
  } catch (e) {
    throw new Error(`Failed to parse SERVICE_ACCOUNT_JSON: ${e.message}`);
  }
}
/**
 * Generate a Google OAuth2 access token
 */ async function getAccessToken() {
  const { client_email, private_key } = getServiceAccountCredentials();
  const privateKeyFormatted = private_key.replace(/\\n/g, "\n");
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
  const now = Math.floor(Date.now() / 1000);
  const jwt = await create({
    alg: "RS256",
    typ: "JWT"
  }, {
    iss: client_email,
    scope: "https://www.googleapis.com/auth/calendar.readonly",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600
  }, cryptoKey);
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
    throw new Error(`Failed to get access token: ${error}`);
  }
  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}
/**
 * Fetch events from Google Calendar
 */ async function fetchGoogleCalendarEvents(calendarId, timeMin, timeMax) {
  const accessToken = await getAccessToken();
  const params = new URLSearchParams({
    timeMin,
    timeMax,
    singleEvents: "true",
    orderBy: "startTime",
    maxResults: "2500"
  });
  const url = `${CALENDAR_API_BASE}/calendars/${encodeURIComponent(calendarId)}/events?${params}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json"
    }
  });
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Calendar API error: ${response.status} - ${error}`);
  }
  const data = await response.json();
  return data.items || [];
}
/**
 * Parse a Google Calendar event into our schema
 */ function parseGoogleEvent(event, calendarId) {
  // Handle all-day vs timed events
  const isAllDay = !!event.start?.date;
  const startTime = event.start?.dateTime || event.start?.date + "T00:00:00Z";
  const endTime = event.end?.dateTime || event.end?.date + "T00:00:00Z";
  // Parse location
  const location = event.location || null;
  // Extract attendees
  const attendees = (event.attendees || []).map((a)=>({
      email: a.email,
      displayName: a.displayName || a.email,
      responseStatus: a.responseStatus || "needsAction"
    }));
  // Column names below must match public.calendar_events exactly; the mapper
  // previously wrote google_calendar_id/visibility/recurrence/html_link/
  // last_synced_at, none of which exist, so every event errored on write.
  return {
    google_event_id: event.id,
    calendar_id: calendarId,
    title: event.summary || "Untitled Event",
    description: event.description || null,
    location,
    start_time: startTime,
    end_time: endTime,
    is_all_day: isAllDay,
    status: event.status || "confirmed",
    attendees: attendees.length > 0 ? attendees : null,
    organizer_email: event.organizer?.email || null,
    is_recurring: !!(event.recurrence && event.recurrence.length),
    recurrence_rule: event.recurrence && event.recurrence.length ? event.recurrence.join("\n") : null,
    synced_at: new Date().toISOString()
  };
}
/**
 * Sync events to database
 */ async function syncEventsToDatabase(events) {
  let inserted = 0;
  let updated = 0;
  let errors = 0;
  for (const event of events){
    try {
      const { data: existing } = await supabase.from("calendar_events").select("id").eq("google_event_id", event.google_event_id).maybeSingle();
      if (existing) {
        const { error } = await supabase.from("calendar_events").update(event).eq("google_event_id", event.google_event_id);
        if (error) {
          console.error(`Error updating event ${event.google_event_id}:`, error);
          errors++;
        } else {
          updated++;
        }
      } else {
        const { error } = await supabase.from("calendar_events").insert(event);
        if (error) {
          console.error(`Error inserting event ${event.google_event_id}:`, error);
          errors++;
        } else {
          inserted++;
        }
      }
    } catch (e) {
      console.error(`Error syncing event ${event.google_event_id}:`, e);
      errors++;
    }
  }
  return {
    inserted,
    updated,
    errors
  };
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  const gate = await requireAuthenticatedUser(req);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  try {
    const body = await req.json().catch(()=>({}));
    // Default to syncing 6 months back and 12 months forward
    const now = new Date();
    const timeMin = body.timeMin || new Date(now.getFullYear(), now.getMonth() - 6, 1).toISOString();
    const timeMax = body.timeMax || new Date(now.getFullYear(), now.getMonth() + 12, 0).toISOString();
    const calendarId = body.calendarId || DEFAULT_CALENDAR_ID;
    console.log(`Syncing calendar ${calendarId} from ${timeMin} to ${timeMax}`);
    // Fetch events from Google Calendar
    const googleEvents = await fetchGoogleCalendarEvents(calendarId, timeMin, timeMax);
    console.log(`Fetched ${googleEvents.length} events from Google Calendar`);
    // Parse events
    const parsedEvents = googleEvents.map((e)=>parseGoogleEvent(e, calendarId));
    // Sync to database
    const results = await syncEventsToDatabase(parsedEvents);
    console.log(`Sync complete: ${results.inserted} inserted, ${results.updated} updated`);
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:sync-google-calendar",
      row_id: null,
      context: {
        event: "sync-google-calendar",
        calendar_id: calendarId,
        time_min: timeMin,
        time_max: timeMax,
        fetched: googleEvents.length,
        inserted: results.inserted,
        updated: results.updated,
        errors: results.errors
      }
    }).then(() => {}).catch((e) => console.error("[sync-google-calendar] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      message: `Synced ${googleEvents.length} events`,
      results,
      timeRange: {
        timeMin,
        timeMax
      }
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Sync error:", error);
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
