-- Close the anon-EXECUTE holes on SECURITY DEFINER RPCs found by the
-- 2026-08-11 audit of public schema functions.
--
-- Every one of these is owned by `postgres` (BYPASSRLS), so a grant to anon
-- hands the caller whatever the body reads, with RLS off. All 12 were live
-- confirmed returning real personal data to an anonymous caller holding only
-- the publishable anon key.
--
-- REVOKE FROM PUBLIC, not just anon. The ACL on every one of these was
-- `=X/postgres` (the PUBLIC grant) in addition to the explicit anon grant.
-- anon inherits PUBLIC, so revoking anon alone leaves the hole wide open
-- while looking effective.
--
-- Callers were traced across my-bluebubbles-web (Flutter CRM),
-- moyd-consolidation/moyoungdemocrats (Next.js site + member portal) and
-- every deployed edge function. `authenticated` is kept wherever a real
-- logged-in caller exists, and dropped where none does.
--
-- NOT touched: members_preauth_check(text) and get_user_valid_committees(text).
-- Both have a genuine anonymous caller — the CRM login screen calls them
-- BEFORE sign-in (lib/app/layouts/startup/password_screen.dart). Breaking
-- sign-in is worse than the membership-oracle exposure, and neither can be
-- guarded on auth.uid() by construction since there is no session yet.
--
-- search_path is pinned as `public, pg_temp` rather than bare `public`.
-- With a bare `public`, pg_temp is still searched FIRST implicitly, which is
-- the shadowing hole the pin is supposed to close. Listing pg_temp last is
-- what the five already-pinned functions here use; this matches them.

-- ---------------------------------------------------------------------------
-- 1. Member PII. Full members row (phone, DOB, address, race, gender identity,
--    sexual orientation, religion, disability, notes, internal_member_info).
--    Real caller: member portal profile page, authenticated, always with the
--    caller's OWN member id (src/app/site-members/dashboard/profile/page.tsx).
--    The body had NO guard of any kind, so any caller could name any member.
--    Ownership guard added: yourself, or an executive.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_member_profile_with_pending_changes(p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $function$
DECLARE
  v_member_data JSONB;
  v_field_record RECORD;
BEGIN
  -- Guard: you may read your own profile, executives may read any.
  -- Email is matched case-insensitively on purpose: auth accounts that differ
  -- only by email case exist in this project and would otherwise be locked out.
  IF NOT (
    public.is_executive()
    OR EXISTS (
      SELECT 1
      FROM public.members m
      WHERE m.id = p_member_id
        AND (
          m.user_id = auth.uid()
          OR (
            (auth.jwt() ->> 'email') IS NOT NULL
            AND lower(m.email) = lower(auth.jwt() ->> 'email')
          )
        )
    )
  ) THEN
    RAISE EXCEPTION 'not authorized to read this member profile'
      USING ERRCODE = '42501';
  END IF;

  SELECT to_jsonb(m.*) INTO v_member_data
  FROM public.members m
  WHERE m.id = p_member_id;

  IF v_member_data IS NULL THEN
    RETURN NULL;
  END IF;

  FOR v_field_record IN
    SELECT DISTINCT ON (field_name)
      field_name,
      new_value,
      change_type
    FROM public.member_profile_changes
    WHERE member_id = p_member_id
      AND status = 'pending'
    ORDER BY field_name, created_at DESC
  LOOP
    IF v_field_record.change_type = 'delete' THEN
      v_member_data := jsonb_set(v_member_data, ARRAY[v_field_record.field_name], 'null'::jsonb);
    ELSE
      v_member_data := jsonb_set(
        v_member_data,
        ARRAY[v_field_record.field_name],
        to_jsonb(v_field_record.new_value)
      );
    END IF;
  END LOOP;

  RETURN v_member_data;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_member_profile_with_pending_changes(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_member_profile_with_pending_changes(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_member_profile_with_pending_changes(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Donor and payee PII + full contribution / expenditure history.
--    Real callers: Flutter CRM only (mec_repository.dart, mec_donor_screen.dart,
--    mec_payee_screen.dart, committees_tab.dart) — all authenticated.
--    get_donor_profile_by_natural_key and get_payee_profile_by_natural_key are
--    reachable by NAME with no id, so they were anonymously enumerable.
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.get_donor_unified_profile(integer) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_donor_unified_profile(integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_donor_unified_profile(integer) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_donor_unified_profile(integer) TO authenticated, service_role;

ALTER FUNCTION public.get_donor_profile_by_id(integer) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_donor_profile_by_id(integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_donor_profile_by_id(integer) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_donor_profile_by_id(integer) TO authenticated, service_role;

ALTER FUNCTION public.get_donor_profile_by_natural_key(text, text, text, text) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_donor_profile_by_natural_key(text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_donor_profile_by_natural_key(text, text, text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_donor_profile_by_natural_key(text, text, text, text) TO authenticated, service_role;

ALTER FUNCTION public.get_payee_profile_by_natural_key(text, text, text, text, text) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_payee_profile_by_natural_key(text, text, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_payee_profile_by_natural_key(text, text, text, text, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_payee_profile_by_natural_key(text, text, text, text, text) TO authenticated, service_role;

ALTER FUNCTION public.get_committee_donors_paginated(text, integer, integer, text, boolean) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_committee_donors_paginated(text, integer, integer, text, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_committee_donors_paginated(text, integer, integer, text, boolean) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_committee_donors_paginated(text, integer, integer, text, boolean) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Candidate CRM internals. search_candidates returns date_of_birth, address,
--    voter_id, van_id, notes and the moyd_* / score_* internal fields, and it
--    pages, so it was a full candidate-table dump. get_candidate_full returns
--    the private candidate_contacts log. No anonymous caller in any repo.
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.search_candidates(text, text, text, integer, integer, boolean, text, integer, integer) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.search_candidates(text, text, text, integer, integer, boolean, text, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.search_candidates(text, text, text, integer, integer, boolean, text, integer, integer) FROM anon;
GRANT  EXECUTE ON FUNCTION public.search_candidates(text, text, text, integer, integer, boolean, text, integer, integer) TO authenticated, service_role;

ALTER FUNCTION public.get_candidate_full(uuid) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_candidate_full(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_candidate_full(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_candidate_full(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Exec name + email harvesting, and per-member attendance.
--    No caller in any repo, public site included.
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.get_committee_leaders(text) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_committee_leaders(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_committee_leaders(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_committee_leaders(text) TO authenticated, service_role;

ALTER FUNCTION public.get_committee_with_leaders(text) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_committee_with_leaders(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_committee_with_leaders(text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_committee_with_leaders(text) TO authenticated, service_role;

ALTER FUNCTION public.get_member_attendance_stats(uuid) SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.get_member_attendance_stats(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_member_attendance_stats(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_member_attendance_stats(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Internal analytics blob: top donor names and members broken down by
--    county / gender / race / religion / committee / college. Its only caller
--    is another SECURITY DEFINER function in the database, which runs as
--    postgres, so no client role needs EXECUTE at all.
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.format_dashboard_metrics_for_knowledge() SET search_path TO public, pg_temp;
REVOKE EXECUTE ON FUNCTION public.format_dashboard_metrics_for_knowledge() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.format_dashboard_metrics_for_knowledge() FROM anon;
REVOKE EXECUTE ON FUNCTION public.format_dashboard_metrics_for_knowledge() FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.format_dashboard_metrics_for_knowledge() TO service_role;
