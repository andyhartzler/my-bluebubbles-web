// ============================================================================
// INSTAGRAM STATS FETCHER EDGE FUNCTION (v24.0 - DECEMBER 2025)
// 
// CORRECT API PARAMETERS:
// - Account insights with metric_type=total_value: profile_views, website_clicks,
//   accounts_engaged, total_interactions, follows_and_unfollows, views
// - Account insights with period=day only: reach
// - Post insights: views, reach, saved, shares, total_interactions
// - Demographics: follower_demographics, engaged_audience_demographics, reached_audience_demographics
//
// Deploy: supabase functions deploy fetch-instagram-stats
// ============================================================================
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};
const API_VERSION = "v24.0";

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
      table_name: "edge_fn:fetch-instagram-stats",
      row_id: null,
      context: { event: "fetch-instagram-stats" }
    }).then(() => {}).catch((e) => console.error("[fetch-instagram-stats] audit_log insert failed:", e));
    console.log(`🔄 Starting Instagram stats fetch (${API_VERSION})...`);
    const { data: accounts, error: accountsError } = await supabase.from("social_media_accounts").select("*").eq("platform", "instagram").eq("is_active", true);
    if (accountsError) throw new Error(accountsError.message);
    if (!accounts || accounts.length === 0) {
      return new Response(JSON.stringify({
        message: "No Instagram accounts found"
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
        const { stats, demographics } = await fetchInstagramStats(account);
        const today = new Date().toISOString().split("T")[0];
        // Upsert stats
        const { error: insertError } = await supabase.from("social_media_stats").upsert({
          account_id: account.id,
          platform: "instagram",
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
async function fetchInstagramStats(account) {
  const accessToken = account.access_token;
  const igAccountId = account.account_id;
  const today = new Date().toISOString().split('T')[0];
  const stats = {};
  const demographics = {};
  // ========================================================================
  // 1. Get basic account info (followers count, media count, following)
  // ========================================================================
  console.log("Getting account info...");
  const accountUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}` + `?fields=followers_count,follows_count,media_count,username,name,biography,profile_picture_url` + `&access_token=${accessToken}`;
  const accountResponse = await fetch(accountUrl);
  const accountData = await accountResponse.json();
  if (accountData.error) {
    throw new Error(`Instagram API error: ${accountData.error.message}`);
  }
  stats.followers_count = accountData.followers_count || 0;
  stats.following_count = accountData.follows_count || 0;
  console.log(`✅ Followers: ${stats.followers_count}, Following: ${stats.following_count}`);
  // ========================================================================
  // 2. Get Account-level insights - GROUP 1: metric_type=total_value
  // ========================================================================
  console.log("Getting account-level insights (total_value metrics)...");
  let profileViews = 0;
  let websiteClicks = 0;
  let accountsEngaged = 0;
  let totalInteractions = 0;
  let accountViews = 0;
  let newFollows = 0;
  let unfollows = 0;
  try {
    const totalValueMetricsUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=profile_views,website_clicks,accounts_engaged,total_interactions,follows_and_unfollows,views` + `&metric_type=total_value` + `&period=day` + `&access_token=${accessToken}`;
    const totalValueResponse = await fetch(totalValueMetricsUrl);
    const totalValueData = await totalValueResponse.json();
    if (totalValueData.data) {
      for (const metric of totalValueData.data){
        const value = metric.total_value?.value || 0;
        switch(metric.name){
          case "profile_views":
            profileViews = value;
            break;
          case "website_clicks":
            websiteClicks = value;
            break;
          case "accounts_engaged":
            accountsEngaged = value;
            break;
          case "total_interactions":
            totalInteractions = value;
            break;
          case "views":
            accountViews = value;
            break;
          case "follows_and_unfollows":
            if (metric.total_value?.breakdown) {
              for (const item of metric.total_value.breakdown){
                if (item.dimension_values?.[0] === "follow") {
                  newFollows = item.value || 0;
                } else if (item.dimension_values?.[0] === "unfollow") {
                  unfollows = item.value || 0;
                }
              }
            }
            break;
        }
      }
      console.log(`✅ Total value metrics: profile_views=${profileViews}, views=${accountViews}, accounts_engaged=${accountsEngaged}`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch total_value metrics: ${e.message}`);
  }
  stats.profile_views = profileViews;
  // ========================================================================
  // 3. Get Account-level insights - GROUP 2: period=day only (reach)
  // ========================================================================
  console.log("Getting account-level insights (daily reach)...");
  let accountReach = 0;
  try {
    const reachUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=reach` + `&period=day` + `&access_token=${accessToken}`;
    const reachResponse = await fetch(reachUrl);
    const reachData = await reachResponse.json();
    if (reachData.data && reachData.data[0]?.values) {
      const values = reachData.data[0].values;
      accountReach = values[values.length - 1]?.value || 0;
      console.log(`✅ Daily reach: ${accountReach}`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch daily reach: ${e.message}`);
  }
  // ========================================================================
  // 4. Get Demographics - Follower Demographics
  // ========================================================================
  console.log("Getting follower demographics...");
  // Age/Gender breakdown from follower_demographics
  try {
    const followerDemoUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=follower_demographics` + `&period=lifetime` + `&metric_type=total_value` + `&breakdown=age,gender` + `&access_token=${accessToken}`;
    const followerDemoResponse = await fetch(followerDemoUrl);
    const followerDemoData = await followerDemoResponse.json();
    if (followerDemoData.data && followerDemoData.data[0]?.total_value?.breakdowns?.[0]?.results) {
      const results = followerDemoData.data[0].total_value.breakdowns[0].results;
      const ageGenderBreakdown = {};
      for (const item of results){
        const dimensions = item.dimension_values || [];
        const age = dimensions[0] || 'unknown';
        const gender = dimensions[1] || 'unknown';
        const key = `${gender}_${age}`;
        ageGenderBreakdown[key] = item.value || 0;
      }
      demographics.age_gender_breakdown = ageGenderBreakdown;
      console.log(`✅ Got follower age/gender demographics: ${Object.keys(ageGenderBreakdown).length} segments`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch follower demographics: ${e.message}`);
  }
  // Country breakdown
  try {
    const countryDemoUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=follower_demographics` + `&period=lifetime` + `&metric_type=total_value` + `&breakdown=country` + `&access_token=${accessToken}`;
    const countryDemoResponse = await fetch(countryDemoUrl);
    const countryDemoData = await countryDemoResponse.json();
    if (countryDemoData.data && countryDemoData.data[0]?.total_value?.breakdowns?.[0]?.results) {
      const results = countryDemoData.data[0].total_value.breakdowns[0].results;
      const countries = {};
      for (const item of results){
        const country = item.dimension_values?.[0] || 'unknown';
        countries[country] = item.value || 0;
      }
      demographics.top_countries = countries;
      console.log(`✅ Got country demographics: ${Object.keys(countries).length} countries`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch country demographics: ${e.message}`);
  }
  // City breakdown
  try {
    const cityDemoUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=follower_demographics` + `&period=lifetime` + `&metric_type=total_value` + `&breakdown=city` + `&access_token=${accessToken}`;
    const cityDemoResponse = await fetch(cityDemoUrl);
    const cityDemoData = await cityDemoResponse.json();
    if (cityDemoData.data && cityDemoData.data[0]?.total_value?.breakdowns?.[0]?.results) {
      const results = cityDemoData.data[0].total_value.breakdowns[0].results;
      const cities = {};
      for (const item of results){
        const city = item.dimension_values?.[0] || 'unknown';
        cities[city] = item.value || 0;
      }
      demographics.top_cities = cities;
      console.log(`✅ Got city demographics: ${Object.keys(cities).length} cities`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch city demographics: ${e.message}`);
  }
  // ========================================================================
  // 5. Get Engaged Audience Demographics (people who engaged with content)
  // ========================================================================
  console.log("Getting engaged audience demographics...");
  let engagedAudienceDemo = {};
  try {
    const engagedDemoUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=engaged_audience_demographics` + `&period=lifetime` + `&metric_type=total_value` + `&breakdown=age,gender` + `&timeframe=this_month` + `&access_token=${accessToken}`;
    const engagedDemoResponse = await fetch(engagedDemoUrl);
    const engagedDemoData = await engagedDemoResponse.json();
    if (engagedDemoData.data && engagedDemoData.data[0]?.total_value?.breakdowns?.[0]?.results) {
      const results = engagedDemoData.data[0].total_value.breakdowns[0].results;
      for (const item of results){
        const dimensions = item.dimension_values || [];
        const age = dimensions[0] || 'unknown';
        const gender = dimensions[1] || 'unknown';
        const key = `${gender}_${age}`;
        engagedAudienceDemo[key] = item.value || 0;
      }
      console.log(`✅ Got engaged audience demographics: ${Object.keys(engagedAudienceDemo).length} segments`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch engaged audience demographics: ${e.message}`);
  }
  // ========================================================================
  // 6. Get Reached Audience Demographics
  // ========================================================================
  console.log("Getting reached audience demographics...");
  let reachedAudienceDemo = {};
  try {
    const reachedDemoUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/insights` + `?metric=reached_audience_demographics` + `&period=lifetime` + `&metric_type=total_value` + `&breakdown=age,gender` + `&timeframe=this_month` + `&access_token=${accessToken}`;
    const reachedDemoResponse = await fetch(reachedDemoUrl);
    const reachedDemoData = await reachedDemoResponse.json();
    if (reachedDemoData.data && reachedDemoData.data[0]?.total_value?.breakdowns?.[0]?.results) {
      const results = reachedDemoData.data[0].total_value.breakdowns[0].results;
      for (const item of results){
        const dimensions = item.dimension_values || [];
        const age = dimensions[0] || 'unknown';
        const gender = dimensions[1] || 'unknown';
        const key = `${gender}_${age}`;
        reachedAudienceDemo[key] = item.value || 0;
      }
      console.log(`✅ Got reached audience demographics: ${Object.keys(reachedAudienceDemo).length} segments`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch reached audience demographics: ${e.message}`);
  }
  // Build platform demographics metadata
  demographics.platform_demographics = {
    collection_date: today,
    api_version: API_VERSION,
    engaged_audience: engagedAudienceDemo,
    reached_audience: reachedAudienceDemo,
    data_notes: {
      follower_demographics: "Lifetime follower breakdown (requires 100+ followers)",
      engaged_audience: "This month - people who engaged with content",
      reached_audience: "This month - people reached by content",
      limitations: "Only top 45 segments returned, requires 100+ engagements in 30 days"
    }
  };
  // ========================================================================
  // 7. Get ALL media (paginate to get comprehensive data)
  // ========================================================================
  console.log("Getting all media...");
  let allMedia = [];
  let nextUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/media` + `?fields=id,media_type,media_product_type,timestamp,like_count,comments_count` + `&limit=100` + `&access_token=${accessToken}`;
  for(let i = 0; i < 5 && nextUrl; i++){
    const response = await fetch(nextUrl);
    const data = await response.json();
    if (data.error) {
      console.warn("Media API error:", data.error);
      break;
    }
    if (data.data) {
      allMedia = allMedia.concat(data.data);
    }
    nextUrl = data.paging?.next || null;
  }
  console.log(`✅ Found ${allMedia.length} total posts`);
  // Filter media by date
  const last30Days = new Date();
  last30Days.setDate(last30Days.getDate() - 30);
  const last30DaysStr = last30Days.toISOString();
  const todayMedia = allMedia.filter((m)=>m.timestamp?.startsWith(today));
  const recent30DaysMedia = allMedia.filter((m)=>m.timestamp >= last30DaysStr);
  stats.posts_count = todayMedia.filter((m)=>m.media_type === "IMAGE" || m.media_type === "CAROUSEL_ALBUM").length;
  stats.reels_count = todayMedia.filter((m)=>m.media_product_type === "REELS").length;
  // ========================================================================
  // 8. Get detailed insights for each post
  // ========================================================================
  console.log("Getting post-level insights...");
  let totalViews = 0;
  let totalReach = 0;
  let totalSaves = 0;
  let totalShares = 0;
  let totalLikes = 0;
  let totalComments = 0;
  let postsWithInsights = 0;
  for (const post of recent30DaysMedia){
    totalLikes += post.like_count || 0;
    totalComments += post.comments_count || 0;
    try {
      const insightsUrl = `https://graph.facebook.com/${API_VERSION}/${post.id}/insights` + `?metric=views,reach,saved,shares,total_interactions` + `&access_token=${accessToken}`;
      const insightsResponse = await fetch(insightsUrl);
      const insightsData = await insightsResponse.json();
      if (insightsData.data && insightsData.data.length > 0) {
        postsWithInsights++;
        for (const metric of insightsData.data){
          const value = metric.values?.[0]?.value || 0;
          switch(metric.name){
            case "views":
              totalViews += value;
              break;
            case "reach":
              totalReach += value;
              break;
            case "saved":
              totalSaves += value;
              break;
            case "shares":
              totalShares += value;
              break;
          }
        }
      }
    } catch (error) {
    // Insights might not be available for all post types
    }
  }
  console.log(`✅ Got insights for ${postsWithInsights}/${recent30DaysMedia.length} posts`);
  stats.likes_count = totalLikes;
  stats.comments_count = totalComments;
  stats.saves_count = totalSaves;
  stats.shares_count = totalShares;
  stats.impressions = totalViews;
  stats.reach = totalReach;
  // ========================================================================
  // 9. Get Stories count
  // ========================================================================
  console.log("Checking for stories...");
  let storiesCount = 0;
  try {
    const storiesUrl = `https://graph.facebook.com/${API_VERSION}/${igAccountId}/stories` + `?fields=id,timestamp` + `&access_token=${accessToken}`;
    const storiesResponse = await fetch(storiesUrl);
    const storiesData = await storiesResponse.json();
    if (storiesData.data) {
      storiesCount = storiesData.data.length;
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch stories: ${e.message}`);
  }
  stats.stories_count = storiesCount;
  // ========================================================================
  // 10. Calculate rates and build platform_metrics
  // ========================================================================
  const avgLikesPerPost = recent30DaysMedia.length > 0 ? Math.round(totalLikes / recent30DaysMedia.length) : 0;
  const avgCommentsPerPost = recent30DaysMedia.length > 0 ? Math.round(totalComments / recent30DaysMedia.length) : 0;
  const avgSavesPerPost = recent30DaysMedia.length > 0 ? Math.round(totalSaves / recent30DaysMedia.length) : 0;
  const engagementRate = stats.followers_count > 0 && recent30DaysMedia.length > 0 ? ((totalLikes + totalComments + totalSaves + totalShares) / recent30DaysMedia.length / stats.followers_count * 100).toFixed(2) : "0.00";
  stats.platform_metrics = {
    collection_date: today,
    api_version: API_VERSION,
    data_methodology: "rolling_30_day_aggregates",
    time_windows: {
      followers_count: "current_snapshot",
      following_count: "current_snapshot",
      impressions: "last_30_days_total (post views)",
      reach: "last_30_days_total (post reach)",
      profile_views: "daily (account level)",
      likes_count: "last_30_days_total",
      comments_count: "last_30_days_total",
      saves_count: "last_30_days_total",
      shares_count: "last_30_days_total",
      posts_count: "today_only",
      reels_count: "today_only",
      stories_count: "active_stories (24h)"
    },
    account_daily: {
      date: today,
      profile_views: profileViews,
      website_clicks: websiteClicks,
      accounts_engaged: accountsEngaged,
      total_interactions: totalInteractions,
      views: accountViews,
      reach: accountReach,
      new_follows: newFollows,
      unfollows: unfollows,
      net_follower_change: newFollows - unfollows
    },
    last_30_days: {
      date_range: {
        start: last30DaysStr.split('T')[0],
        end: today,
        days: 30
      },
      totals: {
        posts: recent30DaysMedia.length,
        views: totalViews,
        reach: totalReach,
        likes: totalLikes,
        comments: totalComments,
        saves: totalSaves,
        shares: totalShares,
        total_engagement: totalLikes + totalComments + totalSaves + totalShares
      },
      averages: {
        views_per_post: postsWithInsights > 0 ? Math.round(totalViews / postsWithInsights) : 0,
        reach_per_post: postsWithInsights > 0 ? Math.round(totalReach / postsWithInsights) : 0,
        likes_per_post: avgLikesPerPost,
        comments_per_post: avgCommentsPerPost,
        saves_per_post: avgSavesPerPost,
        shares_per_post: recent30DaysMedia.length > 0 ? Math.round(totalShares / recent30DaysMedia.length) : 0,
        engagement_per_post: avgLikesPerPost + avgCommentsPerPost + avgSavesPerPost
      },
      rates: {
        engagement_rate: parseFloat(engagementRate)
      },
      content_breakdown: {
        images: recent30DaysMedia.filter((m)=>m.media_type === "IMAGE").length,
        carousels: recent30DaysMedia.filter((m)=>m.media_type === "CAROUSEL_ALBUM").length,
        reels: recent30DaysMedia.filter((m)=>m.media_product_type === "REELS").length,
        videos: recent30DaysMedia.filter((m)=>m.media_type === "VIDEO" && m.media_product_type !== "REELS").length
      }
    },
    today: {
      date: today,
      new_posts: stats.posts_count,
      new_reels: stats.reels_count,
      active_stories: storiesCount,
      total_new_content: stats.posts_count + stats.reels_count
    },
    account: {
      current_followers: stats.followers_count,
      current_following: stats.following_count,
      total_posts_all_time: allMedia.length,
      posts_in_30day_window: recent30DaysMedia.length
    },
    data_quality: {
      posts_analyzed: recent30DaysMedia.length,
      posts_with_insights: postsWithInsights,
      insights_coverage_pct: recent30DaysMedia.length > 0 ? parseFloat((postsWithInsights / recent30DaysMedia.length * 100).toFixed(1)) : 0,
      note: postsWithInsights > 0 ? `Successfully retrieved insights for ${postsWithInsights}/${recent30DaysMedia.length} posts` : "No post insights available"
    }
  };
  console.log(`📊 Instagram Stats Summary:`);
  console.log(`   ═══════════════════════════════════════`);
  console.log(`   API VERSION: ${API_VERSION}`);
  console.log(`   Followers: ${stats.followers_count.toLocaleString()}`);
  console.log(`   Views: ${totalViews.toLocaleString()}`);
  console.log(`   Reach: ${totalReach.toLocaleString()}`);
  console.log(`   Likes: ${totalLikes.toLocaleString()}`);
  console.log(`   Comments: ${totalComments.toLocaleString()}`);
  console.log(`   Saves: ${totalSaves.toLocaleString()}`);
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
