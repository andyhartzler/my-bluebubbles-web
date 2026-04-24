// ============================================================================
// THREADS STATS FETCHER EDGE FUNCTION (v1.0 - DECEMBER 2025)
// 
// API DETAILS:
// - Base URL: https://graph.threads.net/v1.0/
// - User Insights: /{user_id}/threads_insights (views, likes, replies, reposts, quotes, followers_count)
// - Media Insights: /{media_id}/insights (views, likes, replies, reposts, quotes, shares)
// - Demographics: threads_follower_demographics (age, gender, country, city breakdowns)
// - Data available since April 13, 2024 (timestamp: 1712991600)
//
// PERMISSIONS REQUIRED:
// - threads_basic
// - threads_manage_insights
//
// Deploy: supabase functions deploy fetch-threads-stats
// ============================================================================
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};
const API_VERSION = "v1.0";
const BASE_URL = "https://graph.threads.net";
// Data only available since April 13, 2024
const THREADS_DATA_START_TIMESTAMP = 1712991600;

// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
async function requireAuthorized(req) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
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

serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:fetch-threads-stats",
      row_id: null,
      context: { event: "fetch-threads-stats" }
    }).then(() => {}).catch((e) => console.error("[fetch-threads-stats] audit_log insert failed:", e));
    console.log(`🔄 Starting Threads stats fetch (${API_VERSION})...`);
    const { data: accounts, error: accountsError } = await supabase.from("social_media_accounts").select("*").eq("platform", "threads").eq("is_active", true);
    if (accountsError) throw new Error(accountsError.message);
    if (!accounts || accounts.length === 0) {
      return new Response(JSON.stringify({
        message: "No Threads accounts found"
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const results = [];
    for (const account of accounts){
      try {
        console.log(`📊 Fetching stats for: ${account.account_name}`);
        const { stats, demographics } = await fetchThreadsStats(account);
        const today = new Date().toISOString().split("T")[0];
        // Upsert stats
        const { error: insertError } = await supabase.from("social_media_stats").upsert({
          account_id: account.id,
          platform: "threads",
          metric_date: today,
          ...stats,
          updated_at: new Date().toISOString()
        }, {
          onConflict: "account_id,metric_date,metric_hour"
        });
        if (insertError) {
          console.error(`Error storing stats:`, insertError);
          results.push({
            account: account.account_name,
            success: false,
            error: insertError.message
          });
        } else {
          console.log(`✅ Stats stored for ${account.account_name}`);
          // Upsert demographics if we have any data
          if (demographics && Object.keys(demographics.age_gender_breakdown || {}).length > 0) {
            const { error: demoError } = await supabase.from("social_media_audience_demographics").upsert({
              account_id: account.id,
              metric_date: today,
              age_gender_breakdown: demographics.age_gender_breakdown || {},
              top_countries: demographics.top_countries || {},
              top_cities: demographics.top_cities || {},
              top_languages: demographics.top_languages || {},
              platform_demographics: demographics.platform_demographics || {},
              updated_at: new Date().toISOString()
            }, {
              onConflict: "account_id,metric_date"
            });
            if (demoError) {
              console.error(`Error storing demographics:`, demoError);
            } else {
              console.log(`✅ Demographics stored for ${account.account_name}`);
            }
          }
          results.push({
            account: account.account_name,
            success: true
          });
          await supabase.from("social_media_accounts").update({
            last_synced_at: new Date().toISOString()
          }).eq("id", account.id);
        }
      } catch (error) {
        console.error(`Error processing ${account.account_name}:`, error);
        results.push({
          account: account.account_name,
          success: false,
          error: error.message
        });
      }
    }
    return new Response(JSON.stringify({
      success: true,
      results
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Fatal error:", error);
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
async function fetchThreadsStats(account) {
  const accessToken = account.access_token;
  const userId = account.account_id;
  const today = new Date().toISOString().split('T')[0];
  const stats = {};
  const demographics = {};
  // ========================================================================
  // 1. Get User Profile Info
  // ========================================================================
  console.log("Getting user profile...");
  const profileUrl = `${BASE_URL}/${API_VERSION}/${userId}` + `?fields=id,username,name,threads_profile_picture_url,threads_biography` + `&access_token=${accessToken}`;
  const profileResponse = await fetch(profileUrl);
  const profileData = await profileResponse.json();
  if (profileData.error) {
    throw new Error(`Threads API error: ${profileData.error.message}`);
  }
  console.log(`✅ Profile: @${profileData.username}`);
  // ========================================================================
  // 2. Get Account-Level Insights (followers_count, views, etc.)
  // ========================================================================
  console.log("Getting account insights...");
  let followersCount = 0;
  let accountViews = 0;
  let accountLikes = 0;
  let accountReplies = 0;
  let accountReposts = 0;
  let accountQuotes = 0;
  // Calculate 30 days ago timestamp
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const sinceTimestamp = Math.max(Math.floor(thirtyDaysAgo.getTime() / 1000), THREADS_DATA_START_TIMESTAMP);
  try {
    // Get followers_count
    const followersUrl = `${BASE_URL}/${API_VERSION}/${userId}/threads_insights` + `?metric=followers_count` + `&access_token=${accessToken}`;
    const followersResponse = await fetch(followersUrl);
    const followersData = await followersResponse.json();
    if (followersData.data) {
      for (const metric of followersData.data){
        if (metric.name === "followers_count") {
          followersCount = metric.total_value?.value || 0;
        }
      }
    }
    console.log(`✅ Followers: ${followersCount}`);
  } catch (e) {
    console.warn(`⚠️ Could not fetch followers_count: ${e.message}`);
  }
  // Get other account-level metrics with time range
  try {
    const insightsUrl = `${BASE_URL}/${API_VERSION}/${userId}/threads_insights` + `?metric=views,likes,replies,reposts,quotes` + `&since=${sinceTimestamp}` + `&access_token=${accessToken}`;
    const insightsResponse = await fetch(insightsUrl);
    const insightsData = await insightsResponse.json();
    if (insightsData.data) {
      for (const metric of insightsData.data){
        const value = metric.total_value?.value || 0;
        switch(metric.name){
          case "views":
            accountViews = value;
            break;
          case "likes":
            accountLikes = value;
            break;
          case "replies":
            accountReplies = value;
            break;
          case "reposts":
            accountReposts = value;
            break;
          case "quotes":
            accountQuotes = value;
            break;
        }
      }
      console.log(`✅ Account insights: views=${accountViews}, likes=${accountLikes}, replies=${accountReplies}`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch account insights: ${e.message}`);
  }
  stats.followers_count = followersCount;
  // ========================================================================
  // 3. Get Follower Demographics
  // NOTE: follower_demographics requires:
  //   - Exactly ONE breakdown parameter (age, gender, country, or city)
  //   - Does NOT support since/until parameters
  //   - Requires 100+ followers
  //   - Requires linked Instagram account
  // ========================================================================
  console.log("Getting follower demographics...");
  // Helper function to fetch a single demographic breakdown
  async function fetchDemographicBreakdown(breakdown) {
    try {
      const url = `${BASE_URL}/${API_VERSION}/${userId}/threads_insights` + `?metric=follower_demographics` + `&breakdown=${breakdown}` + `&access_token=${accessToken}`;
      console.log(`   Fetching ${breakdown} breakdown...`);
      const response = await fetch(url);
      const data = await response.json();
      // Log full response for debugging
      console.log(`   ${breakdown} response:`, JSON.stringify(data).substring(0, 500));
      if (data.error) {
        // Check for specific error codes
        if (data.error.code === 10 || data.error.message?.includes('not have access')) {
          console.warn(`   ⚠️ ${breakdown}: Feature not available (may need linked Instagram or 100+ followers)`);
        } else {
          console.warn(`   ⚠️ ${breakdown} error: ${data.error.message} (code: ${data.error.code})`);
        }
        return null;
      }
      // The response format for follower_demographics
      if (data.data && data.data[0]?.total_value?.breakdowns?.[0]?.results) {
        const results = data.data[0].total_value.breakdowns[0].results;
        const breakdown_data = {};
        for (const item of results){
          const key = item.dimension_values?.[0] || 'unknown';
          breakdown_data[key] = item.value || 0;
        }
        console.log(`   ✅ Got ${breakdown}: ${Object.keys(breakdown_data).length} segments`);
        return breakdown_data;
      }
      // Try alternative response structure (just in case)
      if (data.data && data.data[0]?.total_value?.value) {
        console.log(`   ⚠️ ${breakdown}: Got simple value format, not breakdown`);
        return null;
      }
      console.log(`   ⚠️ No ${breakdown} data in response structure`);
      return null;
    } catch (e) {
      console.warn(`   ⚠️ Could not fetch ${breakdown} demographics: ${e.message}`);
      return null;
    }
  }
  // Fetch all four breakdowns (must be separate API calls)
  const [ageData, genderData, countryData, cityData] = await Promise.all([
    fetchDemographicBreakdown('age'),
    fetchDemographicBreakdown('gender'),
    fetchDemographicBreakdown('country'),
    fetchDemographicBreakdown('city')
  ]);
  // Store age breakdown
  if (ageData) {
    demographics.age_breakdown = ageData;
  }
  // Store gender breakdown
  if (genderData) {
    demographics.gender_breakdown = genderData;
  }
  // Combine age and gender into age_gender_breakdown for consistency with other platforms
  demographics.age_gender_breakdown = {
    ...ageData || {},
    ...genderData || {}
  };
  // Store country breakdown
  if (countryData) {
    demographics.top_countries = countryData;
  }
  // Store city breakdown
  if (cityData) {
    demographics.top_cities = cityData;
  }
  // Build platform demographics metadata
  demographics.platform_demographics = {
    collection_date: today,
    api_version: API_VERSION,
    base_url: BASE_URL,
    age_breakdown: ageData || {},
    gender_breakdown: genderData || {},
    data_notes: {
      source: "follower_demographics metric",
      requirements: "Requires 100+ followers and linked Instagram account",
      limitations: "Each breakdown (age, gender, country, city) requires separate API call",
      data_available_since: "2024-04-13"
    },
    data_available: {
      age: !!ageData,
      gender: !!genderData,
      country: !!countryData,
      city: !!cityData
    }
  };
  // ========================================================================
  // 4. Get All Threads (Posts)
  // ========================================================================
  console.log("Getting threads (posts)...");
  let allThreads = [];
  const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];
  let nextUrl = `${BASE_URL}/${API_VERSION}/${userId}/threads` + `?fields=id,media_type,media_product_type,text,timestamp,permalink,shortcode,is_quote_post` + `&since=${thirtyDaysAgoStr}` + `&limit=100` + `&access_token=${accessToken}`;
  for(let i = 0; i < 5 && nextUrl; i++){
    const response = await fetch(nextUrl);
    const data = await response.json();
    if (data.error) {
      console.warn("Threads API error:", data.error);
      break;
    }
    if (data.data) {
      allThreads = allThreads.concat(data.data);
    }
    nextUrl = data.paging?.next || null;
  }
  console.log(`✅ Found ${allThreads.length} threads from last 30 days`);
  const todayThreads = allThreads.filter((t)=>t.timestamp?.startsWith(today));
  stats.posts_count = todayThreads.length;
  // ========================================================================
  // 5. Get Post-Level Insights for Each Thread
  // ========================================================================
  console.log("Getting post-level insights...");
  let totalViews = 0;
  let totalLikes = 0;
  let totalReplies = 0;
  let totalReposts = 0;
  let totalQuotes = 0;
  let totalShares = 0;
  let threadsWithInsights = 0;
  for (const thread of allThreads){
    try {
      const postInsightsUrl = `${BASE_URL}/${API_VERSION}/${thread.id}/insights` + `?metric=views,likes,replies,reposts,quotes,shares` + `&access_token=${accessToken}`;
      const postInsightsResponse = await fetch(postInsightsUrl);
      const postInsightsData = await postInsightsResponse.json();
      if (postInsightsData.data && postInsightsData.data.length > 0) {
        threadsWithInsights++;
        for (const metric of postInsightsData.data){
          const value = metric.values?.[0]?.value || 0;
          switch(metric.name){
            case "views":
              totalViews += value;
              break;
            case "likes":
              totalLikes += value;
              break;
            case "replies":
              totalReplies += value;
              break;
            case "reposts":
              totalReposts += value;
              break;
            case "quotes":
              totalQuotes += value;
              break;
            case "shares":
              totalShares += value;
              break;
          }
        }
      }
    } catch (error) {
    // Insights might not be available for all threads
    }
  }
  console.log(`✅ Got insights for ${threadsWithInsights}/${allThreads.length} threads`);
  stats.likes_count = totalLikes;
  stats.comments_count = totalReplies;
  stats.shares_count = totalReposts + totalShares;
  stats.impressions = totalViews;
  stats.reach = totalViews;
  // ========================================================================
  // 6. Calculate rates and build platform_metrics
  // ========================================================================
  const avgLikesPerPost = allThreads.length > 0 ? Math.round(totalLikes / allThreads.length) : 0;
  const avgRepliesPerPost = allThreads.length > 0 ? Math.round(totalReplies / allThreads.length) : 0;
  const engagementRate = stats.followers_count > 0 && allThreads.length > 0 ? ((totalLikes + totalReplies + totalReposts + totalQuotes) / allThreads.length / stats.followers_count * 100).toFixed(2) : "0.00";
  stats.platform_metrics = {
    collection_date: today,
    api_version: API_VERSION,
    base_url: BASE_URL,
    data_methodology: "rolling_30_day_aggregates",
    time_windows: {
      followers_count: "current_snapshot",
      impressions: "last_30_days_total (views)",
      reach: "last_30_days_total (views)",
      likes_count: "last_30_days_total",
      comments_count: "last_30_days_total (replies)",
      shares_count: "last_30_days_total (reposts + shares)",
      posts_count: "today_only"
    },
    account_insights: {
      date: today,
      period_start: thirtyDaysAgoStr,
      followers_count: followersCount,
      views: accountViews,
      likes: accountLikes,
      replies: accountReplies,
      reposts: accountReposts,
      quotes: accountQuotes
    },
    last_30_days: {
      date_range: {
        start: thirtyDaysAgoStr,
        end: today,
        days: 30
      },
      totals: {
        threads: allThreads.length,
        views: totalViews,
        likes: totalLikes,
        replies: totalReplies,
        reposts: totalReposts,
        quotes: totalQuotes,
        shares: totalShares,
        total_engagement: totalLikes + totalReplies + totalReposts + totalQuotes
      },
      averages: {
        views_per_thread: threadsWithInsights > 0 ? Math.round(totalViews / threadsWithInsights) : 0,
        likes_per_thread: avgLikesPerPost,
        replies_per_thread: avgRepliesPerPost,
        reposts_per_thread: allThreads.length > 0 ? Math.round(totalReposts / allThreads.length) : 0,
        quotes_per_thread: allThreads.length > 0 ? Math.round(totalQuotes / allThreads.length) : 0,
        engagement_per_thread: avgLikesPerPost + avgRepliesPerPost
      },
      rates: {
        engagement_rate: parseFloat(engagementRate)
      },
      content_breakdown: {
        text_only: allThreads.filter((t)=>t.media_type === "TEXT_POST").length,
        with_image: allThreads.filter((t)=>t.media_type === "IMAGE").length,
        with_video: allThreads.filter((t)=>t.media_type === "VIDEO").length,
        carousel: allThreads.filter((t)=>t.media_type === "CAROUSEL_ALBUM").length,
        quote_posts: allThreads.filter((t)=>t.is_quote_post === true).length
      }
    },
    today: {
      date: today,
      new_threads: stats.posts_count
    },
    account: {
      user_id: userId,
      username: profileData.username,
      name: profileData.name || null,
      biography: profileData.threads_biography || null,
      current_followers: followersCount,
      threads_in_30day_window: allThreads.length
    },
    data_quality: {
      threads_analyzed: allThreads.length,
      threads_with_insights: threadsWithInsights,
      insights_coverage_pct: allThreads.length > 0 ? parseFloat((threadsWithInsights / allThreads.length * 100).toFixed(1)) : 0,
      data_available_since: "2024-04-13",
      note: threadsWithInsights > 0 ? `Successfully retrieved insights for ${threadsWithInsights}/${allThreads.length} threads` : "No thread insights available"
    }
  };
  console.log(`📊 Threads Stats Summary:`);
  console.log(`   ═══════════════════════════════════════`);
  console.log(`   API: ${BASE_URL}/${API_VERSION}`);
  console.log(`   Username: @${profileData.username}`);
  console.log(`   Followers: ${followersCount.toLocaleString()}`);
  console.log(`   Views: ${totalViews.toLocaleString()}`);
  console.log(`   Likes: ${totalLikes.toLocaleString()}`);
  console.log(`   Replies: ${totalReplies.toLocaleString()}`);
  console.log(`   Reposts: ${totalReposts.toLocaleString()}`);
  console.log(`   Quotes: ${totalQuotes.toLocaleString()}`);
  console.log(`   Shares: ${totalShares.toLocaleString()}`);
  console.log(`   Engagement Rate: ${engagementRate}%`);
  console.log(`   Demographics: ${Object.keys(demographics.age_gender_breakdown || {}).length} age/gender segments`);
  console.log(`   Demographics: ${Object.keys(demographics.top_countries || {}).length} countries`);
  console.log(`   Demographics: ${Object.keys(demographics.top_cities || {}).length} cities`);
  console.log(`   ═══════════════════════════════════════`);
  return {
    stats,
    demographics
  };
}
