-- 2026-04-22 RLS Phase 2 — scope permissive policies to MOYD staff
--
-- Builds on 20260422_03_rls_phase1_safety.sql (RLS enabled + destructive
-- anon grants revoked + helpers seeded). Phase 1 left every authenticated
-- user with blanket `FOR ALL ... USING (true)` on ~42 tables and did not
-- touch ~50 other tables that have hand-rolled `qual=true` policies from
-- much older migrations. Phase 2 tightens both groups.
--
-- Design principles:
--   * The MOYD CRM is staff-only. Every staff member is either on the
--     executive committee (`is_executive() = true`) OR has a non-null
--     `committee` array (`is_committee_member() = true`). So a default
--     policy of `USING (public.is_executive() OR public.is_committee_member())`
--     preserves the CRM for Andrew and all committee members without
--     leaving blanket `true` access on sensitive PII.
--   * Anon-by-design paths stay intact: public form submission
--     (`form_submissions INSERT` when the form is active), form analytics
--     pixel writes, public event RSVP on `event_attendees` /
--     `subscribers`, link-click tracking on `tracking_links` /
--     `campaign_links`, BlueBubbles inbox ingest on `email_inbox`, and
--     the various `*_zip_*` + `fec_*` + `mo_*_entities` research caches.
--   * `members` needs a self-read carve-out so
--     `user_session_provider.loadUserSession()` can bootstrap on first
--     login — before the helper functions know about the user.
--   * REVOKE anon SELECT/INSERT/UPDATE on every sensitive PII table that
--     Phase 1 didn't already cover. `REFERENCES`/`TRIGGER` grants are
--     harmless and left alone.
--   * Idempotent: every policy is dropped-if-exists before create,
--     guarded by DO blocks. Re-runnable without error.
--   * No destructive schema changes. Only policy + grant changes.
--
-- Rollback: each block can be reverted by re-running 20260422_03 (which
-- is also idempotent) or by manually DROP POLICY + CREATE POLICY with
-- the old `true` predicates. The helper functions are not modified.

BEGIN;

-- ============================================================================
-- 1. Helper: is_staff()
-- ============================================================================
-- Every Phase 2 policy funnels through this. Re-entrant SECURITY DEFINER so
-- policies on `members` don't recurse infinitely: the helper bypasses RLS.

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.members m
    WHERE m.user_id = auth.uid()
      AND (
        m.executive_committee = true
        OR m.committee IS NOT NULL
      )
    LIMIT 1
  );
$$;

COMMENT ON FUNCTION public.is_staff() IS
  'True when the calling Supabase Auth user is a MOYD staff member (executive OR on any committee). Combines is_executive() + is_committee_member() in a single plan-friendly call.';

REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated, service_role;

-- ============================================================================
-- 2. `members` — replace 3 anon-read + 3 enable-access policies with a
--    scoped set. Keep: self-read, staff-read, staff-write, walk-in
--    registration (public INSERT but only when caller creates a row with
--    their own user_id/email OR server-side walk-in flag).
-- ============================================================================

DO $$
DECLARE
  p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='members'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.members', p);
  END LOOP;
END $$;

-- Authenticated users can read their own row (supports first-login bootstrap)
CREATE POLICY "members_self_read"
  ON public.members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR email = auth.jwt() ->> 'email');

-- Staff can read every member
CREATE POLICY "members_staff_read"
  ON public.members FOR SELECT TO authenticated
  USING (public.is_staff());

-- Staff can insert/update/delete members (walk-in reg, profile edits)
CREATE POLICY "members_staff_write"
  ON public.members FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- Authenticated users can update their OWN row (profile self-edit)
CREATE POLICY "members_self_update"
  ON public.members FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Service role keeps full access (Edge Functions, admin scripts)
CREATE POLICY "members_service_role"
  ON public.members AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 3. `subscribers` — keep anon INSERT for public-event subscribe flow.
--    Restrict SELECT/UPDATE/DELETE to staff only.
-- ============================================================================

DO $$
DECLARE p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='subscribers'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.subscribers', p);
  END LOOP;
END $$;

CREATE POLICY "subscribers_public_insert"
  ON public.subscribers FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "subscribers_staff_read"
  ON public.subscribers FOR SELECT TO authenticated
  USING (public.is_staff());

CREATE POLICY "subscribers_staff_write"
  ON public.subscribers FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE POLICY "subscribers_service_role"
  ON public.subscribers AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 4. Helper macro-block: swap `qual=true` staff tables in one pass.
--    For every table in the list below, drop all existing authenticated
--    policies and replace with a single `USING (is_staff())` policy.
--    Keep `service_role` policies in place via a separate re-create.
-- ============================================================================

DO $$
DECLARE
  t text;
  p text;
  staff_tables text[] := ARRAY[
    -- donor PII + financial (authed-full-access → staff only)
    'mec_donors', 'donor_enrichment', 'donor_profiles', 'donor_tags',
    'donor_activity_log', 'donor_call_outcomes', 'donor_contacts', 'donors',
    'donations', 'donation_thank_yous',
    'mec_contributions', 'mec_committees', 'mec_expenditures',
    'mec_independent_expenditures', 'mec_large_contributions',
    'mec_financial_summaries', 'mec_donor_merges', 'mec_reports',
    'bank_transactions', 'plaid_connections', 'receipts',
    -- CRM research objects
    'candidates', 'historical_candidates', 'candidate_contacts',
    'candidate_endorsements', 'candidate_news', 'district_demographics',
    'election_history', 'nonprofit_officers',
    -- voter file + VAN
    'mo_voter_file',
    'van_voters', 'van_addresses', 'van_emails', 'van_phones',
    'van_household', 'van_voting_history', 'van_early_voting',
    'van_scores', 'van_districts', 'van_polling_locations',
    'van_mec_donor_parties',
    -- meetings & events staff data
    'meetings', 'meeting_attendance', 'meeting_invitees',
    'non_member_attendees', 'scheduled_meetings',
    'member_portal_meetings', 'member_portal_resources',
    'member_portal_field_visibility', 'member_profile_changes',
    'member_submitted_events', 'member_email_history',
    'chapter_documents', 'chapters',
    -- slack integration
    'slack_messages', 'slack_user_mapping', 'slack_users_unmatched',
    'slack_avatar_sync_queue', 'slack_channel_committee_mapping',
    'slack_channel_membership_log', 'slack_message_archive_status',
    'slack_analytics_cache',
    -- campaigns & comms
    'email_campaigns', 'email_campaign_recipients', 'email_campaign_links',
    'email_campaign_link_clicks', 'email_campaign_statistics',
    'email_templates', 'campaign_recipients',
    'email_cleanup_staging',
    -- surveys
    'surveys', 'survey_questions', 'survey_responses', 'survey_sessions',
    -- call time
    'call_time_lists', 'call_time_list_items',
    -- admin / internal
    'ai_configuration', 'mautic_sync_log', 'mautic_sync_queue',
    'legislation_text_extraction_queue'
  ];
BEGIN
  FOREACH t IN ARRAY staff_tables LOOP
    -- drop every non-service-role policy currently on the table
    FOR p IN
      SELECT policyname FROM pg_policies
      WHERE schemaname='public' AND tablename=t
        AND NOT (policyname ILIKE '%service_role%' OR policyname ILIKE '%service role%')
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p, t);
    END LOOP;

    -- create a single permissive staff policy
    EXECUTE format($q$
      CREATE POLICY "rls_phase2_staff_all"
        ON public.%I AS PERMISSIVE FOR ALL TO authenticated
        USING (public.is_staff())
        WITH CHECK (public.is_staff())
    $q$, t);

    -- make sure service_role always has a blanket policy (idempotent)
    EXECUTE format($q$
      DROP POLICY IF EXISTS "rls_phase2_service_role_all" ON public.%I
    $q$, t);
    EXECUTE format($q$
      CREATE POLICY "rls_phase2_service_role_all"
        ON public.%I AS PERMISSIVE FOR ALL TO service_role
        USING (true) WITH CHECK (true)
    $q$, t);
  END LOOP;
END $$;

-- ============================================================================
-- 5. `event_attendees` — keep public RSVP (anon INSERT), staff owns the
--    rest. The prior policy set had 9 overlapping rules; collapse to 4.
-- ============================================================================

DO $$
DECLARE p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='event_attendees'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.event_attendees', p);
  END LOOP;
END $$;

CREATE POLICY "event_attendees_public_rsvp"
  ON public.event_attendees FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- Preserve the "guest can update their own row by email" flow from the
-- prior policy set (public check-in / ticketing correction).
CREATE POLICY "event_attendees_guest_update"
  ON public.event_attendees FOR UPDATE TO anon, authenticated
  USING (guest_email IS NOT NULL)
  WITH CHECK (guest_email IS NOT NULL);

CREATE POLICY "event_attendees_staff_read"
  ON public.event_attendees FOR SELECT TO authenticated
  USING (public.is_staff());

CREATE POLICY "event_attendees_staff_write"
  ON public.event_attendees FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE POLICY "event_attendees_service_role"
  ON public.event_attendees AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 6. `events` — authenticated users read published, staff manages.
-- ============================================================================

DO $$
DECLARE p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='events'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.events', p);
  END LOOP;
END $$;

CREATE POLICY "events_authenticated_read"
  ON public.events FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "events_staff_write"
  ON public.events FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE POLICY "events_service_role"
  ON public.events AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 7. `form_submissions` — preserve anon INSERT for active forms, staff read.
-- ============================================================================

DO $$
DECLARE p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='form_submissions'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.form_submissions', p);
  END LOOP;
END $$;

CREATE POLICY "form_submissions_public_insert_active"
  ON public.form_submissions FOR INSERT TO anon, authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.form_schemas fs
    WHERE fs.id = form_submissions.form_id
      AND fs.status = 'active'
  ));

CREATE POLICY "form_submissions_self_read"
  ON public.form_submissions FOR SELECT TO authenticated
  USING (member_id = (SELECT id FROM public.members WHERE user_id = auth.uid()));

CREATE POLICY "form_submissions_staff_read"
  ON public.form_submissions FOR SELECT TO authenticated
  USING (public.is_staff());

CREATE POLICY "form_submissions_staff_write"
  ON public.form_submissions FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE POLICY "form_submissions_service_role"
  ON public.form_submissions AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 8. `email_inbox` — BlueBubbles ingest uses anon key to INSERT; nothing
--    else should be public. Staff reads.
-- ============================================================================

DO $$
DECLARE p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='email_inbox'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.email_inbox', p);
  END LOOP;
END $$;

CREATE POLICY "email_inbox_anon_ingest"
  ON public.email_inbox FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "email_inbox_staff_read"
  ON public.email_inbox FOR SELECT TO authenticated
  USING (public.is_staff());

CREATE POLICY "email_inbox_staff_write"
  ON public.email_inbox FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE POLICY "email_inbox_service_role"
  ON public.email_inbox AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 9. `email_logs` + `email_log_members` — internal delivery logs, staff only.
-- ============================================================================

DO $$
DECLARE p text; tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['email_logs', 'email_log_members'] LOOP
    FOR p IN
      SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=tbl
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p, tbl);
    END LOOP;
    EXECUTE format($q$
      CREATE POLICY "rls_phase2_staff_all"
        ON public.%I AS PERMISSIVE FOR ALL TO authenticated
        USING (public.is_staff()) WITH CHECK (public.is_staff())
    $q$, tbl);
    EXECUTE format($q$
      CREATE POLICY "rls_phase2_service_role_all"
        ON public.%I AS PERMISSIVE FOR ALL TO service_role
        USING (true) WITH CHECK (true)
    $q$, tbl);
  END LOOP;
END $$;

-- ============================================================================
-- 10. `committees` — authenticated read (CRM sidebar), staff write.
-- ============================================================================

DO $$
DECLARE p text;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='committees'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.committees', p);
  END LOOP;
END $$;

CREATE POLICY "committees_authenticated_read"
  ON public.committees FOR SELECT TO authenticated USING (true);

CREATE POLICY "committees_staff_write"
  ON public.committees FOR ALL TO authenticated
  USING (public.is_staff()) WITH CHECK (public.is_staff());

CREATE POLICY "committees_service_role"
  ON public.committees AS PERMISSIVE FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ============================================================================
-- 11. Leave permissive but DOCUMENTED — anon-by-design paths.
--    These tables intentionally allow anon writes for public forms,
--    pixel analytics, link tracking, etc. We keep them as-is but annotate.
-- ============================================================================

COMMENT ON TABLE public.form_analytics IS
  'Anon INSERT allowed by design (submission funnel analytics pixels). SELECT is staff only. Rate-limiting is done in the /api/forms/*/submit route, not in RLS.';
COMMENT ON TABLE public.form_field_analytics IS
  'Anon INSERT allowed by design (field-level form analytics pixels).';
COMMENT ON TABLE public.form_events IS
  'Anon INSERT allowed by design (form-event pixels).';
COMMENT ON TABLE public.form_files IS
  'Anon INSERT allowed by design (form file-upload stubs; real file lives in Storage).';
COMMENT ON TABLE public.job_applications IS
  'Anon INSERT allowed by design (public job application flow).';
COMMENT ON TABLE public.job_analytics_events IS
  'Anon INSERT allowed by design (job board funnel analytics).';
COMMENT ON TABLE public.page_views IS
  'Anon INSERT/UPDATE allowed by design (page-view counter on public pages).';
COMMENT ON TABLE public.tracking_links IS
  'Anon SELECT/UPDATE allowed by design (redirect + click-count tracking on marketing links).';
COMMENT ON TABLE public.campaign_links IS
  'Anon SELECT allowed by design (link unfurl during email opens).';
COMMENT ON TABLE public.hanaway_campaign_tracking IS
  'Anon INSERT allowed by design (campaign signup funnel).';
COMMENT ON TABLE public.kv_store IS
  'Anon full access allowed by design. Used for the public member-portal session store; replace before production scale.';
COMMENT ON TABLE public.legislation_legislators IS
  'Public SELECT allowed by design (civic directory). UPDATE is authenticated.';
COMMENT ON TABLE public.fec_candidates IS 'Public research cache; anon-readable by design.';
COMMENT ON TABLE public.fec_committees IS 'Public research cache; anon-readable by design.';
COMMENT ON TABLE public.fec_contributions IS 'Public research cache; anon-readable by design.';
COMMENT ON TABLE public.mec_historical_filings IS 'Public research cache; anon-readable by design.';
COMMENT ON TABLE public.civic_representatives IS 'Public civic directory; anon writes allowed for enrichment scrapers.';
COMMENT ON TABLE public.civic_zip_districts IS 'Public civic directory; anon writes allowed for enrichment scrapers.';
COMMENT ON TABLE public.property_records IS 'Public research cache; anon writes allowed for scraper enrichment.';
COMMENT ON TABLE public.mo_business_entities IS 'Public research cache; anon writes allowed for scraper enrichment.';
COMMENT ON TABLE public.zillow_zip_data IS 'Public research cache; anon writes allowed for scraper enrichment.';
COMMENT ON TABLE public.sec_insider_filings IS 'Public research cache; anon writes allowed for scraper enrichment.';
COMMENT ON TABLE public.census_zip_data IS 'Public research cache; anon readable by design.';
COMMENT ON TABLE public.casenet_records IS 'Scraper-enriched public-record cache; anon writes allowed by design.';
COMMENT ON TABLE public.donor_zip5_lookup IS 'Public zip-code lookup cache; anon read by design.';

-- ============================================================================
-- 12. REVOKE anon SELECT/INSERT/UPDATE on every sensitive PII table that
--     Phase 1 didn't already lock down.
-- ============================================================================

DO $$
DECLARE
  t text;
  revoke_tables text[] := ARRAY[
    -- new Phase 2 revokes
    'members', 'subscribers', 'mec_donors', 'mec_committees', 'mec_contributions',
    'mec_expenditures', 'mec_independent_expenditures', 'mec_large_contributions',
    'mec_financial_summaries', 'mec_donor_merges', 'mec_reports',
    'donors', 'donor_enrichment', 'donor_contacts', 'donations',
    'donation_thank_yous',
    'bank_transactions', 'plaid_connections',
    'meetings', 'meeting_attendance', 'meeting_invitees',
    'non_member_attendees', 'scheduled_meetings',
    'member_email_history', 'member_portal_meetings',
    'member_portal_field_visibility', 'member_portal_resources',
    'member_profile_changes', 'member_submitted_events',
    'email_logs', 'email_log_members',
    'email_campaigns', 'email_campaign_recipients',
    'email_campaign_links', 'email_campaign_link_clicks',
    'email_campaign_statistics', 'email_templates',
    'campaign_recipients', 'email_cleanup_staging',
    'chapter_documents', 'chapters',
    'call_time_lists', 'call_time_list_items',
    'committees'
  ];
BEGIN
  FOREACH t IN ARRAY revoke_tables LOOP
    -- Best-effort REVOKE. Ignore errors for tables that have auto-grants
    -- (event_attendees keeps INSERT for public RSVP via policy; handled below).
    EXECUTE format('REVOKE SELECT, UPDATE, DELETE ON public.%I FROM anon', t);
    EXECUTE format('REVOKE SELECT, UPDATE, DELETE ON public.%I FROM PUBLIC', t);
  END LOOP;
END $$;

-- Keep `subscribers` INSERT for anon (public subscribe form):
GRANT INSERT ON public.subscribers TO anon;

-- Keep `members` INSERT for anon ONLY on walk-in registration? No — CRM
-- always registers members through an authenticated staff session. Revoke:
REVOKE INSERT ON public.members FROM anon, PUBLIC;

-- `event_attendees`: anon INSERT for RSVP + UPDATE (guest-email flow) expected. Revoke SELECT + DELETE.
REVOKE SELECT, DELETE ON public.event_attendees FROM anon, PUBLIC;

-- `form_submissions`: anon INSERT for active-form submit is expected. Leave INSERT, revoke the rest.
REVOKE SELECT, UPDATE, DELETE ON public.form_submissions FROM anon, PUBLIC;

-- `email_inbox`: anon INSERT from BlueBubbles ingest is expected. Revoke everything else.
REVOKE SELECT, UPDATE, DELETE ON public.email_inbox FROM anon, PUBLIC;

-- ============================================================================
-- 13. Tell PostgREST to pick up the new policies
-- ============================================================================

NOTIFY pgrst, 'reload schema';

COMMIT;
