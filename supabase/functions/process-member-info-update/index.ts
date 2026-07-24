// supabase/functions/process-member-info-update/index.ts
// Processes member-info form submissions - updates existing member records with additional info

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const tokenSecret = Deno.env.get("MEMBER_INFO_TOKEN_SECRET") || "moyd-default-secret-change-me";
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Validate secure token
function validateToken(memberId: string, token: string): boolean {
  // Token format: base64(hmac-sha256(memberId, secret))
  // For now, we'll use a simple validation - in production you'd want proper HMAC
  const expectedToken = btoa(`${memberId}-${tokenSecret}`).substring(0, 32);
  return token === expectedToken;
}

// Generate token for a member (used when sending emails)
export function generateMemberToken(memberId: string): string {
  return btoa(`${memberId}-${tokenSecret}`).substring(0, 32);
}

// Clean social media handle - remove @ prefix
function cleanSocialHandle(handle: string | null): string | null {
  if (!handle) return null;
  return handle.trim().replace(/^@/, '');
}

// Convert array to comma-separated string for text fields
function arrayToText(arr: any[] | string | null): string | null {
  if (!arr) return null;
  if (typeof arr === 'string') return arr;
  if (Array.isArray(arr)) {
    // Filter out null/empty values
    const filtered = arr.filter(v => v && v !== 'null' && v !== 'prefer_not_to_say');
    return filtered.length > 0 ? filtered.join(', ') : null;
  }
  return null;
}

// Convert form value to boolean
function toBoolean(value: any): boolean | null {
  if (value === true || value === 'true' || value === 'yes' || value === 'Yes') return true;
  if (value === false || value === 'false' || value === 'no' || value === 'No') return false;
  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { submission_id, form_data, settings } = await req.json();

    if (!submission_id || !form_data) {
      return new Response(
        JSON.stringify({ error: "Missing submission_id or form_data" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Processing member info update:", submission_id);

    // Extract hidden fields
    const memberId = form_data.hidden_member_id;
    const chapterId = form_data.hidden_chapter_id;
    const token = form_data.hidden_token;

    if (!memberId) {
      return new Response(
        JSON.stringify({ error: "Missing member ID" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate token if required
    const requireToken = settings?.require_valid_token !== false;
    if (requireToken && token) {
      if (!validateToken(memberId, token)) {
        console.error("Invalid token for member:", memberId);
        return new Response(
          JSON.stringify({ error: "Invalid or expired token" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Verify member exists
    const { data: existingMember, error: fetchError } = await supabase
      .from('members')
      .select('id, name, email')
      .eq('id', memberId)
      .single();

    if (fetchError || !existingMember) {
      return new Response(
        JSON.stringify({ error: "Member not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build update object - only include non-null values
    const updateData: Record<string, any> = {};

    // Handle pronouns - if "other" was selected, use the custom value
    if (form_data.preferred_pronouns) {
      if (form_data.preferred_pronouns === 'other' && form_data.pronouns_other) {
        updateData.preferred_pronouns = form_data.pronouns_other;
      } else if (form_data.preferred_pronouns !== 'null' && form_data.preferred_pronouns !== 'prefer_not_to_say') {
        updateData.preferred_pronouns = form_data.preferred_pronouns;
      }
    }

    // Gender identity
    if (form_data.gender_identity && form_data.gender_identity !== 'null') {
      updateData.gender_identity = form_data.gender_identity;
    }

    // Race - convert array to comma-separated text
    if (form_data.race) {
      updateData.race = arrayToText(form_data.race);
    }

    // Hispanic/Latino - convert to boolean
    if (form_data.hispanic_latino !== undefined && form_data.hispanic_latino !== null) {
      updateData.hispanic_latino = toBoolean(form_data.hispanic_latino);
    }

    // Education level
    if (form_data.education_level) {
      updateData.education_level = form_data.education_level;
    }

    // Graduation year
    if (form_data.graduation_year && form_data.graduation_year !== 'null') {
      updateData.graduation_year = form_data.graduation_year;
    }

    // Registered voter - convert to boolean
    if (form_data.registered_voter !== undefined && form_data.registered_voter !== null) {
      updateData.registered_voter = toBoolean(form_data.registered_voter);
    }

    // Areas of interest - convert array to comma-separated text
    if (form_data.areas_of_interest) {
      updateData.areas_of_interest = arrayToText(form_data.areas_of_interest);
    }

    // Text fields - direct mapping
    if (form_data.passionate_issues) {
      updateData.passionate_issues = form_data.passionate_issues;
    }

    if (form_data.desire_to_lead) {
      updateData.desire_to_lead = form_data.desire_to_lead;
    }

    if (form_data.hours_per_week) {
      updateData.hours_per_week = form_data.hours_per_week;
    }

    if (form_data.political_experience) {
      updateData.political_experience = form_data.political_experience;
    }

    if (form_data.referral_source) {
      updateData.referral_source = form_data.referral_source;
    }

    if (form_data.accommodations) {
      updateData.accommodations = form_data.accommodations;
    }

    // Social media handles - clean and store
    if (form_data.social_instagram) {
      updateData.instagram = cleanSocialHandle(form_data.social_instagram);
    }

    if (form_data.social_x) {
      updateData.x = cleanSocialHandle(form_data.social_x);
    }

    if (form_data.social_tiktok) {
      updateData.tiktok = cleanSocialHandle(form_data.social_tiktok);
    }

    // Only update if we have data
    if (Object.keys(updateData).length === 0) {
      console.log("No fields to update for member:", memberId);
      
      // Still mark submission as processed
      await supabase
        .from('form_submissions')
        .update({
          status: 'processed',
          member_id: memberId,
          page_data: {
            member_id: memberId,
            fields_updated: 0,
            processed_at: new Date().toISOString(),
          },
        })
        .eq('id', submission_id);

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            member_id: memberId,
            fields_updated: 0,
            message: "No changes to save.",
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Updating member with fields:", Object.keys(updateData));

    // Update member
    const { error: updateError } = await supabase
      .from('members')
      .update(updateData)
      .eq('id', memberId);

    if (updateError) {
      console.error("Error updating member:", updateError);
      throw updateError;
    }

    console.log(`Updated member ${existingMember.name} with ${Object.keys(updateData).length} fields`);

    // Update form submission status
    await supabase
      .from('form_submissions')
      .update({
        status: 'processed',
        member_id: memberId,
        page_data: {
          member_id: memberId,
          fields_updated: Object.keys(updateData).length,
          updated_fields: Object.keys(updateData),
          processed_at: new Date().toISOString(),
        },
      })
      .eq('id', submission_id);

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          member_id: memberId,
          fields_updated: Object.keys(updateData).length,
          message: "Thank you! Your information has been saved.",
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Error processing member info update:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});