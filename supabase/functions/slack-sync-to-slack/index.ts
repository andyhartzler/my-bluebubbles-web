// ============================================
// EDGE FUNCTION: slack-sync-to-slack
// Processes pending invites/removals from Supabase to Slack
// Triggered periodically or manually
// ============================================
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};

async function requireAuthorized(req, supabaseUrl, supabaseAnonKey) {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { actorId: null, actorRole: "service_role" };
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header or x-cron-secret" }), {
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
  return { actorId: userData.user.id, actorRole: "authenticated" };
}
// Invite user to Slack channel
async function inviteToChannel(channelId, userId, slackToken) {
  const response = await fetch("https://slack.com/api/conversations.invite", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${slackToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      channel: channelId,
      users: userId
    })
  });
  const data = await response.json();
  if (!data.ok) {
    // already_in_channel is not an error
    if (data.error === "already_in_channel") {
      return {
        success: true,
        already_in: true
      };
    }
    console.error("Failed to invite to channel:", data.error);
    return {
      success: false,
      error: data.error
    };
  }
  return {
    success: true
  };
}
// Remove user from Slack channel
async function removeFromChannel(channelId, userId, slackToken) {
  const response = await fetch("https://slack.com/api/conversations.kick", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${slackToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      channel: channelId,
      user: userId
    })
  });
  const data = await response.json();
  if (!data.ok) {
    // not_in_channel is not an error
    if (data.error === "not_in_channel") {
      return {
        success: true,
        not_in: true
      };
    }
    console.error("Failed to remove from channel:", data.error);
    return {
      success: false,
      error: data.error
    };
  }
  return {
    success: true
  };
}
// Process pending membership changes
async function processPendingChanges(supabase, slackToken) {
  // Get all pending changes (where success = false)
  const { data: pendingChanges, error: fetchError } = await supabase.from("slack_channel_membership_log").select("*").eq("success", false).eq("source", "supabase_trigger").order("created_at", {
    ascending: true
  }).limit(50); // Process in batches
  if (fetchError) {
    console.error("Failed to fetch pending changes:", fetchError);
    return {
      processed: 0,
      errors: 0
    };
  }
  if (!pendingChanges || pendingChanges.length === 0) {
    console.log("No pending changes to process");
    return {
      processed: 0,
      errors: 0
    };
  }
  console.log(`Processing ${pendingChanges.length} pending changes`);
  let processed = 0;
  let errors = 0;
  for (const change of pendingChanges){
    try {
      let result;
      if (change.action === "invited") {
        result = await inviteToChannel(change.slack_channel_id, change.slack_user_id, slackToken);
      } else if (change.action === "removed") {
        result = await removeFromChannel(change.slack_channel_id, change.slack_user_id, slackToken);
      } else {
        console.error("Unknown action:", change.action);
        continue;
      }
      // Update the log entry
      await supabase.from("slack_channel_membership_log").update({
        success: result.success,
        error_message: result.error || null,
        metadata: {
          ...change.metadata,
          processed_at: new Date().toISOString(),
          already_in: result.already_in || false,
          not_in: result.not_in || false
        }
      }).eq("id", change.id);
      if (result.success) {
        processed++;
      } else {
        errors++;
      }
      // Rate limiting - wait 100ms between requests
      await new Promise((resolve)=>setTimeout(resolve, 100));
    } catch (error) {
      console.error("Error processing change:", error);
      errors++;
      // Update log with error
      await supabase.from("slack_channel_membership_log").update({
        success: false,
        error_message: error.message
      }).eq("id", change.id);
    }
  }
  return {
    processed,
    errors,
    total: pendingChanges.length
  };
}
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  const supabaseUrlEnv = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const gate = await requireAuthorized(req, supabaseUrlEnv, supabaseAnonKey);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  try {
    const slackToken = Deno.env.get("SLACK_BOT_TOKEN");
    const supabaseUrl = supabaseUrlEnv;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!slackToken || !supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing required environment variables");
    }
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Process pending changes
    const results = await processPendingChanges(supabase, slackToken);
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:slack-sync-to-slack",
      row_id: null,
      context: {
        event: "slack-sync-to-slack",
        processed: results.processed,
        errors: results.errors,
        total: results.total ?? null
      }
    }).then(() => {}).catch((e) => console.error("[slack-sync-to-slack] audit_log insert failed:", e));
    return new Response(JSON.stringify({
      success: true,
      message: `Processed ${results.processed} changes, ${results.errors} errors`,
      ...results
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error in slack-sync-to-slack:", error);
    return new Response(JSON.stringify({
      success: false,
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
