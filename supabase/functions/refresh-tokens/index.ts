// ============================================================================
// TOKEN REFRESH EDGE FUNCTION
// 
// Refreshes long-lived tokens before they expire:
// - Threads: 60-day tokens, refreshable via th_refresh_token
// - Instagram: 60-day tokens, refreshable via ig_refresh_token (if needed)
//
// Schedule this to run daily or weekly via cron
// Deploy: supabase functions deploy refresh-tokens
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Refresh tokens that expire within this many days
const REFRESH_THRESHOLD_DAYS = 7;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    console.log("🔄 Starting token refresh check...");

    const results = [];

    // ========================================================================
    // 1. Refresh Threads Tokens
    // ========================================================================
    const { data: threadsAccounts, error: threadsError } = await supabase
      .from("social_media_accounts")
      .select("*")
      .eq("platform", "threads")
      .eq("is_active", true);

    if (threadsError) {
      console.error("Error fetching Threads accounts:", threadsError);
    } else if (threadsAccounts && threadsAccounts.length > 0) {
      for (const account of threadsAccounts) {
        const result = await refreshThreadsToken(supabase, account);
        results.push(result);
      }
    }

    // ========================================================================
    // 2. Refresh Instagram Tokens (if needed)
    // ========================================================================
    const { data: instagramAccounts, error: instagramError } = await supabase
      .from("social_media_accounts")
      .select("*")
      .eq("platform", "instagram")
      .eq("is_active", true);

    if (instagramError) {
      console.error("Error fetching Instagram accounts:", instagramError);
    } else if (instagramAccounts && instagramAccounts.length > 0) {
      for (const account of instagramAccounts) {
        const result = await refreshInstagramToken(supabase, account);
        results.push(result);
      }
    }

    // Facebook Page tokens are permanent (no refresh needed)
    console.log("ℹ️ Facebook Page tokens are permanent - no refresh needed");

    return new Response(JSON.stringify({ 
      success: true, 
      message: "Token refresh check complete",
      results 
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Fatal error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ============================================================================
// THREADS TOKEN REFRESH
// ============================================================================
async function refreshThreadsToken(supabase: any, account: any) {
  console.log(`🧵 Checking Threads token for: ${account.account_name}`);

  try {
    // Check if token needs refresh by checking expiration
    const shouldRefresh = await shouldRefreshToken(account);
    
    if (!shouldRefresh) {
      console.log(`✅ Threads token for ${account.account_name} is still valid`);
      return {
        platform: "threads",
        account: account.account_name,
        action: "skipped",
        reason: "Token still valid"
      };
    }

    console.log(`🔄 Refreshing Threads token for: ${account.account_name}`);

    // Refresh the token
    const refreshUrl = `https://graph.threads.net/refresh_access_token` +
      `?grant_type=th_refresh_token` +
      `&access_token=${account.access_token}`;

    const response = await fetch(refreshUrl);
    const data = await response.json();

    if (data.error) {
      console.error(`❌ Threads token refresh failed:`, data.error);
      return {
        platform: "threads",
        account: account.account_name,
        action: "failed",
        error: data.error.message
      };
    }

    // Calculate new expiration date
    const expiresIn = data.expires_in || 5184000; // Default 60 days
    const newExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    // Update the token in database
    const { error: updateError } = await supabase
      .from("social_media_accounts")
      .update({
        access_token: data.access_token,
        token_expires_at: newExpiresAt,
        updated_at: new Date().toISOString()
      })
      .eq("id", account.id);

    if (updateError) {
      console.error(`❌ Failed to update token in database:`, updateError);
      return {
        platform: "threads",
        account: account.account_name,
        action: "failed",
        error: updateError.message
      };
    }

    console.log(`✅ Threads token refreshed for ${account.account_name}, expires: ${newExpiresAt}`);
    return {
      platform: "threads",
      account: account.account_name,
      action: "refreshed",
      expires_at: newExpiresAt
    };

  } catch (error) {
    console.error(`❌ Error refreshing Threads token:`, error);
    return {
      platform: "threads",
      account: account.account_name,
      action: "failed",
      error: error.message
    };
  }
}

// ============================================================================
// INSTAGRAM TOKEN REFRESH
// ============================================================================
async function refreshInstagramToken(supabase: any, account: any) {
  console.log(`📸 Checking Instagram token for: ${account.account_name}`);

  try {
    // Check if token needs refresh
    const shouldRefresh = await shouldRefreshToken(account);
    
    if (!shouldRefresh) {
      console.log(`✅ Instagram token for ${account.account_name} is still valid`);
      return {
        platform: "instagram",
        account: account.account_name,
        action: "skipped",
        reason: "Token still valid"
      };
    }

    console.log(`🔄 Refreshing Instagram token for: ${account.account_name}`);

    // Instagram uses the Facebook Graph API for token refresh
    const refreshUrl = `https://graph.facebook.com/v24.0/oauth/access_token` +
      `?grant_type=fb_exchange_token` +
      `&client_id=${Deno.env.get("FACEBOOK_APP_ID") || "25535357332743174"}` +
      `&client_secret=${Deno.env.get("FACEBOOK_APP_SECRET") || ""}` +
      `&fb_exchange_token=${account.access_token}`;

    const response = await fetch(refreshUrl);
    const data = await response.json();

    if (data.error) {
      console.error(`❌ Instagram token refresh failed:`, data.error);
      return {
        platform: "instagram",
        account: account.account_name,
        action: "failed",
        error: data.error.message
      };
    }

    // Calculate new expiration date (Instagram tokens are ~60 days)
    const expiresIn = data.expires_in || 5184000;
    const newExpiresAt = new Date(Date.now() + expiresIn * 1000).toISOString();

    // Update the token in database
    const { error: updateError } = await supabase
      .from("social_media_accounts")
      .update({
        access_token: data.access_token,
        token_expires_at: newExpiresAt,
        updated_at: new Date().toISOString()
      })
      .eq("id", account.id);

    if (updateError) {
      console.error(`❌ Failed to update token in database:`, updateError);
      return {
        platform: "instagram",
        account: account.account_name,
        action: "failed",
        error: updateError.message
      };
    }

    console.log(`✅ Instagram token refreshed for ${account.account_name}, expires: ${newExpiresAt}`);
    return {
      platform: "instagram",
      account: account.account_name,
      action: "refreshed",
      expires_at: newExpiresAt
    };

  } catch (error) {
    console.error(`❌ Error refreshing Instagram token:`, error);
    return {
      platform: "instagram",
      account: account.account_name,
      action: "failed",
      error: error.message
    };
  }
}

// ============================================================================
// HELPER: Check if token should be refreshed
// ============================================================================
async function shouldRefreshToken(account: any): Promise<boolean> {
  // If no expiration date stored, try to refresh anyway
  if (!account.token_expires_at) {
    console.log(`⚠️ No expiration date stored for ${account.account_name}, will attempt refresh`);
    return true;
  }

  const expiresAt = new Date(account.token_expires_at);
  const now = new Date();
  const daysUntilExpiry = (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);

  console.log(`📅 Token for ${account.account_name} expires in ${daysUntilExpiry.toFixed(1)} days`);

  // Refresh if expiring within threshold
  return daysUntilExpiry <= REFRESH_THRESHOLD_DAYS;
}