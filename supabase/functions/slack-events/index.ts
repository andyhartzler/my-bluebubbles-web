// ============================================
// ENHANCED EDGE FUNCTION: slack-events
// Now includes: Message archiving + Better matching + Avatar sync
// FIXED: No longer auto-creates members - adds to unmatched table instead
// UPDATED: Handles user_change events to keep avatars in sync
// UPDATED: Populates avatar URL for unmatched users
// ============================================
import { serve as stdServe } from "https://deno.land/std@0.168.0/http/server.ts";
import { withSentry } from "../_shared/sentry.ts";
// Sentry-wrapped serve: errors + 5xx responses report to supabase-edge project.
const serve = (h: (req: Request) => Promise<Response> | Response) => stdServe(withSentry("slack-events", h));
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { groupForChannel, addMemberToGroup, removeMemberFromGroup } from "../_shared/google-groups.ts";

// ============================================================================
// Slack channel membership -> Google Group sync (replaces 8 Zapier zaps).
// Go-forward only: on member_joined_channel add the user's email to the mapped
// Google Group; on member_left_channel remove it. Only mapped channels act
// (google-groups.ts CHANNEL_TO_GROUP). Idempotent (adding an existing member or
// removing a non-member is a no-op, never an error).
//
// GATE: GROUP_SYNC_MODE env. "live" = real Directory writes. Anything else
// (unset / "off" / "dry_run", the DEFAULT) = compute + audit only, NO write.
// Andrew flips this to "live" to activate the ongoing sync. This is deliberate,
// documented, and audited (never a silent no-op): the compute-only path records
// exactly what it WOULD do in public.audit_log.
// ============================================================================
function groupSyncMode(): string {
  return (Deno.env.get("GROUP_SYNC_MODE") || "").trim().toLowerCase();
}

// Non-blocking audit of a group-sync decision/outcome.
function auditGroupSync(supabase: any, ctx: Record<string, unknown>): void {
  supabase.from("audit_log").insert({
    action: "EDGE_FN",
    actor_id: null,
    actor_role: "service_role",
    schema_name: "public",
    table_name: "edge_fn:slack-events:group-sync",
    row_id: null,
    context: { event: "slack-group-sync", ...ctx },
  }).then(() => {}).catch((e: unknown) => console.error("[group-sync] audit insert failed:", e));
}

// Add/remove the Slack user's email to/from the Google Group mapped to the
// channel. `kind` is "join" or "leave". Runs independently of committee
// matching so unmatched Slack users still sync. No-op for unmapped channels.
async function syncGroupMembership(
  event: any,
  kind: "join" | "leave",
  supabase: any,
  slackToken: string,
): Promise<void> {
  const channel = event.channel;
  const slackUserId = event.user;
  const group = groupForChannel(channel);
  if (!group) return; // channel not in the map — ignore

  // Resolve the member email. Prefer live Slack profile; fall back to the
  // stored mapping (e.g. a deactivated user on leave).
  let email: string | null = null;
  const info = await getSlackUserInfo(slackUserId, slackToken);
  if (info) email = info.profile?.email || null;
  if (!email) {
    const { data: um } = await supabase
      .from("slack_user_mapping").select("slack_email").eq("slack_user_id", slackUserId).single();
    email = um?.slack_email || null;
  }

  const mode = groupSyncMode();
  if (!email) {
    console.warn(`[group-sync] ${kind} ${channel}: no email for ${slackUserId} — skipped`);
    auditGroupSync(supabase, { kind, channel, group, slack_user_id: slackUserId, result: "no_email", mode });
    return;
  }
  if (mode !== "live") {
    console.log(`[group-sync] ${mode || "off"} (compute-only): would ${kind === "join" ? "add" : "remove"} ${email} ${kind === "join" ? "to" : "from"} ${group}`);
    auditGroupSync(supabase, { kind, channel, group, email, slack_user_id: slackUserId, result: "compute_only", mode: mode || "off" });
    return;
  }

  const r = kind === "join"
    ? await addMemberToGroup(email, group)
    : await removeMemberFromGroup(email, group);
  console.log(`[group-sync] LIVE ${kind} ${email} ${group}: ${r.action} (status ${r.status})${r.error ? " err=" + r.error : ""}`);
  if (r.scopeError) {
    console.error("[group-sync] DWD SCOPE ERROR — Andrew must authorize scope 'https://www.googleapis.com/auth/admin.directory.group.member' for client-id 114261141581576499255 in admin.google.com (Security > API controls > Domain-wide delegation)");
  }
  auditGroupSync(supabase, {
    kind, channel, group, email, slack_user_id: slackUserId,
    result: r.action, ok: r.ok, status: r.status, scope_error: r.scopeError ?? false,
    error: r.error ?? null, mode: "live",
  });
}
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-slack-signature, x-slack-request-timestamp"
};
// Verify Slack signature
async function verifySlackSignature(body, timestamp, signature, signingSecret) {
  const sigBasestring = `v0:${timestamp}:${body}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", encoder.encode(signingSecret), {
    name: "HMAC",
    hash: "SHA-256"
  }, false, [
    "sign"
  ]);
  const signed = await crypto.subtle.sign("HMAC", key, encoder.encode(sigBasestring));
  const hexSignature = Array.from(new Uint8Array(signed)).map((b)=>b.toString(16).padStart(2, '0')).join('');
  const expectedSignature = `v0=${hexSignature}`;
  return expectedSignature === signature;
}
// Get user info from Slack
async function getSlackUserInfo(userId, slackToken) {
  const response = await fetch(`https://slack.com/api/users.info?user=${userId}`, {
    headers: {
      "Authorization": `Bearer ${slackToken}`
    }
  });
  const data = await response.json();
  if (!data.ok) {
    console.error("Failed to get Slack user info:", data.error);
    return null;
  }
  return data.user;
}
// Helper to get avatar URL from Slack user
function getAvatarUrl(slackUser) {
  return slackUser.profile?.image_512 || slackUser.profile?.image_192 || slackUser.profile?.image_72 || null;
}
// UPDATED: Helper function to add user to unmatched table (now includes avatar)
async function addToUnmatched(slackUser, reason, supabase) {
  try {
    const avatarUrl = getAvatarUrl(slackUser);
    await supabase.from("slack_users_unmatched").upsert({
      slack_user_id: slackUser.id || slackUser.slack_user_id,
      slack_email: slackUser.profile?.email || slackUser.slack_email || null,
      slack_real_name: slackUser.real_name || slackUser.slack_real_name || 'Unknown',
      slack_display_name: slackUser.profile?.display_name || slackUser.slack_display_name || null,
      slack_avatar_url: avatarUrl,
      potential_matches: null,
      notes: reason
    }, {
      onConflict: 'slack_user_id'
    });
    console.log(`Added Slack user ${slackUser.id} to unmatched table: ${reason}`);
  } catch (e) {
    console.error('Failed to add to unmatched:', e);
  }
}
// FIXED: Find member OR add to unmatched - never auto-create members
async function findOrCreateMemberFromSlack(slackUser, supabase) {
  const email = slackUser.profile?.email;
  const realName = slackUser.real_name;
  const displayName = slackUser.profile?.display_name;
  if (!email) {
    console.log("No email for Slack user:", slackUser.id);
    // Try to use auto-matching function for non-email matches
    const { data: matchResult } = await supabase.rpc('auto_match_slack_user', {
      p_slack_user_id: slackUser.id,
      p_slack_email: email,
      p_slack_real_name: realName,
      p_slack_display_name: displayName,
      p_confidence_threshold: 0.90
    });
    if (matchResult?.status === 'auto_matched') {
      return matchResult.member_id;
    }
    // No match - add to unmatched table (with avatar)
    await addToUnmatched(slackUser, 'No email address in Slack profile', supabase);
    return null;
  }
  // Try exact email match first
  const { data: existingMember } = await supabase.from("members").select("id").eq("email", email).single();
  if (existingMember) {
    // Update with Slack ID
    await supabase.from("members").update({
      slack_user_id: slackUser.id
    }).eq("id", existingMember.id);
    return existingMember.id;
  }
  // Try school email match
  const { data: schoolEmailMember } = await supabase.from("members").select("id").eq("school_email", email).single();
  if (schoolEmailMember) {
    await supabase.from("members").update({
      slack_user_id: slackUser.id
    }).eq("id", schoolEmailMember.id);
    return schoolEmailMember.id;
  }
  // Use auto-matching function for fuzzy matching
  const { data: matchResult } = await supabase.rpc('auto_match_slack_user', {
    p_slack_user_id: slackUser.id,
    p_slack_email: email,
    p_slack_real_name: realName,
    p_slack_display_name: displayName,
    p_confidence_threshold: 0.90
  });
  if (matchResult?.status === 'auto_matched') {
    return matchResult.member_id;
  }
  // NO MATCH FOUND - Add to unmatched table (with avatar)
  await addToUnmatched(slackUser, 'No matching member found in database', supabase);
  return null;
}
// ENHANCED: Sync with avatar and more metadata
async function syncSlackUserMapping(slackUser, memberId, supabase) {
  const avatarUrl = getAvatarUrl(slackUser);
  const { error } = await supabase.from("slack_user_mapping").upsert({
    member_id: memberId,
    slack_user_id: slackUser.id,
    slack_email: slackUser.profile?.email,
    slack_display_name: slackUser.profile?.display_name,
    slack_real_name: slackUser.real_name,
    slack_avatar_url: avatarUrl,
    slack_is_admin: slackUser.is_admin || false,
    slack_is_bot: slackUser.is_bot || false,
    slack_deleted: slackUser.deleted || false,
    last_synced_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }, {
    onConflict: "slack_user_id"
  });
  if (error) {
    console.error("Failed to sync user mapping:", error);
  } else {
    console.log(`Synced user mapping for ${slackUser.real_name || slackUser.id} with avatar: ${avatarUrl ? 'yes' : 'no'}`);
  }
}
// Handle user_change event (profile updates including avatar changes)
async function handleUserChange(event, supabase) {
  const slackUser = event.user;
  if (!slackUser || !slackUser.id) {
    console.log("No user in user_change event");
    return;
  }
  // Skip bots
  if (slackUser.is_bot) {
    console.log("Skipping bot user:", slackUser.id);
    return;
  }
  console.log(`User profile changed: ${slackUser.real_name || slackUser.id}`);
  const avatarUrl = getAvatarUrl(slackUser);
  // Check if user exists in mapping
  const { data: existingMapping } = await supabase.from("slack_user_mapping").select("id, member_id, slack_avatar_url").eq("slack_user_id", slackUser.id).single();
  if (existingMapping) {
    // Update existing mapping
    const { error } = await supabase.from("slack_user_mapping").update({
      slack_email: slackUser.profile?.email,
      slack_display_name: slackUser.profile?.display_name,
      slack_real_name: slackUser.real_name,
      slack_avatar_url: avatarUrl,
      slack_is_admin: slackUser.is_admin || false,
      slack_deleted: slackUser.deleted || false,
      last_synced_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }).eq("id", existingMapping.id);
    if (error) {
      console.error("Failed to update user mapping:", error);
    } else {
      if (existingMapping.slack_avatar_url !== avatarUrl) {
        console.log(`Avatar URL changed for ${slackUser.real_name}, will be re-cached by trigger`);
      }
      console.log(`Updated user mapping for ${slackUser.real_name || slackUser.id}`);
    }
  } else {
    // Check if user exists in unmatched table
    const { data: existingUnmatched } = await supabase.from("slack_users_unmatched").select("id").eq("slack_user_id", slackUser.id).single();
    if (existingUnmatched) {
      // Update existing unmatched user
      const { error } = await supabase.from("slack_users_unmatched").update({
        slack_email: slackUser.profile?.email,
        slack_display_name: slackUser.profile?.display_name,
        slack_real_name: slackUser.real_name,
        slack_avatar_url: avatarUrl
      }).eq("id", existingUnmatched.id);
      if (error) {
        console.error("Failed to update unmatched user:", error);
      } else {
        console.log(`Updated unmatched user ${slackUser.real_name || slackUser.id}`);
      }
    } else {
      // User not in mapping or unmatched - try to find matching member
      console.log(`User ${slackUser.id} not found, attempting to match...`);
      const memberId = await findOrCreateMemberFromSlack(slackUser, supabase);
      if (memberId) {
        await syncSlackUserMapping(slackUser, memberId, supabase);
      }
    // If no memberId, findOrCreateMemberFromSlack already added to unmatched with avatar
    }
  }
}
// Archive a message
async function archiveMessage(event, supabase) {
  // Get member_id from slack_user_id
  const { data: userMapping } = await supabase.from("slack_user_mapping").select("member_id").eq("slack_user_id", event.user).single();
  const memberId = userMapping?.member_id;
  // Check if channel should be archived
  const { data: channelMapping } = await supabase.from("slack_channel_committee_mapping").select("archive_messages").eq("slack_channel_id", event.channel).single();
  if (channelMapping && !channelMapping.archive_messages) {
    console.log("Channel not configured for archiving");
    return;
  }
  // Extract file info if present
  let files = null;
  if (event.files && event.files.length > 0) {
    files = event.files.map((f)=>({
        id: f.id,
        name: f.name,
        url_private: f.url_private,
        mimetype: f.mimetype,
        size: f.size
      }));
  }
  // Insert or update message
  const { error } = await supabase.from("slack_messages").upsert({
    slack_message_ts: event.ts,
    slack_channel_id: event.channel,
    slack_user_id: event.user,
    member_id: memberId,
    message_text: event.text,
    message_type: event.subtype || 'message',
    thread_ts: event.thread_ts,
    has_files: event.files && event.files.length > 0 || false,
    files: files,
    posted_at: new Date(parseFloat(event.ts) * 1000).toISOString(),
    raw_payload: event
  }, {
    onConflict: "slack_channel_id, slack_message_ts"
  });
  if (error) {
    console.error("Failed to archive message:", error);
  }
}
// Add committee to member
async function addCommitteeToMember(memberId, committee, supabase) {
  const { data: member } = await supabase.from("members").select("committee").eq("id", memberId).single();
  if (!member) return false;
  const currentCommittees = member.committee || [];
  if (currentCommittees.includes(committee)) {
    console.log(`Member ${memberId} already has committee ${committee}`);
    return true;
  }
  const newCommittees = [
    ...currentCommittees,
    committee
  ];
  const { error } = await supabase.from("members").update({
    committee: newCommittees
  }).eq("id", memberId);
  if (error) {
    console.error("Failed to add committee:", error);
    return false;
  }
  console.log(`Added committee ${committee} to member ${memberId}`);
  return true;
}
// Remove committee from member
async function removeCommitteeFromMember(memberId, committee, supabase) {
  const { data: member } = await supabase.from("members").select("committee").eq("id", memberId).single();
  if (!member) return false;
  const currentCommittees = member.committee || [];
  if (!currentCommittees.includes(committee)) {
    console.log(`Member ${memberId} doesn't have committee ${committee}`);
    return true;
  }
  const newCommittees = currentCommittees.filter((c)=>c !== committee);
  const { error } = await supabase.from("members").update({
    committee: newCommittees
  }).eq("id", memberId);
  if (error) {
    console.error("Failed to remove committee:", error);
    return false;
  }
  console.log(`Removed committee ${committee} from member ${memberId}`);
  return true;
}
// Handle member_joined_channel event
async function handleMemberJoined(event, supabase, slackToken) {
  console.log("Member joined channel:", event);
  const { data: mapping } = await supabase.from("slack_channel_committee_mapping").select("*").eq("slack_channel_id", event.channel).eq("is_active", true).single();
  if (!mapping) {
    console.log("No committee mapping for channel:", event.channel);
    return;
  }
  const slackUser = await getSlackUserInfo(event.user, slackToken);
  if (!slackUser) {
    console.error("Could not get Slack user info");
    return;
  }
  const memberId = await findOrCreateMemberFromSlack(slackUser, supabase);
  // If no member found (user added to unmatched with avatar), still log the event
  if (!memberId) {
    console.log("User added to unmatched table, skipping committee assignment");
    await supabase.from("slack_channel_membership_log").insert({
      member_id: null,
      slack_user_id: event.user,
      slack_channel_id: event.channel,
      action: "joined",
      source: "slack_event",
      success: false,
      error_message: "User not matched to member - added to unmatched table",
      metadata: {
        committee: mapping.committee_name,
        channel_name: mapping.slack_channel_name,
        unmatched: true
      }
    });
    return;
  }
  await syncSlackUserMapping(slackUser, memberId, supabase);
  const success = await addCommitteeToMember(memberId, mapping.committee_name, supabase);
  await supabase.from("slack_channel_membership_log").insert({
    member_id: memberId,
    slack_user_id: event.user,
    slack_channel_id: event.channel,
    action: "joined",
    source: "slack_event",
    success: success,
    metadata: {
      committee: mapping.committee_name,
      channel_name: mapping.slack_channel_name
    }
  });
}
// Handle member_left_channel event
async function handleMemberLeft(event, supabase) {
  console.log("Member left channel:", event);
  const { data: mapping } = await supabase.from("slack_channel_committee_mapping").select("*").eq("slack_channel_id", event.channel).eq("is_active", true).single();
  if (!mapping) {
    console.log("No committee mapping for channel:", event.channel);
    return;
  }
  const { data: userMapping } = await supabase.from("slack_user_mapping").select("member_id").eq("slack_user_id", event.user).single();
  if (!userMapping) {
    console.log("No member found for Slack user:", event.user);
    return;
  }
  const success = await removeCommitteeFromMember(userMapping.member_id, mapping.committee_name, supabase);
  await supabase.from("slack_channel_membership_log").insert({
    member_id: userMapping.member_id,
    slack_user_id: event.user,
    slack_channel_id: event.channel,
    action: "left",
    source: "slack_event",
    success: success,
    metadata: {
      committee: mapping.committee_name,
      channel_name: mapping.slack_channel_name
    }
  });
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const slackSigningSecret = Deno.env.get("SLACK_SIGNING_SECRET");
    const slackToken = Deno.env.get("SLACK_BOT_TOKEN");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!slackSigningSecret || !slackToken || !supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing required environment variables");
    }
    const timestamp = req.headers.get("x-slack-request-timestamp");
    const signature = req.headers.get("x-slack-signature");
    const body = await req.text();
    // Verify timestamp
    if (timestamp) {
      const now = Math.floor(Date.now() / 1000);
      const requestTime = parseInt(timestamp);
      if (Math.abs(now - requestTime) > 60 * 5) {
        return new Response(JSON.stringify({
          error: "Request too old"
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
    }
    // Verify signature
    if (signature && timestamp) {
      const isValid = await verifySlackSignature(body, timestamp, signature, slackSigningSecret);
      if (!isValid) {
        console.error("Invalid Slack signature");
        return new Response(JSON.stringify({
          error: "Invalid signature"
        }), {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
      }
    }
    const payload = JSON.parse(body);
    // Handle URL verification
    if (payload.type === "url_verification") {
      return new Response(JSON.stringify({
        challenge: payload.challenge
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Handle events
    if (payload.type === "event_callback") {
      const supabase = createClient(supabaseUrl, supabaseServiceKey);
      const event = payload.event;
      // Wave 4 access-audit 2026-04-24: audit log (non-blocking). Webhook auth is Slack-signature only.
      supabase.from("audit_log").insert({
        action: "EDGE_FN",
        actor_id: null,
        actor_role: "service_role",
        schema_name: "public",
        table_name: "edge_fn:slack-events",
        row_id: null,
        context: {
          event: "slack-events",
          slack_event_type: event.type,
          slack_user_id: event.user?.id ?? event.user ?? null,
          slack_channel_id: event.channel ?? null
        }
      }).then(() => {}).catch((e) => console.error("[slack-events] audit_log insert failed:", e));
      switch(event.type){
        case "member_joined_channel":
          await handleMemberJoined(event, supabase, slackToken);
          // Slack channel membership -> Google Group sync (replaces 8 zaps).
          await syncGroupMembership(event, "join", supabase, slackToken);
          break;
        case "member_left_channel":
          await handleMemberLeft(event, supabase);
          await syncGroupMembership(event, "leave", supabase, slackToken);
          break;
        case "message":
          // Archive messages from channels
          if (event.subtype !== "bot_message" && event.user) {
            await archiveMessage(event, supabase);
          }
          break;
        // Handle user profile changes (including avatar updates)
        case "user_change":
          await handleUserChange(event, supabase);
          break;
        // Handle team_join for new workspace members
        case "team_join":
          console.log("New team member joined:", event.user?.real_name || event.user?.id);
          await handleUserChange(event, supabase);
          break;
        default:
          console.log("Unhandled event type:", event.type);
      }
      return new Response(JSON.stringify({
        ok: true
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    return new Response(JSON.stringify({
      ok: true
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error processing Slack event:", error);
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
