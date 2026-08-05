// supabase/functions/fetch-slack-avatars/index.ts
//
// ONE-TIME FUNCTION: Fetches avatar URLs from Slack API for all users
// and updates slack_user_mapping AND slack_users_unmatched tables
//
// Run this once to backfill avatar URLs for existing users
// After this, the slack-events function will keep them updated
//
// Usage: POST /functions/v1/fetch-slack-avatars
// Body: {"limit": 200} (optional, defaults to all users)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireCronSecret } from "../_shared/machine-auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-cron-secret",
};

interface SlackUser {
  id: string;
  name: string;
  real_name?: string;
  deleted: boolean;
  is_bot: boolean;
  is_admin?: boolean;
  profile: {
    email?: string;
    display_name?: string;
    real_name?: string;
    image_24?: string;
    image_32?: string;
    image_48?: string;
    image_72?: string;
    image_192?: string;
    image_512?: string;
    image_original?: string;
  };
}

interface SlackUsersResponse {
  ok: boolean;
  members?: SlackUser[];
  response_metadata?: {
    next_cursor?: string;
  };
  error?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const denied = requireCronSecret(req, corsHeaders);
  if (denied) return denied;

  const startTime = Date.now();
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const slackToken = Deno.env.get("SLACK_BOT_TOKEN");

  if (!slackToken) {
    return new Response(
      JSON.stringify({ error: "SLACK_BOT_TOKEN not configured" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // Parse options
  let options = { limit: 0 }; // 0 = no limit
  try {
    if (req.body) {
      const body = await req.json();
      options = { ...options, ...body };
    }
  } catch {
    // Use defaults
  }

  const results = {
    slack_users_fetched: 0,
    existing_mappings_updated: 0,
    new_mappings_created: 0,
    unmatched_updated: 0,
    skipped_bots: 0,
    skipped_no_match: 0,
    errors: [] as string[],
  };

  try {
    console.log("[fetch-slack-avatars] Fetching all Slack users...");

    // Fetch ALL Slack users (handles pagination)
    let allSlackUsers: SlackUser[] = [];
    let cursor: string | undefined;

    do {
      const url = new URL("https://slack.com/api/users.list");
      url.searchParams.set("limit", "200");
      if (cursor) {
        url.searchParams.set("cursor", cursor);
      }

      const response = await fetch(url.toString(), {
        headers: {
          "Authorization": `Bearer ${slackToken}`,
          "Content-Type": "application/json",
        },
      });

      const data: SlackUsersResponse = await response.json();

      if (!data.ok) {
        throw new Error(`Slack API error: ${data.error}`);
      }

      if (data.members) {
        allSlackUsers = allSlackUsers.concat(data.members);
      }

      cursor = data.response_metadata?.next_cursor;
      
      // Rate limiting
      await new Promise((resolve) => setTimeout(resolve, 100));
    } while (cursor && cursor !== "");

    results.slack_users_fetched = allSlackUsers.length;
    console.log(`[fetch-slack-avatars] Fetched ${allSlackUsers.length} users from Slack`);

    // Get all existing mappings
    const { data: existingMappings } = await supabase
      .from("slack_user_mapping")
      .select("id, slack_user_id, slack_avatar_url, member_id");

    const mappingsBySlackId = new Map(
      (existingMappings || []).map((m: any) => [m.slack_user_id, m])
    );

    // Get all unmatched users
    const { data: unmatchedUsers } = await supabase
      .from("slack_users_unmatched")
      .select("id, slack_user_id, slack_avatar_url");

    const unmatchedBySlackId = new Map(
      (unmatchedUsers || []).map((u: any) => [u.slack_user_id, u])
    );

    // Process each Slack user
    let processed = 0;
    for (const slackUser of allSlackUsers) {
      // Apply limit if specified
      if (options.limit > 0 && processed >= options.limit) {
        break;
      }

      // Skip bots only
      if (slackUser.is_bot) {
        results.skipped_bots++;
        continue;
      }

      // NOTE: We do NOT skip deleted users anymore

      const avatarUrl = slackUser.profile?.image_512 || 
                        slackUser.profile?.image_192 || 
                        slackUser.profile?.image_72;

      const existingMapping = mappingsBySlackId.get(slackUser.id);
      const existingUnmatched = unmatchedBySlackId.get(slackUser.id);

      if (existingMapping) {
        // Update existing mapping with avatar URL (and other metadata)
        const { error } = await supabase
          .from("slack_user_mapping")
          .update({
            slack_avatar_url: avatarUrl,
            slack_display_name: slackUser.profile?.display_name || existingMapping.slack_display_name,
            slack_real_name: slackUser.real_name || existingMapping.slack_real_name,
            slack_email: slackUser.profile?.email || existingMapping.slack_email,
            slack_is_admin: slackUser.is_admin || false,
            slack_deleted: slackUser.deleted || false,
            last_synced_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", existingMapping.id);

        if (error) {
          results.errors.push(`Update mapping ${slackUser.id}: ${error.message}`);
        } else {
          results.existing_mappings_updated++;
          console.log(`[fetch-slack-avatars] Updated mapping: ${slackUser.real_name || slackUser.id}`);
        }
      } else if (existingUnmatched) {
        // Update existing unmatched user with avatar URL
        const { error } = await supabase
          .from("slack_users_unmatched")
          .update({
            slack_avatar_url: avatarUrl,
            slack_display_name: slackUser.profile?.display_name,
            slack_real_name: slackUser.real_name,
            slack_email: slackUser.profile?.email,
          })
          .eq("id", existingUnmatched.id);

        if (error) {
          results.errors.push(`Update unmatched ${slackUser.id}: ${error.message}`);
        } else {
          results.unmatched_updated++;
          console.log(`[fetch-slack-avatars] Updated unmatched: ${slackUser.real_name || slackUser.id}`);
        }
      } else {
        // No existing mapping - try to find matching member by email
        const email = slackUser.profile?.email;
        
        if (!email) {
          // No email - add to unmatched
          const { error } = await supabase
            .from("slack_users_unmatched")
            .upsert({
              slack_user_id: slackUser.id,
              slack_email: null,
              slack_real_name: slackUser.real_name,
              slack_display_name: slackUser.profile?.display_name,
              slack_avatar_url: avatarUrl,
              notes: "No email in Slack profile",
            }, { onConflict: "slack_user_id" });

          if (!error) {
            results.unmatched_updated++;
          }
          results.skipped_no_match++;
          continue;
        }

        // Try to match by email
        const { data: member } = await supabase
          .from("members")
          .select("id")
          .or(`email.eq.${email},school_email.eq.${email}`)
          .single();

        if (member) {
          // Create new mapping
          const { error } = await supabase
            .from("slack_user_mapping")
            .insert({
              member_id: member.id,
              slack_user_id: slackUser.id,
              slack_email: email,
              slack_display_name: slackUser.profile?.display_name,
              slack_real_name: slackUser.real_name,
              slack_avatar_url: avatarUrl,
              slack_is_admin: slackUser.is_admin || false,
              slack_is_bot: false,
              slack_deleted: slackUser.deleted || false,
              matched_by: "email",
              match_confidence: 1.0,
              last_synced_at: new Date().toISOString(),
            });

          if (error) {
            if (error.code === "23505") {
              // Duplicate - already exists
              results.skipped_no_match++;
            } else {
              results.errors.push(`Insert ${slackUser.id}: ${error.message}`);
            }
          } else {
            results.new_mappings_created++;
            console.log(`[fetch-slack-avatars] Created mapping: ${slackUser.real_name || slackUser.id}`);
          }
        } else {
          // No member match - add to unmatched table
          const { error } = await supabase
            .from("slack_users_unmatched")
            .upsert({
              slack_user_id: slackUser.id,
              slack_email: email,
              slack_real_name: slackUser.real_name,
              slack_display_name: slackUser.profile?.display_name,
              slack_avatar_url: avatarUrl,
              notes: "No matching member found",
            }, { onConflict: "slack_user_id" });

          if (!error) {
            results.unmatched_updated++;
          }
          results.skipped_no_match++;
        }
      }

      processed++;

      // Small delay to avoid overwhelming the database
      if (processed % 50 === 0) {
        await new Promise((resolve) => setTimeout(resolve, 100));
      }
    }

    // Now trigger the avatar sync to download the images
    console.log("[fetch-slack-avatars] Avatar URLs updated. Triggering image download...");

    // Call sync-slack-avatars to download the actual images
    const syncResponse = await fetch(
      `${supabaseUrl}/functions/v1/sync-slack-avatars`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${supabaseServiceKey}`,
        },
        body: JSON.stringify({ source: "manual", limit: 500 }),
      }
    );

    let syncResult = null;
    try {
      syncResult = await syncResponse.json();
    } catch {
      // Ignore parse errors
    }

    return new Response(
      JSON.stringify({
        success: true,
        ...results,
        avatar_sync_triggered: syncResponse.ok,
        avatar_sync_result: syncResult,
        duration_ms: Date.now() - startTime,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("[fetch-slack-avatars] Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
        ...results,
        duration_ms: Date.now() - startTime,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});