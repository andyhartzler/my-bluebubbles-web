// ============================================
// EDGE FUNCTION: slack-member-messages (ENHANCED)
// Get all Slack messages for a specific member
// ============================================
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleCors } from "../_shared/cors.ts";
// Kept for the non-preflight responses below. Access-Control-Allow-Headers is
// only read by the browser on the preflight, which handleCors now answers by
// reflecting access-control-request-headers, so this list no longer gates
// anything. Do not add sentry-trace or baggage here by hand: a hand-maintained
// list is the defect this is fixing.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

async function requireStaffUser(req, supabaseUrl, supabaseAnonKey) {
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

serve(async (req)=>{
  const _cors = handleCors(req);
  if (_cors) return _cors;
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const gate = await requireStaffUser(req, supabaseUrl, supabaseAnonKey);
  if ("error" in gate) return gate.error;
  const actorId = gate.userId;
  const auditClient = createClient(supabaseUrl, supabaseServiceKey);
  try {
    console.log('=== NEW REQUEST ===');
    console.log('Method:', req.method);
    console.log('URL:', req.url);
    // Log all headers
    const headers = {};
    req.headers.forEach((value, key)=>{
      headers[key] = value;
    });
    console.log('Headers:', JSON.stringify(headers, null, 2));
    // Parse request body with extensive debugging
    let body = {};
    let rawText = '';
    try {
      rawText = await req.text();
      console.log('Raw body text:', rawText);
      console.log('Raw body length:', rawText.length);
      console.log('Raw body bytes:', new TextEncoder().encode(rawText).length);
      if (rawText) {
        body = JSON.parse(rawText);
        console.log('Parsed body:', JSON.stringify(body, null, 2));
        console.log('Body keys:', Object.keys(body));
        console.log('Body type:', typeof body);
      } else {
        console.log('Empty body received');
      }
    } catch (e) {
      console.error('Failed to parse request body:', e);
      console.error('Raw text that failed:', rawText);
      return new Response(JSON.stringify({
        success: false,
        error: "Invalid JSON in request body",
        details: e.message,
        raw_text: rawText
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Try multiple strategies to extract member_id
    let memberId = null;
    // Strategy 1: Direct access with underscore
    if (body.member_id) {
      memberId = String(body.member_id);
      console.log('Found member_id via strategy 1 (underscore):', memberId);
    }
    // Strategy 2: CamelCase
    if (!memberId && body.memberId) {
      memberId = String(body.memberId);
      console.log('Found member_id via strategy 2 (camelCase):', memberId);
    }
    // Strategy 3: Case-insensitive search
    if (!memberId) {
      for (const key of Object.keys(body)){
        if (key.toLowerCase() === 'member_id' || key.toLowerCase() === 'memberid') {
          memberId = String(body[key]);
          console.log(`Found member_id via strategy 3 (case-insensitive key: ${key}):`, memberId);
          break;
        }
      }
    }
    // Strategy 4: Check if body itself is the ID (edge case)
    if (!memberId && typeof body === 'string') {
      memberId = body;
      console.log('Found member_id via strategy 4 (body is string):', memberId);
    }
    // Strategy 5: Check nested structure
    if (!memberId && body.data && typeof body.data === 'object') {
      if (body.data.member_id) {
        memberId = String(body.data.member_id);
        console.log('Found member_id via strategy 5 (nested in data):', memberId);
      } else if (body.data.memberId) {
        memberId = String(body.data.memberId);
        console.log('Found member_id via strategy 5 (nested in data, camelCase):', memberId);
      }
    }
    console.log('Final extracted member_id:', memberId);
    console.log('Member ID is empty?', !memberId);
    console.log('Member ID length:', memberId?.length || 0);
    if (!memberId || memberId.trim() === '') {
      console.error('member_id is missing or empty after all strategies');
      console.error('Received body structure:', JSON.stringify(body, null, 2));
      return new Response(JSON.stringify({
        success: false,
        error: "member_id parameter is required",
        received_body: body,
        body_keys: Object.keys(body),
        raw_text: rawText,
        help: "Expected format: {\"member_id\": \"uuid-here\", \"limit\": 50}"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Trim whitespace just in case
    memberId = memberId.trim();
    const limit = parseInt(String(body.limit || body.LIMIT || '50'));
    const offset = parseInt(String(body.offset || body.OFFSET || '0'));
    console.log(`Fetching messages for member ${memberId}, limit ${limit}, offset ${offset}`);
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase environment variables");
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Fetch messages with channel info
    const { data: messages, error: messagesError } = await supabase.from("slack_messages").select(`
        *,
        slack_channel_committee_mapping!inner(
          slack_channel_id,
          slack_channel_name,
          committee_name
        )
      `).eq("member_id", memberId).order("posted_at", {
      ascending: false
    }).range(offset, offset + limit - 1);
    if (messagesError) {
      console.error('Error fetching messages:', messagesError);
      throw messagesError;
    }
    console.log(`Found ${messages?.length || 0} messages`);
    // Calculate statistics
    const stats = {
      total_messages: messages?.length || 0,
      channels_active_in: 0,
      latest_message: null,
      earliest_message: null
    };
    if (messages && messages.length > 0) {
      const uniqueChannels = new Set(messages.map((m)=>m.slack_channel_id));
      stats.channels_active_in = uniqueChannels.size;
      stats.latest_message = messages[0]?.posted_at;
      stats.earliest_message = messages[messages.length - 1]?.posted_at;
    }
    console.log('Returning success response');
    // Audit log (non-blocking)
    auditClient.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:slack-member-messages",
      row_id: null,
      context: {
        event: "slack-member-messages",
        member_id: memberId,
        total_messages: stats.total_messages
      }
    }).then(() => {}).catch((e) => console.error("[slack-member-messages] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      member_id: memberId,
      total_messages: stats.total_messages,
      messages: messages || [],
      statistics: stats
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error in slack-member-messages:", error);
    console.error("Error stack:", error.stack);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      stack: error.stack
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
