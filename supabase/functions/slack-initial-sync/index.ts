// ============================================
// EDGE FUNCTION: slack-initial-sync (BULLETPROOF)
// Never crashes, always returns valid JSON
// ============================================
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};

// Get all users in workspace
async function getAllUsers(slackToken: string) {
  const users: any[] = [];
  let cursor = "";
  
  do {
    const url = cursor 
      ? `https://slack.com/api/users.list?limit=200&cursor=${cursor}` 
      : "https://slack.com/api/users.list?limit=200";
    
    const response = await fetch(url, {
      headers: { "Authorization": `Bearer ${slackToken}` }
    });
    
    const data = await response.json();
    
    if (!data.ok) {
      throw new Error(`Failed to fetch users: ${data.error}`);
    }
    
    users.push(...data.members.filter((m: any) => 
      !m.deleted && !m.is_bot && m.id !== "USLACKBOT"
    ));
    
    cursor = data.response_metadata?.next_cursor || "";
    await new Promise(resolve => setTimeout(resolve, 100));
  } while (cursor);
  
  return users;
}

// Get members of a specific channel
async function getChannelMembers(channelId: string, slackToken: string) {
  const members: string[] = [];
  let cursor = "";
  
  do {
    const url = cursor
      ? `https://slack.com/api/conversations.members?channel=${channelId}&limit=200&cursor=${cursor}`
      : `https://slack.com/api/conversations.members?channel=${channelId}&limit=200`;
    
    const response = await fetch(url, {
      headers: { "Authorization": `Bearer ${slackToken}` }
    });
    
    const data = await response.json();
    
    if (!data.ok) {
      console.error(`Failed to fetch members for channel ${channelId}:`, data.error);
      return [];
    }
    
    members.push(...data.members);
    cursor = data.response_metadata?.next_cursor || "";
    await new Promise(resolve => setTimeout(resolve, 100));
  } while (cursor);
  
  return members;
}

// Add user to unmatched table
async function addToUnmatched(slackUser: any, reason: string, supabase: any) {
  try {
    await supabase.from("slack_users_unmatched").upsert({
      slack_user_id: slackUser.id || slackUser.slack_user_id,
      slack_email: slackUser.profile?.email || slackUser.slack_email || null,
      slack_real_name: slackUser.real_name || slackUser.slack_real_name || 'Unknown',
      slack_display_name: slackUser.profile?.display_name || slackUser.slack_display_name || null,
      potential_matches: null,
      notes: reason
    }, { onConflict: 'slack_user_id' });
  } catch (e) {
    console.error('Failed to add to unmatched:', e);
  }
}

// Sync all users to member table and mapping table
async function syncAllUsers(users: any[], supabase: any, autoCreateMembers: boolean = false) {
  let matched = 0;
  let unmatched = 0;
  let created = 0;
  let errors = 0;
  
  for (const user of users) {
    try {
      const email = user.profile?.email;
      
      // Skip users without email
      if (!email) {
        await addToUnmatched(user, 'No email address in Slack profile', supabase);
        unmatched++;
        continue;
      }
      
      // Try to find existing member by email or school_email
      const { data: existingMember, error: findError } = await supabase
        .from("members")
        .select("id")
        .or(`email.eq.${email},school_email.eq.${email}`)
        .maybeSingle();
      
      if (findError) {
        console.error(`Error finding member for ${email}:`, findError);
        await addToUnmatched(user, `Database error: ${findError.message}`, supabase);
        errors++;
        continue;
      }
      
      let memberId;
      
      if (existingMember) {
        // Found a match!
        memberId = existingMember.id;
        matched++;
        
        // Create/update user mapping
        await supabase.from("slack_user_mapping").upsert({
          member_id: memberId,
          slack_user_id: user.id,
          slack_email: email,
          slack_display_name: user.profile?.display_name,
          slack_real_name: user.real_name,
          matched_by: 'email',
          match_confidence: 1.0,
          last_synced_at: new Date().toISOString()
        }, { onConflict: "slack_user_id" });
        
        // Update member with slack_user_id
        await supabase
          .from("members")
          .update({ slack_user_id: user.id })
          .eq("id", memberId);
        
      } else if (autoCreateMembers) {
        // No match found - create new member if flag is set
        const { data: newMember, error: createError } = await supabase
          .from("members")
          .insert({
            email: email,
            first_name: user.profile?.first_name || user.real_name?.split(' ')[0] || '',
            last_name: user.profile?.last_name || user.real_name?.split(' ').slice(1).join(' ') || '',
            slack_user_id: user.id,
            committee: []
          })
          .select("id")
          .single();
        
        if (createError) {
          console.error("Failed to create member:", createError);
          await addToUnmatched(user, `Failed to create member: ${createError.message}`, supabase);
          errors++;
          continue;
        }
        
        memberId = newMember.id;
        created++;
        
        // Create user mapping
        await supabase.from("slack_user_mapping").upsert({
          member_id: memberId,
          slack_user_id: user.id,
          slack_email: email,
          slack_display_name: user.profile?.display_name,
          slack_real_name: user.real_name,
          matched_by: 'auto_created',
          match_confidence: 1.0,
          last_synced_at: new Date().toISOString()
        }, { onConflict: "slack_user_id" });
        
      } else {
        // No match found - add to unmatched table
        await addToUnmatched(user, 'No matching member found in database', supabase);
        unmatched++;
      }
      
    } catch (error: any) {
      console.error(`Error processing user ${user.id}:`, error);
      await addToUnmatched(user, `Processing error: ${error.message}`, supabase);
      errors++;
    }
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  
  return { matched, unmatched, created, errors };
}

// Sync members of a specific channel and add committees
async function syncChannel(channelMapping: any, slackToken: string, supabase: any) {
  console.log(`Syncing channel: ${channelMapping.slack_channel_name}`);
  
  const members = await getChannelMembers(channelMapping.slack_channel_id, slackToken);
  console.log(`Found ${members.length} members in ${channelMapping.slack_channel_name}`);
  
  let synced = 0;
  let skipped = 0;
  let errors = 0;
  
  for (const slackUserId of members) {
    try {
      // Find member by Slack user ID
      const { data: userMapping, error: mappingError } = await supabase
        .from("slack_user_mapping")
        .select("member_id")
        .eq("slack_user_id", slackUserId)
        .maybeSingle();
      
      if (mappingError) {
        console.error(`Error fetching mapping for ${slackUserId}:`, mappingError);
        errors++;
        continue;
      }
      
      if (!userMapping) {
        // User not in mapping table - add to unmatched
        console.log(`No member found for Slack user ${slackUserId} - adding to unmatched`);
        
        await supabase.from("slack_users_unmatched").upsert({
          slack_user_id: slackUserId,
          slack_email: null,
          slack_real_name: null,
          slack_display_name: null,
          potential_matches: null,
          notes: `Found in channel ${channelMapping.slack_channel_name} but not matched to member`
        }, { onConflict: 'slack_user_id', ignoreDuplicates: true });
        
        skipped++;
        continue;
      }
      
      // Get current committee
      const { data: member, error: memberError } = await supabase
        .from("members")
        .select("committee")
        .eq("id", userMapping.member_id)
        .single();
      
      if (memberError) {
        console.error(`Error fetching member ${userMapping.member_id}:`, memberError);
        errors++;
        continue;
      }
      
      const currentCommittees = member?.committee || [];
      
      // Check if member already has this committee
      if (!currentCommittees.includes(channelMapping.committee_name)) {
        // Add committee
        const newCommittees = [...currentCommittees, channelMapping.committee_name];
        
        const { error: updateError } = await supabase
          .from("members")
          .update({ committee: newCommittees })
          .eq("id", userMapping.member_id);
        
        if (updateError) {
          console.error(`Failed to add committee to member:`, updateError);
          errors++;
          continue;
        }
        
        synced++;
      }
      
      // Log the sync
      await supabase.from("slack_channel_membership_log").insert({
        member_id: userMapping.member_id,
        slack_user_id: slackUserId,
        slack_channel_id: channelMapping.slack_channel_id,
        action: "joined",
        source: "manual_sync",
        success: true,
        metadata: {
          committee: channelMapping.committee_name,
          channel_name: channelMapping.slack_channel_name,
          initial_sync: true
        }
      });
      
    } catch (error: any) {
      console.error(`Error syncing member ${slackUserId}:`, error);
      errors++;
    }
    
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  
  return {
    channel: channelMapping.slack_channel_name,
    total: members.length,
    synced,
    skipped,
    errors
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  
  try {
    console.log('=== SLACK INITIAL SYNC STARTED ===');
    
    const slackToken = Deno.env.get("SLACK_BOT_TOKEN");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    
    if (!slackToken || !supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: "Missing required environment variables" 
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Parse request body for options
    let body: any = {};
    try {
      const text = await req.text();
      if (text) {
        body = JSON.parse(text);
      }
    } catch (e) {
      console.log('No body or invalid JSON, using defaults');
    }
    
    const syncUsers = body.syncUsers !== false;
    const syncChannels = body.syncChannels !== false;
    const autoCreateMembers = body.autoCreateMembers === true;
    
    console.log('Options:', { syncUsers, syncChannels, autoCreateMembers });
    
    const results: any = {
      success: true,
      timestamp: new Date().toISOString(),
      auto_create_members: autoCreateMembers
    };
    
    // Step 1: Sync all users
    if (syncUsers) {
      try {
        console.log("Fetching all Slack users...");
        const users = await getAllUsers(slackToken);
        console.log(`Found ${users.length} users`);
        
        console.log("Syncing users to database...");
        const userSyncResults = await syncAllUsers(users, supabase, autoCreateMembers);
        
        results.users = {
          total: users.length,
          ...userSyncResults
        };
        
        console.log('User sync results:', userSyncResults);
        
        // Get count of unmatched users
        const { count: unmatchedCount } = await supabase
          .from("slack_users_unmatched")
          .select("*", { count: 'exact', head: true });
        
        results.users.total_unmatched = unmatchedCount || 0;
      } catch (error: any) {
        console.error('Error in user sync:', error);
        results.users = {
          error: error.message,
          success: false
        };
      }
    }
    
    // Step 2: Sync channel memberships
    if (syncChannels) {
      try {
        console.log("Fetching channel mappings...");
        const { data: channelMappings, error: mappingError } = await supabase
          .from("slack_channel_committee_mapping")
          .select("*")
          .eq("is_active", true);
        
        if (mappingError) {
          throw mappingError;
        }
        
        if (!channelMappings || channelMappings.length === 0) {
          results.channels = {
            error: "No active channel mappings found. Please add channel mappings first."
          };
        } else {
          console.log(`Found ${channelMappings.length} channel mappings`);
          
          const channelResults = [];
          for (const mapping of channelMappings) {
            try {
              const result = await syncChannel(mapping, slackToken, supabase);
              channelResults.push(result);
            } catch (error: any) {
              console.error(`Error syncing channel ${mapping.slack_channel_name}:`, error);
              channelResults.push({
                channel: mapping.slack_channel_name,
                error: error.message,
                success: false
              });
            }
            await new Promise(resolve => setTimeout(resolve, 500));
          }
          
          results.channels = {
            total: channelMappings.length,
            results: channelResults,
            totalSynced: channelResults.reduce((sum, r) => sum + (r.synced || 0), 0),
            totalSkipped: channelResults.reduce((sum, r) => sum + (r.skipped || 0), 0),
            totalErrors: channelResults.reduce((sum, r) => sum + (r.errors || 0), 0)
          };
        }
      } catch (error: any) {
        console.error('Error in channel sync:', error);
        results.channels = {
          error: error.message,
          success: false
        };
      }
    }
    
    console.log('=== SLACK INITIAL SYNC COMPLETED ===');
    
    return new Response(JSON.stringify(results, null, 2), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
    
  } catch (error: any) {
    console.error("FATAL ERROR in slack-initial-sync:", error);
    console.error("Error stack:", error.stack);
    
    // Always return valid JSON, never crash
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || 'Unknown error',
        timestamp: new Date().toISOString()
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});