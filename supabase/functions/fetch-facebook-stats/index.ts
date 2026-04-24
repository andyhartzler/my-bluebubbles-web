// ============================================================================
// FACEBOOK STATS FETCHER EDGE FUNCTION (v24.0 - DECEMBER 2025)
// 
// CORRECT SETTINGS:
// - API Version: v24.0
// - post_media_view (singular, not plural) - replaces post_impressions
// - page_media_view (singular, not plural) - replaces page_impressions
// - post_clicks, post_reactions_by_type_total, post_activity_by_action_type
//
// NOTE: Demographics (page_fans_gender_age, page_fans_country, page_fans_city)
// were deprecated in March 2024. We still try to fetch them but they may return empty.
//
// Deploy: supabase functions deploy fetch-facebook-stats
// ============================================================================
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};
const API_VERSION = "v24.0";

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
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:fetch-facebook-stats",
      row_id: null,
      context: { event: "fetch-facebook-stats" }
    }).then(() => {}).catch((e) => console.error("[fetch-facebook-stats] audit_log insert failed:", e));
    console.log(`🔄 Starting Facebook stats fetch (${API_VERSION})...`);
    const { data: accounts, error: accountsError } = await supabase.from("social_media_accounts").select("*").eq("platform", "facebook").eq("is_active", true);
    if (accountsError) throw new Error(accountsError.message);
    if (!accounts || accounts.length === 0) {
      return new Response(JSON.stringify({
        message: "No Facebook accounts found"
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
        console.log(`📊 Fetching stats for Facebook Page: ${account.account_name}`);
        const { stats, demographics } = await fetchFacebookStats(account);
        const today = new Date().toISOString().split("T")[0];
        // Upsert stats
        const { error: insertError } = await supabase.from("social_media_stats").upsert({
          account_id: account.id,
          platform: "facebook",
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
          if (demographics && (demographics.age_gender_breakdown || demographics.top_countries)) {
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
async function fetchFacebookStats(account) {
  const accessToken = account.access_token;
  const pageId = account.account_id;
  const today = new Date().toISOString().split('T')[0];
  const stats = {};
  const demographics = {};
  // ========================================================================
  // 1. Get Page basic information (followers count)
  // ========================================================================
  console.log("Fetching page info...");
  const pageUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}` + `?fields=followers_count,fan_count,name` + `&access_token=${accessToken}`;
  const pageResponse = await fetch(pageUrl);
  const pageData = await pageResponse.json();
  if (pageData.error) {
    throw new Error(`Facebook API error: ${pageData.error.message}`);
  }
  stats.followers_count = pageData.followers_count || pageData.fan_count || 0;
  console.log(`✅ Followers: ${stats.followers_count}`);
  // ========================================================================
  // 2. Get Page-level insights (page_media_view for overall impressions)
  // ========================================================================
  console.log("Fetching page-level insights...");
  let pageMediaViews = 0;
  let pageVideoViews = 0;
  let pagePostEngagements = 0;
  let pageDailyFollows = 0;
  let pageDailyUnfollows = 0;
  let pageViewsTotal = 0;
  try {
    const pageInsightsUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/insights` + `?metric=page_media_view,page_video_views,page_post_engagements,page_daily_follows,page_daily_unfollows_unique,page_views_total` + `&period=day` + `&access_token=${accessToken}`;
    const pageInsightsResponse = await fetch(pageInsightsUrl);
    const pageInsightsData = await pageInsightsResponse.json();
    if (pageInsightsData.data) {
      for (const metric of pageInsightsData.data){
        const latestValue = metric.values?.[metric.values.length - 1]?.value || 0;
        switch(metric.name){
          case "page_media_view":
            pageMediaViews = latestValue;
            break;
          case "page_video_views":
            pageVideoViews = latestValue;
            break;
          case "page_post_engagements":
            pagePostEngagements = latestValue;
            break;
          case "page_daily_follows":
            pageDailyFollows = latestValue;
            break;
          case "page_daily_unfollows_unique":
            pageDailyUnfollows = latestValue;
            break;
          case "page_views_total":
            pageViewsTotal = latestValue;
            break;
        }
      }
      console.log(`✅ Page insights: media_views=${pageMediaViews}, video_views=${pageVideoViews}, engagements=${pagePostEngagements}, profile_views=${pageViewsTotal}`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch page insights: ${e.message}`);
  }
  // ========================================================================
  // 3. Get Demographics (NOTE: Mostly deprecated as of March 2024)
  // ========================================================================
  console.log("Fetching demographics (may be deprecated)...");
  // Try to get age/gender breakdown
  try {
    const ageGenderUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/insights` + `?metric=page_fans_gender_age` + `&period=lifetime` + `&access_token=${accessToken}`;
    const ageGenderResponse = await fetch(ageGenderUrl);
    const ageGenderData = await ageGenderResponse.json();
    if (ageGenderData.data && ageGenderData.data[0]?.values?.[0]?.value) {
      demographics.age_gender_breakdown = ageGenderData.data[0].values[0].value;
      console.log(`✅ Got age/gender demographics`);
    } else {
      console.log(`⚠️ Age/gender demographics not available (deprecated March 2024)`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch age/gender demographics: ${e.message}`);
  }
  // Try to get country breakdown
  try {
    const countryUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/insights` + `?metric=page_fans_country` + `&period=lifetime` + `&access_token=${accessToken}`;
    const countryResponse = await fetch(countryUrl);
    const countryData = await countryResponse.json();
    if (countryData.data && countryData.data[0]?.values?.[0]?.value) {
      demographics.top_countries = countryData.data[0].values[0].value;
      console.log(`✅ Got country demographics`);
    } else {
      console.log(`⚠️ Country demographics not available`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch country demographics: ${e.message}`);
  }
  // Try to get city breakdown
  try {
    const cityUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/insights` + `?metric=page_fans_city` + `&period=lifetime` + `&access_token=${accessToken}`;
    const cityResponse = await fetch(cityUrl);
    const cityData = await cityResponse.json();
    if (cityData.data && cityData.data[0]?.values?.[0]?.value) {
      demographics.top_cities = cityData.data[0].values[0].value;
      console.log(`✅ Got city demographics`);
    } else {
      console.log(`⚠️ City demographics not available`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch city demographics: ${e.message}`);
  }
  // Try to get language breakdown
  try {
    const localeUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/insights` + `?metric=page_fans_locale` + `&period=lifetime` + `&access_token=${accessToken}`;
    const localeResponse = await fetch(localeUrl);
    const localeData = await localeResponse.json();
    if (localeData.data && localeData.data[0]?.values?.[0]?.value) {
      demographics.top_languages = localeData.data[0].values[0].value;
      console.log(`✅ Got language demographics`);
    } else {
      console.log(`⚠️ Language demographics not available`);
    }
  } catch (e) {
    console.warn(`⚠️ Could not fetch language demographics: ${e.message}`);
  }
  // Build platform demographics metadata
  demographics.platform_demographics = {
    collection_date: today,
    api_version: API_VERSION,
    data_status: "Facebook deprecated most demographic metrics in March 2024",
    available_data: {
      age_gender: !!demographics.age_gender_breakdown,
      countries: !!demographics.top_countries,
      cities: !!demographics.top_cities,
      languages: !!demographics.top_languages
    }
  };
  // ========================================================================
  // 4. Get recent posts (past 30 days)
  // ========================================================================
  console.log("Fetching posts...");
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const since = thirtyDaysAgo.toISOString().split('T')[0];
  const postsUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/posts` + `?fields=id,message,created_time,shares,likes.summary(true),comments.summary(true),reactions.summary(true)` + `&since=${since}` + `&limit=100` + `&access_token=${accessToken}`;
  const postsResponse = await fetch(postsUrl);
  const postsData = await postsResponse.json();
  const posts = postsData.data || [];
  console.log(`✅ Found ${posts.length} posts from last 30 days`);
  // Count posts from today
  const todayPosts = posts.filter((p)=>p.created_time?.startsWith(today));
  stats.posts_count = todayPosts.length;
  // Aggregate engagement from post objects
  let totalLikes = 0;
  let totalComments = 0;
  let totalShares = 0;
  let totalReactions = 0;
  // Aggregate from post insights API
  let totalMediaViews = 0;
  let totalClicks = 0;
  let totalVideoViews = 0;
  let postsWithInsights = 0;
  // Reaction breakdown
  let reactionBreakdown = {
    like: 0,
    love: 0,
    wow: 0,
    haha: 0,
    sad: 0,
    angry: 0,
    care: 0
  };
  // Activity breakdown
  let activityBreakdown = {
    like: 0,
    comment: 0,
    share: 0
  };
  for (const post of posts){
    const likes = post.likes?.summary?.total_count || 0;
    const comments = post.comments?.summary?.total_count || 0;
    const shares = post.shares?.count || 0;
    const reactions = post.reactions?.summary?.total_count || 0;
    totalLikes += likes;
    totalComments += comments;
    totalShares += shares;
    totalReactions += reactions;
    try {
      const postInsightsUrl = `https://graph.facebook.com/${API_VERSION}/${post.id}/insights` + `?metric=post_media_view,post_clicks,post_reactions_by_type_total,post_activity_by_action_type,post_video_views` + `&access_token=${accessToken}`;
      const postInsightsResponse = await fetch(postInsightsUrl);
      const postInsightsData = await postInsightsResponse.json();
      if (!postInsightsData.error && postInsightsData.data && postInsightsData.data.length > 0) {
        postsWithInsights++;
        for (const metric of postInsightsData.data){
          const value = metric.values?.[0]?.value;
          switch(metric.name){
            case "post_media_view":
              if (typeof value === 'number') {
                totalMediaViews += value;
              }
              break;
            case "post_clicks":
              if (typeof value === 'number') {
                totalClicks += value;
              }
              break;
            case "post_video_views":
              if (typeof value === 'number') {
                totalVideoViews += value;
              }
              break;
            case "post_reactions_by_type_total":
              if (value && typeof value === 'object') {
                reactionBreakdown.like += value.like || 0;
                reactionBreakdown.love += value.love || 0;
                reactionBreakdown.wow += value.wow || 0;
                reactionBreakdown.haha += value.haha || 0;
                reactionBreakdown.sad += value.sad || value.sorry || 0;
                reactionBreakdown.angry += value.angry || value.anger || 0;
                reactionBreakdown.care += value.care || 0;
              }
              break;
            case "post_activity_by_action_type":
              if (value && typeof value === 'object') {
                activityBreakdown.like += value.like || 0;
                activityBreakdown.comment += value.comment || 0;
                activityBreakdown.share += value.share || 0;
              }
              break;
          }
        }
      }
    } catch (error) {
    // Skip silently
    }
  }
  // Store aggregated metrics
  stats.likes_count = totalReactions;
  stats.comments_count = totalComments;
  stats.shares_count = totalShares;
  stats.impressions = totalMediaViews;
  stats.reach = 0;
  stats.profile_views = pageViewsTotal;
  // Calculate rates
  const engagementRate = posts.length > 0 && stats.followers_count > 0 ? ((totalReactions + totalComments + totalShares) / posts.length / stats.followers_count * 100).toFixed(2) : "0.00";
  stats.platform_metrics = {
    collection_date: today,
    api_version: API_VERSION,
    data_methodology: "rolling_30_day_aggregates",
    time_windows: {
      followers_count: "current_snapshot",
      impressions: "last_30_days_total (post_media_view)",
      reach: "not_available",
      profile_views: "daily (page_views_total)",
      likes_count: "last_30_days_total",
      comments_count: "last_30_days_total",
      shares_count: "last_30_days_total",
      clicks: "last_30_days_total",
      video_views: "last_30_days_total",
      posts_count: "today_only"
    },
    page_daily: {
      date: today,
      media_views: pageMediaViews,
      video_views: pageVideoViews,
      engagements: pagePostEngagements,
      profile_views: pageViewsTotal,
      new_follows: pageDailyFollows,
      unfollows: pageDailyUnfollows,
      net_follower_change: pageDailyFollows - pageDailyUnfollows
    },
    last_30_days: {
      date_range: {
        start: since,
        end: today,
        days: 30
      },
      totals: {
        posts: posts.length,
        media_views: totalMediaViews,
        clicks: totalClicks,
        video_views: totalVideoViews,
        reactions: totalReactions,
        likes: totalLikes,
        comments: totalComments,
        shares: totalShares,
        total_engagement: totalReactions + totalComments + totalShares
      },
      averages: {
        media_views_per_post: posts.length > 0 ? Math.round(totalMediaViews / posts.length) : 0,
        clicks_per_post: posts.length > 0 ? Math.round(totalClicks / posts.length) : 0,
        reactions_per_post: posts.length > 0 ? Math.round(totalReactions / posts.length) : 0,
        comments_per_post: posts.length > 0 ? Math.round(totalComments / posts.length) : 0,
        shares_per_post: posts.length > 0 ? Math.round(totalShares / posts.length) : 0,
        engagement_per_post: posts.length > 0 ? Math.round((totalReactions + totalComments + totalShares) / posts.length) : 0
      },
      rates: {
        engagement_rate: parseFloat(engagementRate)
      },
      reactions_breakdown: reactionBreakdown,
      activity_breakdown: activityBreakdown
    },
    today: {
      date: today,
      new_posts: stats.posts_count
    },
    account: {
      current_followers: stats.followers_count,
      posts_in_30day_window: posts.length
    },
    data_quality: {
      posts_analyzed: posts.length,
      posts_with_insights: postsWithInsights,
      insights_coverage_pct: posts.length > 0 ? parseFloat((postsWithInsights / posts.length * 100).toFixed(1)) : 0,
      note: postsWithInsights > 0 ? `Successfully retrieved insights for ${postsWithInsights}/${posts.length} posts` : "No post insights available"
    }
  };
  // Get videos count
  console.log("Fetching videos...");
  const videosUrl = `https://graph.facebook.com/${API_VERSION}/${pageId}/videos` + `?fields=id,created_time` + `&limit=100` + `&access_token=${accessToken}`;
  const videosResponse = await fetch(videosUrl);
  const videosData = await videosResponse.json();
  if (!videosData.error && videosData.data) {
    const todayVideos = videosData.data.filter((v)=>v.created_time?.startsWith(today));
    stats.videos_count = todayVideos.length;
  } else {
    stats.videos_count = 0;
  }
  console.log(`📊 Facebook Stats Summary:`);
  console.log(`   ═══════════════════════════════════════`);
  console.log(`   API VERSION: ${API_VERSION}`);
  console.log(`   Followers: ${stats.followers_count.toLocaleString()}`);
  console.log(`   Media Views: ${totalMediaViews.toLocaleString()}`);
  console.log(`   Clicks: ${totalClicks.toLocaleString()}`);
  console.log(`   Reactions: ${totalReactions.toLocaleString()}`);
  console.log(`   Comments: ${totalComments.toLocaleString()}`);
  console.log(`   Shares: ${totalShares.toLocaleString()}`);
  console.log(`   Engagement Rate: ${engagementRate}%`);
  console.log(`   Demographics available: ${Object.values(demographics.platform_demographics?.available_data || {}).filter(Boolean).length}/4`);
  console.log(`   ═══════════════════════════════════════`);
  return {
    stats,
    demographics
  };
}
