// ============================================
// EDGE FUNCTION: slack-archive-messages
// Backfill Slack message history for channels
// Beats the 90-day free plan limit!
// ============================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
// Fetch message history from a channel
async function fetchChannelHistory(channelId, slackToken, oldest, latest) {
  const messages = [];
  let cursor = "";
  let hasMore = true;
  while(hasMore){
    const params = new URLSearchParams({
      channel: channelId,
      limit: "200" // Max allowed by Slack
    });
    if (cursor) params.append("cursor", cursor);
    if (oldest) params.append("oldest", oldest);
    if (latest) params.append("latest", latest);
    const response = await fetch(`https://slack.com/api/conversations.history?${params}`, {
      headers: {
        "Authorization": `Bearer ${slackToken}`
      }
    });
    const data = await response.json();
    if (!data.ok) {
      console.error(`Failed to fetch history for ${channelId}:`, data.error);
      return messages;
    }
    messages.push(...data.messages);
    hasMore = data.has_more || false;
    cursor = data.response_metadata?.next_cursor || "";
    // Rate limiting - Slack recommends 1 request per second
    await new Promise((resolve)=>setTimeout(resolve, 1000));
  }
  return messages;
}
// Archive messages to database (with better error handling)
async function archiveMessages(messages, channelId, supabase) {
  let archived = 0;
  let errors = 0;
  const errorDetails = [];
  // Batch user lookups for efficiency
  const uniqueUserIds = [
    ...new Set(messages.map((m)=>m.user).filter(Boolean))
  ];
  const { data: userMappings } = await supabase.from("slack_user_mapping").select("slack_user_id, member_id").in("slack_user_id", uniqueUserIds);
  // Create lookup map
  const userMap = new Map(userMappings?.map((u)=>[
      u.slack_user_id,
      u.member_id
    ]) || []);
  for (const msg of messages){
    try {
      // Skip bot messages
      if (msg.bot_id) continue;
      // Get member_id from lookup map (much faster)
      const memberId = userMap.get(msg.user) || null;
      // Extract file info
      let files = null;
      if (msg.files && msg.files.length > 0) {
        files = msg.files.map((f)=>({
            id: f.id,
            name: f.name,
            url_private: f.url_private,
            mimetype: f.mimetype,
            size: f.size
          }));
      }
      // Extract reactions
      let reactions = null;
      if (msg.reactions) {
        reactions = msg.reactions.map((r)=>({
            name: r.name,
            count: r.count,
            users: r.users
          }));
      }
      // Convert timestamp to ISO format
      const postedAt = new Date(parseFloat(msg.ts) * 1000).toISOString();
      const editedAt = msg.edited ? new Date(parseFloat(msg.edited.ts) * 1000).toISOString() : null;
      // Insert message with proper conflict handling
      const { error } = await supabase.from("slack_messages").upsert({
        slack_message_ts: msg.ts,
        slack_channel_id: channelId,
        slack_user_id: msg.user,
        member_id: memberId,
        message_text: msg.text,
        message_type: msg.subtype || 'message',
        thread_ts: msg.thread_ts || null,
        has_files: msg.files && msg.files.length > 0 || false,
        files: files,
        reactions: reactions,
        posted_at: postedAt,
        edited_at: editedAt,
        raw_payload: msg
      }, {
        onConflict: "slack_channel_id,slack_message_ts",
        ignoreDuplicates: false // Update existing messages
      });
      if (error) {
        console.error("Error archiving message:", error);
        errors++;
        errorDetails.push({
          ts: msg.ts,
          error: error.message
        });
      } else {
        archived++;
      }
    } catch (error) {
      console.error("Error processing message:", error);
      errors++;
      errorDetails.push({
        ts: msg.ts,
        error: error.message
      });
    }
  }
  return {
    archived,
    errors,
    errorDetails: errorDetails.slice(0, 10) // Return first 10 errors for debugging
  };
}
// Update archive status
async function updateArchiveStatus(channelId, lastTs, totalArchived, supabase) {
  await supabase.from("slack_message_archive_status").upsert({
    slack_channel_id: channelId,
    last_archived_ts: lastTs,
    last_archive_date: new Date().toISOString(),
    total_messages_archived: totalArchived,
    archive_in_progress: false
  }, {
    onConflict: "slack_channel_id"
  });
}
// Wave 2 access-audit 2026-04-24: gate on authenticated user.
// This fn is invoked from Dart (slack_management_repository.dart) with the
// user's JWT via the anon client — must validate here.
async function requireAuthenticatedUser(req, supabaseUrl, supabaseAnonKey, supabaseServiceKey) {
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
  // Staff gate
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);
  const { data: memberRow } = await adminClient
    .from("members")
    .select("executive_committee")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (!memberRow?.executive_committee) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — executive_committee required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { userId: userData.user.id };
}
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    // Get environment variables
    const slackToken = Deno.env.get("SLACK_BOT_TOKEN");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!slackToken || !supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing required environment variables");
    }
    const gate = await requireAuthenticatedUser(req, supabaseUrl, supabaseAnonKey, supabaseServiceKey);
    if ("error" in gate) return gate.error;
    const actorId = gate.userId;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:slack-archive-messages",
      row_id: null,
      context: { event: "slack-archive-messages" }
    }).then(() => {}).catch((e) => console.error("[slack-archive-messages] audit_log insert failed:", e));
    // Parse request body
    const body = req.method === "POST" ? await req.json() : {};
    const specificChannel = body.channelId; // Optional: archive specific channel
    const daysBack = body.daysBack || 90; // How far back to go (default: 90 days)
    const incremental = body.incremental !== false; // Default: true (only new messages)
    console.log(`Archive settings - incremental: ${incremental}, daysBack: ${daysBack}`);
    // Get channels to archive
    let channelsToArchive = [];
    if (specificChannel) {
      // Archive specific channel
      const { data: channel } = await supabase.from("slack_channel_committee_mapping").select("*").eq("slack_channel_id", specificChannel).eq("is_active", true).eq("archive_messages", true).single();
      if (channel) {
        channelsToArchive = [
          channel
        ];
      } else {
        return new Response(JSON.stringify({
          success: false,
          error: `Channel ${specificChannel} not found or not configured for archiving`
        }), {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
    } else {
      // Archive all channels configured for archiving
      const { data: channels } = await supabase.from("slack_channel_committee_mapping").select("*").eq("is_active", true).eq("archive_messages", true);
      channelsToArchive = channels || [];
    }
    if (channelsToArchive.length === 0) {
      return new Response(JSON.stringify({
        success: false,
        error: "No channels configured for archiving"
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    console.log(`Found ${channelsToArchive.length} channels to archive`);
    const results = [];
    for (const channel of channelsToArchive){
      console.log(`\n=== Archiving channel: ${channel.slack_channel_name} ===`);
      // Mark as in progress
      await supabase.from("slack_message_archive_status").upsert({
        slack_channel_id: channel.slack_channel_id,
        archive_in_progress: true
      }, {
        onConflict: "slack_channel_id"
      });
      try {
        // Get last archived timestamp for incremental sync
        let oldest = null;
        if (!incremental) {
          // Full sync - go back X days
          const oldestDate = new Date();
          oldestDate.setDate(oldestDate.getDate() - daysBack);
          oldest = (oldestDate.getTime() / 1000).toString();
          console.log(`Full sync - going back ${daysBack} days to ${oldest}`);
        } else {
          // Incremental - get last archived timestamp
          const { data: status } = await supabase.from("slack_message_archive_status").select("last_archived_ts").eq("slack_channel_id", channel.slack_channel_id).single();
          oldest = status?.last_archived_ts || null;
          // If no previous archive, go back X days
          if (!oldest) {
            const oldestDate = new Date();
            oldestDate.setDate(oldestDate.getDate() - daysBack);
            oldest = (oldestDate.getTime() / 1000).toString();
            console.log(`First sync - going back ${daysBack} days to ${oldest}`);
          } else {
            console.log(`Incremental sync - fetching from ${oldest}`);
          }
        }
        // Fetch messages
        console.log(`Fetching messages from ${channel.slack_channel_id}...`);
        const messages = await fetchChannelHistory(channel.slack_channel_id, slackToken, oldest);
        console.log(`Fetched ${messages.length} messages from ${channel.slack_channel_name}`);
        // Archive messages
        const { archived, errors, errorDetails } = await archiveMessages(messages, channel.slack_channel_id, supabase);
        console.log(`Archived ${archived} messages, ${errors} errors`);
        // Update status
        if (messages.length > 0) {
          // Get most recent timestamp
          const latestTs = messages.reduce((max, msg)=>parseFloat(msg.ts) > parseFloat(max) ? msg.ts : max, messages[0].ts);
          await updateArchiveStatus(channel.slack_channel_id, latestTs, archived, supabase);
        } else {
          // No new messages
          await supabase.from("slack_message_archive_status").update({
            last_archive_date: new Date().toISOString(),
            archive_in_progress: false
          }).eq("slack_channel_id", channel.slack_channel_id);
        }
        results.push({
          channel: channel.slack_channel_name,
          channel_id: channel.slack_channel_id,
          messages_fetched: messages.length,
          messages_archived: archived,
          errors: errors,
          error_details: errorDetails
        });
      } catch (error) {
        console.error(`Error archiving ${channel.slack_channel_name}:`, error);
        // Mark as not in progress
        await supabase.from("slack_message_archive_status").update({
          archive_in_progress: false
        }).eq("slack_channel_id", channel.slack_channel_id);
        results.push({
          channel: channel.slack_channel_name,
          channel_id: channel.slack_channel_id,
          error: error.message
        });
      }
      // Rate limiting between channels
      await new Promise((resolve)=>setTimeout(resolve, 2000));
    }
    return new Response(JSON.stringify({
      success: true,
      timestamp: new Date().toISOString(),
      channels_processed: results.length,
      results: results
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error in slack-archive-messages:", error);
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
