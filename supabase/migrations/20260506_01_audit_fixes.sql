-- =============================================================================
-- 20260506_01_audit_fixes.sql
-- =============================================================================
-- Wave 4 Agent F1 — follow-up to Wave 3 Agent R1's SQL review of the
-- per-user-audit branch (review at /tmp/moyd-access-audit/review-R1-sql.md).
-- Applies three targeted fixes on top of 20260505_01_audit_retention.sql +
-- 20260424_01_audit_foundations.sql. All changes are idempotent — safe to
-- re-run.
--
-- Fixes:
--   (1) Tighten fn_prune_audit_log_partitions() archive-completeness guard.
--       Was: "ANY file under YYYY/MM/" is sufficient. Now: require a distinct
--       daily archive for EACH day-in-month before dropping the partition.
--   (2) Wrap the audit-log-archive-daily cron body in a Vault-secret guard.
--       First-run before Andrew seeds AUDIT_ARCHIVE_FN_JWT will RAISE WARNING
--       and skip instead of POSTing an empty Bearer and getting 401'd in
--       net._http_response (which pg_net silently swallows).
--   (3) Revoke EXECUTE on public.create_auth_users_from_members() from
--       `authenticated`. Phase 0 revoked anon + PUBLIC only; any logged-in
--       user could still mass-insert auth.users rows. Per plan 04 §D#14.
--
-- Rollback:
--   (1) Re-apply the prior fn body from 20260505_01_audit_retention.sql.
--   (2) cron.alter_job(...) back to the original inline net.http_post body or
--       DROP FUNCTION public.fn_audit_log_archive_dispatch() then reschedule.
--   (3) GRANT EXECUTE ON FUNCTION public.create_auth_users_from_members() TO
--       authenticated;  -- undoes fix 3.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fix 1: Tighten archive-completeness check in prune fn
-- -----------------------------------------------------------------------------
-- For each partition whose month ended more than 90 days ago, require
-- COUNT(DISTINCT daily-parquet-filename) = N days-in-month. A partition where
-- 29/30 days archived successfully but day 30 silently failed will now skip
-- with a NOTICE instead of being dropped. The filename regex enforces the
-- agreed storage-key convention (YYYY/MM/YYYY-MM-DD.parquet).

CREATE OR REPLACE FUNCTION public.fn_prune_audit_log_partitions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cutoff_date   date := (now() AT TIME ZONE 'UTC')::date - 90;
    v_partition     record;
    v_year          text;
    v_month         text;
    v_prefix        text;
    v_archive_count bigint;
    v_expected_days int;
    v_month_start   date;
BEGIN
    FOR v_partition IN
        SELECT c.relname AS part_name,
               substring(c.relname FROM 'audit_log_(\d{4})_\d{2}') AS year,
               substring(c.relname FROM 'audit_log_\d{4}_(\d{2})') AS month
        FROM pg_inherits i
        JOIN pg_class c ON c.oid = i.inhrelid
        JOIN pg_class p ON p.oid = i.inhparent
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE p.relname = 'audit_log'
          AND n.nspname = 'public'
          AND c.relname ~ '^audit_log_\d{4}_\d{2}$'
    LOOP
        v_year  := v_partition.year;
        v_month := v_partition.month;
        v_month_start := to_date(v_year || '-' || v_month || '-01', 'YYYY-MM-DD');

        -- Eligibility: first-of-next-month must already be on or before cutoff.
        IF (v_month_start + interval '1 month')::date > v_cutoff_date THEN
            CONTINUE;
        END IF;

        v_prefix := v_year || '/' || v_month || '/';

        -- Days-in-month for partition month. EXTRACT(day FROM last-of-month).
        v_expected_days := EXTRACT(day FROM
            (v_month_start + interval '1 month' - interval '1 day'))::int;

        -- Require one distinct daily parquet per day-in-month at the path
        -- audit-archive/YYYY/MM/YYYY-MM-DD.parquet. COUNT(DISTINCT name)
        -- tolerates duplicate rows (unlikely, but cheap).
        SELECT COUNT(DISTINCT name) INTO v_archive_count
        FROM storage.objects
        WHERE bucket_id = 'audit-archive'
          AND name LIKE v_prefix || '%'
          AND name ~ ('^' || v_prefix || '\d{4}-\d{2}-\d{2}\.parquet$');

        IF v_archive_count < v_expected_days THEN
            RAISE WARNING 'audit-log-partition-prune: skipping % — have % of % expected daily archive files at %',
                v_partition.part_name, v_archive_count, v_expected_days, v_prefix;
            CONTINUE;
        END IF;

        -- All days archived. DETACH before DROP (belt-and-braces for
        -- publication wiring).
        EXECUTE format('ALTER TABLE public.audit_log DETACH PARTITION public.%I;',
                       v_partition.part_name);
        EXECUTE format('DROP TABLE IF EXISTS public.%I;', v_partition.part_name);

        RAISE NOTICE 'audit-log-partition-prune: dropped % (% of % days archived at %)',
            v_partition.part_name, v_archive_count, v_expected_days, v_prefix;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_prune_audit_log_partitions() FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- Fix 2: Archive cron fail-loud guard on missing Vault secret
-- -----------------------------------------------------------------------------
-- Define a dispatcher fn the cron row calls instead of inlining the
-- net.http_post. The dispatcher checks Vault FIRST: if
-- AUDIT_ARCHIVE_FN_JWT is missing/empty, RAISE WARNING and return without
-- enqueueing a doomed 401. Otherwise post normally.
--
-- Once Andrew seeds the Vault secret (runbook step 1 in Phase 5), subsequent
-- runs flow through. The WARNING shows up in Postgres logs (Supabase Logs
-- Explorer → severity WARNING) so a missing secret is observable on day 1,
-- not three months later when prune finds no archive files.

CREATE OR REPLACE FUNCTION public.fn_audit_log_archive_dispatch()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_jwt          text;
    v_target_date  date := (now() AT TIME ZONE 'UTC')::date - 1;
BEGIN
    SELECT decrypted_secret INTO v_jwt
    FROM vault.decrypted_secrets
    WHERE name = 'AUDIT_ARCHIVE_FN_JWT'
    LIMIT 1;

    IF v_jwt IS NULL OR v_jwt = '' THEN
        RAISE WARNING 'audit-log-archive-daily: AUDIT_ARCHIVE_FN_JWT not set in Vault — skipping run for %', v_target_date;
        RETURN;
    END IF;

    PERFORM net.http_post(
        url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/export-audit-log-to-storage',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_jwt
        ),
        body := jsonb_build_object(
            'date', v_target_date::text
        ),
        timeout_milliseconds := 120000
    );
END;
$$;

REVOKE ALL ON FUNCTION public.fn_audit_log_archive_dispatch() FROM PUBLIC;
-- Only the postgres role (pg_cron owner) and superadmin-via-psql will call it.

-- Rewire the existing cron row. unschedule-by-name then re-schedule against
-- the new dispatcher. Idempotent: if the job doesn't exist (e.g. Phase 5 was
-- never applied) this migration silently creates it; if it does, it's
-- replaced.

DO $cron_rewire$
DECLARE
    v_job_id bigint;
BEGIN
    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'audit-log-archive-daily';

    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;

    PERFORM cron.schedule(
        'audit-log-archive-daily',
        '0 3 * * *',
        $cmd$SELECT public.fn_audit_log_archive_dispatch();$cmd$
    );
END
$cron_rewire$;

-- -----------------------------------------------------------------------------
-- Fix 3: Revoke `authenticated` EXECUTE on create_auth_users_from_members
-- -----------------------------------------------------------------------------
-- Phase 0 (20260424_01_audit_foundations.sql §10) revoked anon + PUBLIC only.
-- This function mass-INSERTs rows into auth.users for every public.members
-- row lacking one — a trivially-abusable escalation vector if any logged-in
-- user can call it. Plan 04-supabase-audit §D#14 flagged this.
--
-- Wrapped in a DO block: REVOKE is a no-op if the grant is already absent,
-- but wrapping in DO keeps the migration's error behavior consistent with
-- the rest of this file (one statement per fix).

DO $revoke_caufm$
BEGIN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.create_auth_users_from_members() FROM authenticated';
EXCEPTION
    WHEN undefined_function THEN
        RAISE NOTICE 'create_auth_users_from_members() not present — skipping revoke';
END
$revoke_caufm$;

-- =============================================================================
-- Appendix: other SECURITY DEFINER + anon/authenticated-callable functions
-- =============================================================================
-- Running the audit query from the review (`has_function_privilege('anon', …
-- 'EXECUTE')` on every SECURITY DEFINER fn in public) returned ~97 functions.
-- Every one has EXECUTE for BOTH anon AND authenticated except three that
-- are authenticated-only (`is_staff`, `is_executive`, `is_committee_member`,
-- `get_yd_primary_challengers` — role helpers, fine to expose).
--
-- Most are READ-ONLY (get_*, count_*, search_*, render_*, format_*,
-- slack_*_needs_sync, etc) or are trigger-fn bodies that PostgreSQL tracks
-- grants on by habit but never actually invokes via SQL callers. Those are
-- not concerning.
--
-- The following WRITE-CAPABLE fns are grouped by risk; F1 revoked only the
-- single worst offender (create_auth_users_from_members). The rest are
-- flagged here for Andrew / R2 reviewer to decide:
--
--   HIGH (bulk-mutation across many rows, no per-caller gating):
--     - bulk_sync_donors()                       — inserts/updates many donors
--     - bulk_sync_event_attendees()              — inserts/updates many attendees
--     - enrich_donors_from_census()              — rewrites donor geography cols
--     - recalculate_all_legislator_sponsorship_counts()  — rewrites aggregates
--
--   MEDIUM (single-row mutation or controlled scope):
--     - batch_update_node_positions(p_updates jsonb)  — org-chart node moves
--     - delete_node_with_cleanup(p_node_id uuid)      — deletes an org-chart node
--     - cleanup_expired_tokens()                      — removes rows from a token table
--     - apply_approved_profile_change(...)            — applies a reviewed diff
--     - add_member_field_to_visibility(...)           — member visibility config
--     - manual_refresh_dashboard_metrics()            — refreshes metrics MV
--     - refresh_crm_dashboard_metrics()               — refreshes metrics MV
--     - reset_api_key_daily_counts()                  — resets usage counters
--     - discover_new_tables()                         — read-only introspection
--
--   LOW / presumed-safe (server-side queues, callback paths, edge-fn helpers):
--     - auto_create_auth_user_from_member (trigger body, invoked by trigger
--       not direct RPC; anon grant is cosmetic but harmless here since the
--       caller path is AFTER INSERT on members which anon can't do).
--     - call_job_notification_edge_function / call_populate_subscriber_geography
--       — trigger bodies.
--     - trigger_*, auto_*, sync_* — all trigger-body fns (EXECUTE grant is
--       not the attack surface; the trigger firing is).
--
-- F1 deliberately does NOT revoke the HIGH/MEDIUM list in this migration —
-- mass-revoking could break Flutter CRM flows that call these via PostgREST
-- (e.g. bulk_sync_donors is used by Andrew's Donor tools page per the Dart
-- audit). Needs per-function analysis of call sites first. R2 / Andrew can
-- triage.
-- =============================================================================

-- =============================================================================
-- End of 20260506_01_audit_fixes.sql
-- =============================================================================
