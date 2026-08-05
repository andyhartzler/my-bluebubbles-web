import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
// ============================================================================
// PHONE UTILITIES
// ============================================================================
function normalizePhone(phone) {
  return phone.replace(/\D/g, '');
}
function formatPhoneE164(phone) {
  const digits = normalizePhone(phone);
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+1${digits}`;
  }
  if (phone.startsWith('+') && digits.length >= 10) {
    return `+${digits}`;
  }
  return `+1${digits}`;
}
function isValidPhone(phone) {
  const digits = normalizePhone(phone);
  return digits.length >= 10 && digits.length <= 15;
}
function generatePlaceholderEmail(phoneE164) {
  return `form_${phoneE164.replace('+', '')}@pending.moyd.org`;
}
function generatePlaceholderName(phoneE164) {
  return `Pending ${phoneE164}`;
}
function isPlaceholderEmail(email) {
  return email.endsWith('@pending.moyd.org');
}
function isPlaceholderName(name) {
  return name.startsWith('Pending +');
}
function generateSessionToken() {
  return crypto.randomUUID();
}
// ============================================================================
// PHONE VERIFICATION (Twilio Verify)
// ============================================================================
// This function does BOTH halves itself, server side, with the same project
// secrets verify-phone reads: it STARTS the verification (texts the code) and
// it CHECKS the code. The browser never calls verify-phone in this flow.
//
// Twilio's VerificationCheck is one-shot: if the browser checked the code it
// would burn it and leave the server with nothing left to verify, so the only
// thing the server could trust would be the client saying "I verified". Doing
// the check here means the one code path that runs a person lookup is the same
// request that just proved SMS possession. There is no client-held "verified"
// flag to forge and no double-check race.
const TWILIO_API_KEY_SID = Deno.env.get('TWILIO_API_KEY_SID') ?? '';
const TWILIO_API_KEY_SECRET = Deno.env.get('TWILIO_API_KEY_SECRET') ?? '';
const TWILIO_VERIFY_SERVICE_SID = Deno.env.get('TWILIO_VERIFY_SERVICE_SID') ?? '';
const BAD_CODE_MESSAGE = 'That code is not right or has expired. Try again or tap Resend code.';
// Everything that consumes a session later (submit, check_election,
// subscribe_alerts) needs the provenance row init_session writes. A session
// created before this deploy has none, so it is refused with this. The promise
// is true: update_field and the server draft already persisted the answers, and
// a refresh re-inits the session.
const SESSION_REFRESH_MESSAGE = 'Please refresh the page to continue. Your answers are saved.';
/**
 * Ask Twilio to text a fresh code to this number.
 * Returns { started, error } and never throws. A Twilio refusal (60203 max
 * attempts, 21608 trial restriction, 60200 unreachable number) rides back as
 * `error` so the person is told what actually happened instead of waiting for
 * a text that is never coming.
 */ async function startVerification(phoneE164) {
  if (!TWILIO_API_KEY_SID || !TWILIO_API_KEY_SECRET || !TWILIO_VERIFY_SERVICE_SID) {
    // Misconfiguration, not a bad number. Loud in the logs, gentle to the user.
    console.error('[submit-form] Twilio Verify secrets are missing from this function');
    return {
      started: false,
      error: 'Phone verification is temporarily unavailable. Please try again shortly.'
    };
  }
  try {
    const res = await fetch(`https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SERVICE_SID}/Verifications`, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + btoa(`${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}`),
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        To: phoneE164,
        Channel: 'sms'
      })
    });
    const data = await res.json();
    if (!res.ok) {
      console.error('[submit-form] Verification start rejected', res.status, data?.code, data?.message);
      return {
        started: false,
        error: data?.message || 'Could not send code'
      };
    }
    return {
      started: true
    };
  } catch (e) {
    console.error('[submit-form] Verification start failed:', e instanceof Error ? e.message : String(e));
    return {
      started: false,
      error: 'Could not reach the verification service, please try again'
    };
  }
}
/**
 * Ask Twilio whether this code is the one it texted to this number.
 * Returns { approved, error } and never throws.
 */ async function checkVerificationCode(phoneE164, code) {
  const digits = String(code ?? '').replace(/\D/g, '');
  if (!digits) {
    return {
      approved: false,
      error: 'Enter the 6 digit code we texted you.'
    };
  }
  if (!TWILIO_API_KEY_SID || !TWILIO_API_KEY_SECRET || !TWILIO_VERIFY_SERVICE_SID) {
    // Misconfiguration, not a bad code. Loud in the logs, gentle to the user.
    console.error('[submit-form] Twilio Verify secrets are missing from this function');
    return {
      approved: false,
      error: 'Phone verification is temporarily unavailable. Please try again shortly.'
    };
  }
  try {
    const res = await fetch(`https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SERVICE_SID}/VerificationCheck`, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + btoa(`${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}`),
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        To: phoneE164,
        Code: digits
      })
    });
    const data = await res.json();
    // Twilio 404s when the verification expired or was already used.
    if (!res.ok) {
      console.warn('[submit-form] VerificationCheck rejected', res.status, data?.code);
      return {
        approved: false,
        error: BAD_CODE_MESSAGE
      };
    }
    return {
      approved: data.status === 'approved'
    };
  } catch (e) {
    console.error('[submit-form] VerificationCheck failed:', e instanceof Error ? e.message : String(e));
    return {
      approved: false,
      error: 'Could not reach the verification service, please try again'
    };
  }
}
// ============================================================================
// FORM AVAILABILITY GATE
// ============================================================================
// A form closes on a DATE, opens on a DATE, and is capped by a COUNT. This
// function used to read none of the three: it asked for status and nothing
// else, so a tab left open before the close, a session resumed afterwards, or a
// hand-rolled POST could still land a submission on a form the render path
// refuses to draw. The close is enforced on the WRITE here, which is the only
// place it can actually be true, and it applies to every form this function
// serves rather than to the endorsement questionnaire alone.
//
// Wording is kept in lockstep with src/app/site-forms/api/forms/[slug]/submit/
// route.ts and with checkFormAvailability in src/app/site-forms/types/forms.ts.
// All three have to agree; whichever one is loosest is the one that decides.
const FORM_AVAILABILITY_COLUMNS = 'id, title, slug, status, opens_at, closes_at, max_submissions, submission_count';
const FORM_NOT_ACTIVE = {
  code: 'FORM_NOT_ACTIVE',
  error: 'This form is not currently active.'
};
const FORM_NOT_OPEN = {
  code: 'FORM_NOT_OPEN',
  error: 'This form is not yet open.'
};
const FORM_CLOSED = {
  code: 'FORM_CLOSED',
  error: 'This form is closed.'
};
const FORM_LIMIT_REACHED = {
  code: 'FORM_LIMIT_REACHED',
  error: 'This form has reached its submission limit.'
};
const FORM_NOT_FOUND = {
  code: 'FORM_NOT_FOUND',
  error: 'This form is no longer available.'
};
// A malformed or missing timestamp is not a closure. Both helpers answer false
// for null, '' and unparseable text, so bad data leaves the form open rather
// than silently shutting every form off.
function isTimestampInFuture(value) {
  if (!value) return false;
  const t = new Date(value).getTime();
  return Number.isFinite(t) && t > Date.now();
}
function isTimestampInPast(value) {
  if (!value) return false;
  const t = new Date(value).getTime();
  return Number.isFinite(t) && t < Date.now();
}
/**
 * Why this form is refusing, on status and the open/close window, or null when
 * it is accepting. Cheap and side effect free: the caller already has the row.
 */ function formWindowRefusal(form) {
  if (!form) return FORM_NOT_FOUND;
  if (form.status !== 'active') return FORM_NOT_ACTIVE;
  if (isTimestampInFuture(form.opens_at)) return FORM_NOT_OPEN;
  if (isTimestampInPast(form.closes_at)) return FORM_CLOSED;
  return null;
}
/**
 * Why this form is refusing on max_submissions, or null.
 *
 * `ownRows` is how many of form_schemas.submission_count belong to the request
 * being judged. That counter is bumped by an AFTER INSERT trigger on
 * form_submissions (public.update_form_submission_count), so it counts ROWS
 * CREATED, not applications finished: by the time a progressive session reaches
 * submit, its own row has already been counted, while the Next route counts
 * before it inserts. Passing 1 from submit is what makes both paths ask the
 * same question, "have max_submissions rows other than this one been created",
 * instead of this one refusing the last legitimate submitter by one.
 *
 * Only submit calls this. init_session deliberately does not: it cannot know
 * yet whether findOrCreateSubmission will create a row or reclaim an existing
 * one, so counting there would refuse a returning respondent whose row is
 * already inside the cap. The cap is a rule about what gets recorded, and
 * submit is where recording happens.
 */ function formCapRefusal(form, ownRows) {
  if (!form) return FORM_NOT_FOUND;
  const max = form.max_submissions;
  if (!max) return null;
  const counted = Number(form.submission_count ?? 0) - ownRows;
  return counted >= max ? FORM_LIMIT_REACHED : null;
}
// ============================================================================
// ELECTION GATE
// ============================================================================
// public.elections IS the rule. There is no hardcoded closed election here any
// more: one row per election we take applications for, carrying the
// jurisdiction, the statutory election_date, the type, OUR submission_deadline
// (ours to set and to edit, not statutory) and, on a general, primary_election_id
// pointing back at the primary that decides it.
//
// Two rules, both read off that row and off nothing else:
//   1. past submission_deadline            -> ELECTION_CLOSED
//   2. a general whose primary has not yet
//      been held                           -> ELECTION_PRIMARY_PENDING
//
// The race page shows the same two and the closed modal explains which one
// fired. The modal is never what stops a submission: a session resumed from
// before the deadline, a replayed request, or a hand rolled POST all die here.
//
// Kept in lockstep with src/app/site-forms/api/forms/[slug]/submit/route.ts,
// which is a public POST that inserts with the service role. Whichever of the
// two is loosest is the one that decides, so they have to answer identically.
const ELECTION_COLUMNS = 'id, jurisdiction, label, election_type, election_date, submission_deadline, primary_election_id, is_active';
// The election gate belongs to the endorsement questionnaire and to nothing
// else. Keyed on the slug PREFIX, the same idiom the live trigger, the live
// view and the two Next API routes use, so it survives the 2026 rename.
const ENDORSEMENT_SLUG_PREFIX = 'endorsement-questionnaire';
function isEndorsementSlug(slug) {
  return typeof slug === 'string' && slug.startsWith(ENDORSEMENT_SLUG_PREFIX);
}
function valueOr(v, fallback) {
  if (v === null || v === undefined || v === '') return fallback;
  return String(v);
}
// ----------------------------------------------------------------------------
// THE MIRRORED RULE
// ----------------------------------------------------------------------------
// Rule 2 is stated canonically in src/app/site-forms/lib/electionCalendar.ts.
// Deno cannot import from src/, so the two functions below are copies, and the
// regions marked `election-rule:<name>:begin/end` are byte identical to the
// regions of the same name there. Do not edit one without the other:
// scripts/check-election-rule.mjs compares them character for character, then
// runs both copies over a matrix of dates and clock instants, and `npm run
// build` runs it, so a divergence stops the build rather than showing up on one
// particular day in production.
//
// Today in Missouri, as YYYY-MM-DD. Election days are calendar days, not
// instants, so the comparison has to happen in Missouri's own day: a naive UTC
// date rolls over at 7pm Central and would flip this rule five hours early.
// en-CA is the locale whose short date is already ISO ordered, so the result
// compares directly with `>` against a Postgres `date`.
function missouriToday(now) {
  // election-rule:missouriToday:begin
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Chicago',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
  // election-rule:missouriToday:end
}
// Has this primary actually been held?
//
// A primary counts as held only once its whole day in Missouri is over. The day
// of the primary is NOT held: polls close at 7pm Central and the count runs
// into the night, so until the following morning there is nobody on the
// general's ballot to apply against. An unusable date reads as not held, which
// keeps a general closed rather than opening it on a broken pointer.
//
// The full reasoning lives with the canonical copy in electionCalendar.ts.
function primaryHasBeenHeld(primaryDate, todayInMissouri) {
  // election-rule:primaryHasBeenHeld:begin
  const day = String(primaryDate ?? '').slice(0, 10);
  if (day.length !== 10) return false;
  return todayInMissouri > day;
  // election-rule:primaryHasBeenHeld:end
}
function electionYearOf(election) {
  return String(election?.election_date ?? '').slice(0, 4);
}
function formatElectionDate(isoDate) {
  const iso = String(isoDate ?? '').slice(0, 10);
  if (iso.length !== 10) return '';
  // Noon UTC so no timezone can push the label onto the day before.
  const d = new Date(`${iso}T12:00:00Z`);
  if (!Number.isFinite(d.getTime())) return '';
  return d.toLocaleDateString('en-US', {
    timeZone: 'UTC',
    month: 'long',
    day: 'numeric',
    year: 'numeric'
  });
}
function formatDeadline(timestamp) {
  if (!timestamp) return '';
  const d = new Date(timestamp);
  if (!Number.isFinite(d.getTime())) return '';
  return d.toLocaleDateString('en-US', {
    timeZone: 'America/Chicago',
    month: 'long',
    day: 'numeric',
    year: 'numeric'
  });
}
function electionName(election) {
  return valueOr(election?.label, '') || `${electionYearOf(election)} ${valueOr(election?.jurisdiction, '')} ${valueOr(election?.election_type, 'election')}`.trim();
}
/**
 * The election a respondent picked, as a row from the calendar.
 *
 * They name it by `election_id`, which is the only unambiguous name: two
 * jurisdictions can share a year and a type (Kansas City and St. Louis City
 * both hold a primary in 2027), so the year/type pair is a key only when it
 * happens to match exactly one active row. It is accepted on that condition and
 * refused otherwise, which is the honest answer rather than a guess between two
 * real elections.
 *
 * Returns { election } on success, { unavailable: true } when the calendar
 * itself could not be read (never "carry on"), { election: null } when nothing
 * was picked or the pick names no single election.
 */ async function resolveElection(picked) {
  const source = picked && typeof picked === 'object' ? picked : {};
  const electionId = valueOr(source['election_id'], '');
  if (electionId) {
    const { data, error } = await supabase.from('elections').select(ELECTION_COLUMNS).eq('id', electionId).maybeSingle();
    if (error) {
      console.error('[submit-form] Could not read the election calendar:', error);
      return {
        unavailable: true
      };
    }
    return {
      election: data ?? null
    };
  }
  const year = valueOr(source['election_year'], '');
  if (!/^\d{4}$/.test(year)) {
    return {
      election: null
    };
  }
  const type = valueOr(source['election_type'], '');
  let query = supabase.from('elections').select(ELECTION_COLUMNS).eq('is_active', true).gte('election_date', `${year}-01-01`).lte('election_date', `${year}-12-31`);
  if (type) query = query.eq('election_type', type);
  const { data: rows, error } = await query;
  if (error) {
    console.error('[submit-form] Could not read the election calendar:', error);
    return {
      unavailable: true
    };
  }
  if (!rows || rows.length !== 1) {
    return {
      election: null
    };
  }
  return {
    election: rows[0]
  };
}
/**
 * Why this election is refusing applications, or null when it is open.
 * Async because rule 2 has to look at the primary this general points back at.
 */ async function electionRefusal(election) {
  if (!election || election.is_active === false) {
    return {
      code: 'ELECTION_CLOSED',
      error: 'We are not accepting endorsement applications for that election.'
    };
  }
  if (isTimestampInPast(election.submission_deadline)) {
    const closedOn = formatDeadline(election.submission_deadline);
    return {
      code: 'ELECTION_CLOSED',
      error: closedOn ? `Applications for the ${electionName(election)} closed on ${closedOn}.` : `We are no longer accepting endorsement applications for the ${electionName(election)}.`
    };
  }
  if (valueOr(election.election_type, '') === 'general' && election.primary_election_id) {
    const { data: primary, error } = await supabase.from('elections').select('id, label, jurisdiction, election_type, election_date').eq('id', election.primary_election_id).maybeSingle();
    if (error) {
      console.error('[submit-form] Could not read the primary behind a general:', error);
      return {
        code: 'ELECTION_CALENDAR_UNAVAILABLE',
        error: 'We could not check that election just now. Please try again shortly.'
      };
    }
    // A general whose primary has not been held yet is not a race anyone can
    // apply for: nobody is on that ballot until the primary decides who is.
    // On the day of the primary itself that is still true, which is why this
    // asks primaryHasBeenHeld rather than comparing dates inline.
    if (primary && !primaryHasBeenHeld(primary.election_date, missouriToday(new Date()))) {
      const heldOn = formatElectionDate(primary.election_date);
      return {
        code: 'ELECTION_PRIMARY_PENDING',
        error: heldOn ? `The ${electionName(election)} is not open yet. We take applications for it after its primary on ${heldOn}.` : `The ${electionName(election)} is not open yet. We take applications for it after its primary has been held.`
      };
    }
  }
  return null;
}
/**
 * Does this stored submission belong to this election?
 *
 * A row names its election the same two ways a live pick does. Rows written
 * before the election fields existed name none, so they match nothing here; the
 * election they were filed under is refused on its own deadline anyway, which
 * is the gate that actually stops a second application for it.
 */ function rowMatchesElection(rowData, election) {
  const d = rowData && typeof rowData === 'object' ? rowData : {};
  const rowElectionId = valueOr(d['election_id'], '');
  if (rowElectionId) return rowElectionId === election.id;
  const year = valueOr(d['election_year'], '');
  if (!year || year !== electionYearOf(election)) return false;
  const type = valueOr(d['election_type'], '');
  return !type || type === valueOr(election.election_type, '');
}
/**
 * Does this phone already have a genuinely finished submission on this form for
 * this election? Returns ONE boolean: never the row, the id, the name, or the
 * date. Reaching it requires a session_token bound to a submission created
 * through SMS verification of this very phone, so it is not an enumeration
 * oracle.
 */ async function hasFinishedSubmissionForElection(formId, phoneE164, election, excludeSubmissionId) {
  if (!formId || !phoneE164 || !election?.id) return false;
  const { data: rows } = await supabase.from('form_submissions').select('id, data').eq('form_id', formId).eq('submitter_phone', phoneE164).eq('status', 'submitted');
  if (!rows || rows.length === 0) return false;
  return rows.some((r)=>{
    if (excludeSubmissionId && r.id === excludeSubmissionId) return false;
    // Same "truly finished" predicate findOrCreateSubmission uses: the 2026-07
    // incident left rows marked submitted that never reached the last page, and
    // those people still need to come back and really submit.
    if (!(r.data && typeof r.data === 'object' && r.data['certify'] && r.data['signature'])) return false;
    return rowMatchesElection(r.data, election);
  });
}
// Identity/prefill keys. Anything OUTSIDE this set is a real answer the
// respondent typed (a policy position, a committee choice, a signature, etc.).
const IDENTITY_FIELD_KEYS = new Set([
  'name',
  'full_name',
  'first_name',
  'last_name',
  'email',
  'email_address',
  'phone',
  'phone_number',
  'zip_code',
  'zipcode',
  'postal_code'
]);
// True if the submission's data map already holds any answer the respondent
// typed (i.e. a key that is not a pure identity/prefill field). Used to make
// `abandon` safe by construction: a row with real answers must never be
// marked abandoned by a stray unload beacon.
function hasRealAnswers(data) {
  if (!data || typeof data !== 'object') return false;
  return Object.keys(data).some((k)=>{
    if (IDENTITY_FIELD_KEYS.has(k.toLowerCase())) return false;
    const v = data[k];
    // treat empty string/null/undefined/empty array as "not answered"
    if (v === null || v === undefined || v === '') return false;
    if (Array.isArray(v) && v.length === 0) return false;
    return true;
  });
}
// ============================================================================
// DATABASE OPERATIONS
// ============================================================================
/**
 * Search for a person across all tables by phone number
 */ async function lookupPersonByPhone(phone) {
  const phoneE164 = formatPhoneE164(phone);
  const normalizedPhone = normalizePhone(phone);
  // Try to use the database function first
  const { data: result, error } = await supabase.rpc('find_or_create_subscriber_by_phone', {
    p_phone: phone,
    p_phone_e164: phoneE164,
    p_source: 'form'
  });
  if (error) {
    console.error('Error calling find_or_create_subscriber_by_phone:', error);
    // Fall back to manual lookup
    return await manualLookupAndCreate(phone, phoneE164);
  }
  if (result && result.length > 0) {
    const r = result[0];
    return {
      found: !r.is_new,
      subscriber_id: r.subscriber_id,
      member_id: r.member_id,
      donor_id: r.donor_id,
      is_new: r.is_new,
      name: r.name,
      email: r.email,
      phone: phone,
      phone_e164: phoneE164,
      zip_code: r.zip_code,
      address: r.address,
      city: r.city,
      state: r.state,
      source: r.source_type
    };
  }
  // Fall back to manual if no results
  return await manualLookupAndCreate(phone, phoneE164);
}
/**
 * Search the four person tables for this phone. Creates NOTHING.
 *
 * Split out of manualLookupAndCreate so the verification gate can ask "do we
 * already hold details for this number" without the act of asking creating a
 * placeholder subscriber for it. manualLookupAndCreate calls this and then
 * creates, so every pre-existing path behaves exactly as it did.
 *
 * Table schemas:
 * - members: has phone, phone_e164, address, county (NO city, state, zip_code!)
 * - donors: has phone, phone_e164, address, city, state, zip_code
 * - event_attendees: has guest_phone, address, city, state, zip (NOT zip_code!)
 * - subscribers: has phone, phone_e164, address, city, state, zip_code
 */ async function searchPersonByPhone(phone) {
  const phoneE164 = formatPhoneE164(phone);
  const normalizedPhone = normalizePhone(phone);
  // Also try without the +1 prefix (10 digits only)
  const phoneWithoutCountry = phoneE164.replace('+1', '');
  console.log('Manual lookup with phone variants:', {
    phone,
    phoneE164,
    normalizedPhone,
    phoneWithoutCountry
  });
  // =========================================================================
  // Search MEMBERS - has phone, phone_e164 columns
  // Note: members does NOT have city, state, zip_code columns!
  // =========================================================================
  let member = null;
  // Try phone_e164 column first (most reliable)
  const { data: memberByE164Col } = await supabase.from('members').select('*').eq('phone_e164', phoneE164).limit(1).maybeSingle();
  if (memberByE164Col) {
    member = memberByE164Col;
  } else {
    // Try phone column with various formats
    const { data: memberByPhone } = await supabase.from('members').select('*').eq('phone', normalizedPhone).limit(1).maybeSingle();
    if (memberByPhone) {
      member = memberByPhone;
    } else {
      const { data: memberByE164 } = await supabase.from('members').select('*').eq('phone', phoneE164).limit(1).maybeSingle();
      if (memberByE164) {
        member = memberByE164;
      } else {
        const { data: memberByWithoutCountry } = await supabase.from('members').select('*').eq('phone', phoneWithoutCountry).limit(1).maybeSingle();
        member = memberByWithoutCountry;
      }
    }
  }
  // =========================================================================
  // Search SUBSCRIBERS - has phone, phone_e164 columns
  // =========================================================================
  let subscriber = null;
  // Try phone_e164 column first
  const { data: subByE164Column } = await supabase.from('subscribers').select('*').eq('phone_e164', phoneE164).limit(1).maybeSingle();
  if (subByE164Column) {
    subscriber = subByE164Column;
  } else {
    const { data: subByPhone } = await supabase.from('subscribers').select('*').eq('phone', normalizedPhone).limit(1).maybeSingle();
    if (subByPhone) {
      subscriber = subByPhone;
    } else {
      const { data: subByE164 } = await supabase.from('subscribers').select('*').eq('phone', phoneE164).limit(1).maybeSingle();
      subscriber = subByE164;
    }
  }
  // =========================================================================
  // Search DONORS - has phone, phone_e164 columns
  // =========================================================================
  let donor = null;
  // Try phone_e164 column first
  const { data: donorByE164Col } = await supabase.from('donors').select('*').eq('phone_e164', phoneE164).limit(1).maybeSingle();
  if (donorByE164Col) {
    donor = donorByE164Col;
  } else {
    const { data: donorByPhone } = await supabase.from('donors').select('*').eq('phone', normalizedPhone).limit(1).maybeSingle();
    if (donorByPhone) {
      donor = donorByPhone;
    } else {
      const { data: donorByE164 } = await supabase.from('donors').select('*').eq('phone', phoneE164).limit(1).maybeSingle();
      donor = donorByE164;
    }
  }
  // =========================================================================
  // Search EVENT_ATTENDEES - has guest_phone column only (no phone_e164)
  // =========================================================================
  let attendee = null;
  const { data: attendeeByE164 } = await supabase.from('event_attendees').select('*').eq('guest_phone', phoneE164).limit(1).maybeSingle();
  if (attendeeByE164) {
    attendee = attendeeByE164;
  } else {
    const { data: attendeeByNormalized } = await supabase.from('event_attendees').select('*').eq('guest_phone', normalizedPhone).limit(1).maybeSingle();
    attendee = attendeeByNormalized;
  }
  console.log('Lookup results:', {
    foundMember: !!member,
    foundSubscriber: !!subscriber,
    foundDonor: !!donor,
    foundAttendee: !!attendee
  });
  // =========================================================================
  // Determine best source and build result
  // =========================================================================
  let foundSubscriberId = null;
  let foundMemberId = null;
  let foundDonorId = null;
  let name = null;
  let email = null;
  let zipCode = null;
  let address = null;
  let city = null;
  let state = null;
  let source = null;
  // Priority 1: Member (but members don't have city/state/zip!)
  if (member) {
    foundMemberId = member.id;
    name = member.name;
    email = member.email;
    address = member.address;
    // Members don't have city, state, zip_code - leave as null
    source = 'member';
  }
  // Priority 2: Subscriber (has all address fields)
  if (subscriber) {
    foundSubscriberId = subscriber.id;
    foundMemberId = foundMemberId || subscriber.member_id;
    foundDonorId = subscriber.donor_id;
    name = name || subscriber.name;
    email = email || subscriber.email;
    zipCode = zipCode || subscriber.zip_code;
    address = address || subscriber.address;
    city = city || subscriber.city;
    state = state || subscriber.state;
    source = source || 'subscriber';
  }
  // Priority 3: Donor (has all address fields)
  if (donor && !foundSubscriberId && !foundMemberId) {
    foundDonorId = donor.id;
    foundMemberId = donor.member_id;
    name = name || donor.name;
    email = email || donor.email;
    zipCode = zipCode || donor.zip_code;
    address = address || donor.address;
    city = city || donor.city;
    state = state || donor.state;
    source = source || 'donor';
  }
  // Priority 4: Event attendee (has zip not zip_code!)
  if (attendee && !foundSubscriberId && !foundMemberId && !foundDonorId) {
    foundMemberId = attendee.member_id;
    name = name || attendee.guest_name;
    email = email || attendee.guest_email;
    zipCode = zipCode || attendee.zip; // Note: column is "zip" not "zip_code"
    address = address || attendee.address;
    city = city || attendee.city;
    state = state || attendee.state;
    source = source || 'event_attendee';
  }
  // If we found a member but no subscriber, try to get subscriber for that member
  if (foundMemberId && !foundSubscriberId) {
    const { data: memberSubscriber } = await supabase.from('subscribers').select('*').eq('member_id', foundMemberId).limit(1).maybeSingle();
    if (memberSubscriber) {
      foundSubscriberId = memberSubscriber.id;
      foundDonorId = foundDonorId || memberSubscriber.donor_id;
      // Get address info from subscriber if member didn't have it
      zipCode = zipCode || memberSubscriber.zip_code;
      city = city || memberSubscriber.city;
      state = state || memberSubscriber.state;
      address = address || memberSubscriber.address;
    }
  }
  console.log('After lookup, found:', {
    name,
    email,
    zipCode,
    city,
    state,
    source
  });
  return {
    subscriber_id: foundSubscriberId,
    member_id: foundMemberId,
    donor_id: foundDonorId,
    name,
    email,
    phone,
    phone_e164: phoneE164,
    zip_code: zipCode,
    address,
    city,
    state,
    source
  };
}
/**
 * Manual lookup and create if the RPC doesn't exist or fails
 */ async function manualLookupAndCreate(phone, phoneE164) {
  const searched = await searchPersonByPhone(phone);
  let foundSubscriberId = searched.subscriber_id;
  const foundMemberId = searched.member_id;
  const foundDonorId = searched.donor_id;
  let name = searched.name;
  let email = searched.email;
  const zipCode = searched.zip_code;
  const address = searched.address;
  const city = searched.city;
  const state = searched.state;
  let source = searched.source;
  let isNew = false;
  // =========================================================================
  // If no subscriber found, create one with placeholder
  // =========================================================================
  if (!foundSubscriberId) {
    isNew = true;
    const placeholderEmail = email || generatePlaceholderEmail(phoneE164);
    const placeholderName = name || generatePlaceholderName(phoneE164);
    console.log('Creating new subscriber with:', {
      placeholderName,
      placeholderEmail,
      phoneE164
    });
    const { data: newSubscriber, error: createError } = await supabase.from('subscribers').insert({
      name: placeholderName,
      email: placeholderEmail,
      phone: phone,
      phone_e164: phoneE164,
      zip_code: zipCode,
      address: address,
      city: city,
      state: state,
      member_id: foundMemberId,
      donor_id: foundDonorId,
      source: 'form',
      subscription_status: 'pending',
      optin_date: new Date().toISOString()
    }).select('id').single();
    if (createError) {
      console.error('Error creating subscriber:', createError);
      throw new Error(`Failed to create subscriber: ${createError.message}`);
    }
    foundSubscriberId = newSubscriber.id;
    name = placeholderName;
    email = placeholderEmail;
    source = 'new';
  }
  return {
    found: !isNew,
    subscriber_id: foundSubscriberId,
    member_id: foundMemberId,
    donor_id: foundDonorId,
    is_new: isNew,
    name,
    email,
    phone,
    phone_e164: phoneE164,
    zip_code: zipCode,
    address,
    city,
    state,
    source
  };
}
/**
 * Find or create a form submission for this session
 */ async function findOrCreateSubmission(formId, subscriberId, memberId, phoneE164, sessionToken, ipAddress, userAgent) {
  // Reclaim any non-final row for this phone+form so a returning respondent
  // continues the SAME submission instead of forking a new one. We consider:
  //  - in_progress rows;
  //  - abandoned rows that still hold real answers (a prior false-abandon);
  //  - 'submitted' rows that are NOT actually finished (missing the last-page
  //    certify/signature) — those were frozen mid-fill by the 2026-07 incident
  //    and their owner must be able to come back and truly submit. A genuinely
  //    finished submission (certify + signature present) is never reclaimed.
  const { data: candidates } = await supabase.from('form_submissions').select('id, status, data').eq('form_id', formId).eq('submitter_phone', phoneE164).in('status', [
    'in_progress',
    'abandoned',
    'submitted'
  ]).order('created_at', {
    ascending: false
  });
  const isTrulyFinished = (d)=>!!(d && typeof d === 'object' && d['certify'] && d['signature']);
  let existing = null;
  if (candidates && candidates.length > 0) {
    // A genuinely finished submission for this phone means: do NOT reclaim
    // anything — the person is done (handleSubmit stays idempotent for them).
    const finished = candidates.find((c)=>c.status === 'submitted' && isTrulyFinished(c.data));
    if (!finished) {
      existing = candidates.find((c)=>c.status === 'in_progress') || candidates.find((c)=>c.status === 'abandoned' && hasRealAnswers(c.data)) || candidates.find((c)=>c.status === 'submitted' && !isTrulyFinished(c.data)) || null;
    }
  }
  if (existing) {
    // Resume it under the new session; restore in_progress if it was abandoned.
    await supabase.from('form_submissions').update({
      session_token: sessionToken,
      subscriber_id: subscriberId,
      member_id: memberId,
      status: 'in_progress',
      updated_at: new Date().toISOString()
    }).eq('id', existing.id);
    return existing.id;
  }
  // Create new submission
  const { data: newSubmission, error } = await supabase.from('form_submissions').insert({
    form_id: formId,
    subscriber_id: subscriberId,
    member_id: memberId,
    submitter_phone: phoneE164,
    session_token: sessionToken,
    status: 'in_progress',
    data: {},
    ip_address: ipAddress,
    user_agent: userAgent
  }).select('id').single();
  if (error) {
    console.error('Error creating submission:', error);
    throw new Error(`Failed to create submission: ${error.message}`);
  }
  return newSubmission.id;
}
/**
 * The saved draft for this phone on this form.
 *
 * Only ever called after the SMS code checked out. The get_form_draft RPC is
 * stonewalled for every slug because it was itself a phone oracle: slug plus
 * phone, callable by anon, returning a stranger's typed answers. This is the
 * verified path to the same data.
 */ async function fetchServerDraft(formSlug, phoneE164) {
  if (!formSlug) return null;
  // Same key the database uses (public._normalize_phone): the right 10 digits.
  const phoneKey = normalizePhone(phoneE164).slice(-10);
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase.from('form_drafts').select('data, page, updated_at').eq('form_slug', formSlug).eq('phone_key', phoneKey).gt('updated_at', cutoff).maybeSingle();
  if (error) {
    console.error('Error loading server draft:', error);
    return null;
  }
  return data || null;
}
/**
 * Would handing this person back put any REAL detail on the wire?
 *
 * This is the whole definition of "we know this number". A subscriber that
 * exists only as a placeholder (Pending +1..., form_...@pending.moyd.org, no
 * address) is not a person we know; it is a husk this very function created on
 * a previous visit, and gating on it would text a code to someone whose data we
 * do not hold. Mirrors the prefill block below exactly: if any key in there
 * would come back non-null, the answer is yes.
 */ function prefillHasRealDetail(person) {
  if (!person) return false;
  const name = person.name || '';
  const email = person.email || '';
  if (name && !isPlaceholderName(name)) return true;
  if (email && !isPlaceholderEmail(email)) return true;
  return !!(person.zip_code || person.address || person.city || person.state);
}
/**
 * Persist WHERE THIS SESSION CAME FROM.
 *
 * form_submissions is anon-INSERTable with no column restriction (policy
 * form_submissions_public_insert_active), so any flag written there is
 * forgeable by a direct PostgREST insert and worth nothing. This table has RLS
 * on and zero policies: only the service role, i.e. only this function, can
 * write or read it.
 *
 * Written on EVERY successful init, both paths. phone_verified_at is stamped
 * only when this very request's Twilio VerificationCheck approved, and is
 * otherwise carried forward, so a person who verified once and then re-inits
 * does not silently lose it. The row is still never sufficient on its own:
 * every consumer also matches session_token and keys its phone queries off
 * phone_e164 here rather than off the anon-writable submitter_phone.
 */ async function recordSessionVerification(submissionId, sessionToken, phoneE164, verifiedThisRequest) {
  const row = {
    submission_id: submissionId,
    session_token: sessionToken,
    phone_e164: phoneE164,
    phone_verified_at: null
  };
  if (verifiedThisRequest) {
    row.phone_verified_at = new Date().toISOString();
  } else {
    const { data: prior } = await supabase.from('form_session_verifications').select('phone_verified_at').eq('submission_id', submissionId).maybeSingle();
    row.phone_verified_at = prior?.phone_verified_at ?? null;
  }
  const { error } = await supabase.from('form_session_verifications').upsert(row, {
    onConflict: 'submission_id'
  });
  if (error) {
    // Loud: without this row every later action refuses the session.
    console.error('Error recording session verification:', error);
  }
}
/**
 * The provenance row for a request, or null if this session was not created by
 * this function. Null means refuse, never "carry on unverified".
 */ async function loadSessionProvenance(submissionId, sessionToken) {
  if (!submissionId || !sessionToken) return null;
  const { data, error } = await supabase.from('form_session_verifications').select('submission_id, session_token, phone_e164, phone_verified_at').eq('submission_id', submissionId).maybeSingle();
  if (error) {
    console.error('Error loading session provenance:', error);
    return null;
  }
  if (!data) return null;
  if (data.session_token !== sessionToken) return null;
  return data;
}
/**
 * Record a form analytics event
 */ async function recordFormAnalytics(formId, eventType, options) {
  await supabase.from('form_analytics').insert({
    form_id: formId,
    submission_id: options.submissionId || null,
    subscriber_id: options.subscriberId || null,
    member_id: options.memberId || null,
    session_token: options.sessionToken || null,
    event_type: eventType,
    timestamp: new Date().toISOString(),
    ip_address: options.ipAddress || null,
    user_agent: options.userAgent || null,
    referrer: options.referrer || null,
    metadata: options.metadata || null
  });
}
/**
 * Record a field analytics event
 */ async function recordFieldAnalytics(formId, fieldId, eventType, options) {
  await supabase.from('form_field_analytics').insert({
    form_id: formId,
    field_id: fieldId,
    field_type: options.fieldType || null,
    submission_id: options.submissionId || null,
    subscriber_id: options.subscriberId || null,
    member_id: options.memberId || null,
    session_token: options.sessionToken || null,
    event_type: eventType,
    timestamp: new Date().toISOString(),
    metadata: options.metadata || null
  });
}
/**
 * Update subscriber with real values (replacing placeholders)
 */ async function updateSubscriber(subscriberId, updates) {
  // First get current subscriber to check for placeholders
  const { data: current } = await supabase.from('subscribers').select('name, email').eq('id', subscriberId).single();
  if (!current) {
    return {
      success: false
    };
  }
  const updateData = {};
  // Only update name if current is placeholder or new name is provided
  if (updates.name && (isPlaceholderName(current.name) || updates.name !== current.name)) {
    updateData.name = updates.name;
  }
  // Handle email update carefully (unique constraint)
  if (updates.email && updates.email !== current.email) {
    // Check if this email already exists
    const { data: existingWithEmail } = await supabase.from('subscribers').select('id').eq('email', updates.email.toLowerCase()).neq('id', subscriberId).maybeSingle();
    if (existingWithEmail) {
      // Email exists with different subscriber - return conflict info
      return {
        success: false,
        conflictSubscriberId: existingWithEmail.id
      };
    }
    // Safe to update email
    updateData.email = updates.email.toLowerCase();
    // If updating from placeholder, also update subscription status
    if (isPlaceholderEmail(current.email)) {
      updateData.subscription_status = 'subscribed';
    }
  }
  // Add other fields
  if (updates.zip_code) updateData.zip_code = updates.zip_code;
  if (updates.address) updateData.address = updates.address;
  if (updates.city) updateData.city = updates.city;
  if (updates.state) updateData.state = updates.state;
  if (Object.keys(updateData).length === 0) {
    return {
      success: true
    };
  }
  updateData.updated_at = new Date().toISOString();
  const { error } = await supabase.from('subscribers').update(updateData).eq('id', subscriberId);
  if (error) {
    console.error('Error updating subscriber:', error);
    return {
      success: false
    };
  }
  return {
    success: true
  };
}
// ============================================================================
// ACTION HANDLERS
// ============================================================================
/**
 * Start a verification and answer with the minimum the client needs to show the
 * code screen. This is the ENTIRE known-person response: no submission_id, no
 * subscriber_id, no member_id, no donor_id, no session_token, no person_found,
 * no prefill, no draft, no is_placeholder. Nothing here describes the person or
 * carries an identifier whose reclaim semantics would describe them.
 *
 * `error` rides along only when Twilio refused to send (max attempts, an
 * unreachable number). That is about the send, not about the human, so it
 * leaks nothing, and without it the person sits on a code screen waiting for a
 * text that is never coming.
 */ async function beginPhoneVerification(phoneE164) {
  const started = await startVerification(phoneE164);
  const response = {
    success: true,
    verification_required: true
  };
  if (!started.started && started.error) {
    response.error = started.error;
  }
  return response;
}
/**
 * ACTION: init_session
 * Called when phone number is entered - creates subscriber and submission immediately
 */ async function handleInitSession(request) {
  const { form_id, phone, session_token, verification_code, ip_address, user_agent, referrer } = request;
  // Validate
  if (!form_id) {
    throw new Error('form_id is required');
  }
  if (!phone || !isValidPhone(phone)) {
    throw new Error('Valid phone number is required');
  }
  // Verify form exists and is open for business
  const { data: form, error: formError } = await supabase.from('form_schemas').select(FORM_AVAILABILITY_COLUMNS).eq('id', form_id).maybeSingle();
  if (formError || !form) {
    throw new Error('Form not found');
  }
  // Status alone used to be the whole check here. A closed form should not mint
  // a new session, create a subscriber, or spend an SMS, so the window is
  // enforced before any of that happens. Structured rather than thrown so the
  // client can tell "this form is closed" apart from a 500; handlePhoneSubmit
  // already surfaces `error` verbatim on success:false, and the absence of
  // verification_required keeps it out of the code-screen branch.
  const startRefusal = formWindowRefusal(form);
  if (startRefusal) {
    return {
      success: false,
      ...startRefusal
    };
  }
  const phoneE164 = formatPhoneE164(phone);
  const newSessionToken = session_token || generateSessionToken();
  // ==========================================================================
  // VERIFICATION GATE. EVERY FORM, NO OPT-IN, NO FLAG.
  // ==========================================================================
  // The person is told nothing about any of this. They tap Continue and either
  // a code screen appears or the details screen does. There is no third
  // outcome and no copy anywhere explaining the branch.
  //
  // Order matters. With no code in hand we first ask, WITHOUT creating
  // anything, whether we already hold real details for this number. If we do,
  // we look nobody up, reclaim no submission, record no analytics, and answer
  // with verification_required and nothing else: typing a stranger's number
  // teaches you that we know it and not one field about them. If we do not,
  // there is nothing to protect, so no text is sent and today's flow runs
  // untouched, verification_required absent.
  let verifiedThisRequest = false;
  if (verification_code) {
    // The one-shot check happens HERE, in the same request that returns the
    // data. Nothing about it survives for a client to replay or forge.
    const check = await checkVerificationCode(phoneE164, verification_code);
    if (!check.approved) {
      return {
        success: false,
        code: 'VERIFICATION_FAILED',
        error: check.error || BAD_CODE_MESSAGE
      };
    }
    verifiedThisRequest = true;
  } else {
    const known = await searchPersonByPhone(phone);
    if (prefillHasRealDetail(known)) {
      return await beginPhoneVerification(phoneE164);
    }
  }
  // Look up or create subscriber
  const personResult = await lookupPersonByPhone(phone);
  if (!personResult.subscriber_id) {
    throw new Error('Failed to create subscriber');
  }
  // BELT AND BRACES. lookupPersonByPhone prefers the RPC, whose matching is not
  // the same code as the dry-run search above, so it can find someone the
  // search missed. If it did, this response would carry their details, so it
  // does not go out: we start a verification and answer exactly as we would
  // have a moment ago. The gate's correctness must never depend on two
  // different matchers agreeing.
  if (!verifiedThisRequest && prefillHasRealDetail(personResult)) {
    return await beginPhoneVerification(phoneE164);
  }
  // Find or create submission
  const submissionId = await findOrCreateSubmission(form_id, personResult.subscriber_id, personResult.member_id, phoneE164, newSessionToken, ip_address, user_agent);
  // Record analytics
  await recordFormAnalytics(form_id, 'phone_entered', {
    submissionId,
    subscriberId: personResult.subscriber_id,
    memberId: personResult.member_id,
    sessionToken: newSessionToken,
    ipAddress: ip_address,
    userAgent: user_agent,
    referrer,
    metadata: {
      phone_e164: phoneE164,
      person_found: personResult.found,
      source: personResult.source
    }
  });
  if (personResult.found) {
    await recordFormAnalytics(form_id, 'identity_found', {
      submissionId,
      subscriberId: personResult.subscriber_id,
      memberId: personResult.member_id,
      sessionToken: newSessionToken,
      metadata: {
        source: personResult.source
      }
    });
  }
  // Determine if the prefill data is real or placeholder
  const isPlaceholder = personResult.is_new || isPlaceholderEmail(personResult.email || '') || isPlaceholderName(personResult.name || '');
  const response = {
    success: true,
    submission_id: submissionId,
    subscriber_id: personResult.subscriber_id,
    member_id: personResult.member_id,
    donor_id: personResult.donor_id,
    session_token: newSessionToken,
    person_found: personResult.found,
    prefill: {
      name: isPlaceholderName(personResult.name || '') ? null : personResult.name,
      email: isPlaceholderEmail(personResult.email || '') ? null : personResult.email,
      zip_code: personResult.zip_code,
      address: personResult.address,
      city: personResult.city,
      state: personResult.state
    },
    is_placeholder: isPlaceholder
  };
  // Where this session came from, written where anon cannot reach it. Both
  // paths write it, so an unknown-number session is refusable-by-token later
  // without ever having been verified.
  await recordSessionVerification(submissionId, newSessionToken, phoneE164, verifiedThisRequest);
  // The draft rides back only on a request that just proved possession of this
  // number. get_form_draft is stonewalled for every slug now, so this is the
  // only way to it, and an unknown-number session has no draft to fetch: a
  // draft only exists once someone reached the identity stage, and doing that
  // makes them known.
  if (verifiedThisRequest) {
    response.draft = await fetchServerDraft(form.slug, phoneE164);
  }
  return response;
}
/**
 * ACTION: update_field
 * Called when any field is completed (on blur)
 */ async function handleUpdateField(request) {
  const { submission_id, session_token, field_key, field_value, field_type } = request;
  // Validate
  if (!submission_id || !session_token || !field_key) {
    throw new Error('submission_id, session_token, and field_key are required');
  }
  // Get submission and verify session
  const { data: submission, error: subError } = await supabase.from('form_submissions').select('id, form_id, subscriber_id, member_id, data, status').eq('id', submission_id).eq('session_token', session_token).single();
  if (subError || !submission) {
    throw new Error('Submission not found or session mismatch');
  }
  if (submission.status === 'submitted') {
    // Idempotent no-op: a late field autosave arriving after submit must not
    // 500 (that error used to spam the client). The submitted data is final.
    return {
      success: true,
      ignored: 'already_submitted'
    };
  }
  // Merge the new field value into existing data
  const updatedData = {
    ...submission.data || {},
    [field_key]: field_value
  };
  // Prepare submission update
  const submissionUpdate = {
    data: updatedData,
    updated_at: new Date().toISOString()
  };
  // Handle identity fields specially
  const identityFields = [
    'name',
    'full_name',
    'first_name',
    'email',
    'email_address',
    'zip_code',
    'zipcode',
    'postal_code'
  ];
  const isIdentityField = identityFields.includes(field_key.toLowerCase());
  if (isIdentityField && submission.subscriber_id) {
    // Map field key to subscriber field
    let subscriberField = null;
    let submissionField = null;
    if ([
      'name',
      'full_name',
      'first_name'
    ].includes(field_key.toLowerCase())) {
      subscriberField = 'name';
      submissionField = 'submitter_name';
    } else if ([
      'email',
      'email_address'
    ].includes(field_key.toLowerCase())) {
      subscriberField = 'email';
      submissionField = 'submitter_email';
    } else if ([
      'zip_code',
      'zipcode',
      'postal_code'
    ].includes(field_key.toLowerCase())) {
      subscriberField = 'zip_code';
    }
    // Update subscriber
    if (subscriberField && field_value) {
      const updateResult = await updateSubscriber(submission.subscriber_id, {
        [subscriberField]: field_value
      });
      if (!updateResult.success && updateResult.conflictSubscriberId) {
        // Email conflict - we might want to merge or handle differently
        // For now, just log it
        console.warn(`Email conflict: ${field_value} already exists with subscriber ${updateResult.conflictSubscriberId}`);
      }
    }
    // Update submission fields
    if (submissionField) {
      submissionUpdate[submissionField] = field_value;
    }
  }
  // Update submission
  await supabase.from('form_submissions').update(submissionUpdate).eq('id', submission_id);
  // Record field analytics
  await recordFieldAnalytics(submission.form_id, field_key, 'field_completed', {
    fieldType: field_type,
    submissionId: submission_id,
    subscriberId: submission.subscriber_id,
    memberId: submission.member_id,
    sessionToken: session_token,
    metadata: {
      is_identity_field: isIdentityField
    }
  });
  return {
    success: true
  };
}
/**
 * ACTION: submit
 * Called when form is submitted
 */ async function handleSubmit(request) {
  const { submission_id, session_token, final_data } = request;
  // Validate
  if (!submission_id || !session_token) {
    throw new Error('submission_id and session_token are required');
  }
  // Get submission and verify session
  const { data: submission, error: subError } = await supabase.from('form_submissions').select('id, form_id, subscriber_id, member_id, data, status, submitter_name, submitter_email, submitter_phone').eq('id', submission_id).eq('session_token', session_token).single();
  if (subError || !submission) {
    throw new Error('Submission not found or session mismatch');
  }
  // IDEMPOTENT: a real last-page tap must never surface as an error. If this
  // same session already submitted (double-tap, retry, or a row previously
  // flipped to submitted), return success without re-writing. Not re-writing
  // avoids re-firing any AFTER-UPDATE side effects (e.g. thank-you email).
  if (submission.status === 'submitted') {
    return {
      success: true,
      submission_id,
      idempotent: true
    };
  }
  // Merge final data if provided. This is the authoritative last-page payload
  // and wins over the incrementally-saved per-field data.
  const mergedData = final_data ? {
    ...submission.data || {},
    ...final_data
  } : submission.data;
  // One read of the form serves both gates below.
  const { data: formRow } = await supabase.from('form_schemas').select(FORM_AVAILABILITY_COLUMNS).eq('id', submission.form_id).maybeSingle();
  // ==========================================================================
  // FORM AVAILABILITY GATE
  // ==========================================================================
  // Every form, not just the endorsement questionnaire. Placed AFTER the
  // idempotent early-return, so someone who already submitted before the close
  // still gets their silent success rather than being told the door shut on
  // them, and BEFORE the status UPDATE, so nothing lands. This is the bolt: the
  // render path can refuse to draw a closed form, but it cannot stop a tab that
  // was open before the close, a resumed session, or a direct POST.
  const submitRefusal = formWindowRefusal(formRow) || formCapRefusal(formRow, 1);
  if (submitRefusal) {
    return {
      success: false,
      ...submitRefusal
    };
  }
  // ==========================================================================
  // ELECTION GATE
  // ==========================================================================
  // Placed AFTER the idempotent early-return (so a double-tap stays silent) and
  // BEFORE the status UPDATE. The browser modal is cosmetic on its own: a
  // session resumed from before it shipped, a replayed request, or a hand-rolled
  // POST all die right here instead. Keyed on the endorsement slug prefix, so
  // every other form takes the path it always took.
  if (isEndorsementSlug(formRow?.slug)) {
    const gateData = mergedData || {};
    // The proof is the provenance row this function wrote, matched on token.
    // Nothing on form_submissions is trusted here: anon can insert that table
    // with no column restriction, so submitter_phone is attacker-supplied and
    // the duplicate query below keys off phone_e164 from the locked row.
    const provenance = await loadSessionProvenance(submission_id, session_token);
    if (!provenance) {
      return {
        success: false,
        code: 'SESSION_REFRESH_REQUIRED',
        error: SESSION_REFRESH_MESSAGE
      };
    }
    const resolved = await resolveElection(gateData);
    if (resolved.unavailable) {
      // The calendar is the rule. If it cannot be read we do not know whether
      // this election is open, and letting the application land is the one
      // outcome that cannot be undone. Loud in the logs, recoverable for the
      // person: their answers are already saved and a retry goes through.
      return {
        success: false,
        code: 'ELECTION_CALENDAR_UNAVAILABLE',
        error: 'We could not check that election just now. Your answers are saved. Please try again shortly.'
      };
    }
    if (!resolved.election) {
      return {
        success: false,
        code: 'ELECTION_REQUIRED',
        error: 'Please tell us which election you are running in.'
      };
    }
    const refusal = await electionRefusal(resolved.election);
    if (refusal) {
      return {
        success: false,
        ...refusal
      };
    }
    const duplicate = await hasFinishedSubmissionForElection(submission.form_id, provenance.phone_e164, resolved.election, submission_id);
    if (duplicate) {
      return {
        success: false,
        code: 'ALREADY_SUBMITTED',
        error: 'We have already received your endorsement application for this election.'
      };
    }
  }
  // Update submission to submitted (scoped to this session). Any prior status
  // other than 'submitted' (in_progress, or an erroneously-abandoned row) is
  // promoted forward here, so an active submit always wins over a stray abandon.
  await supabase.from('form_submissions').update({
    data: mergedData,
    status: 'submitted',
    updated_at: new Date().toISOString()
  }).eq('id', submission_id).eq('session_token', session_token);
  // If subscriber still has placeholder values, try to update from submission data
  if (submission.subscriber_id) {
    const { data: subscriber } = await supabase.from('subscribers').select('name, email, subscription_status').eq('id', submission.subscriber_id).single();
    if (subscriber) {
      const updates = {};
      // Update subscription status to active
      if (subscriber.subscription_status === 'pending') {
        updates.subscription_status = 'subscribed';
      }
      // Get name and email from submission if subscriber has placeholders
      if (isPlaceholderName(subscriber.name) && submission.submitter_name) {
        updates.name = submission.submitter_name;
      }
      if (isPlaceholderEmail(subscriber.email) && submission.submitter_email) {
        updates.email = submission.submitter_email.toLowerCase();
      }
      if (Object.keys(updates).length > 0) {
        await supabase.from('subscribers').update(updates).eq('id', submission.subscriber_id);
      }
    }
  }
  // Record submit analytics
  await recordFormAnalytics(submission.form_id, 'submit', {
    submissionId: submission_id,
    subscriberId: submission.subscriber_id,
    memberId: submission.member_id,
    sessionToken: session_token,
    metadata: {
      final: true
    }
  });
  return {
    success: true,
    submission_id
  };
}
/**
 * ACTION: check_election
 * The verdict on the election a session just picked, for the modal the race
 * page shows. Two independent answers, in one round trip:
 *
 *   refusal          why the calendar refuses this election, or null.
 *                    ELECTION_CLOSED (past our submission deadline) or
 *                    ELECTION_PRIMARY_PENDING (a general whose primary has not
 *                    been held). Exactly what handleSubmit would answer, from
 *                    the same two functions, so the modal and the write agree
 *                    by construction rather than by two people remembering to
 *                    edit both.
 *   already_submitted  does this phone already have a finished application for
 *                    it? One opaque boolean: no id, no name, no email, no date
 *                    crosses the wire, and the question cannot be asked without
 *                    a session_token matching the provenance row, whose
 *                    phone_e164 (not the anon-writable submitter_phone) is the
 *                    number actually queried.
 *
 * The refusal is public calendar information, so it is safe on either path:
 * someone we did not know still has to be told the deadline has passed.
 */ async function handleCheckElection(request) {
  const { submission_id, session_token } = request;
  if (!submission_id || !session_token) {
    throw new Error('submission_id and session_token are required');
  }
  const { data: submission, error: subError } = await supabase.from('form_submissions').select('id, form_id').eq('id', submission_id).eq('session_token', session_token).single();
  if (subError || !submission) {
    throw new Error('Submission not found or session mismatch');
  }
  const provenance = await loadSessionProvenance(submission_id, session_token);
  if (!provenance) {
    return {
      success: false,
      code: 'SESSION_REFRESH_REQUIRED',
      error: SESSION_REFRESH_MESSAGE
    };
  }
  const resolved = await resolveElection(request);
  if (resolved.unavailable) {
    return {
      success: false,
      code: 'ELECTION_CALENDAR_UNAVAILABLE',
      error: 'We could not check that election just now. Please try again shortly.'
    };
  }
  if (!resolved.election) {
    // Nothing picked yet, so nothing to block.
    return {
      success: true,
      already_submitted: false,
      refusal: null
    };
  }
  const refusal = await electionRefusal(resolved.election);
  const already = await hasFinishedSubmissionForElection(submission.form_id, provenance.phone_e164, resolved.election, submission_id);
  return {
    success: true,
    already_submitted: already,
    refusal: refusal ?? null,
    election: {
      id: resolved.election.id,
      label: electionName(resolved.election),
      election_date: resolved.election.election_date,
      submission_deadline: resolved.election.submission_deadline
    }
  };
}
/**
 * ACTION: subscribe_alerts
 * The closed-primary modal's "alert me about future endorsements" button.
 *
 * This runs server side so the copy ("You are now subscribed to alerts") is
 * actually true. By the time someone sees that modal they ALREADY have a
 * subscribers row, created by init_session, so an anonymous client-side insert
 * of their email would collide with the unique email constraint and fail at
 * exactly the moment we promise them it worked. Their email arrived on page 1
 * and is already on that row; we never ask for it again.
 *
 * Idempotent by construction: re-tapping the button changes nothing.
 */ async function handleSubscribeAlerts(request) {
  const { submission_id, session_token, election_year, election_type } = request;
  if (!submission_id || !session_token) {
    throw new Error('submission_id and session_token are required');
  }
  const { data: submission, error: subError } = await supabase.from('form_submissions').select('id, form_id, subscriber_id').eq('id', submission_id).eq('session_token', session_token).single();
  if (subError || !submission) {
    throw new Error('Submission not found or session mismatch');
  }
  const { data: form } = await supabase.from('form_schemas').select('slug').eq('id', submission.form_id).maybeSingle();
  if (!isEndorsementSlug(form?.slug)) {
    throw new Error('This form does not offer endorsement alerts');
  }
  const provenance = await loadSessionProvenance(submission_id, session_token);
  if (!provenance) {
    return {
      success: false,
      code: 'SESSION_REFRESH_REQUIRED',
      error: SESSION_REFRESH_MESSAGE
    };
  }
  if (!submission.subscriber_id) {
    throw new Error('No subscriber on this session');
  }
  // The election they asked to hear about, named the same way they named it on
  // the race page. The calendar row is authoritative when it resolves; the raw
  // values are used only when it does not, so a calendar hiccup never costs
  // somebody their alert signup.
  const resolved = await resolveElection(request);
  const year = resolved.election ? electionYearOf(resolved.election) : valueOr(election_year, '');
  const type = resolved.election ? valueOr(resolved.election.election_type, '') : valueOr(election_type, '');
  if (!year) {
    throw new Error('Tell us which election you want alerts about');
  }
  // election_type is stored as '' rather than NULL for anything that carries no
  // type, because in Postgres a NULL never conflicts with anything and the
  // unique (subscriber_id, election_year, election_type) would stop deduping.
  const { error: signupError } = await supabase.from('endorsement_alert_signups').upsert({
    subscriber_id: submission.subscriber_id,
    submission_id: submission.id,
    election_year: year,
    election_type: type
  }, {
    onConflict: 'subscriber_id,election_year,election_type',
    ignoreDuplicates: true
  });
  if (signupError) {
    console.error('Error recording endorsement alert signup:', signupError);
    throw new Error('Could not record your alert signup');
  }
  // Only lift a still-pending subscriber. Anyone already subscribed, or who has
  // unsubscribed on purpose, is left exactly as they are.
  await supabase.from('subscribers').update({
    subscription_status: 'subscribed',
    updated_at: new Date().toISOString()
  }).eq('id', submission.subscriber_id).eq('subscription_status', 'pending');
  return {
    success: true
  };
}
/**
 * ACTION: abandon
 * Called on a true page unload. Safe by construction:
 *  - scoped by session_token so one tab can never abandon another's row;
 *  - NEVER downgrades a row that already holds real answers (a half-filled
 *    survey must never become 'abandoned' just because the page unloaded).
 * Together with the client no longer firing abandon on mobile app-switch/lock
 * (useBeforeUnload), this makes the 2026-07 false-abandon cascade impossible.
 */ async function handleAbandon(request) {
  const { submission_id, session_token } = request;
  if (!submission_id) {
    throw new Error('submission_id is required');
  }
  if (!session_token) {
    // No session scope -> refuse to abandon anything. Fail safe.
    return {
      success: true
    };
  }
  // Get submission, scoped to this session only.
  const { data: submission } = await supabase.from('form_submissions').select('id, form_id, subscriber_id, member_id, status, data').eq('id', submission_id).eq('session_token', session_token).maybeSingle();
  if (!submission) {
    return {
      success: true
    }; // Already gone or not our session, that's fine
  }
  if (submission.status !== 'in_progress') {
    return {
      success: true
    }; // Not in progress (submitted/abandoned already), don't change
  }
  if (hasRealAnswers(submission.data)) {
    // The respondent has typed real answers. Leave it in_progress so the
    // data stays recoverable; do NOT mark abandoned.
    return {
      success: true,
      skipped: 'has_real_answers'
    };
  }
  // Only truly-empty in-progress rows (phone entered, nothing else) get here.
  await supabase.from('form_submissions').update({
    status: 'abandoned',
    updated_at: new Date().toISOString()
  }).eq('id', submission_id).eq('session_token', session_token);
  // Record abandon analytics
  await recordFormAnalytics(submission.form_id, 'abandon', {
    submissionId: submission_id,
    subscriberId: submission.subscriber_id,
    memberId: submission.member_id,
    sessionToken: session_token,
    metadata: {
      reason: 'user_initiated'
    }
  });
  return {
    success: true
  };
}
/**
 * ACTION: view
 * Called when form is first viewed (before phone entry)
 */ async function handleView(request) {
  const { form_id, ip_address, user_agent, referrer } = request;
  const sessionToken = request.session_token || generateSessionToken();
  if (!form_id) {
    throw new Error('form_id is required');
  }
  // Record view event
  await recordFormAnalytics(form_id, 'view', {
    sessionToken,
    ipAddress: ip_address,
    userAgent: user_agent,
    referrer
  });
  return {
    success: true,
    session_token: sessionToken
  };
}
/**
 * The 'lookup' search itself. Returns the full found payload or null.
 * Creates nothing and never texts anybody.
 */ async function lookupExistingByPhone(phone, phoneE164) {
  const normalizedPhone = normalizePhone(phone);
  // Search without creating. Only digit-derived values (normalizedPhone,
  // phoneE164) are interpolated into the PostgREST filter; the raw request
  // string is never used here, so it cannot inject filter syntax.
  const { data: subscriber } = await supabase.from('subscribers').select('*').or(`phone.eq.${normalizedPhone},phone.eq.${phoneE164},phone_e164.eq.${phoneE164}`).not('email', 'ilike', '%@pending.moyd.org') // Exclude placeholders
  .limit(1).maybeSingle();
  if (subscriber) {
    return {
      found: true,
      subscriber_id: subscriber.id,
      member_id: subscriber.member_id,
      donor_id: subscriber.donor_id,
      is_new: false,
      name: subscriber.name,
      email: subscriber.email,
      phone: subscriber.phone,
      phone_e164: subscriber.phone_e164,
      zip_code: subscriber.zip_code,
      address: subscriber.address,
      city: subscriber.city,
      state: subscriber.state,
      source: 'subscriber'
    };
  }
  // Check other tables (digit-derived filter values only; no raw request string)
  const { data: member } = await supabase.from('members').select('*').or(`phone.eq.${phoneE164},phone.eq.${normalizedPhone}`).limit(1).maybeSingle();
  if (member) {
    return {
      found: true,
      subscriber_id: null,
      member_id: member.id,
      donor_id: member.donor_id,
      is_new: false,
      name: member.name,
      email: member.email,
      phone: member.phone,
      phone_e164: phoneE164,
      zip_code: member.zip_code,
      address: member.address,
      city: member.city,
      state: member.state,
      source: 'member'
    };
  }
  return null;
}
/**
 * ACTION: lookup (backwards compatibility)
 *
 * This used to hand a stranger's name, email, address, city, state and zip to
 * anyone who typed their number, over the public anon key, with no auth at all.
 * Same two-step contract as the other doors now:
 *   { phone }        -> known: text a code, answer { verification_required: true }
 *                       unknown: today's all-null not-found shape, no text sent
 *   { phone, code }  -> checked in THIS request: approved returns the payload
 *                       below, rejected returns verification_required and no data
 * No live browser caller in this repo reaches it (site-jobs and site-events call
 * submit-job and submit-event-by-phone), but it is a public door and it closes.
 */ async function handleLookup(request) {
  const { phone, code } = request || {};
  if (!phone || !isValidPhone(phone)) {
    return {
      found: false,
      subscriber_id: null,
      member_id: null,
      donor_id: null,
      is_new: false,
      name: null,
      email: null,
      phone: null,
      phone_e164: null,
      zip_code: null,
      address: null,
      city: null,
      state: null,
      source: null
    };
  }
  const phoneE164 = formatPhoneE164(phone);
  const person = await lookupExistingByPhone(phone, phoneE164);
  if (!person) {
    // Nothing to protect. Byte for byte the old not-found answer, no SMS.
    return {
      found: false,
      subscriber_id: null,
      member_id: null,
      donor_id: null,
      is_new: false,
      name: null,
      email: null,
      phone: phone,
      phone_e164: phoneE164,
      zip_code: null,
      address: null,
      city: null,
      state: null,
      source: null
    };
  }
  if (!code) {
    const started = await startVerification(phoneE164);
    const response = {
      verification_required: true
    };
    if (!started.started && started.error) {
      response.error = started.error;
    }
    return response;
  }
  const check = await checkVerificationCode(phoneE164, code);
  if (!check.approved) {
    return {
      verification_required: true,
      error: check.error || BAD_CODE_MESSAGE
    };
  }
  return person;
}
// ============================================================================
// MAIN REQUEST HANDLER
// ============================================================================
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  try {
    const body = await req.json();
    const { action, ...data } = body;
    let result;
    switch(action){
      case 'view':
        result = await handleView(data);
        break;
      case 'init_session':
        result = await handleInitSession(data);
        break;
      case 'update_field':
        result = await handleUpdateField(data);
        break;
      case 'submit':
        result = await handleSubmit(data);
        break;
      case 'check_election':
        result = await handleCheckElection(data);
        break;
      case 'subscribe_alerts':
        result = await handleSubscribeAlerts(data);
        break;
      case 'abandon':
        result = await handleAbandon(data);
        break;
      case 'lookup':
        result = await handleLookup(data);
        break;
      default:
        return new Response(JSON.stringify({
          error: "Invalid action. Use 'view', 'init_session', 'update_field', 'submit', 'check_election', 'subscribe_alerts', 'abandon', or 'lookup'",
          code: 'INVALID_ACTION'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
    }
    return new Response(JSON.stringify(result), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("Error processing request:", error);
    return new Response(JSON.stringify({
      error: error.message || "Failed to process request",
      code: "INTERNAL_ERROR"
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
