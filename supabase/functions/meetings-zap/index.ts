// supabase/functions/process-meeting/index.ts
import { serve as stdServe } from "https://deno.land/std@0.168.0/http/server.ts";
import { withSentry } from "../_shared/sentry.ts";
// Sentry-wrapped serve: errors + 5xx responses report to supabase-edge project.
const serve = (h: (req: Request) => Promise<Response> | Response) => stdServe(withSentry("meetings-zap", h));
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
const IGNORED_ATTENDEES = {
  emails: [
    'info@moyoungdemocrats.org'
  ],
  names: [
    'Missouri Young Democrats',
    'missouri young democrats'
  ]
};
// Arbiter for the non_member_attendees unique constraint
// (non_member_attendees_meeting_person_key, UNIQUE NULLS NOT DISTINCT).
// One row per guest per meeting: a rejoin belongs in number_of_joins and
// total_duration_minutes, which this function already aggregates per participant
// before writing. Re-enrichment of the same meeting must refresh that row rather
// than insert a second one, which is what produced 6 identical rows per guest on
// the 2026-08-12 executive meeting.
const NON_MEMBER_CONFLICT_TARGET = 'meeting_id,display_name,email';
// ==================== PRONOUN & NAME PARSING HELPERS ====================
/**
 * Extract pronouns from a display name
 * Examples: "John (he/him)", "Jane (she/her)", "Alex (they/them)"
 */ function extractPronouns(displayName) {
  if (!displayName) return {
    cleanName: '',
    pronouns: null
  };
  // Match pronouns in parentheses: (he/him), (she/her), (they/them), etc.
  const pronounRegex = /\s*\(([^)]*(?:he|she|they|ze|xe|hir|per|ve|ey|ne|fae)[^)]*)\)\s*/gi;
  const matches = displayName.match(pronounRegex);
  if (matches && matches.length > 0) {
    // Extract the pronouns (remove parentheses)
    const pronouns = matches[0].replace(/[()]/g, '').trim();
    // Remove pronoun text from name
    const cleanName = displayName.replace(pronounRegex, ' ').trim();
    console.log(`Extracted pronouns from "${displayName}": "${pronouns}" -> Clean name: "${cleanName}"`);
    return {
      cleanName,
      pronouns
    };
  }
  return {
    cleanName: displayName.trim(),
    pronouns: null
  };
}
/**
 * Detect if the display name is a phone number
 */ function isPhoneNumber(displayName) {
  if (!displayName) return false;
  // Remove common separators and check if what remains is mostly digits
  const cleaned = displayName.replace(/[\s\-().+]/g, '');
  // Must be at least 10 digits and at least 70% digits
  const digitCount = (cleaned.match(/\d/g) || []).length;
  return digitCount >= 10 && digitCount / cleaned.length >= 0.7;
}
/**
 * Extract phone number from display name
 */ function extractPhoneNumber(displayName) {
  if (!isPhoneNumber(displayName)) return null;
  // Remove non-digit characters
  return displayName.replace(/\D/g, '');
}
/**
 * Detect if the display name is a device name (e.g., "iPhone", "iPad", "Android")
 */ function isDeviceName(displayName) {
  if (!displayName) return false;
  const devicePatterns = [
    /iphone/i,
    /ipad/i,
    /android/i,
    /mobile/i,
    /tablet/i,
    /desktop/i,
    /'s\s+(iphone|ipad|android|mobile)/i
  ];
  return devicePatterns.some((pattern)=>pattern.test(displayName));
}
/**
 * Extract owner name from device name (e.g., "John's iPhone" -> "John")
 */ function extractOwnerFromDevice(displayName) {
  // Possessive form: "Sarah's iPad", "Karen’s iPhone". Straight and curly
  // apostrophes both occur in real Zoom display names.
  const possessiveMatch = displayName.match(/^(.+?)['’]s\s+/i);
  if (possessiveMatch && possessiveMatch[1]) {
    return possessiveMatch[1].trim();
  }
  // Bare trailing-device form: "James iPhone", "Dana Galaxy S23". This is the
  // shape that put an executive committee member in Guest Participants every
  // month: isDeviceName() fired, no possessive existed, and the participant
  // was written straight to non_member_attendees without ANY match attempt.
  // Strip the device words off the end and hand the remainder back. A name
  // that is nothing but device words ("iPhone", "iPad (2)", "Zoom user")
  // returns null and is still treated as a device.
  const cleaned = displayName
    .replace(/\s*\(\d+\)\s*$/, '')
    .trim();
  const deviceTail = /(?:'s|’s)?\s*\b(?:iphone|ipad|ipod|android|galaxy|pixel|tablet|mobile|phone|desktop|laptop|macbook|surface|chromebook)\b[\s\d\w+-]*$/i;
  const remainder = cleaned.replace(deviceTail, '').trim();
  if (!remainder || remainder.length < 2) return null;
  // Refuse to treat a leftover that is itself a device/placeholder word as a
  // person. Also refuse anything with no letters.
  if (!/[a-z]/i.test(remainder)) return null;
  if (/^(?:zoom|user|guest|my|the|new)$/i.test(remainder)) return null;
  return remainder;
}
// ==================== DURABLE ALIASES ====================
// public.meeting_attendee_aliases maps a Zoom display name to a member once a
// human has confirmed it. It is consulted BEFORE every heuristic below,
// including the device short-circuit, because a confirmed answer outranks any
// guess. See supabase/migrations/20260822_02_meeting_attendee_aliases.sql.
async function findMemberByAlias(supabaseClient, displayName) {
  if (!displayName) return null;
  const key = normalizeString(displayName);
  if (!key) return null;
  try {
    const { data, error } = await supabaseClient
      .from('meeting_attendee_aliases')
      .select('member_id')
      .eq('display_name_key', key)
      .maybeSingle();
    if (error) {
      console.error(`Alias lookup failed for "${displayName}": ${error.message}`);
      return null;
    }
    if (!data || !data.member_id) return null;
    const { data: member, error: memberError } = await supabaseClient
      .from('members')
      .select('id, name')
      .eq('id', data.member_id)
      .maybeSingle();
    if (memberError || !member) {
      console.error(`Alias for "${displayName}" points at a member that could not be read`);
      return null;
    }
    console.log(`✓ Matched by confirmed alias: "${displayName}" -> ${member.name}`);
    return {
      id: member.id,
      name: member.name,
      matched_by: 'alias'
    };
  } catch (error) {
    console.error(`Alias lookup threw for "${displayName}": ${error.message}`);
    return null;
  }
}
// ==================== MEMBER ROSTER FETCH ====================
// The name-matching path used to read `.limit(300)` from a 424-row members
// table, so 124 arbitrary members were invisible to it and a member could
// silently drop out of matching as the roster grew or as rows moved in the
// heap. Chloé Ray matched by normalized name on 2026-06-10 and 2026-07-15 and
// then appeared as a GUEST on 2026-07-22, 07-29 and 08-12 with no code change
// in between. Page the whole roster instead of capping it.
async function fetchAllMembers(supabaseClient) {
  const pageSize = 1000;
  const all = [];
  for(let from = 0;; from += pageSize){
    const { data, error } = await supabaseClient
      .from('members')
      .select('id, name, email, school_email, committee, executive_committee')
      .order('id', { ascending: true })
      .range(from, from + pageSize - 1);
    if (error) {
      console.error(`Failed to fetch members page at offset ${from}: ${error.message}`);
      break;
    }
    if (!data || data.length === 0) break;
    all.push(...data);
    if (data.length < pageSize) break;
  }
  console.log(`Fetched ${all.length} members for matching`);
  return all;
}
// A meeting's plausible attendee set: members carrying a committee that maps
// to the meeting title, plus every executive when the meeting is an executive
// meeting. Used only to DISAMBIGUATE, never to widen a match.
function isExecutiveMeetingTitle(meetingTitle) {
  return normalizeString(meetingTitle || '').includes('exec');
}
function membersOnMeetingCommittee(allMembers, meetingTitle) {
  if (!meetingTitle) return [];
  const execMeeting = isExecutiveMeetingTitle(meetingTitle);
  return allMembers.filter((m)=>committeesMatch(meetingTitle, m.committee) || execMeeting && m.executive_committee === true);
}
// First name alone resolves ONLY when exactly one member with that first name
// sits on the meeting's committee. "James" is ambiguous across three members
// org-wide, so it resolves on the executive committee (where only one James
// sits) and nowhere else. A tie refuses rather than guessing: a wrong match
// silently credits attendance to the wrong person, which is worse than a
// guest row.
function resolveByFirstNameOnCommittee(allMembers, firstName, meetingTitle) {
  const key = normalizeString(firstName || '');
  if (key.length < 2) return null;
  const scoped = membersOnMeetingCommittee(allMembers, meetingTitle);
  if (scoped.length === 0) return null;
  const hits = scoped.filter((m)=>{
    const parts = (m.name || '').trim().split(/\s+/);
    return parts.length > 0 && normalizeString(parts[0]) === key;
  });
  if (hits.length !== 1) {
    if (hits.length > 1) {
      console.log(`✗ First name "${firstName}" is ambiguous on this committee (${hits.length} members) — refusing to guess`);
    }
    return null;
  }
  console.log(`✓ Matched by unique first name on meeting committee: ${hits[0].name}`);
  return {
    id: hits[0].id,
    name: hits[0].name,
    matched_by: 'first_name_committee'
  };
}
// ==================== DATE/TIME PARSING HELPERS ====================
/**
 * Robustly parse various date/time formats into ISO string
 */ function parseDateTime(value) {
  if (!value) {
    console.log('No date/time value provided, using current time');
    return new Date().toISOString();
  }
  // Already a Date object
  if (value instanceof Date) {
    if (isNaN(value.getTime())) {
      console.log('Invalid Date object, using current time');
      return new Date().toISOString();
    }
    return value.toISOString();
  }
  // String value
  if (typeof value === 'string') {
    const trimmed = value.trim();
    // Empty string
    if (trimmed.length === 0) {
      console.log('Empty date string, using current time');
      return new Date().toISOString();
    }
    // Try parsing as ISO string or any standard date format
    const parsed = new Date(trimmed);
    if (!isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
    // Try parsing as Unix timestamp (seconds)
    const asNumber = parseFloat(trimmed);
    if (!isNaN(asNumber)) {
      return parseUnixTimestamp(asNumber);
    }
    console.log(`Could not parse date string: "${trimmed}", using current time`);
    return new Date().toISOString();
  }
  // Number value (Unix timestamp)
  if (typeof value === 'number') {
    return parseUnixTimestamp(value);
  }
  console.log(`Unknown date format (${typeof value}), using current time`);
  return new Date().toISOString();
}
/**
 * Parse Unix timestamp (handles both seconds and milliseconds)
 */ function parseUnixTimestamp(timestamp) {
  // If timestamp is in seconds (less than year 2286 in milliseconds)
  if (timestamp < 10000000000) {
    timestamp = timestamp * 1000;
  }
  const date = new Date(timestamp);
  if (isNaN(date.getTime())) {
    console.log(`Invalid Unix timestamp: ${timestamp}, using current time`);
    return new Date().toISOString();
  }
  return date.toISOString();
}
/**
 * Robustly parse duration into minutes
 */ function parseDurationMinutes(value) {
  if (!value && value !== 0) {
    console.log('No duration value provided, defaulting to 0');
    return 0;
  }
  // Already a number
  if (typeof value === 'number') {
    // Sanity check - if duration is very large, it might be in seconds
    if (value > 1000) {
      console.log(`Duration seems large (${value}), treating as seconds`);
      return Math.round(value / 60);
    }
    return Math.round(value);
  }
  // String value
  if (typeof value === 'string') {
    const trimmed = value.trim();
    // Empty string
    if (trimmed.length === 0) {
      console.log('Empty duration string, defaulting to 0');
      return 0;
    }
    // Try parsing as number
    const asNumber = parseFloat(trimmed);
    if (!isNaN(asNumber)) {
      // Same sanity check for large numbers
      if (asNumber > 1000) {
        console.log(`Duration seems large (${asNumber}), treating as seconds`);
        return Math.round(asNumber / 60);
      }
      return Math.round(asNumber);
    }
    // Try extracting number from string like "45 minutes" or "1.5 hours"
    const numberMatch = trimmed.match(/(\d+\.?\d*)/);
    if (numberMatch) {
      const num = parseFloat(numberMatch[1]);
      const lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed.includes('hour')) {
        return Math.round(num * 60);
      } else if (lowerTrimmed.includes('second')) {
        return Math.round(num / 60);
      } else {
        // Default to minutes
        return Math.round(num);
      }
    }
    console.log(`Could not parse duration: "${trimmed}", defaulting to 0`);
    return 0;
  }
  console.log(`Unknown duration format (${typeof value}), defaulting to 0`);
  return 0;
}
/**
 * Calculate end time from start time and duration
 */ function calculateEndTime(startTime, durationMinutes) {
  try {
    const start = new Date(startTime);
    const end = new Date(start.getTime() + durationMinutes * 60 * 1000);
    return end.toISOString();
  } catch (error) {
    console.error('Error calculating end time:', error);
    return new Date().toISOString();
  }
}
// ==================== STRING NORMALIZATION ====================
function normalizeString(str) {
  return str.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, '').trim();
}
function normalizeEmail(email) {
  return email.toLowerCase().trim();
}
function calculateSimilarity(str1, str2) {
  const longer = str1.length > str2.length ? str1 : str2;
  const shorter = str1.length > str2.length ? str2 : str1;
  if (longer.length === 0) return 1.0;
  const editDistance = levenshteinDistance(longer, shorter);
  return (longer.length - editDistance) / longer.length;
}
function levenshteinDistance(str1, str2) {
  const matrix = [];
  for(let i = 0; i <= str2.length; i++){
    matrix[i] = [
      i
    ];
  }
  for(let j = 0; j <= str1.length; j++){
    matrix[0][j] = j;
  }
  for(let i = 1; i <= str2.length; i++){
    for(let j = 1; j <= str1.length; j++){
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(matrix[i - 1][j - 1] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j] + 1);
      }
    }
  }
  return matrix[str2.length][str1.length];
}
function committeesMatch(meetingTitle, memberCommittees) {
  if (!memberCommittees || memberCommittees.length === 0) {
    return false;
  }
  const normalizedMeeting = normalizeString(meetingTitle);
  const patterns = {
    'executive': [
      'exec',
      'executivecommittee',
      'executive'
    ],
    'politicalaffairs': [
      'pac',
      'politicalaffairscommittee',
      'politicalaffairs',
      'political'
    ],
    'communications': [
      'comms',
      'comm',
      'communicationscommittee',
      'communications'
    ],
    'membership': [
      'mem',
      'membershipcommittee',
      'membership'
    ],
    'finance': [
      'fin',
      'financecommittee',
      'finance'
    ],
    'events': [
      'evt',
      'eventscommittee',
      'events'
    ]
  };
  for (const committee of memberCommittees){
    const normalizedCommittee = normalizeString(committee);
    if (normalizedMeeting.includes(normalizedCommittee) || normalizedCommittee.includes(normalizedMeeting)) {
      return true;
    }
    for (const [key, variations] of Object.entries(patterns)){
      const meetingMatches = variations.some((v)=>normalizedMeeting.includes(v));
      const committeeMatches = variations.some((v)=>normalizedCommittee.includes(v));
      if (meetingMatches && committeeMatches) {
        return true;
      }
    }
  }
  return false;
}
// ==================== ZOOM TOKEN ====================
async function getZoomAccessToken() {
  const clientId = Deno.env.get('ZOOM_CLIENT_ID');
  const clientSecret = Deno.env.get('ZOOM_CLIENT_SECRET');
  const accountId = Deno.env.get('ZOOM_ACCOUNT_ID');
  if (!clientId || !clientSecret || !accountId) {
    throw new Error('Missing Zoom credentials in environment');
  }
  const credentials = btoa(`${clientId}:${clientSecret}`);
  const response = await fetch('https://zoom.us/oauth/token', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: `grant_type=account_credentials&account_id=${accountId}`
  });
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Zoom OAuth error: ${response.status} - ${errorText}`);
  }
  const data = await response.json();
  return data.access_token;
}
// ==================== ZOOM API ====================
async function fetchZoomParticipants(meetingId) {
  try {
    const accessToken = await getZoomAccessToken();
    const response = await fetch(`https://api.zoom.us/v2/report/meetings/${meetingId}/participants`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    if (!response.ok) {
      throw new Error(`Zoom API error: ${response.status} ${response.statusText}`);
    }
    const data = await response.json();
    return extractParticipants(data);
  } catch (error) {
    console.error('Error fetching Zoom participants:', error);
    return [];
  }
}
// ==================== FILTER IGNORED ====================
function filterIgnoredAttendees(participants) {
  return participants.filter((p)=>{
    const email = p.user_email || p.email || p.participant_email;
    const name = p.name || p.user_name || p.participant_name || '';
    if (email && IGNORED_ATTENDEES.emails.some((ignored)=>email.toLowerCase().includes(ignored.toLowerCase()))) {
      console.log(`Filtering out ignored email: ${email}`);
      return false;
    }
    if (IGNORED_ATTENDEES.names.some((ignored)=>name.toLowerCase().includes(ignored.toLowerCase()))) {
      console.log(`Filtering out ignored name: ${name}`);
      return false;
    }
    return true;
  });
}
// ==================== HOST IDENTIFICATION ====================
async function identifyAndMatchHost(supabaseClient, hostHint, meetingTitle, participants) {
  console.log(`\n┌─────────────────────────────────────────┐`);
  console.log(`│ STEP 1: Search database for "${hostHint}"`);
  console.log(`└─────────────────────────────────────────┘`);
  const normalizedHint = normalizeString(hostHint);
  console.log(`Normalized hint: "${normalizedHint}"`);
  const { data: allMembers, error: fetchError } = await supabaseClient.from('members').select('id, name, email, school_email, committee');
  if (fetchError) {
    console.error('❌ Database error:', fetchError);
    return null;
  }
  if (!allMembers || allMembers.length === 0) {
    console.log('❌ No members found in database');
    return null;
  }
  console.log(`✓ Fetched ${allMembers.length} total members from database`);
  const matchingMembers = [];
  console.log(`\n┌─────────────────────────────────────────┐`);
  console.log(`│ STEP 2: Find members matching hint      │`);
  console.log(`└─────────────────────────────────────────┘`);
  for (const member of allMembers){
    const normalizedName = normalizeString(member.name);
    const nameParts = member.name.split(' ');
    const firstName = nameParts.length > 0 ? normalizeString(nameParts[0]) : '';
    const lastName = nameParts.length > 1 ? normalizeString(nameParts[nameParts.length - 1]) : '';
    if (normalizedName === normalizedHint) {
      console.log(`✓ Exact match: ${member.name}`);
      matchingMembers.push({
        member,
        matchType: 'exact',
        score: 1.0
      });
      continue;
    }
    if (firstName === normalizedHint) {
      console.log(`✓ First name match: ${member.name}`);
      matchingMembers.push({
        member,
        matchType: 'first_name',
        score: 0.9
      });
      continue;
    }
    if (lastName === normalizedHint) {
      console.log(`✓ Last name match: ${member.name}`);
      matchingMembers.push({
        member,
        matchType: 'last_name',
        score: 0.9
      });
      continue;
    }
    if (normalizedName.includes(normalizedHint) || normalizedHint.includes(normalizedName)) {
      console.log(`✓ Partial match: ${member.name}`);
      matchingMembers.push({
        member,
        matchType: 'partial',
        score: 0.8
      });
      continue;
    }
    const similarity = calculateSimilarity(normalizedHint, normalizedName);
    if (similarity >= 0.7) {
      console.log(`✓ Similarity match (${(similarity * 100).toFixed(0)}%): ${member.name}`);
      matchingMembers.push({
        member,
        matchType: 'similarity',
        score: similarity
      });
    }
  }
  if (matchingMembers.length === 0) {
    console.log('❌ No matching members found');
    return null;
  }
  console.log(`\n✓ Found ${matchingMembers.length} matching member(s)`);
  matchingMembers.sort((a, b)=>b.score - a.score);
  console.log(`\n┌─────────────────────────────────────────┐`);
  console.log(`│ STEP 3: Select best member match        │`);
  console.log(`└─────────────────────────────────────────┘`);
  let selectedMember = null;
  if (matchingMembers.length === 1) {
    selectedMember = matchingMembers[0].member;
    console.log(`✓ Single match: ${selectedMember.name}`);
  } else {
    console.log(`Multiple matches found, checking committees...`);
    for (const match of matchingMembers){
      const member = match.member;
      console.log(`  - ${member.name}`);
      console.log(`    Committees: ${member.committee ? JSON.stringify(member.committee) : 'none'}`);
      if (member.committee && committeesMatch(meetingTitle, member.committee)) {
        selectedMember = member;
        console.log(`    ✓ Committee matches meeting title!`);
        break;
      }
    }
    if (!selectedMember) {
      selectedMember = matchingMembers[0].member;
      console.log(`  ⚠ No committee match, using highest score: ${selectedMember.name}`);
    }
  }
  console.log(`\n┌─────────────────────────────────────────┐`);
  console.log(`│ STEP 4: Match to participant            │`);
  console.log(`└─────────────────────────────────────────┘`);
  console.log(`Selected member: ${selectedMember.name}`);
  console.log(`Member email: ${selectedMember.email || 'none'}`);
  console.log(`Member school email: ${selectedMember.school_email || 'none'}`);
  console.log(`Available participants: ${participants.length}`);
  let matchedParticipant = null;
  for (const participant of participants){
    console.log(`\nChecking participant: ${participant.name} (${participant.email || 'no email'})`);
    if (participant.email) {
      const participantEmail = normalizeEmail(participant.email);
      if (selectedMember.email && participantEmail === normalizeEmail(selectedMember.email)) {
        matchedParticipant = participant;
        console.log(`  ✓ Matched by email!`);
        break;
      }
      if (selectedMember.school_email && participantEmail === normalizeEmail(selectedMember.school_email)) {
        matchedParticipant = participant;
        console.log(`  ✓ Matched by school email!`);
        break;
      }
    }
    const participantNormalized = normalizeString(participant.name);
    const memberNormalized = normalizeString(selectedMember.name);
    if (participantNormalized === memberNormalized) {
      matchedParticipant = participant;
      console.log(`  ✓ Matched by name!`);
      break;
    }
    const participantParts = participant.name.split(' ');
    const memberParts = selectedMember.name.split(' ');
    if (participantParts.length >= 2 && memberParts.length >= 2) {
      const pFirst = normalizeString(participantParts[0]);
      const pLast = normalizeString(participantParts[participantParts.length - 1]);
      const mFirst = normalizeString(memberParts[0]);
      const mLast = normalizeString(memberParts[memberParts.length - 1]);
      if (pFirst === mFirst && pLast === mLast) {
        matchedParticipant = participant;
        console.log(`  ✓ Matched by first+last name!`);
        break;
      }
    }
  }
  if (!matchedParticipant) {
    console.log(`\n⚠ Member found but not in participant list`);
    console.log(`  Will add them as host-only participant`);
  }
  return {
    memberId: selectedMember.id,
    memberName: selectedMember.name,
    memberEmail: selectedMember.email || selectedMember.school_email || null,
    participant: matchedParticipant
  };
}
// ==================== EXTRACT PARTICIPANTS ====================
function extractParticipants(participants) {
  if (!participants) return [];
  if (Array.isArray(participants)) return participants;
  if (typeof participants === 'object') {
    if (participants.results && Array.isArray(participants.results)) {
      return participants.results;
    }
    if (participants.participants && Array.isArray(participants.participants)) {
      return participants.participants;
    }
    if (participants.users && Array.isArray(participants.users)) {
      return participants.users;
    }
    if (participants.data && Array.isArray(participants.data)) {
      return participants.data;
    }
    for (const key of [
      'attendees',
      'members',
      'people',
      'list',
      'items'
    ]){
      if (participants[key] && Array.isArray(participants[key])) {
        return participants[key];
      }
    }
    if (participants.name || participants.user_name) {
      return [
        participants
      ];
    }
  }
  if (typeof participants === 'string') {
    try {
      return extractParticipants(JSON.parse(participants));
    } catch (error) {
      console.error('Failed to parse participants string:', error);
    }
  }
  return [];
}
// ==================== DEDUPLICATION ====================
function deduplicateParticipants(participants) {
  const participantMap = new Map();
  for (const participant of participants){
    const participantName = participant.name || participant.user_name || participant.participant_name;
    if (!participantName || participantName.trim().length === 0) {
      continue;
    }
    if (participant.status === 'in_waiting_room') {
      continue;
    }
    const participantEmail = participant.user_email || participant.email || participant.participant_email;
    const joinTime = parseDateTime(participant.join_time);
    const leaveTime = parseDateTime(participant.leave_time);
    const duration = typeof participant.duration === 'number' ? participant.duration : 0;
    const nameKey = normalizeString(participantName);
    if (participantMap.has(nameKey)) {
      const existing = participantMap.get(nameKey);
      existing.totalDuration += duration;
      existing.numberOfJoins += 1;
      if (participantEmail && !existing.email) {
        existing.email = participantEmail;
      }
      if (new Date(joinTime) < new Date(existing.firstJoin)) {
        existing.firstJoin = joinTime;
      }
      if (new Date(leaveTime) > new Date(existing.lastLeave)) {
        existing.lastLeave = leaveTime;
      }
    } else {
      participantMap.set(nameKey, {
        name: participantName,
        email: participantEmail || undefined,
        totalDuration: duration,
        firstJoin: joinTime,
        lastLeave: leaveTime,
        numberOfJoins: 1,
        isHost: false
      });
    }
  }
  return Array.from(participantMap.values());
}
// ==================== TRANSCRIPT STORAGE ====================
async function storeTranscript(supabaseClient, meetingTitle, meetingDate, transcriptText) {
  const date = new Date(meetingDate);
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const year = date.getFullYear();
  const cleanTitle = meetingTitle.replace(/[^a-zA-Z0-9\s-]/g, '').trim();
  const fileName = `transcripts/${cleanTitle}/${month}/${day}/${year}.txt`;
  console.log(`Storing transcript at: ${fileName}`);
  const encoder = new TextEncoder();
  const data = encoder.encode(transcriptText);
  const { error: uploadError } = await supabaseClient.storage.from('meetings').upload(fileName, data, {
    contentType: 'text/plain',
    upsert: true
  });
  if (uploadError) {
    throw new Error(`Failed to store transcript: ${uploadError.message}`);
  }
  return fileName;
}
// ==================== PHONE NUMBER MATCHING ====================
/**
 * Update member pronouns if extracted from display name and different from stored value
 */ async function updateMemberPronouns(supabaseClient, memberId, memberName, extractedPronouns) {
  try {
    console.log(`\n🏷️  Pronoun update check for ${memberName}`);
    console.log(`   Extracted pronouns: "${extractedPronouns}"`);
    // Get current pronouns from member record
    const { data: member, error: fetchError } = await supabaseClient.from('members').select('preferred_pronouns').eq('id', memberId).single();
    if (fetchError) {
      console.error(`   ❌ Error fetching member pronouns: ${fetchError.message}`);
      return;
    }
    const currentPronouns = member?.preferred_pronouns;
    console.log(`   Current pronouns in DB: ${currentPronouns || 'null'}`);
    // Update if null or different
    if (!currentPronouns || currentPronouns !== extractedPronouns) {
      const { error: updateError } = await supabaseClient.from('members').update({
        preferred_pronouns: extractedPronouns
      }).eq('id', memberId);
      if (updateError) {
        console.error(`   ❌ Error updating pronouns: ${updateError.message}`);
      } else {
        console.log(`   ✅ Updated pronouns: "${currentPronouns || 'null'}" → "${extractedPronouns}"`);
      }
    } else {
      console.log(`   ℹ️  Pronouns unchanged (already "${currentPronouns}")`);
    }
  } catch (error) {
    console.error(`Error in updateMemberPronouns: ${error.message}`);
  }
}
// ==================== PHONE NUMBER MATCHING ====================
async function findMemberByPhoneNumber(supabaseClient, phoneNumber) {
  console.log(`Searching for member by phone number: ${phoneNumber}`);
  // Try exact match first
  const { data: exactMatch } = await supabaseClient.from('members').select('id, name, phone_number').eq('phone_number', phoneNumber).limit(1).maybeSingle();
  if (exactMatch) {
    console.log(`✓ Matched by phone number: ${exactMatch.name}`);
    return {
      id: exactMatch.id,
      name: exactMatch.name,
      matched_by: 'phone_number'
    };
  }
  // Try normalized phone matching (remove all non-digits and compare)
  const normalizedPhone = phoneNumber.replace(/\D/g, '');
  // Get last 10 digits (US phone numbers)
  const lastTenDigits = normalizedPhone.slice(-10);
  const { data: allMembers } = await supabaseClient.from('members').select('id, name, phone_number').not('phone_number', 'is', null).limit(500);
  if (allMembers && allMembers.length > 0) {
    for (const member of allMembers){
      if (!member.phone_number) continue;
      const memberNormalized = member.phone_number.replace(/\D/g, '');
      const memberLastTen = memberNormalized.slice(-10);
      if (lastTenDigits === memberLastTen) {
        console.log(`✓ Matched by normalized phone number: ${member.name}`);
        return {
          id: member.id,
          name: member.name,
          matched_by: 'phone_number_normalized'
        };
      }
    }
  }
  console.log(`✗ No member found with phone number: ${phoneNumber}`);
  return null;
}
// ==================== ATTENDANCE PROCESSING ====================
async function processAttendance(supabaseClient, meetingId, participants, meetingTitle) {
  const results = [];
  // One roster read for the whole meeting rather than one per participant.
  const allMembers = await fetchAllMembers(supabaseClient);
  for (const participant of participants){
    try {
      let originalDisplayName = participant.name;
      let cleanedName = participant.name;
      let extractedPronouns = null;
      let phoneNumber = null;
      let deviceDerivedName = false;
      // STEP 0: Confirmed alias on the RAW display name. Checked before the
      // device short-circuit below, which otherwise skips matching entirely.
      const aliasMember = await findMemberByAlias(supabaseClient, originalDisplayName);
      // STEP 1: Handle device names
      if (isDeviceName(originalDisplayName) && !aliasMember) {
        const ownerName = extractOwnerFromDevice(originalDisplayName);
        if (ownerName) {
          console.log(`Device name detected: "${originalDisplayName}" -> Owner: "${ownerName}"`);
          cleanedName = ownerName;
          participant.name = ownerName;
          deviceDerivedName = true;
        } else {
          console.log(`Device name without owner: "${originalDisplayName}" - will create non-member record`);
          // Create non-member record for device without owner
          const { error: nonMemberError } = await supabaseClient.from('non_member_attendees').upsert({
            meeting_id: meetingId,
            display_name: originalDisplayName,
            email: participant.email || null,
            phone_number: null,
            pronouns: null,
            total_duration_minutes: Math.round(participant.totalDuration / 60),
            first_join_time: participant.firstJoin,
            last_leave_time: participant.lastLeave,
            number_of_joins: participant.numberOfJoins
          }, {
            onConflict: NON_MEMBER_CONFLICT_TARGET
          });
          if (nonMemberError) {
            console.error(`Error creating non-member record for device: ${nonMemberError.message}`);
          }
          results.push({
            name: originalDisplayName,
            email: participant.email,
            status: 'non_member_device',
            duration: Math.round(participant.totalDuration / 60),
            is_host: participant.isHost || false
          });
          continue;
        }
      }
      // STEP 2: Handle phone numbers
      if (isPhoneNumber(cleanedName) && !aliasMember) {
        phoneNumber = extractPhoneNumber(cleanedName);
        console.log(`Phone number detected: "${cleanedName}" -> ${phoneNumber}`);
        if (phoneNumber) {
          const memberMatch = await findMemberByPhoneNumber(supabaseClient, phoneNumber);
          if (memberMatch) {
            // Found member by phone - create attendance record
            participant.memberId = memberMatch.id;
            participant.name = memberMatch.name;
            cleanedName = memberMatch.name;
            const { error: attendanceError } = await supabaseClient.from('meeting_attendance').insert({
              meeting_id: meetingId,
              member_id: memberMatch.id,
              total_duration_minutes: Math.round(participant.totalDuration / 60),
              first_join_time: participant.firstJoin,
              last_leave_time: participant.lastLeave,
              number_of_joins: participant.numberOfJoins,
              zoom_display_name: originalDisplayName,
              zoom_email: participant.email || null,
              matched_by: memberMatch.matched_by,
              is_host: participant.isHost || false
            });
            if (attendanceError && attendanceError.code !== '23505') {
              console.error(`Error creating attendance for phone match: ${attendanceError.message}`);
            } else {
              // Update pronouns if we extracted any (even from a phone number display with pronouns)
              if (extractedPronouns) {
                await updateMemberPronouns(supabaseClient, memberMatch.id, memberMatch.name, extractedPronouns);
              }
            }
            results.push({
              name: originalDisplayName,
              matched_member: memberMatch.name,
              member_id: memberMatch.id,
              matched_by: memberMatch.matched_by,
              duration_minutes: Math.round(participant.totalDuration / 60),
              joins: participant.numberOfJoins,
              pronouns_updated: extractedPronouns ? true : false,
              is_host: participant.isHost || false,
              status: 'success'
            });
            continue;
          } else {
            // Phone number but no member match - create non-member record
            const { error: nonMemberError } = await supabaseClient.from('non_member_attendees').upsert({
              meeting_id: meetingId,
              display_name: originalDisplayName,
              email: participant.email || null,
              phone_number: phoneNumber,
              pronouns: null,
              total_duration_minutes: Math.round(participant.totalDuration / 60),
              first_join_time: participant.firstJoin,
              last_leave_time: participant.lastLeave,
              number_of_joins: participant.numberOfJoins
            }, {
              onConflict: NON_MEMBER_CONFLICT_TARGET
            });
            if (nonMemberError) {
              console.error(`Error creating non-member record for phone: ${nonMemberError.message}`);
            }
            results.push({
              name: originalDisplayName,
              phone_number: phoneNumber,
              status: 'non_member_phone',
              duration: Math.round(participant.totalDuration / 60),
              is_host: participant.isHost || false
            });
            continue;
          }
        }
      }
      // STEP 3: Extract pronouns
      const { cleanName, pronouns } = extractPronouns(cleanedName);
      if (pronouns) {
        extractedPronouns = pronouns;
        cleanedName = cleanName;
        participant.name = cleanName;
        console.log(`Pronouns extracted from "${originalDisplayName}": ${pronouns} -> Clean: "${cleanedName}"`);
      }
      // STEP 4: Check if participant already has memberId (from host identification)
      let member = null;
      if (aliasMember) {
        member = aliasMember;
      } else if (participant.memberId) {
        console.log(`Using pre-identified member ID for ${cleanedName}: ${participant.memberId}`);
        member = {
          id: participant.memberId,
          name: cleanedName,
          matched_by: 'host_identified'
        };
      } else {
        // STEP 5: Try to find member match
        member = await findMemberWithFallback(supabaseClient, cleanedName, participant.email, allMembers, meetingTitle);
      }
      if (!member) {
        console.log(`No member match found for: ${cleanedName} (${participant.email || 'no email'})`);
        // Check if this is a single-word name (just first name)
        const nameParts = cleanedName.trim().split(/\s+/);
        const isSingleName = nameParts.length === 1;
        // Only create non-member record if:
        // 1. Has email, OR
        // 2. Has last name (at least 2 name parts), OR
        // 3. Has pronouns extracted, OR
        // 4. The single name came from stripping a device suffix. Without
        //    this, "James iPhone" would resolve to the one-word "James",
        //    fail the committee rule, and then be dropped entirely rather
        //    than staying visible as an unresolved guest.
        if (participant.email || !isSingleName || extractedPronouns || deviceDerivedName) {
          console.log(`Creating non-member record for: ${cleanedName}`);
          const { error: nonMemberError } = await supabaseClient.from('non_member_attendees').upsert({
            meeting_id: meetingId,
            display_name: originalDisplayName,
            email: participant.email || null,
            phone_number: phoneNumber,
            pronouns: extractedPronouns,
            total_duration_minutes: Math.round(participant.totalDuration / 60),
            first_join_time: participant.firstJoin,
            last_leave_time: participant.lastLeave,
            number_of_joins: participant.numberOfJoins
          }, {
            onConflict: NON_MEMBER_CONFLICT_TARGET
          });
          if (nonMemberError) {
            console.error(`Error creating non-member record: ${nonMemberError.message}`);
          }
          results.push({
            name: originalDisplayName,
            email: participant.email,
            pronouns: extractedPronouns,
            status: 'non_member',
            duration: Math.round(participant.totalDuration / 60),
            is_host: participant.isHost || false
          });
        } else {
          // Single name without email or pronouns - just log as no match
          results.push({
            name: originalDisplayName,
            status: 'no_match_single_name',
            duration: Math.round(participant.totalDuration / 60),
            is_host: participant.isHost || false
          });
        }
        continue;
      }
      // STEP 6: Check if attendance already exists
      const { data: existingAttendance } = await supabaseClient.from('meeting_attendance').select('id').eq('meeting_id', meetingId).eq('member_id', member.id).maybeSingle();
      if (existingAttendance) {
        console.log(`Attendance already recorded for ${member.name}, updating is_host flag...`);
        if (participant.isHost) {
          await supabaseClient.from('meeting_attendance').update({
            is_host: true
          }).eq('id', existingAttendance.id);
        }
        // Update pronouns even if attendance already exists
        if (extractedPronouns) {
          await updateMemberPronouns(supabaseClient, member.id, member.name, extractedPronouns);
        }
        results.push({
          name: originalDisplayName,
          matched_member: member.name,
          pronouns_updated: extractedPronouns ? true : false,
          status: 'already_recorded',
          is_host: participant.isHost || false
        });
        continue;
      }
      // STEP 7: Create attendance record
      const { error: attendanceError } = await supabaseClient.from('meeting_attendance').insert({
        meeting_id: meetingId,
        member_id: member.id,
        total_duration_minutes: Math.round(participant.totalDuration / 60),
        first_join_time: participant.firstJoin,
        last_leave_time: participant.lastLeave,
        number_of_joins: participant.numberOfJoins,
        zoom_display_name: originalDisplayName,
        zoom_email: participant.email || null,
        matched_by: member.matched_by,
        is_host: participant.isHost || false
      });
      if (attendanceError) {
        if (attendanceError.code === '23505') {
          results.push({
            name: originalDisplayName,
            matched_member: member.name,
            status: 'duplicate',
            is_host: participant.isHost || false
          });
        } else {
          results.push({
            name: originalDisplayName,
            status: 'error',
            error: attendanceError.message
          });
        }
      } else {
        // SUCCESS: Update member pronouns if we extracted any
        if (extractedPronouns) {
          await updateMemberPronouns(supabaseClient, member.id, member.name, extractedPronouns);
        }
        results.push({
          name: originalDisplayName,
          email: participant.email,
          matched_member: member.name,
          member_id: member.id,
          matched_by: member.matched_by,
          duration_minutes: Math.round(participant.totalDuration / 60),
          joins: participant.numberOfJoins,
          pronouns_updated: extractedPronouns ? true : false,
          is_host: participant.isHost || false,
          status: 'success'
        });
      }
    } catch (error) {
      console.error(`Error processing participant ${participant.name}:`, error);
      results.push({
        name: participant.name,
        status: 'error',
        error: error.message
      });
    }
  }
  return results;
}
// ==================== MEMBER MATCHING ====================
async function findMemberWithFallback(supabaseClient, zoomName, zoomEmail, preloadedMembers, meetingTitle) {
  console.log(`Matching: ${zoomName} | ${zoomEmail || 'no email'}`);
  // A display name of one word carries no surname, so every substring and
  // similarity rule below can only ever be a guess. Single-word names take
  // exact-normalized equality and the committee-scoped unique-first-name rule,
  // and nothing else.
  const isSingleWord = zoomName.trim().split(/\s+/).length === 1;
  // STEP 1: Email matching
  if (zoomEmail && zoomEmail.trim().length > 0) {
    const normalizedEmail = normalizeEmail(zoomEmail);
    const { data: emailMatch } = await supabaseClient.from('members').select('id, name, email').eq('email', normalizedEmail).limit(1).maybeSingle();
    if (emailMatch) {
      console.log(`✓ Matched by email: ${emailMatch.name}`);
      return {
        ...emailMatch,
        matched_by: 'email'
      };
    }
    const { data: schoolEmailMatch } = await supabaseClient.from('members').select('id, name, email, school_email').eq('school_email', normalizedEmail).limit(1).maybeSingle();
    if (schoolEmailMatch) {
      console.log(`✓ Matched by school_email: ${schoolEmailMatch.name}`);
      return {
        id: schoolEmailMatch.id,
        name: schoolEmailMatch.name,
        matched_by: 'school_email'
      };
    }
  }
  // STEP 2: Exact name matching (case-insensitive)
  const { data: nameMatch } = await supabaseClient.from('members').select('id, name, email').ilike('name', zoomName.trim()).limit(1).maybeSingle();
  if (nameMatch) {
    console.log(`✓ Matched by exact name: ${nameMatch.name}`);
    return {
      ...nameMatch,
      matched_by: 'name'
    };
  }
  // STEP 3: Normalized name matching
  const normalizedZoomName = normalizeString(zoomName);
  const allMembers = preloadedMembers && preloadedMembers.length > 0 ? preloadedMembers : await fetchAllMembers(supabaseClient);
  if (allMembers && allMembers.length > 0) {
    // STEP 3a: Exact normalized match
    for (const member of allMembers){
      const normalizedMemberName = normalizeString(member.name);
      if (normalizedMemberName === normalizedZoomName) {
        console.log(`✓ Matched by normalized name: ${member.name}`);
        return {
          id: member.id,
          name: member.name,
          matched_by: 'fuzzy_exact'
        };
      }
    }
    // STEP 3a2: A one-word display name has no surname to check against, so
    // exact equality above was the only safe full-name rule. Try the
    // committee-scoped unique first name and then stop, rather than falling
    // through to substring and similarity rules that would happily bind
    // "James" to whichever James the roster listed first.
    if (isSingleWord) {
      const byFirstName = resolveByFirstNameOnCommittee(allMembers, zoomName, meetingTitle);
      if (byFirstName) return byFirstName;
      console.log(`✗ No safe match for single-word name: ${zoomName}`);
      return null;
    }
    // STEP 3b: Concatenated name match (for names without spaces)
    for (const member of allMembers){
      const normalizedMemberName = normalizeString(member.name);
      if (normalizedZoomName.length >= 8 && normalizedMemberName.length >= 8) {
        if (normalizedMemberName === normalizedZoomName) {
          console.log(`✓ Matched by concatenated name: ${member.name}`);
          return {
            id: member.id,
            name: member.name,
            matched_by: 'fuzzy_concatenated'
          };
        }
      }
    }
    // STEP 3c: Partial name match. Substring containment is the one rule here
    // that can bind a display name to more than one member at once, and it
    // used to return whichever the roster happened to list first. Collect
    // every candidate and refuse on a tie.
    const partialHits = [];
    for (const member of allMembers){
      const normalizedMemberName = normalizeString(member.name);
      if (normalizedMemberName.length >= 5 && normalizedZoomName.length >= 5) {
        if (normalizedMemberName.includes(normalizedZoomName) || normalizedZoomName.includes(normalizedMemberName)) {
          partialHits.push(member);
        }
      }
    }
    if (partialHits.length === 1) {
      console.log(`✓ Matched by partial name: ${partialHits[0].name}`);
      return {
        id: partialHits[0].id,
        name: partialHits[0].name,
        matched_by: 'fuzzy_partial'
      };
    }
    if (partialHits.length > 1) {
      console.log(`✗ Partial name "${zoomName}" is ambiguous across ${partialHits.length} members — refusing to guess`);
    }
    // STEP 3d: First + Last name match
    const zoomParts = zoomName.toLowerCase().split(/\s+/);
    if (zoomParts.length >= 2) {
      const zoomFirst = normalizeString(zoomParts[0]);
      const zoomLast = normalizeString(zoomParts[zoomParts.length - 1]);
      for (const member of allMembers){
        const memberParts = member.name.toLowerCase().split(/\s+/);
        if (memberParts.length >= 2) {
          const memberFirst = normalizeString(memberParts[0]);
          const memberLast = normalizeString(memberParts[memberParts.length - 1]);
          if (zoomFirst === memberFirst && zoomLast === memberLast) {
            console.log(`✓ Matched by first+last name: ${member.name}`);
            return {
              id: member.id,
              name: member.name,
              matched_by: 'fuzzy_firstlast'
            };
          }
        }
      }
    }
    // STEP 3e: Similarity matching
    let bestMatch = null;
    const MIN_SIMILARITY = 0.75;
    for (const member of allMembers){
      const normalizedMemberName = normalizeString(member.name);
      // Skip if length difference is too large
      const lengthDiff = Math.abs(normalizedMemberName.length - normalizedZoomName.length);
      if (lengthDiff > Math.max(normalizedMemberName.length, normalizedZoomName.length) * 0.3) {
        continue;
      }
      const similarity = calculateSimilarity(normalizedZoomName, normalizedMemberName);
      if (similarity >= MIN_SIMILARITY && (!bestMatch || similarity > bestMatch.score)) {
        bestMatch = {
          member,
          score: similarity
        };
      }
    }
    if (bestMatch) {
      console.log(`✓ Matched by similarity (${(bestMatch.score * 100).toFixed(1)}%): ${bestMatch.member.name}`);
      return {
        id: bestMatch.member.id,
        name: bestMatch.member.name,
        matched_by: 'fuzzy_similarity'
      };
    }
  }
  // STEP 4: Full-text search (if available)
  try {
    const { data: searchMatch } = await supabaseClient.from('members').select('id, name, email').textSearch('search_name', zoomName.trim()).limit(1).maybeSingle();
    if (searchMatch) {
      console.log(`✓ Matched by full-text search: ${searchMatch.name}`);
      return {
        ...searchMatch,
        matched_by: 'search'
      };
    }
  } catch (error) {
    console.error('Full-text search failed:', error);
  }
  console.log(`✗ No match found for: ${zoomName}`);
  return null;
}
// ==================== MAIN HANDLER ====================
// Wave 2 access-audit 2026-04-24:
// This function is a Zoom webhook ingest — invoked server-to-server by Zoom
// after each meeting ends with the transcript + participant payload. It is
// NOT invoked from the Dart CRM (Dart uses zoom-create-meeting, zoom-update-
// meeting, zoom-delete-meeting, send-meeting-invites instead — audited
// separately). Since no user JWT exists in the webhook path, we gate on an
// optional shared secret via ZOOM_WEBHOOK_SECRET + the existing Zoom
// verification token header `x-zoom-request-token`. Audit-log each meeting
// upsert with actor_role='service_role'.
serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  // Webhook auth gate. Accept either:
  //   (a) ZOOM_WEBHOOK_SECRET match via x-zoom-request-token (legacy/manual replay), or
  //   (b) a Supabase-shaped Bearer JWT in Authorization (n8n workflow, zoom-webhook
  //       internal fan-out, or CRM service-role calls — verify_jwt is false on this
  //       function so we still require *some* gate here).
  // Falls open if neither secret nor any auth header is present AND no env is set
  // (preserves the original audit-comment intent).
  const webhookSecret = Deno.env.get('ZOOM_WEBHOOK_SECRET') ?? '';
  const zoomTokenHeader = req.headers.get('x-zoom-request-token') ?? '';
  const authHeader = req.headers.get('authorization') ?? '';
  const hasBearerJwt = /^Bearer\s+eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$/.test(authHeader);
  const secretMatches = webhookSecret && zoomTokenHeader.includes(webhookSecret);
  if (webhookSecret && !secretMatches && !hasBearerJwt) {
    return new Response(JSON.stringify({
      error: 'Invalid or missing Zoom webhook secret'
    }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
  let payload = null;
  try {
    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });
    payload = await req.json();
    console.log('Received payload keys:', Object.keys(payload));
    if (!payload.meeting_id || !payload.meeting_topic) {
      throw new Error('Missing required fields: meeting_id and meeting_topic are required');
    }
    // Parse date/time and duration robustly
    const meetingStartTime = parseDateTime(payload.start_time);
    const meetingDuration = parseDurationMinutes(payload.duration);
    console.log(`Parsed meeting time: ${meetingStartTime}`);
    console.log(`Parsed duration: ${meetingDuration} minutes`);
    let participantsArray = extractParticipants(payload.participants);
    console.log(`Extracted ${participantsArray.length} participant entries (before filtering)`);
    participantsArray = filterIgnoredAttendees(participantsArray);
    console.log(`After filtering ignored attendees: ${participantsArray.length} participants`);
    let finalParticipants = participantsArray;
    if (finalParticipants.length === 0 && payload.meeting_id) {
      console.log('No participants found, fetching from Zoom API...');
      finalParticipants = await fetchZoomParticipants(payload.meeting_id);
      finalParticipants = filterIgnoredAttendees(finalParticipants);
    }
    let uniqueParticipants = deduplicateParticipants(finalParticipants);
    console.log(`Unique attendees after deduplication: ${uniqueParticipants.length}`);
    // OCCURRENCE WINDOW GUARD. Zoom's /past_meetings/{id}/participants endpoint
    // takes the NUMERIC meeting id, and for a recurring meeting that returns the
    // LATEST occurrence's participants regardless of which occurrence is being
    // processed. Both callers hit this: the n8n leg fetches by numeric id and
    // sends the result in the payload, and the fallback above does the same.
    //
    // Observed 2026-08-20 replaying the 2026-07-22 Executive Committee meeting:
    // four attendees were written onto it whose first_join_time was 2026-08-12,
    // i.e. the 08-12 occurrence's attendees attributed to a meeting three weeks
    // earlier. That meeting genuinely had none.
    //
    // Somebody who joined outside this meeting's own time window cannot be an
    // attendee of it. Anything with no join time is kept, because absence of a
    // timestamp is not evidence of the wrong occurrence.
    if (meetingStartTime) {
      const startMs = new Date(meetingStartTime).getTime();
      const SLACK_MS = 60 * 60 * 1000;
      const windowStart = startMs - SLACK_MS;
      const windowEnd = startMs + (meetingDuration > 0 ? meetingDuration : 0) * 60 * 1000 + SLACK_MS;
      const before = uniqueParticipants.length;
      uniqueParticipants = uniqueParticipants.filter((p)=>{
        if (!p.firstJoin) return true;
        const joinMs = new Date(p.firstJoin).getTime();
        if (!Number.isFinite(joinMs)) return true;
        const inWindow = joinMs >= windowStart && joinMs <= windowEnd;
        if (!inWindow) {
          console.log(`Dropping out-of-window attendee ${p.name}: joined ${p.firstJoin}, meeting starts ${meetingStartTime}`);
        }
        return inWindow;
      });
      if (before !== uniqueParticipants.length) {
        console.log(`Occurrence window guard dropped ${before - uniqueParticipants.length} attendee(s) from another occurrence`);
      }
    }
    // HOST IDENTIFICATION WITH AUTO-ADD TO PARTICIPANTS
    let meetingHostMemberId = null;
    let meetingHostName = null;
    if (payload.meeting_host && payload.meeting_host.trim().length > 0) {
      console.log('\n═══════════════════════════════════════════');
      console.log('🔍 STARTING HOST IDENTIFICATION');
      console.log('═══════════════════════════════════════════');
      console.log(`Host hint: "${payload.meeting_host}"`);
      console.log(`Meeting title: "${payload.meeting_topic}"`);
      console.log(`Participants count: ${uniqueParticipants.length}`);
      const hostResult = await identifyAndMatchHost(supabaseClient, payload.meeting_host, payload.meeting_topic, uniqueParticipants);
      if (hostResult) {
        meetingHostMemberId = hostResult.memberId;
        meetingHostName = hostResult.memberName;
        // If host was matched to a participant, mark them
        if (hostResult.participant) {
          hostResult.participant.isHost = true;
          hostResult.participant.memberId = hostResult.memberId;
          console.log(`✓ Host found in participant list: ${hostResult.participant.name}`);
        } else {
          // Host not in participant list - ADD THEM
          console.log(`⚠ Host not in participant list - adding as participant`);
          const hostParticipant = {
            name: hostResult.memberName,
            email: hostResult.memberEmail || undefined,
            totalDuration: meetingDuration * 60,
            firstJoin: meetingStartTime,
            lastLeave: calculateEndTime(meetingStartTime, meetingDuration),
            numberOfJoins: 1,
            isHost: true,
            memberId: hostResult.memberId
          };
          uniqueParticipants.push(hostParticipant);
          console.log(`✓ Added host as participant with full meeting duration: ${hostResult.memberName}`);
        }
        console.log('\n✅ HOST IDENTIFICATION SUCCESSFUL');
        console.log(`   Member: ${meetingHostName}`);
        console.log(`   ID: ${meetingHostMemberId}`);
        console.log(`   Total participants (including host): ${uniqueParticipants.length}`);
        console.log('═══════════════════════════════════════════\n');
      } else {
        console.log('\n❌ HOST IDENTIFICATION FAILED');
        console.log(`   Could not identify host from hint: "${payload.meeting_host}"`);
        console.log('═══════════════════════════════════════════\n');
      }
    } else {
      console.log('No meeting_host provided in payload');
    }
    let summaryFields = {
      action_items: payload.action_items,
      agenda_reviewed: payload.agenda_reviewed,
      decisions_rationales: payload.decisions_rationales,
      discussion_highlights: payload.discussion_highlights,
      executive_recap: payload.executive_recap,
      risks_open_questions: payload.risks_open_questions
    };
    console.log('Summary fields present:', Object.keys(summaryFields).filter((k)=>summaryFields[k]));
    let transcriptFilePath = null;
    if (payload.transcript_text && payload.transcript_text.trim().length > 0) {
      transcriptFilePath = await storeTranscript(supabaseClient, payload.meeting_topic, meetingStartTime, payload.transcript_text);
      console.log(`Transcript stored at: ${transcriptFilePath}`);
    }
    // DEDUP on the per-occurrence Zoom UUID (zoom_meeting_uuid), NOT the numeric
    // meeting id. Recurring meetings reuse ONE numeric id for every occurrence;
    // only the UUID is unique per occurrence, so keying on the numeric id
    // collapsed every occurrence onto the first row. Requires the UNIQUE index
    // meetings_zoom_meeting_uuid_unique on public.meetings (added 2026-07-14,
    // replacing the old UNIQUE(zoom_meeting_id)). The numeric zoom_meeting_id is
    // still written for display/back-compat.
    //
    // payload.meeting_uuid is supplied by the zoom-webhook relay (leg A) and by
    // zoom-reconcile. The n8n enrichment leg (leg B) currently posts only the
    // numeric meeting_id; for that legacy path we attach to the most recently
    // created row for this numeric id — the occurrence the relay's minimal-row
    // upsert just created — instead of colliding recurring occurrences.
    const zoomMeetingId = String(payload.meeting_id);
    const zoomMeetingUuid = payload.meeting_uuid ? String(payload.meeting_uuid).trim() : '';
    const meetingFields = {
      meeting_date: meetingStartTime,
      meeting_title: payload.meeting_topic,
      zoom_meeting_id: zoomMeetingId,
      duration_minutes: meetingDuration,
      recording_url: payload.recording_url,
      recording_embed_url: payload.recording_embed_url,
      recording_thumbnail_url: payload.recording_thumbnail_url || null,
      transcript_file_path: transcriptFilePath,
      meeting_host: meetingHostMemberId,
      action_items: summaryFields.action_items || null,
      executive_recap: summaryFields.executive_recap || null,
      agenda_reviewed: summaryFields.agenda_reviewed || null,
      discussion_highlights: summaryFields.discussion_highlights || null,
      decisions_rationales: summaryFields.decisions_rationales || null,
      risks_open_questions: summaryFields.risks_open_questions || null,
      attendance_count: 0,
      processing_status: 'processing'
    };
    let meeting = null;
    let meetingError = null;
    if (zoomMeetingUuid) {
      // Per-occurrence upsert: recording.completed / summary_completed for the
      // same occurrence share this UUID and merge onto one row.
      ({ data: meeting, error: meetingError } = await supabaseClient.from('meetings').upsert({
        ...meetingFields,
        zoom_meeting_uuid: zoomMeetingUuid
      }, { onConflict: 'zoom_meeting_uuid' }).select().single());
    } else {
      // Legacy caller without a per-occurrence UUID (current n8n leg B).
      //
      // Match the OCCURRENCE by numeric id + start time first. The payload
      // always carries start_time, and meetings.meeting_date is written from
      // that same value, so for a recurring meeting the pair identifies the
      // occurrence exactly even though the numeric id does not.
      //
      // The most-recently-created fallback below is only correct when the row
      // the relay just created IS the occurrence being enriched, which holds
      // for a live meeting and FAILS for a replay of an older one. Observed
      // 2026-08-20: replaying the 2026-07-29 Executive Committee meeting sent
      // its enrichment to the 2026-08-12 row, because 08-12 was the most
      // recently created row for numeric id 99334786595. That overwrote a
      // correct 08-12 record and left 07-29 still stranded.
      let existing = null;
      if (meetingStartTime) {
        const { data: byStart } = await supabaseClient.from('meetings')
          .select('id')
          .eq('zoom_meeting_id', zoomMeetingId)
          .eq('meeting_date', meetingStartTime)
          .limit(1)
          .maybeSingle();
        if (byStart) {
          existing = byStart;
          console.log(`Matched occurrence by zoom_meeting_id + start_time: ${byStart.id}`);
        }
      }
      if (!existing) {
        const { data: byRecent } = await supabaseClient.from('meetings')
          .select('id')
          .eq('zoom_meeting_id', zoomMeetingId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();
        existing = byRecent;
        if (byRecent) console.log(`Fell back to most-recently-created row: ${byRecent.id}`);
      }
      if (existing) {
        ({ data: meeting, error: meetingError } = await supabaseClient.from('meetings')
          .update(meetingFields).eq('id', existing.id).select().single());
      } else {
        ({ data: meeting, error: meetingError } = await supabaseClient.from('meetings')
          .insert({ ...meetingFields, zoom_meeting_uuid: null }).select().single());
      }
    }
    if (meetingError) {
      throw new Error(`Failed to create meeting: ${meetingError.message}`);
    }
    console.log('Created meeting record:', meeting.id);
    const attendanceResults = await processAttendance(supabaseClient, meeting.id, uniqueParticipants, meeting.meeting_title);
    // 'already_recorded' counts as a match. On a FIRST run this status never
    // occurs, so first-run behaviour is unchanged. On a REPLAY every attendee
    // already has a row, processAttendance returns 'already_recorded' for each,
    // and counting only 'success' made successfulMatches 0 — which the update
    // below then wrote over a previously correct attendance_count. Observed
    // 2026-08-20 replaying the 2026-08-12 Executive Committee meeting: four
    // attendees matched by exact name, all four already recorded, and the row's
    // attendance_count went 4 → 0 while meeting_attendance still held the four
    // matched rows. An already-recorded attendee IS a matched member.
    const successfulMatches = attendanceResults.filter((r)=>r.status === 'success' || r.status === 'already_recorded').length;
    const nonMemberCount = attendanceResults.filter((r)=>r.status === 'non_member' || r.status === 'non_member_phone' || r.status === 'non_member_device').length;
    // attendance_count is a denormalised copy of "how many matched members
    // attended", so read it back from meeting_attendance rather than from this
    // run's results. Deriving it from successfulMatches is only right on a
    // first run: a replay reports 'already_recorded' instead of 'success', and
    // a run whose participant list came back empty or was rejected by the
    // occurrence window guard above reports nothing at all. Both wrote a 0 over
    // a correct count. Observed twice on 2026-08-20, on the 2026-08-12 row
    // (4 → 0) and the 2026-07-29 row (5 → 0 while five matched rows sat in
    // meeting_attendance). Counting the rows is correct in every case.
    const { count: matchedAttendanceRows } = await supabaseClient
      .from('meeting_attendance')
      .select('id', { count: 'exact', head: true })
      .eq('meeting_id', meeting.id)
      .not('member_id', 'is', null);
    const attendanceCount = typeof matchedAttendanceRows === 'number' ? matchedAttendanceRows : successfulMatches;
    console.log(`attendance_count for ${meeting.id}: ${attendanceCount} (this run matched ${successfulMatches})`);
    await supabaseClient.from('meetings').update({
      attendance_count: attendanceCount,
      processing_status: 'completed'
    }).eq('id', meeting.id);
    console.log(`Attendance processed: ${successfulMatches} matched, ${nonMemberCount} non-members`);
    // Audit log (non-blocking) — Zoom webhook ingest, no user actor.
    supabaseClient.from('audit_log').insert({
      action: 'EDGE_FN',
      actor_id: null,
      actor_role: 'service_role',
      schema_name: 'public',
      table_name: 'edge_fn:meetings-zap',
      row_id: meeting.id,
      context: {
        event: 'meetings-zap:zoom-webhook',
        zoom_meeting_id: payload.meeting_id,
        topic: payload.meeting_topic,
        host_member_id: meetingHostMemberId,
        attendance_matched: successfulMatches,
        non_members: nonMemberCount
      }
    }).then(() => {}).catch((e) => console.error('[meetings-zap] audit_log insert failed:', e));
    return new Response(JSON.stringify({
      success: true,
      meeting_id: meeting.id,
      meeting_title: meeting.meeting_title,
      meeting_date: meeting.meeting_date,
      meeting_host_id: meetingHostMemberId,
      meeting_host_name: meetingHostName,
      recording_embed_url: meeting.recording_embed_url,
      recording_thumbnail_url: meeting.recording_thumbnail_url,
      stats: {
        raw_zoom_entries: participantsArray.length,
        unique_attendees: uniqueParticipants.length,
        matched_members: successfulMatches,
        non_members: nonMemberCount,
        unmatched: uniqueParticipants.length - successfulMatches - nonMemberCount
      },
      attendance_details: attendanceResults,
      transcript_stored: !!transcriptFilePath
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('Error processing meeting:', error);
    if (payload?.meeting_id) {
      try {
        const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
        // Scope the failure flag to the specific occurrence when we have its UUID;
        // fall back to the numeric id (marks all rows for that id) only if absent.
        const failUpdate = supabaseClient.from('meetings').update({
          processing_status: 'failed',
          processing_error: error.message
        });
        if (payload.meeting_uuid) {
          await failUpdate.eq('zoom_meeting_uuid', String(payload.meeting_uuid).trim());
        } else {
          await failUpdate.eq('zoom_meeting_id', String(payload.meeting_id));
        }
      } catch (updateError) {
        console.error('Failed to update meeting status:', updateError);
      }
    }
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      details: error.stack
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 400
    });
  }
});
