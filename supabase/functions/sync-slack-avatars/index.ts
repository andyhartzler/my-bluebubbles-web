// supabase/functions/sync-slack-avatars/index.ts
//
// Batch downloads Slack avatars and caches them in Supabase Storage
// Pre-configured for: https://faajpcarasilbfndzkmd.supabase.co
// 
// NOW HANDLES BOTH:
// - public.slack_user_mapping (matched users)
// - public.slack_users_unmatched (unmatched users)
//
// Modes:
// - "queue": Process pending items from slack_avatar_sync_queue (triggered by new users)
// - "cron": Full scan for any users needing sync (daily job)
// - "manual": Same as cron but triggered manually
// - "force": Re-download all avatars regardless of cache status
//
// Test in Supabase UI with body: {"source": "manual", "limit": 100}

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireCronSecret } from "../_shared/machine-auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-cron-secret",
};

const SUPABASE_URL = "https://faajpcarasilbfndzkmd.supabase.co";
const STORAGE_BUCKET = "avatars";

interface SyncOptions {
  source?: "queue" | "cron" | "manual";
  limit?: number;
  force?: boolean;
}

interface SyncResult {
  processed: number;
  cached: number;
  skipped: number;
  failed: number;
  unchanged: number;
  matched_cached: number;
  unmatched_cached: number;
  errors: string[];
}

interface UserToProcess {
  id: string;
  slack_user_id: string;
  slack_avatar_url: string;
  slack_display_name?: string;
  slack_real_name?: string;
  cached_avatar_path?: string;
  cached_avatar_source_url?: string;
  queue_id?: string;
  is_unmatched: boolean;  // Flag to know which table to update
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const denied = requireCronSecret(req, corsHeaders);
  if (denied) return denied;

  const startTime = Date.now();
  
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || SUPABASE_URL;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  let options: SyncOptions = { source: "manual", limit: 100, force: false };
  try {
    if (req.body) {
      const body = await req.json();
      options = { ...options, ...body };
    }
  } catch {
    // Use defaults
  }

  const results: SyncResult = {
    processed: 0,
    cached: 0,
    skipped: 0,
    failed: 0,
    unchanged: 0,
    matched_cached: 0,
    unmatched_cached: 0,
    errors: [],
  };

  console.log(`[sync-slack-avatars] Starting - source: ${options.source}, limit: ${options.limit}, force: ${options.force}`);

  try {
    let usersToProcess: UserToProcess[] = [];

    if (options.source === "queue") {
      // =====================================================
      // QUEUE MODE: Process pending items from queue table
      // Handles both matched (mapping_id NOT NULL) and unmatched (mapping_id IS NULL)
      // =====================================================
      const { data: queueItems, error: queueError } = await supabase
        .from("slack_avatar_sync_queue")
        .select("id, slack_user_mapping_id, slack_user_id, slack_avatar_url")
        .eq("status", "pending")
        .order("created_at", { ascending: true })
        .limit(options.limit || 50);

      if (queueError) {
        throw new Error(`Failed to fetch queue: ${queueError.message}`);
      }

      if (queueItems && queueItems.length > 0) {
        // Mark as processing
        const queueIds = queueItems.map((q: any) => q.id);
        await supabase
          .from("slack_avatar_sync_queue")
          .update({ status: "processing" })
          .in("id", queueIds);

        // Separate matched and unmatched queue items
        const matchedQueueItems = queueItems.filter((q: any) => q.slack_user_mapping_id !== null);
        const unmatchedQueueItems = queueItems.filter((q: any) => q.slack_user_mapping_id === null);

        // Get full data for matched users
        if (matchedQueueItems.length > 0) {
          const mappingIds = matchedQueueItems.map((q: any) => q.slack_user_mapping_id);
          const { data: matchedUsers } = await supabase
            .from("slack_user_mapping")
            .select("id, slack_user_id, slack_avatar_url, slack_display_name, cached_avatar_path, cached_avatar_source_url")
            .in("id", mappingIds);

          const matchedToProcess = (matchedUsers || []).map((u: any) => {
            const queueItem = matchedQueueItems.find((q: any) => q.slack_user_mapping_id === u.id);
            return { ...u, queue_id: queueItem?.id, is_unmatched: false };
          });
          usersToProcess.push(...matchedToProcess);
        }

        // Get full data for unmatched users
        if (unmatchedQueueItems.length > 0) {
          const slackUserIds = unmatchedQueueItems.map((q: any) => q.slack_user_id);
          const { data: unmatchedUsers } = await supabase
            .from("slack_users_unmatched")
            .select("id, slack_user_id, slack_avatar_url, slack_display_name, slack_real_name, cached_avatar_path, cached_avatar_source_url")
            .in("slack_user_id", slackUserIds);

          const unmatchedToProcess = (unmatchedUsers || []).map((u: any) => {
            const queueItem = unmatchedQueueItems.find((q: any) => q.slack_user_id === u.slack_user_id);
            return { ...u, queue_id: queueItem?.id, is_unmatched: true };
          });
          usersToProcess.push(...unmatchedToProcess);
        }
      }
    } else {
      // =====================================================
      // SCAN MODE: Find users needing sync from BOTH tables
      // =====================================================
      const halfLimit = Math.floor((options.limit || 100) / 2);

      // Get matched users needing sync
      if (!options.force) {
        const { data: matchedUsers, error: matchedError } = await supabase
          .from("slack_user_mapping")
          .select("id, slack_user_id, slack_avatar_url, slack_display_name, cached_avatar_path, cached_avatar_source_url")
          .not("slack_avatar_url", "is", null)
          .neq("slack_avatar_url", "")
          .or("cached_avatar_path.is.null,cached_avatar_source_url.is.null")
          .limit(halfLimit);

        if (matchedError) {
          throw new Error(`Failed to fetch matched users: ${matchedError.message}`);
        }

        // Filter for changed URLs
        const matchedToProcess = (matchedUsers || [])
          .filter((u: any) =>
            !u.cached_avatar_path ||
            !u.cached_avatar_source_url ||
            u.cached_avatar_source_url !== u.slack_avatar_url
          )
          .map((u: any) => ({ ...u, is_unmatched: false }));

        usersToProcess.push(...matchedToProcess);

        // Get unmatched users needing sync
        const { data: unmatchedUsers, error: unmatchedError } = await supabase
          .from("slack_users_unmatched")
          .select("id, slack_user_id, slack_avatar_url, slack_display_name, slack_real_name, cached_avatar_path, cached_avatar_source_url")
          .not("slack_avatar_url", "is", null)
          .neq("slack_avatar_url", "")
          .or("cached_avatar_path.is.null,cached_avatar_source_url.is.null")
          .limit(halfLimit);

        if (unmatchedError) {
          throw new Error(`Failed to fetch unmatched users: ${unmatchedError.message}`);
        }

        // Filter for changed URLs
        const unmatchedToProcess = (unmatchedUsers || [])
          .filter((u: any) =>
            !u.cached_avatar_path ||
            !u.cached_avatar_source_url ||
            u.cached_avatar_source_url !== u.slack_avatar_url
          )
          .map((u: any) => ({ ...u, is_unmatched: true }));

        usersToProcess.push(...unmatchedToProcess);

      } else {
        // Force mode - get all users with avatars from both tables
        const { data: matchedUsers } = await supabase
          .from("slack_user_mapping")
          .select("id, slack_user_id, slack_avatar_url, slack_display_name, cached_avatar_path, cached_avatar_source_url")
          .not("slack_avatar_url", "is", null)
          .neq("slack_avatar_url", "")
          .limit(halfLimit);

        const matchedToProcess = (matchedUsers || []).map((u: any) => ({ ...u, is_unmatched: false }));
        usersToProcess.push(...matchedToProcess);

        const { data: unmatchedUsers } = await supabase
          .from("slack_users_unmatched")
          .select("id, slack_user_id, slack_avatar_url, slack_display_name, slack_real_name, cached_avatar_path, cached_avatar_source_url")
          .not("slack_avatar_url", "is", null)
          .neq("slack_avatar_url", "")
          .limit(halfLimit);

        const unmatchedToProcess = (unmatchedUsers || []).map((u: any) => ({ ...u, is_unmatched: true }));
        usersToProcess.push(...unmatchedToProcess);
      }
    }

    // =====================================================
    // EARLY EXIT: No users to process
    // =====================================================
    if (usersToProcess.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No users need avatar syncing",
          source: options.source,
          ...results,
          duration_ms: Date.now() - startTime,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[sync-slack-avatars] Processing ${usersToProcess.length} users (${usersToProcess.filter(u => !u.is_unmatched).length} matched, ${usersToProcess.filter(u => u.is_unmatched).length} unmatched)...`);

    // =====================================================
    // PROCESS EACH USER
    // =====================================================
    for (const user of usersToProcess) {
      results.processed++;

      // Skip if URL hasn't changed and we have a cached version (unless force)
      if (
        !options.force &&
        user.cached_avatar_path &&
        user.cached_avatar_source_url === user.slack_avatar_url
      ) {
        results.unchanged++;

        if (user.queue_id) {
          await supabase
            .from("slack_avatar_sync_queue")
            .update({ status: "completed", processed_at: new Date().toISOString() })
            .eq("id", user.queue_id);
        }
        continue;
      }

      try {
        const displayName = user.slack_display_name || user.slack_real_name || user.slack_user_id;
        console.log(`[sync-slack-avatars] Downloading: ${displayName} (${user.is_unmatched ? 'unmatched' : 'matched'})`);

        const response = await fetch(user.slack_avatar_url, {
          headers: {
            "User-Agent": "MOYD-CRM-Avatar-Sync/1.0",
            "Accept": "image/*",
          },
          redirect: "follow",
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const imageData = await response.arrayBuffer();
        const contentType = response.headers.get("Content-Type") || "image/jpeg";

        // Determine file extension
        let ext = "jpg";
        if (contentType.includes("png")) ext = "png";
        else if (contentType.includes("gif")) ext = "gif";
        else if (contentType.includes("webp")) ext = "webp";

        // Use different path prefix for unmatched users
        const pathPrefix = user.is_unmatched ? "slack-unmatched" : "slack";
        const storagePath = `${pathPrefix}/${user.slack_user_id}.${ext}`;

        // Delete old file if extension changed
        if (user.cached_avatar_path && user.cached_avatar_path !== storagePath) {
          await supabase.storage.from(STORAGE_BUCKET).remove([user.cached_avatar_path]);
        }

        // Upload to Supabase Storage (upsert)
        const { error: uploadError } = await supabase.storage
          .from(STORAGE_BUCKET)
          .upload(storagePath, imageData, {
            contentType,
            upsert: true,
          });

        if (uploadError) {
          throw new Error(`Upload failed: ${uploadError.message}`);
        }

        // Update the correct table based on is_unmatched flag
        if (user.is_unmatched) {
          const { error: updateError } = await supabase
            .from("slack_users_unmatched")
            .update({
              cached_avatar_path: storagePath,
              cached_avatar_source_url: user.slack_avatar_url,
              updated_at: new Date().toISOString(),
            })
            .eq("id", user.id);

          if (updateError) {
            throw new Error(`DB update failed: ${updateError.message}`);
          }
          results.unmatched_cached++;
        } else {
          const { error: updateError } = await supabase
            .from("slack_user_mapping")
            .update({
              cached_avatar_path: storagePath,
              cached_avatar_source_url: user.slack_avatar_url,
              updated_at: new Date().toISOString(),
            })
            .eq("id", user.id);

          if (updateError) {
            throw new Error(`DB update failed: ${updateError.message}`);
          }
          results.matched_cached++;
        }

        // Mark queue item as completed
        if (user.queue_id) {
          await supabase
            .from("slack_avatar_sync_queue")
            .update({ status: "completed", processed_at: new Date().toISOString() })
            .eq("id", user.queue_id);
        }

        results.cached++;
        console.log(`[sync-slack-avatars] ✓ Cached: ${displayName}`);

        // Rate limit
        await new Promise((resolve) => setTimeout(resolve, 100));

      } catch (err) {
        results.failed++;
        const errMsg = err instanceof Error ? err.message : "Unknown error";
        results.errors.push(`${user.slack_user_id}: ${errMsg}`);
        console.error(`[sync-slack-avatars] ✗ Failed: ${user.slack_user_id} - ${errMsg}`);

        if (user.queue_id) {
          await supabase
            .from("slack_avatar_sync_queue")
            .update({
              status: "failed",
              error_message: errMsg,
              processed_at: new Date().toISOString(),
            })
            .eq("id", user.queue_id);
        }
      }
    }

    // =====================================================
    // GET FINAL COUNTS
    // =====================================================
    const { count: pendingCount } = await supabase
      .from("slack_avatar_sync_queue")
      .select("*", { count: "exact", head: true })
      .eq("status", "pending");

    const { count: matchedNeedsSyncCount } = await supabase
      .from("slack_user_mapping")
      .select("*", { count: "exact", head: true })
      .not("slack_avatar_url", "is", null)
      .neq("slack_avatar_url", "")
      .or("cached_avatar_path.is.null,cached_avatar_source_url.is.null");

    const { count: unmatchedNeedsSyncCount } = await supabase
      .from("slack_users_unmatched")
      .select("*", { count: "exact", head: true })
      .not("slack_avatar_url", "is", null)
      .neq("slack_avatar_url", "")
      .or("cached_avatar_path.is.null,cached_avatar_source_url.is.null");

    return new Response(
      JSON.stringify({
        success: true,
        source: options.source,
        ...results,
        queue_pending: pendingCount || 0,
        matched_needing_sync: matchedNeedsSyncCount || 0,
        unmatched_needing_sync: unmatchedNeedsSyncCount || 0,
        duration_ms: Date.now() - startTime,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("[sync-slack-avatars] Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error",
        source: options.source,
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