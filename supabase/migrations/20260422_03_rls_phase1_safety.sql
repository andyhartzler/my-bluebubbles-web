-- 2026-04-22 RLS Phase 1 — safety baseline
--
-- Context: prior session audit found that the `anon` key (shipped in every
-- Flutter web build) has `SELECT/INSERT/UPDATE/DELETE/TRUNCATE` grants on
-- most tables in `public`, and 42 tables have RLS disabled entirely. The
-- worst exploit shape is a single `DELETE FROM public.mo_voter_file;`
-- wiping 4.3M voter-file rows.
--
-- This migration is the minimum-disruption safety baseline:
--   1. Revoke `DELETE` and `TRUNCATE` from `anon` (and `public`) on every
--      table in `public`. Nothing in the app does destructive writes via
--      the anon key; those paths run under `authenticated` or inside
--      SECURITY DEFINER RPCs.
--   2. Enable Row Level Security on every table that currently has it off.
--   3. For each newly-RLS'd table, add a permissive `FOR ALL TO
--      authenticated USING (true) WITH CHECK (true)` policy. This
--      preserves the app's current write/read behaviour for logged-in
--      users. We tighten these per-table in Phase 2 once the CRM code is
--      audited against them.
--   4. Seed two helper functions we'll lean on in Phase 2:
--      `public.is_executive()` and `public.is_committee_member()`, both
--      SECURITY DEFINER, STABLE, and scoped to `auth.uid()`.
--
-- This migration is idempotent. It does NOT tighten any existing
-- `qual=true` policies — that's Phase 2.

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Revoke destructive privileges from anon + public globally
-- ----------------------------------------------------------------------------

DO $$
DECLARE
  t text;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('REVOKE DELETE, TRUNCATE ON public.%I FROM anon',   t);
    EXECUTE format('REVOKE DELETE, TRUNCATE ON public.%I FROM PUBLIC', t);
  END LOOP;
END $$;

-- Also default-revoke on future tables created in public.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE DELETE, TRUNCATE ON TABLES FROM anon;

-- ----------------------------------------------------------------------------
-- 2. Helper functions for Phase 2 policy tightening
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_executive()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT m.executive_committee FROM public.members m WHERE m.user_id = auth.uid() LIMIT 1),
    false
  );
$$;

COMMENT ON FUNCTION public.is_executive() IS
  'True when the calling Supabase Auth user is marked executive_committee on their members row. SECURITY DEFINER so policies on PII tables can check without needing SELECT on members.';

CREATE OR REPLACE FUNCTION public.is_committee_member()
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
      AND (m.executive_committee = true OR m.committee IS NOT NULL)
    LIMIT 1
  );
$$;

COMMENT ON FUNCTION public.is_committee_member() IS
  'True when the calling user is on any MOYD committee (executive or general). SECURITY DEFINER as above.';

-- Lock the helpers down: only authenticated + service_role call these
-- directly. Policies using them always resolve under the invoking role.
REVOKE ALL ON FUNCTION public.is_executive() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_committee_member() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_executive()        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_committee_member() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Enable RLS on every currently-disabled table + add a safe default policy
-- ----------------------------------------------------------------------------
-- Default policy shape:
--   FOR ALL TO authenticated USING (true) WITH CHECK (true)
-- Same net effect as before the migration for *authenticated* callers,
-- but now anon is denied by default (no anon policy = anon blocked under RLS).

DO $$
DECLARE
  t text;
  disabled_tables text[] := ARRAY[
    'ai_configuration', 'candidate_contacts', 'candidate_endorsements',
    'candidate_news', 'candidates', 'district_demographics',
    'donor_activity_log', 'donor_call_outcomes', 'donor_profiles',
    'donor_tags', 'election_history', 'email_cleanup_staging',
    'historical_candidates', 'legislation_text_extraction_queue',
    'mautic_sync_log', 'mautic_sync_queue', 'mec_donor_merges',
    'mec_expenditures', 'mec_financial_summaries',
    'mec_independent_expenditures', 'mec_large_contributions',
    'mo_voter_file', 'nonprofit_officers', 'receipts',
    'slack_avatar_sync_queue', 'slack_channel_committee_mapping',
    'slack_channel_membership_log', 'slack_message_archive_status',
    'slack_messages', 'slack_user_mapping', 'slack_users_unmatched',
    'van_addresses', 'van_districts', 'van_early_voting', 'van_emails',
    'van_household', 'van_mec_donor_parties', 'van_phones',
    'van_polling_locations', 'van_scores', 'van_voters',
    'van_voting_history'
  ];
BEGIN
  FOREACH t IN ARRAY disabled_tables LOOP
    -- Enable RLS (idempotent — Postgres is fine with enabling an already-on table)
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

    -- Drop any prior safety policy from a re-run of this migration
    EXECUTE format(
      'DROP POLICY IF EXISTS "rls_phase1_authenticated_all" ON public.%I',
      t
    );

    -- Create a permissive authenticated-all default. Phase 2 tightens per
    -- table once callers are audited.
    EXECUTE format($q$
      CREATE POLICY "rls_phase1_authenticated_all"
        ON public.%I
        AS PERMISSIVE
        FOR ALL
        TO authenticated
        USING (true)
        WITH CHECK (true)
    $q$, t);
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 4. Tighten anon SELECT on the most sensitive PII tables
-- ----------------------------------------------------------------------------
-- Even if RLS + no-anon-policy already denies reads, revoking the grant too
-- is belt-and-braces. These tables hold name/DOB/address/contact info and
-- should never be readable by an unauthenticated caller.

DO $$
DECLARE
  t text;
  pii_tables text[] := ARRAY[
    'mo_voter_file',
    'candidates',
    'historical_candidates',
    'donor_profiles',
    'donor_tags',
    'donor_activity_log',
    'donor_call_outcomes',
    'receipts',
    'van_voters',
    'van_addresses',
    'van_emails',
    'van_phones',
    'van_household',
    'van_voting_history',
    'van_early_voting',
    'van_scores',
    'van_districts',
    'van_polling_locations',
    'van_mec_donor_parties',
    'slack_messages',
    'slack_user_mapping',
    'slack_users_unmatched',
    'email_cleanup_staging'
  ];
BEGIN
  FOREACH t IN ARRAY pii_tables LOOP
    EXECUTE format(
      'REVOKE SELECT, INSERT, UPDATE ON public.%I FROM anon',
      t
    );
  END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 5. Tell PostgREST to refresh its schema cache
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';

COMMIT;
