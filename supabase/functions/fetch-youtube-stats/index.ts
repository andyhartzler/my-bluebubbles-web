// ============================================================================
// FETCH YOUTUBE STATS - Using Service Account Authentication
// 
// Collects: channel stats, video performance, engagement metrics
// Auth: Google Service Account (stored in SERVICE_ACCOUNT_JSON secret)
// API: YouTube Data API v3
//
// Deploy: supabase functions deploy fetch-youtube-stats
// Test: curl -X POST "https://your-project.supabase.co/functions/v1/fetch-youtube-stats"
// ============================================================================
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};

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

const YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3";
const YOUTUBE_ANALYTICS_BASE = "https://youtubeanalytics.googleapis.com/v2";
// ============================================================================
// SERVICE ACCOUNT AUTH - Generate access token from service account JSON
// ============================================================================
async function getAccessToken() {
  const serviceAccountJson = Deno.env.get("SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    throw new Error("SERVICE_ACCOUNT_JSON not found in environment");
  }
  const serviceAccount = JSON.parse(serviceAccountJson);
  // Create JWT header and claims
  const header = {
    alg: "RS256",
    typ: "JWT"
  };
  const now = Math.floor(Date.now() / 1000);
  // Email to impersonate via domain-wide delegation
  const impersonateEmail = Deno.env.get("YOUTUBE_IMPERSONATE_EMAIL") || "andrew@moyoungdemocrats.org";
  const claims = {
    iss: serviceAccount.client_email,
    sub: impersonateEmail,
    scope: "https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/yt-analytics.readonly",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600
  };
  // Base64URL encode
  const base64UrlEncode = (obj)=>{
    const json = JSON.stringify(obj);
    const base64 = btoa(json);
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  };
  const headerEncoded = base64UrlEncode(header);
  const claimsEncoded = base64UrlEncode(claims);
  const signatureInput = `${headerEncoded}.${claimsEncoded}`;
  // Import private key and sign
  const privateKeyPem = serviceAccount.private_key;
  const pemContents = privateKeyPem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '');
  const binaryKey = Uint8Array.from(atob(pemContents), (c)=>c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey("pkcs8", binaryKey, {
    name: "RSASSA-PKCS1-v1_5",
    hash: "SHA-256"
  }, false, [
    "sign"
  ]);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(signatureInput));
  const signatureEncoded = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  const jwt = `${signatureInput}.${signatureEncoded}`;
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
  const tokenData = await tokenResponse.json();
  if (tokenData.error) {
    throw new Error(`Token error: ${tokenData.error_description || tokenData.error}`);
  }
  return tokenData.access_token;
}
// ============================================================================
// YOUTUBE API HELPERS
// ============================================================================
async function youtubeApiCall(endpoint, params, accessToken) {
  const url = new URL(`${YOUTUBE_API_BASE}/${endpoint}`);
  Object.entries(params).forEach(([key, value])=>url.searchParams.append(key, value));
  const response = await fetch(url.toString(), {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`YouTube API error: ${response.status} - ${errorText}`);
  }
  return response.json();
}
// Get channel ID from handle (like @MOYoungDemocrats)
async function getChannelIdFromHandle(handle, accessToken) {
  // Remove @ if present
  const cleanHandle = handle.replace('@', '');
  try {
    // Try to search for the channel by handle
    const searchResult = await youtubeApiCall("search", {
      part: "snippet",
      q: cleanHandle,
      type: "channel",
      maxResults: "5"
    }, accessToken);
    if (searchResult.items && searchResult.items.length > 0) {
      // Find exact match
      for (const item of searchResult.items){
        if (item.snippet.customUrl?.toLowerCase() === `@${cleanHandle.toLowerCase()}` || item.snippet.title.toLowerCase().includes(cleanHandle.toLowerCase())) {
          return item.snippet.channelId;
        }
      }
      // Return first result if no exact match
      return searchResult.items[0].snippet.channelId;
    }
    return null;
  } catch (error) {
    console.error("Error finding channel:", error);
    return null;
  }
}
// Get channel statistics
async function getChannelStats(channelId, accessToken) {
  const result = await youtubeApiCall("channels", {
    part: "snippet,statistics,contentDetails",
    id: channelId
  }, accessToken);
  if (!result.items || result.items.length === 0) {
    throw new Error(`Channel not found: ${channelId}`);
  }
  const channel = result.items[0];
  return {
    channelId: channel.id,
    title: channel.snippet.title,
    description: channel.snippet.description,
    customUrl: channel.snippet.customUrl,
    publishedAt: channel.snippet.publishedAt,
    thumbnailUrl: channel.snippet.thumbnails?.default?.url,
    statistics: {
      subscriberCount: parseInt(channel.statistics.subscriberCount || "0"),
      viewCount: parseInt(channel.statistics.viewCount || "0"),
      videoCount: parseInt(channel.statistics.videoCount || "0"),
      hiddenSubscriberCount: channel.statistics.hiddenSubscriberCount || false
    },
    uploadsPlaylistId: channel.contentDetails?.relatedPlaylists?.uploads
  };
}
// Get recent videos from uploads playlist
async function getRecentVideos(playlistId, accessToken, maxResults = 10) {
  const result = await youtubeApiCall("playlistItems", {
    part: "snippet,contentDetails",
    playlistId: playlistId,
    maxResults: maxResults.toString()
  }, accessToken);
  return result.items?.map((item)=>({
      videoId: item.contentDetails.videoId,
      title: item.snippet.title,
      description: item.snippet.description,
      publishedAt: item.snippet.publishedAt,
      thumbnailUrl: item.snippet.thumbnails?.medium?.url
    })) || [];
}
// Get video statistics for multiple videos
async function getVideoStats(videoIds, accessToken) {
  if (videoIds.length === 0) return [];
  const result = await youtubeApiCall("videos", {
    part: "statistics,contentDetails",
    id: videoIds.join(",")
  }, accessToken);
  return result.items?.map((item)=>({
      videoId: item.id,
      viewCount: parseInt(item.statistics.viewCount || "0"),
      likeCount: parseInt(item.statistics.likeCount || "0"),
      commentCount: parseInt(item.statistics.commentCount || "0"),
      duration: item.contentDetails.duration
    })) || [];
}
// ============================================================================
// YOUTUBE ANALYTICS API - Demographics
// ============================================================================
async function analyticsApiCall(params, accessToken) {
  const url = new URL(`${YOUTUBE_ANALYTICS_BASE}/reports`);
  Object.entries(params).forEach(([key, value])=>url.searchParams.append(key, value));
  const response = await fetch(url.toString(), {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });
  if (!response.ok) {
    const errorText = await response.text();
    console.error(`YouTube Analytics API error: ${response.status} - ${errorText}`);
    return null;
  }
  return response.json();
}
// Get age and gender demographics
async function getAgeGenderDemographics(channelId, accessToken) {
  const endDate = new Date().toISOString().split("T")[0];
  const startDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0]; // 90 days ago
  const result = await analyticsApiCall({
    ids: `channel==${channelId}`,
    startDate,
    endDate,
    metrics: "viewerPercentage",
    dimensions: "ageGroup,gender"
  }, accessToken);
  if (!result || !result.rows) return null;
  const demographics = {};
  for (const row of result.rows){
    const [ageGroup, gender, percentage] = row;
    const key = `${gender}_${ageGroup}`;
    demographics[key] = percentage;
  }
  return demographics;
}
// Get country demographics
async function getCountryDemographics(channelId, accessToken) {
  const endDate = new Date().toISOString().split("T")[0];
  const startDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const result = await analyticsApiCall({
    ids: `channel==${channelId}`,
    startDate,
    endDate,
    metrics: "views,estimatedMinutesWatched",
    dimensions: "country",
    sort: "-views",
    maxResults: "25"
  }, accessToken);
  if (!result || !result.rows) return null;
  return result.rows.map((row)=>({
      country: row[0],
      views: row[1],
      watchTimeMinutes: row[2]
    }));
}
// Get traffic source demographics
async function getTrafficSources(channelId, accessToken) {
  const endDate = new Date().toISOString().split("T")[0];
  const startDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const result = await analyticsApiCall({
    ids: `channel==${channelId}`,
    startDate,
    endDate,
    metrics: "views,estimatedMinutesWatched",
    dimensions: "insightTrafficSourceType",
    sort: "-views"
  }, accessToken);
  if (!result || !result.rows) return null;
  return result.rows.map((row)=>({
      source: row[0],
      views: row[1],
      watchTimeMinutes: row[2]
    }));
}
// Get device type breakdown
async function getDeviceTypes(channelId, accessToken) {
  const endDate = new Date().toISOString().split("T")[0];
  const startDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const result = await analyticsApiCall({
    ids: `channel==${channelId}`,
    startDate,
    endDate,
    metrics: "views,estimatedMinutesWatched",
    dimensions: "deviceType",
    sort: "-views"
  }, accessToken);
  if (!result || !result.rows) return null;
  return result.rows.map((row)=>({
      device: row[0],
      views: row[1],
      watchTimeMinutes: row[2]
    }));
}
// ============================================================================
// MAIN HANDLER
// ============================================================================
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
      table_name: "edge_fn:fetch-youtube-stats",
      row_id: null,
      context: { event: "fetch-youtube-stats" }
    }).then(() => {}).catch((e) => console.error("[fetch-youtube-stats] audit_log insert failed:", e));
    console.log("🎬 Fetching YouTube stats...");
    // Get access token from service account
    const accessToken = await getAccessToken();
    console.log("✅ Got access token from service account");
    // Get YouTube accounts from database
    const { data: accounts, error: accountsError } = await supabase.from("social_media_accounts").select("*").eq("platform", "youtube").eq("is_active", true);
    if (accountsError) {
      throw new Error(`Database error: ${accountsError.message}`);
    }
    if (!accounts || accounts.length === 0) {
      return new Response(JSON.stringify({
        success: false,
        error: "No active YouTube accounts found in database",
        hint: "Add a YouTube account with platform='youtube' and account_id=channel_id or account_name=@handle"
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const results = [];
    const today = new Date().toISOString().split("T")[0];
    for (const account of accounts){
      try {
        console.log(`\n📺 Processing YouTube account: ${account.account_name}`);
        // Get channel ID - either from account_id or resolve from handle
        let channelId = account.account_id;
        if (!channelId || channelId.startsWith("@")) {
          const handle = account.account_name || account.account_id;
          console.log(`🔍 Resolving channel handle: ${handle}`);
          channelId = await getChannelIdFromHandle(handle, accessToken);
          if (!channelId) {
            throw new Error(`Could not find channel for handle: ${handle}`);
          }
          // Update the account with resolved channel ID
          await supabase.from("social_media_accounts").update({
            account_id: channelId
          }).eq("id", account.id);
          console.log(`✅ Resolved to channel ID: ${channelId}`);
        }
        // Get channel stats
        const channelStats = await getChannelStats(channelId, accessToken);
        console.log(`📊 Channel: ${channelStats.title}`);
        console.log(`   Subscribers: ${channelStats.statistics.subscriberCount}`);
        console.log(`   Total Views: ${channelStats.statistics.viewCount}`);
        console.log(`   Videos: ${channelStats.statistics.videoCount}`);
        // Get recent videos
        const recentVideos = await getRecentVideos(channelStats.uploadsPlaylistId, accessToken, 10);
        console.log(`🎥 Found ${recentVideos.length} recent videos`);
        // Get video stats
        const videoIds = recentVideos.map((v)=>v.videoId);
        const videoStats = await getVideoStats(videoIds, accessToken);
        // Combine video info with stats
        const videosWithStats = recentVideos.map((video)=>{
          const stats = videoStats.find((s)=>s.videoId === video.videoId);
          return {
            ...video,
            ...stats
          };
        });
        // Calculate aggregates for recent videos
        const last30DaysVideos = videosWithStats.filter((v)=>{
          const publishDate = new Date(v.publishedAt);
          const thirtyDaysAgo = new Date();
          thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
          return publishDate >= thirtyDaysAgo;
        });
        const aggregates = {
          totalViews: videosWithStats.reduce((sum, v)=>sum + (v.viewCount || 0), 0),
          totalLikes: videosWithStats.reduce((sum, v)=>sum + (v.likeCount || 0), 0),
          totalComments: videosWithStats.reduce((sum, v)=>sum + (v.commentCount || 0), 0),
          videosAnalyzed: videosWithStats.length,
          videosLast30Days: last30DaysVideos.length,
          avgViewsPerVideo: videosWithStats.length > 0 ? Math.round(videosWithStats.reduce((sum, v)=>sum + (v.viewCount || 0), 0) / videosWithStats.length) : 0,
          avgLikesPerVideo: videosWithStats.length > 0 ? Math.round(videosWithStats.reduce((sum, v)=>sum + (v.likeCount || 0), 0) / videosWithStats.length) : 0
        };
        // Prepare platform metrics
        const platformMetrics = {
          collection_date: today,
          api_version: "v3",
          channel: {
            id: channelStats.channelId,
            title: channelStats.title,
            customUrl: channelStats.customUrl,
            description: channelStats.description?.substring(0, 200),
            publishedAt: channelStats.publishedAt
          },
          statistics: channelStats.statistics,
          recent_videos: videosWithStats.slice(0, 5).map((v)=>({
              videoId: v.videoId,
              title: v.title,
              publishedAt: v.publishedAt,
              viewCount: v.viewCount,
              likeCount: v.likeCount,
              commentCount: v.commentCount
            })),
          aggregates,
          data_methodology: "channel_stats_plus_recent_10_videos"
        };
        // Upsert to social_media_stats
        const { error: upsertError } = await supabase.from("social_media_stats").upsert({
          account_id: account.id,
          platform: "youtube",
          metric_date: today,
          metric_hour: null,
          followers_count: channelStats.statistics.subscriberCount,
          subscriber_count: channelStats.statistics.subscriberCount,
          impressions: channelStats.statistics.viewCount,
          posts_count: channelStats.statistics.videoCount,
          likes_count: aggregates.totalLikes,
          comments_count: aggregates.totalComments,
          videos_count: channelStats.statistics.videoCount,
          platform_metrics: platformMetrics,
          updated_at: new Date().toISOString()
        }, {
          onConflict: "account_id,metric_date,metric_hour"
        });
        if (upsertError) {
          console.error("❌ Error saving metrics:", upsertError);
          throw upsertError;
        }
        console.log(`✅ Saved YouTube metrics for ${channelStats.title}`);
        // Update last_synced_at
        await supabase.from("social_media_accounts").update({
          last_synced_at: new Date().toISOString()
        }).eq("id", account.id);
        // ====================================================================
        // FETCH DEMOGRAPHICS (YouTube Analytics API)
        // ====================================================================
        let demographicsResult = null;
        try {
          console.log(`📊 Fetching demographics for ${channelStats.title}...`);
          const [ageGender, countries, trafficSources, devices] = await Promise.all([
            getAgeGenderDemographics(channelId, accessToken),
            getCountryDemographics(channelId, accessToken),
            getTrafficSources(channelId, accessToken),
            getDeviceTypes(channelId, accessToken)
          ]);
          if (ageGender || countries || trafficSources || devices) {
            const platformDemographics = {
              collection_date: today,
              period: "last_90_days",
              traffic_sources: trafficSources,
              device_types: devices
            };
            // Upsert demographics
            const { error: demoError } = await supabase.from("social_media_audience_demographics").upsert({
              account_id: account.id,
              metric_date: today,
              age_gender_breakdown: ageGender || {},
              top_countries: countries || [],
              top_cities: {},
              top_languages: {},
              platform_demographics: platformDemographics,
              updated_at: new Date().toISOString()
            }, {
              onConflict: "account_id,metric_date"
            });
            if (demoError) {
              console.error("❌ Error saving demographics:", demoError);
            } else {
              console.log(`✅ Saved YouTube demographics`);
              demographicsResult = {
                hasAgeGender: !!ageGender,
                countriesCount: countries?.length || 0,
                trafficSourcesCount: trafficSources?.length || 0,
                devicesCount: devices?.length || 0
              };
            }
          } else {
            console.log(`⚠️ No demographics data available (may need domain-wide delegation scopes)`);
          }
        } catch (demoError) {
          console.error(`⚠️ Demographics fetch failed (non-fatal):`, demoError);
        }
        console.log(`✅ Completed YouTube data collection for ${channelStats.title}`);
        results.push({
          account: account.account_name,
          success: true,
          stats: {
            subscribers: channelStats.statistics.subscriberCount,
            totalViews: channelStats.statistics.viewCount,
            videoCount: channelStats.statistics.videoCount,
            recentVideosAnalyzed: videosWithStats.length
          },
          demographics: demographicsResult
        });
      } catch (accountError) {
        console.error(`❌ Error processing ${account.account_name}:`, accountError);
        results.push({
          account: account.account_name,
          success: false,
          error: accountError.message
        });
      }
    }
    return new Response(JSON.stringify({
      success: true,
      collection_date: today,
      results
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("❌ Fatal error:", error);
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
