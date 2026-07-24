// supabase/functions/verify-member-for-vote/index.ts
// 
// Edge Function for public vote verification and submission
// Verifies member by phone number and handles vote casting
// Supports executive_only and committee-restricted votes
//
// Deploy with: supabase functions deploy verify-member-for-vote

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

// ============================================================================
// TYPES
// ============================================================================

interface VerifyMemberRequest {
  phone: string;
  vote_slug: string;
  session_token?: string;
  ip_address?: string;
  user_agent?: string;
  referrer?: string;
}

interface VerifyMemberResponse {
  success: boolean;
  is_member: boolean;
  member_id: string | null;
  member_name: string | null;
  already_voted: boolean;
  vote_id: string | null;
  vote_title: string | null;
  vote_description: string | null;
  vote_schema: any | null;
  vote_status: 'not_found' | 'not_active' | 'not_started' | 'ended' | 'open';
  voting_starts_at: string | null;
  voting_ends_at: string | null;
  is_eligible: boolean;
  eligibility_reason: string | null;
  session_token: string;
  committee_restricted: string | null;
  error?: string;
}

interface SubmitVoteRequest {
  vote_id: string;
  member_id: string;
  vote_data: Record<string, any>;
  session_token: string;
  ip_address?: string;
  user_agent?: string;
}

interface GetVoteInfoRequest {
  slug: string;
  session_token?: string;
  ip_address?: string;
  user_agent?: string;
  referrer?: string;
}

// ============================================================================
// PHONE UTILITIES
// ============================================================================

/**
 * Remove all non-digit characters from phone
 */
function normalizePhone(phone: string): string {
  return phone.replace(/\D/g, '');
}

/**
 * Format phone to E.164 format (+1XXXXXXXXXX)
 */
function formatPhoneE164(phone: string): string {
  const digits = normalizePhone(phone);
  
  // If already has country code (11 digits starting with 1)
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+${digits}`;
  }
  
  // Standard 10-digit US number
  if (digits.length === 10) {
    return `+1${digits}`;
  }
  
  // If starts with + and has enough digits, just normalize
  if (phone.startsWith('+') && digits.length >= 10) {
    return `+${digits}`;
  }
  
  // Default: assume US number
  return `+1${digits}`;
}

/**
 * Validate phone number has enough digits
 */
function isValidPhone(phone: string): boolean {
  const digits = normalizePhone(phone);
  return digits.length >= 10 && digits.length <= 15;
}

/**
 * Generate a unique session token
 */
function generateSessionToken(): string {
  return crypto.randomUUID();
}

// ============================================================================
// COMMITTEE NAME NORMALIZATION
// ============================================================================

/**
 * Normalize a committee name by removing " Committee" suffix and trimming
 * This allows matching between:
 * - "Policy & Advocacy Committee" (form_schemas)
 * - "Policy & Advocacy" (members table)
 */
function normalizeCommitteeName(committeeName: string): string {
  return committeeName
    .trim()
    .replace(/\s+Committee$/i, '') // Remove " Committee" suffix (case-insensitive)
    .toLowerCase();
}

/**
 * Check if a member belongs to a specific committee
 * The member's committee field is a text[] array
 * 
 * Handles variations like:
 * - "Policy & Advocacy Committee" vs "Policy & Advocacy"
 * - Case differences
 * - With or without "Committee" suffix on either side
 */
function isMemberInCommittee(memberCommittees: string[] | null, requiredCommittee: string): boolean {
  if (!memberCommittees || !Array.isArray(memberCommittees)) {
    console.log('Member has no committees array or it is not an array');
    return false;
  }

  const normalizedRequired = normalizeCommitteeName(requiredCommittee);
  
  console.log('Checking committee membership:', {
    requiredCommittee,
    normalizedRequired,
    memberCommittees,
    memberCommitteesNormalized: memberCommittees.map(c => normalizeCommitteeName(c))
  });

  // Check if any of the member's committees match after normalization
  const isMatch = memberCommittees.some((committee) => {
    const normalizedMemberCommittee = normalizeCommitteeName(committee);
    return normalizedMemberCommittee === normalizedRequired;
  });

  console.log('Committee match result:', isMatch);
  return isMatch;
}

// ============================================================================
// MEMBER LOOKUP - Searches both phone and phone_e164 columns
// ============================================================================

/**
 * Find a member by phone number
 * Searches multiple phone formats against both phone and phone_e164 columns
 */
async function findMemberByPhone(phone: string): Promise<{ id: string; name: string } | null> {
  const phoneE164 = formatPhoneE164(phone);
  const normalizedPhone = normalizePhone(phone);
  const phoneWithoutCountry = phoneE164.replace('+1', '');
  
  console.log('Searching for member with phone variants:', {
    original: phone,
    e164: phoneE164,
    normalized: normalizedPhone,
    withoutCountry: phoneWithoutCountry
  });

  // Strategy 1: Search phone_e164 column (most reliable, indexed)
  const { data: memberByE164Column, error: e164Error } = await supabase
    .from('members')
    .select('id, name')
    .eq('phone_e164', phoneE164)
    .limit(1)
    .maybeSingle();

  if (memberByE164Column) {
    console.log('Found member via phone_e164 column:', memberByE164Column.name);
    return memberByE164Column;
  }

  // Strategy 2: Search phone column with E.164 format
  const { data: memberByPhoneE164 } = await supabase
    .from('members')
    .select('id, name')
    .eq('phone', phoneE164)
    .limit(1)
    .maybeSingle();

  if (memberByPhoneE164) {
    console.log('Found member via phone column (e164):', memberByPhoneE164.name);
    return memberByPhoneE164;
  }

  // Strategy 3: Search phone column with normalized digits (10 digits)
  const { data: memberByNormalized } = await supabase
    .from('members')
    .select('id, name')
    .eq('phone', normalizedPhone)
    .limit(1)
    .maybeSingle();

  if (memberByNormalized) {
    console.log('Found member via phone column (normalized):', memberByNormalized.name);
    return memberByNormalized;
  }

  // Strategy 4: Search phone column with 10 digits (without +1)
  const { data: memberByWithoutCountry } = await supabase
    .from('members')
    .select('id, name')
    .eq('phone', phoneWithoutCountry)
    .limit(1)
    .maybeSingle();

  if (memberByWithoutCountry) {
    console.log('Found member via phone column (without country):', memberByWithoutCountry.name);
    return memberByWithoutCountry;
  }

  // Strategy 5: Search phone column with original input (in case it's formatted like (555) 123-4567)
  const { data: memberByOriginal } = await supabase
    .from('members')
    .select('id, name')
    .eq('phone', phone)
    .limit(1)
    .maybeSingle();

  if (memberByOriginal) {
    console.log('Found member via phone column (original):', memberByOriginal.name);
    return memberByOriginal;
  }

  // Strategy 6: Try ILIKE search on phone column for partial matches
  // This catches cases where phone might be stored as "555-123-4567" or "(555) 123-4567"
  const { data: memberByIlike } = await supabase
    .from('members')
    .select('id, name, phone, phone_e164')
    .or(`phone.ilike.%${phoneWithoutCountry}%,phone_e164.ilike.%${phoneWithoutCountry}%`)
    .limit(5);

  if (memberByIlike && memberByIlike.length > 0) {
    // Find exact match by comparing normalized versions
    for (const member of memberByIlike) {
      const memberPhoneNormalized = normalizePhone(member.phone || '');
      const memberE164Normalized = normalizePhone(member.phone_e164 || '');
      
      if (memberPhoneNormalized === normalizedPhone || 
          memberPhoneNormalized === phoneWithoutCountry ||
          memberE164Normalized === normalizedPhone ||
          memberE164Normalized === phoneWithoutCountry) {
        console.log('Found member via ILIKE search:', member.name);
        return { id: member.id, name: member.name };
      }
    }
  }

  console.log('No member found for phone:', phone);
  return null;
}

// ============================================================================
// ELIGIBILITY CHECK
// ============================================================================

/**
 * Check if a member is eligible to vote based on:
 * 1. committee restriction (from committee column OR eligible_members.restrict_to_committee)
 * 2. executive_only flag (requires executive_committee = true on member)
 * 3. eligible_members JSONB filter (other fields)
 */
function checkMemberEligibility(
  memberId: string,
  memberData: any,
  eligibleMembers: Record<string, any> | null,
  executiveOnly: boolean | null,
  committeeRestriction: string | null
): { eligible: boolean; reason: string | null } {
  
  // Determine effective committee restriction
  // Can come from the dedicated committee column OR from eligible_members.restrict_to_committee
  let effectiveCommitteeRestriction = committeeRestriction;
  
  if (!effectiveCommitteeRestriction && eligibleMembers?.restrict_to_committee) {
    effectiveCommitteeRestriction = eligibleMembers.restrict_to_committee as string;
    console.log(`Found committee restriction in eligible_members.restrict_to_committee: ${effectiveCommitteeRestriction}`);
  }
  
  // Check committee restriction FIRST
  if (effectiveCommitteeRestriction) {
    const memberCommittees = memberData.committee as string[] | null;
    
    console.log(`Checking committee restriction for member ${memberId}:`, {
      requiredCommittee: effectiveCommitteeRestriction,
      source: committeeRestriction ? 'committee column' : 'eligible_members.restrict_to_committee',
      memberCommittees: memberCommittees,
      memberCommitteeField: memberData.committee,
      memberCommitteeType: typeof memberData.committee,
    });
    
    if (!isMemberInCommittee(memberCommittees, effectiveCommitteeRestriction)) {
      const displayCommittee = effectiveCommitteeRestriction;
      console.log(`Member ${memberId} NOT eligible: committee-restricted vote (${effectiveCommitteeRestriction}) but member is not in that committee.`);
      return {
        eligible: false,
        reason: `This vote is restricted to members of the ${displayCommittee}`,
      };
    }
    console.log(`Member ${memberId} PASSED committee restriction check for ${effectiveCommitteeRestriction}`);
  }

  // Check executive_only restriction
  if (executiveOnly === true) {
    if (memberData.executive_committee !== true) {
      console.log(`Member ${memberId} not eligible: executive_only vote but member is not on executive committee`);
      return {
        eligible: false,
        reason: 'This vote is restricted to Executive Committee members only',
      };
    }
    console.log(`Member ${memberId} passed executive_only check`);
  }

  // If no additional eligibility filter, member is eligible (passed committee and executive checks if applicable)
  if (!eligibleMembers || Object.keys(eligibleMembers).length === 0) {
    return { eligible: true, reason: null };
  }

  // Check each filter criterion in eligible_members JSONB
  // Skip restrict_to_committee since we already handled it above
  for (const [key, value] of Object.entries(eligibleMembers)) {
    // Skip restrict_to_committee - already handled above
    if (key === 'restrict_to_committee') {
      continue;
    }
    
    if (value === null || value === undefined) {
      continue; // Skip null filters
    }

    const memberValue = memberData[key];

    if (Array.isArray(value)) {
      // Array means "must be one of these values"
      if (!value.includes(memberValue)) {
        return {
          eligible: false,
          reason: `This vote is restricted to members with specific ${key} values`,
        };
      }
    } else if (typeof value === 'boolean') {
      if (memberValue !== value) {
        return {
          eligible: false,
          reason: `This vote requires ${key} to be ${value}`,
        };
      }
    } else if (memberValue !== value) {
      return {
        eligible: false,
        reason: `This vote is restricted based on ${key}`,
      };
    }
  }

  return { eligible: true, reason: null };
}

// ============================================================================
// ANALYTICS
// ============================================================================

/**
 * Record an analytics event
 */
async function recordAnalytics(
  formId: string,
  eventType: string,
  options: {
    memberId?: string | null;
    sessionToken?: string;
    ipAddress?: string;
    userAgent?: string;
    referrer?: string;
    metadata?: Record<string, any>;
  }
): Promise<void> {
  try {
    await supabase.from('form_analytics').insert({
      form_id: formId,
      member_id: options.memberId || null,
      session_token: options.sessionToken || null,
      event_type: eventType,
      timestamp: new Date().toISOString(),
      ip_address: options.ipAddress || null,
      user_agent: options.userAgent || null,
      referrer: options.referrer || null,
      metadata: options.metadata || null,
    });
  } catch (err) {
    console.error('Failed to record analytics:', err);
    // Don't throw - analytics failure shouldn't break the main flow
  }
}

// ============================================================================
// ACTION: GET VOTE INFO (Initial page load, before phone entry)
// ============================================================================

async function handleGetVoteInfo(request: GetVoteInfoRequest): Promise<{
  success: boolean;
  vote_id: string | null;
  vote_title: string | null;
  vote_description: string | null;
  vote_status: 'not_found' | 'not_active' | 'not_started' | 'ended' | 'open';
  voting_starts_at: string | null;
  voting_ends_at: string | null;
  executive_only: boolean;
  committee_restricted: string | null;
  session_token: string;
  error?: string;
}> {
  const { slug, ip_address, user_agent, referrer } = request;
  const sessionToken = request.session_token || generateSessionToken();

  if (!slug) {
    return {
      success: false,
      vote_id: null,
      vote_title: null,
      vote_description: null,
      vote_status: 'not_found',
      voting_starts_at: null,
      voting_ends_at: null,
      executive_only: false,
      committee_restricted: null,
      session_token: sessionToken,
      error: 'Vote slug is required',
    };
  }

  // Get the vote by slug
  const { data: vote, error: voteError } = await supabase
    .from('form_schemas')
    .select('id, title, description, status, voting_starts_at, voting_ends_at, executive_only, committee, eligible_members')
    .eq('slug', slug)
    .eq('form_type', 'vote')
    .maybeSingle();

  if (voteError || !vote) {
    console.log('Vote not found for slug:', slug);
    return {
      success: false,
      vote_id: null,
      vote_title: null,
      vote_description: null,
      vote_status: 'not_found',
      voting_starts_at: null,
      voting_ends_at: null,
      executive_only: false,
      committee_restricted: null,
      session_token: sessionToken,
      error: 'Vote not found',
    };
  }

  // Determine effective committee restriction (from column OR eligible_members)
  const effectiveCommitteeRestriction = vote.committee || 
    (vote.eligible_members as Record<string, any>)?.restrict_to_committee || 
    null;

  // Determine vote status
  const now = new Date();
  let voteStatus: 'not_active' | 'not_started' | 'ended' | 'open' = 'open';

  if (vote.status !== 'active') {
    voteStatus = 'not_active';
  } else if (vote.voting_starts_at && new Date(vote.voting_starts_at) > now) {
    voteStatus = 'not_started';
  } else if (vote.voting_ends_at && new Date(vote.voting_ends_at) < now) {
    voteStatus = 'ended';
  }

  // Record view analytics
  await recordAnalytics(vote.id, 'view', {
    sessionToken,
    ipAddress: ip_address,
    userAgent: user_agent,
    referrer,
    metadata: { 
      slug, 
      action: 'get_info', 
      executive_only: vote.executive_only,
      committee_restricted: effectiveCommitteeRestriction 
    },
  });

  return {
    success: true,
    vote_id: vote.id,
    vote_title: vote.title,
    vote_description: vote.description,
    vote_status: voteStatus,
    voting_starts_at: vote.voting_starts_at,
    voting_ends_at: vote.voting_ends_at,
    executive_only: vote.executive_only === true,
    committee_restricted: effectiveCommitteeRestriction,
    session_token: sessionToken,
  };
}

// ============================================================================
// ACTION: VERIFY MEMBER (After phone number entry)
// ============================================================================

async function handleVerifyMember(request: VerifyMemberRequest): Promise<VerifyMemberResponse> {
  const { phone, vote_slug, ip_address, user_agent, referrer } = request;
  const sessionToken = request.session_token || generateSessionToken();

  // Default error response
  const errorResponse = (error: string, voteStatus: VerifyMemberResponse['vote_status'] = 'not_found'): VerifyMemberResponse => ({
    success: false,
    is_member: false,
    member_id: null,
    member_name: null,
    already_voted: false,
    vote_id: null,
    vote_title: null,
    vote_description: null,
    vote_schema: null,
    vote_status: voteStatus,
    voting_starts_at: null,
    voting_ends_at: null,
    is_eligible: false,
    eligibility_reason: null,
    session_token: sessionToken,
    committee_restricted: null,
    error,
  });

  // Validate inputs
  if (!vote_slug) {
    return errorResponse('Vote slug is required');
  }

  if (!phone || !isValidPhone(phone)) {
    return errorResponse('Valid phone number is required');
  }

  // Get the vote by slug (include executive_only and committee fields)
  const { data: vote, error: voteError } = await supabase
    .from('form_schemas')
    .select('*')
    .eq('slug', vote_slug)
    .eq('form_type', 'vote')
    .maybeSingle();

  if (voteError || !vote) {
    return errorResponse('Vote not found');
  }

  // Check vote status
  const now = new Date();
  let voteStatus: VerifyMemberResponse['vote_status'] = 'open';

  if (vote.status !== 'active') {
    voteStatus = 'not_active';
  } else if (vote.voting_starts_at && new Date(vote.voting_starts_at) > now) {
    voteStatus = 'not_started';
  } else if (vote.voting_ends_at && new Date(vote.voting_ends_at) < now) {
    voteStatus = 'ended';
  }

  // Find member by phone
  const member = await findMemberByPhone(phone);

  // Record phone entry analytics
  await recordAnalytics(vote.id, 'phone_entered', {
    memberId: member?.id || null,
    sessionToken,
    ipAddress: ip_address,
    userAgent: user_agent,
    metadata: {
      phone_e164: formatPhoneE164(phone),
      member_found: !!member,
      executive_only: vote.executive_only,
      committee_restricted: vote.committee || (vote.eligible_members as Record<string, any>)?.restrict_to_committee || null,
    },
  });

  if (!member) {
    // Determine effective committee restriction for response
    const effectiveCommitteeRestriction = vote.committee || 
      (vote.eligible_members as Record<string, any>)?.restrict_to_committee || 
      null;
    
    // Member not found
    return {
      success: true,
      is_member: false,
      member_id: null,
      member_name: null,
      already_voted: false,
      vote_id: vote.id,
      vote_title: vote.title,
      vote_description: vote.description,
      vote_schema: null, // Don't expose schema to non-members
      vote_status: voteStatus,
      voting_starts_at: vote.voting_starts_at,
      voting_ends_at: vote.voting_ends_at,
      is_eligible: false,
      eligibility_reason: 'Phone number not found in member database',
      session_token: sessionToken,
      committee_restricted: effectiveCommitteeRestriction,
    };
  }

  // Member found! Record identity found analytics
  await recordAnalytics(vote.id, 'identity_found', {
    memberId: member.id,
    sessionToken,
    metadata: { source: 'phone_verification' },
  });

  // Get full member data for eligibility check (includes executive_committee and committee array)
  const { data: fullMember, error: memberError } = await supabase
    .from('members')
    .select('*')
    .eq('id', member.id)
    .single();

  if (memberError || !fullMember) {
    return errorResponse('Failed to load member data');
  }

  // Check eligibility (now includes committee restriction and executive_only check)
  const eligibility = checkMemberEligibility(
    member.id,
    fullMember,
    vote.eligible_members,
    vote.executive_only,
    vote.committee  // Pass the committee restriction
  );

  // Check if already voted
  const { data: existingVote } = await supabase
    .from('votes')
    .select('id')
    .eq('voting_form_id', vote.id)
    .eq('member_id', member.id)
    .maybeSingle();

  const alreadyVoted = !!existingVote;

  // Only provide schema if:
  // - Member is eligible (includes committee and executive_only checks)
  // - Has not already voted
  // - Vote is open
  const canVote = eligibility.eligible && !alreadyVoted && voteStatus === 'open';

  // Determine effective committee restriction for response
  const effectiveCommitteeRestriction = vote.committee || 
    (vote.eligible_members as Record<string, any>)?.restrict_to_committee || 
    null;

  return {
    success: true,
    is_member: true,
    member_id: member.id,
    member_name: member.name,
    already_voted: alreadyVoted,
    vote_id: vote.id,
    vote_title: vote.title,
    vote_description: vote.description,
    vote_schema: canVote ? vote.schema : null,
    vote_status: voteStatus,
    voting_starts_at: vote.voting_starts_at,
    voting_ends_at: vote.voting_ends_at,
    is_eligible: eligibility.eligible,
    eligibility_reason: eligibility.reason,
    session_token: sessionToken,
    committee_restricted: effectiveCommitteeRestriction,
  };
}

// ============================================================================
// ACTION: SUBMIT VOTE
// ============================================================================

async function handleSubmitVote(request: SubmitVoteRequest): Promise<{ success: boolean; error?: string }> {
  const { vote_id, member_id, vote_data, session_token, ip_address, user_agent } = request;

  // Validate inputs
  if (!vote_id) {
    return { success: false, error: 'vote_id is required' };
  }
  if (!member_id) {
    return { success: false, error: 'member_id is required' };
  }
  if (!vote_data || Object.keys(vote_data).length === 0) {
    return { success: false, error: 'vote_data is required' };
  }

  // Verify the vote exists and is open (include executive_only and committee fields)
  const { data: vote, error: voteError } = await supabase
    .from('form_schemas')
    .select('id, status, voting_starts_at, voting_ends_at, eligible_members, executive_only, committee, title')
    .eq('id', vote_id)
    .eq('form_type', 'vote')
    .single();

  if (voteError || !vote) {
    return { success: false, error: 'Vote not found' };
  }

  const now = new Date();
  
  if (vote.status !== 'active') {
    return { success: false, error: 'This vote is not currently active' };
  }
  if (vote.voting_starts_at && new Date(vote.voting_starts_at) > now) {
    return { success: false, error: 'Voting has not started yet' };
  }
  if (vote.voting_ends_at && new Date(vote.voting_ends_at) < now) {
    return { success: false, error: 'Voting has ended' };
  }

  // Verify member exists and get their data (includes executive_committee and committee array)
  const { data: member, error: memberError } = await supabase
    .from('members')
    .select('*')
    .eq('id', member_id)
    .single();

  if (memberError || !member) {
    return { success: false, error: 'Member not found' };
  }

  // Check eligibility (now includes committee restriction and executive_only check)
  const eligibility = checkMemberEligibility(
    member_id, 
    member, 
    vote.eligible_members,
    vote.executive_only,
    vote.committee  // Pass the committee restriction
  );
  
  if (!eligibility.eligible) {
    return { success: false, error: eligibility.reason || 'You are not eligible for this vote' };
  }

  // Check if already voted (race condition check)
  const { data: existingVote } = await supabase
    .from('votes')
    .select('id')
    .eq('voting_form_id', vote_id)
    .eq('member_id', member_id)
    .maybeSingle();

  if (existingVote) {
    return { success: false, error: 'You have already voted' };
  }

  // Insert the vote
  const { error: insertError } = await supabase
    .from('votes')
    .insert({
      voting_form_id: vote_id,
      member_id: member_id,
      vote_data: vote_data,
    });

  if (insertError) {
    console.error('Error inserting vote:', insertError);

    // Check if it's a unique constraint violation (race condition)
    if (insertError.code === '23505') {
      return { success: false, error: 'You have already voted' };
    }

    return { success: false, error: 'Failed to submit vote. Please try again.' };
  }

  // Record submit analytics
  await recordAnalytics(vote_id, 'submit', {
    memberId: member_id,
    sessionToken: session_token,
    ipAddress: ip_address,
    userAgent: user_agent,
    metadata: {
      vote_type: 'public_link',
      vote_title: vote.title,
      executive_only: vote.executive_only,
      committee_restricted: vote.committee || (vote.eligible_members as Record<string, any>)?.restrict_to_committee || null,
    },
  });

  const effectiveCommittee = vote.committee || (vote.eligible_members as Record<string, any>)?.restrict_to_committee || 'none';
  console.log(`Vote submitted successfully: member=${member_id}, vote=${vote_id}, committee=${effectiveCommittee}`);

  return { success: true };
}

// ============================================================================
// MAIN SERVER
// ============================================================================

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Only allow POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const { action, ...data } = body;

    console.log(`Processing action: ${action}`);

    let result: any;

    switch (action) {
      case 'get_vote_info':
        result = await handleGetVoteInfo(data);
        break;

      case 'verify_member':
        result = await handleVerifyMember(data);
        break;

      case 'submit_vote':
        result = await handleSubmitVote(data);
        break;

      default:
        return new Response(JSON.stringify({
          error: "Invalid action. Use 'get_vote_info', 'verify_member', or 'submit_vote'",
          code: 'INVALID_ACTION',
        }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Error processing request:", error);
    return new Response(JSON.stringify({
      error: error.message || "Failed to process request",
      code: "INTERNAL_ERROR",
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});