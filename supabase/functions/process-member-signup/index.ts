// supabase/functions/process-member-signup/index.ts
// ============================================================================
// MEMBER SIGNUP PROCESSOR
// ============================================================================
// Processes join-chapter form submissions - creates member records linked to chapters
// Handles both:
// - Template-generated forms (hidden fields have default_value)
// - URL-param forms (hidden fields prefilled from URL)
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Format phone to E.164
function formatPhoneE164(phone: string | null): string | null {
  if (!phone) return null;
  const cleaned = phone.replace(/\D/g, '');
  if (cleaned.length === 10) return `+1${cleaned}`;
  if (cleaned.length === 11 && cleaned.startsWith('1')) return `+${cleaned}`;
  return null;
}

// Build address string from components
function buildAddress(
  street: string | null, 
  city: string | null, 
  state: string | null, 
  zip: string | null
): string | null {
  const parts = [street, city, state, zip].filter(Boolean);
  return parts.length > 0 ? parts.join(', ') : null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { submission_id, form_data, form_slug, form_settings } = await req.json();

    if (!submission_id || !form_data) {
      return new Response(
        JSON.stringify({ error: "Missing submission_id or form_data" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("Processing member signup:", submission_id);

    // Extract member data from form
    const name = form_data.member_name;
    const email = form_data.member_email?.toLowerCase();
    const phone = form_data.member_phone;
    const dateOfBirth = form_data.member_dob;
    const streetAddress = form_data.member_address;
    const city = form_data.member_city;
    const state = form_data.member_state || 'MO';
    const zip = form_data.member_zip;

    // Get chapter info from multiple sources (priority order):
    // 1. Hidden fields in form_data (from URL params or template default_value)
    // 2. Form settings (from template-generated forms)
    // 3. Look up from form slug
    
    let chapterId = form_data.hidden_chapter_id;
    let chapterType = form_data.hidden_chapter_type;
    let chapterName = form_data.hidden_chapter_name;
    let schoolName = form_data.hidden_school_name;

    // If not in form_data, check form_settings (template-generated forms store it there)
    if (form_settings) {
      chapterId = chapterId || form_settings.chapter_id;
      chapterType = chapterType || form_settings.chapter_type;
      chapterName = chapterName || form_settings.chapter_name;
      schoolName = schoolName || form_settings.school_name;
    }

    // If still missing chapter info and we have a form_slug, look up the form
    if ((!chapterId || !chapterName) && form_slug) {
      console.log(`Looking up chapter info from form slug: ${form_slug}`);
      
      const { data: formSchema } = await supabase
        .from('form_schemas')
        .select('settings')
        .eq('slug', form_slug)
        .single();
      
      if (formSchema?.settings) {
        const settings = typeof formSchema.settings === 'string' 
          ? JSON.parse(formSchema.settings) 
          : formSchema.settings;
        
        chapterId = chapterId || settings.chapter_id;
        chapterType = chapterType || settings.chapter_type;
        chapterName = chapterName || settings.chapter_name;
        schoolName = schoolName || settings.school_name;
      }
    }

    if (!name || !email) {
      return new Response(
        JSON.stringify({ error: "Name and email are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!chapterName) {
      console.error("Missing chapter information");
      return new Response(
        JSON.stringify({ error: "Chapter information is missing. Please use the correct signup link." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Signing up ${name} for chapter: ${chapterName} (type: ${chapterType})`);

    // Check if email already exists
    const { data: existingMember } = await supabase
      .from('members')
      .select('id, name, chapter_name')
      .eq('email', email)
      .single();

    if (existingMember) {
      // Update existing member with new chapter info
      const updateData: Record<string, any> = {
        chapter_name: chapterName,
        current_chapter_member: 'Yes',
      };

      // Only update address if provided and not already set
      if (streetAddress) {
        updateData.address = buildAddress(streetAddress, city, state, zip);
      }

      // Set committee based on chapter type
      if (chapterType === 'college') {
        updateData.committee = ['College Democrats'];
        updateData.college = schoolName;
        updateData.school_name = schoolName;
        updateData.in_school = 'Yes';
      } else if (chapterType === 'highschool') {
        updateData.committee = ['High School Democrats'];
        updateData.high_school = schoolName;
        updateData.school_name = schoolName;
        updateData.in_school = 'Yes';
      }

      const { error: updateError } = await supabase
        .from('members')
        .update(updateData)
        .eq('id', existingMember.id);

      if (updateError) throw updateError;

      console.log(`Updated existing member: ${existingMember.name} (${email})`);

      // Update form submission status
      await supabase
        .from('form_submissions')
        .update({
          status: 'processed',
          member_id: existingMember.id,
          page_data: {
            member_id: existingMember.id,
            was_existing: true,
            chapter_name: chapterName,
            processed_at: new Date().toISOString(),
          },
        })
        .eq('id', submission_id);

      return new Response(
        JSON.stringify({
          success: true,
          data: {
            member_id: existingMember.id,
            was_existing: true,
            chapter_name: chapterName,
            message: `Welcome back, ${existingMember.name}! You've been added to ${chapterName}.`,
          },
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Create new member
    const memberData: Record<string, any> = {
      name,
      email,
      phone,
      phone_e164: formatPhoneE164(phone),
      date_of_birth: dateOfBirth,
      address: buildAddress(streetAddress, city, state, zip),
      chapter_name: chapterName,
      current_chapter_member: 'Yes',
      date_joined: new Date().toISOString().split('T')[0],
    };

    // Set committee and school based on chapter type
    if (chapterType === 'college') {
      memberData.committee = ['College Democrats'];
      memberData.college = schoolName;
      memberData.school_name = schoolName;
      memberData.in_school = 'Yes';
    } else if (chapterType === 'highschool') {
      memberData.committee = ['High School Democrats'];
      memberData.high_school = schoolName;
      memberData.school_name = schoolName;
      memberData.in_school = 'Yes';
    }

    const { data: newMember, error: insertError } = await supabase
      .from('members')
      .insert(memberData)
      .select('id')
      .single();

    if (insertError) {
      console.error("Error creating member:", insertError);
      throw insertError;
    }

    console.log(`Created new member: ${name} (${email}) with ID: ${newMember.id}`);

    // Update chapter member count (optional - if you track this)
    if (chapterId) {
      // You could increment a member_count field on the chapters table here
      // await supabase.rpc('increment_chapter_member_count', { chapter_id: chapterId });
    }

    // Update form submission status
    await supabase
      .from('form_submissions')
      .update({
        status: 'processed',
        member_id: newMember.id,
        page_data: {
          member_id: newMember.id,
          was_existing: false,
          chapter_name: chapterName,
          processed_at: new Date().toISOString(),
        },
      })
      .eq('id', submission_id);

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          member_id: newMember.id,
          was_existing: false,
          chapter_name: chapterName,
          message: `Welcome to ${chapterName}, ${name}! You're now officially a member of the Missouri Young Democrats.`,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Error processing member signup:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});