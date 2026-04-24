import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
// Wave 2 access-audit 2026-04-24: gate on authenticated user (executive_committee).
async function requireStaffUser(req, supabaseUrl, supabaseAnonKey, supabaseServiceKey) {
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
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const gate = await requireStaffUser(req, supabaseUrl, supabaseAnonKey, supabaseServiceKey);
    if ("error" in gate) return gate.error;
    const actorId = gate.userId;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: "authenticated",
      schema_name: "public",
      table_name: "edge_fn:slack-compute-analytics",
      row_id: null,
      context: { event: "slack-compute-analytics" }
    }).then(() => {}).catch((e) => console.error("[slack-compute-analytics] audit_log insert failed:", e));
    // Parse request for optional time period
    let body = {};
    try {
      const text = await req.text();
      if (text) body = JSON.parse(text);
    } catch (e) {
    // Default options
    }
    const daysBack = body.daysBack || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - daysBack);
    const startDateStr = startDate.toISOString();
    console.log(`Computing analytics for last ${daysBack} days`);
    const results = {
      computed_at: new Date().toISOString(),
      metrics: {}
    };
    // ============================================
    // METRIC 1: Total Messages
    // ============================================
    const { count: totalMessages } = await supabase.from("slack_messages").select("*", {
      count: "exact",
      head: true
    });
    const { count: recentMessages } = await supabase.from("slack_messages").select("*", {
      count: "exact",
      head: true
    }).gte("posted_at", startDateStr);
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "total_messages",
      metric_value: {
        all_time: totalMessages || 0,
        recent: recentMessages || 0,
        days: daysBack
      },
      time_period: "all_time",
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.total_messages = {
      all_time: totalMessages,
      recent: recentMessages
    };
    // ============================================
    // METRIC 2: Messages by Day (for chart)
    // ============================================
    const { data: messagesByDay } = await supabase.rpc("get_messages_by_day", {
      days_back: daysBack
    });
    // If RPC doesn't exist, use raw query alternative
    let dailyData = messagesByDay;
    if (!dailyData) {
      const { data: rawDaily } = await supabase.from("slack_messages").select("posted_at").gte("posted_at", startDateStr).order("posted_at", {
        ascending: true
      });
      // Group by day in JS
      const grouped = {};
      rawDaily?.forEach((msg)=>{
        const day = msg.posted_at.split("T")[0];
        grouped[day] = (grouped[day] || 0) + 1;
      });
      dailyData = Object.entries(grouped).map(([date, count])=>({
          date,
          count
        }));
    }
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "messages_by_day",
      metric_value: {
        data: dailyData || []
      },
      time_period: `last_${daysBack}_days`,
      period_start: startDateStr,
      period_end: new Date().toISOString(),
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.messages_by_day = dailyData?.length || 0;
    // ============================================
    // METRIC 3: Messages by Channel
    // ============================================
    const { data: channelMessages } = await supabase.from("slack_messages").select("slack_channel_id").gte("posted_at", startDateStr);
    const channelCounts = {};
    channelMessages?.forEach((msg)=>{
      channelCounts[msg.slack_channel_id] = (channelCounts[msg.slack_channel_id] || 0) + 1;
    });
    // Get channel names
    const { data: channels } = await supabase.from("slack_channel_committee_mapping").select("slack_channel_id, slack_channel_name, committee_name");
    const channelData = Object.entries(channelCounts).map(([channelId, count])=>{
      const channel = channels?.find((c)=>c.slack_channel_id === channelId);
      return {
        channel_id: channelId,
        channel_name: channel?.slack_channel_name || "Unknown",
        committee: channel?.committee_name || "Unknown",
        message_count: count
      };
    }).sort((a, b)=>b.message_count - a.message_count);
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "messages_by_channel",
      metric_value: {
        data: channelData
      },
      time_period: `last_${daysBack}_days`,
      period_start: startDateStr,
      period_end: new Date().toISOString(),
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.messages_by_channel = channelData.length;
    // ============================================
    // METRIC 4: Messages by User (Top 20)
    // ============================================
    const { data: userMessages } = await supabase.from("slack_messages").select("slack_user_id, member_id").gte("posted_at", startDateStr);
    const userCounts = {};
    userMessages?.forEach((msg)=>{
      if (!userCounts[msg.slack_user_id]) {
        userCounts[msg.slack_user_id] = {
          count: 0,
          member_id: msg.member_id
        };
      }
      userCounts[msg.slack_user_id].count++;
    });
    // Get user names from mapping
    const userIds = Object.keys(userCounts);
    const { data: userMappings } = await supabase.from("slack_user_mapping").select("slack_user_id, slack_real_name, slack_display_name, member_id").in("slack_user_id", userIds);
    // Get member names
    const memberIds = userMappings?.map((u)=>u.member_id).filter(Boolean) || [];
    const { data: members } = await supabase.from("members").select("id, name").in("id", memberIds);
    const userData = Object.entries(userCounts).map(([userId, data])=>{
      const mapping = userMappings?.find((u)=>u.slack_user_id === userId);
      const member = members?.find((m)=>m.id === data.member_id);
      return {
        slack_user_id: userId,
        name: member?.name || mapping?.slack_real_name || mapping?.slack_display_name || "Unknown",
        member_id: data.member_id,
        is_linked: !!data.member_id,
        message_count: data.count
      };
    }).sort((a, b)=>b.message_count - a.message_count).slice(0, 20); // Top 20
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "messages_by_user",
      metric_value: {
        data: userData
      },
      time_period: `last_${daysBack}_days`,
      period_start: startDateStr,
      period_end: new Date().toISOString(),
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.messages_by_user = userData.length;
    // ============================================
    // METRIC 5: Activity by Day of Week
    // ============================================
    const { data: allMessages } = await supabase.from("slack_messages").select("posted_at").gte("posted_at", startDateStr);
    const dayOfWeekCounts = {
      0: 0,
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0
    };
    allMessages?.forEach((msg)=>{
      const day = new Date(msg.posted_at).getDay();
      dayOfWeekCounts[day]++;
    });
    const dayNames = [
      "Sunday",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday"
    ];
    const dayOfWeekData = Object.entries(dayOfWeekCounts).map(([day, count])=>({
        day: parseInt(day),
        day_name: dayNames[parseInt(day)],
        message_count: count
      }));
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "messages_by_day_of_week",
      metric_value: {
        data: dayOfWeekData
      },
      time_period: `last_${daysBack}_days`,
      period_start: startDateStr,
      period_end: new Date().toISOString(),
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.messages_by_day_of_week = dayOfWeekData;
    // ============================================
    // METRIC 6: Activity by Hour
    // ============================================
    const hourCounts = {};
    for(let i = 0; i < 24; i++)hourCounts[i] = 0;
    allMessages?.forEach((msg)=>{
      const hour = new Date(msg.posted_at).getHours();
      hourCounts[hour]++;
    });
    const hourData = Object.entries(hourCounts).map(([hour, count])=>({
        hour: parseInt(hour),
        message_count: count
      }));
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "messages_by_hour",
      metric_value: {
        data: hourData
      },
      time_period: `last_${daysBack}_days`,
      period_start: startDateStr,
      period_end: new Date().toISOString(),
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.messages_by_hour = hourData;
    // ============================================
    // METRIC 7: User Counts Summary
    // ============================================
    const { count: linkedUsers } = await supabase.from("slack_user_mapping").select("*", {
      count: "exact",
      head: true
    });
    const { count: unmatchedUsers } = await supabase.from("slack_users_unmatched").select("*", {
      count: "exact",
      head: true
    }).eq("manually_rejected", false);
    const { count: rejectedUsers } = await supabase.from("slack_users_unmatched").select("*", {
      count: "exact",
      head: true
    }).eq("manually_rejected", true);
    const { count: activeChannels } = await supabase.from("slack_channel_committee_mapping").select("*", {
      count: "exact",
      head: true
    }).eq("is_active", true);
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "user_counts",
      metric_value: {
        linked_users: linkedUsers || 0,
        unmatched_users: unmatchedUsers || 0,
        rejected_users: rejectedUsers || 0,
        active_channels: activeChannels || 0
      },
      time_period: "current",
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.user_counts = {
      linked: linkedUsers,
      unmatched: unmatchedUsers,
      rejected: rejectedUsers,
      channels: activeChannels
    };
    // ============================================
    // METRIC 8: Recent Membership Changes
    // ============================================
    const { data: membershipChanges } = await supabase.from("slack_channel_membership_log").select(`
        id,
        member_id,
        slack_user_id,
        slack_channel_id,
        action,
        source,
        created_at,
        metadata
      `).order("created_at", {
      ascending: false
    }).limit(50);
    await supabase.from("slack_analytics_cache").upsert({
      metric_name: "recent_membership_changes",
      metric_value: {
        data: membershipChanges || []
      },
      time_period: "recent",
      computed_at: new Date().toISOString()
    }, {
      onConflict: "metric_name,time_period,period_start"
    });
    results.metrics.membership_changes = membershipChanges?.length || 0;
    console.log("Analytics computation complete");
    return new Response(JSON.stringify({
      success: true,
      ...results
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error computing analytics:", error);
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
