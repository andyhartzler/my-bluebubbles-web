-- =============================================================================
-- 20260505_01_audit_retention.sql
-- =============================================================================
-- Phase 5 of the MOYD CRM per-user-access + audit-trail upgrade (plan §3 Phase 5,
-- §2.7). Establishes the retention + archival lifecycle for public.audit_log and
-- performs the final hardening sweep.
--
-- Retention policy (plan §2.7):
--   * Hot   : 90 days full fidelity in public.audit_log (monthly partitions).
--   * Warm  : 90 days – 1 year as Parquet files in Storage bucket 'audit-archive'
--             (private, superadmin SELECT only; service_role writes via the
--             export-audit-log-to-storage edge fn built by Wave 1 Agent H).
--   * Cold  : Beyond 1 year, same bucket but flagged for compliance deletion
--             (Andrew decides the exact cold window in §4.1 — not enforced here).
--
-- Lifecycle jobs:
--   * audit-log-archive-daily         0 3 * * *   — exports yesterday's rows.
--   * audit-log-partition-prune-monthly 0 4 1 * * — DROPs partitions >90 days
--                                                   old ONLY if a corresponding
--                                                   archive file exists in
--                                                   storage.objects.
--   * audit-log-partition-create-monthly          — already in Phase 0 migration
--                                                   20260424_01_audit_foundations.sql
--                                                   (25th at 02:00 UTC). Not
--                                                   recreated here.
--
-- This migration also:
--   * Drops the dead public.custom_access_token_hook(jsonb) function body (per
--     Andrew's §4.7 decision — GoTrue has it disabled, keeping it around just
--     confuses future readers). NOTE: 04-supabase-audit.md §D#13 said "don't
--     drop" — superseded by Andrew's explicit §4.7 decision in the plan.
--   * DROPs the 3 legacy HTTP-webhook triggers on public.members that still
--     fire to retired Make.com + Zapier endpoints on every write (~40K rows of
--     dead traffic in supabase_functions.hooks per 01 §1 / 05-plan §5 risk #12).
--     Verified via pg_trigger 2026-04-24 — all three present, all enabled.
--
-- Rollback: DROP the two new cron jobs (by name). Recreate the 3 legacy
-- triggers only if Make.com / Zapier endpoints are resurrected (they aren't).
-- Recreate custom_access_token_hook by replaying fn_custom_access_token_hook.sql
-- in the audit repo if ever needed. The audit-archive bucket + policies can be
-- dropped via `DELETE FROM storage.buckets WHERE id = 'audit-archive'` after
-- clearing objects.
--
-- Search_path trap: this database's search_path is `listmonk, extensions, public`.
-- Every object below is fully qualified with public. / storage. / cron. — do
-- not relax.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Section 1: Storage bucket 'audit-archive' (private, superadmin-only SELECT)
-- -----------------------------------------------------------------------------
-- Service-role (the edge fn export-audit-log-to-storage) is the only writer.
-- The bucket stays PRIVATE (public=false) so every read goes through RLS or
-- signed URLs. No INSERT/UPDATE/DELETE policy for authenticated — those paths
-- return 403 for every non-service-role caller by default under storage RLS.

INSERT INTO storage.buckets (id, name, public)
    VALUES ('audit-archive', 'audit-archive', false)
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- Section 2: RLS policies on the audit-archive bucket
-- -----------------------------------------------------------------------------
-- Superadmin-only SELECT. Service-role bypasses RLS so the edge fn writes
-- unimpeded; explicitly denying INSERT/UPDATE/DELETE to authenticated is a
-- belt-and-braces move since the default-deny already covers it.

DROP POLICY IF EXISTS "audit_archive_superadmin_select"
    ON storage.objects;
CREATE POLICY "audit_archive_superadmin_select"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'audit-archive'
        AND public.current_user_is_superadmin()
    );

-- Explicit denial policies for authenticated writers. These do nothing a
-- default-deny doesn't already do, but they make the intent legible and make
-- an accidental "FOR ALL authenticated USING (true)" added later (on some
-- other bucket) safer, since these are bucket-scoped and restrictive.

DROP POLICY IF EXISTS "audit_archive_no_authenticated_insert"
    ON storage.objects;
CREATE POLICY "audit_archive_no_authenticated_insert"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id <> 'audit-archive');

DROP POLICY IF EXISTS "audit_archive_no_authenticated_update"
    ON storage.objects;
CREATE POLICY "audit_archive_no_authenticated_update"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (bucket_id <> 'audit-archive')
    WITH CHECK (bucket_id <> 'audit-archive');

DROP POLICY IF EXISTS "audit_archive_no_authenticated_delete"
    ON storage.objects;
CREATE POLICY "audit_archive_no_authenticated_delete"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (bucket_id <> 'audit-archive');

-- anon gets nothing — no policy references bucket_id='audit-archive' for anon,
-- so default-deny applies. Nothing further needed.

-- -----------------------------------------------------------------------------
-- Section 3: pg_cron job — audit-log-archive-daily
-- -----------------------------------------------------------------------------
-- Runs 03:00 UTC daily. Calls the edge fn export-audit-log-to-storage (built
-- separately by Wave 1 Agent H) passing yesterday's date. The edge fn is
-- responsible for:
--   * Reading public.audit_log WHERE occurred_at::date = <date>
--   * Writing a Parquet file to audit-archive at path YYYY/MM/YYYY-MM-DD.parquet
--   * Returning 200 OK on success
--
-- Deliberately does NOT delete rows from audit_log — that is the job of
-- audit-log-partition-prune-monthly, and only after both (a) age > 90 days
-- AND (b) a corresponding archive file exists. Archive-then-purge is safer
-- than archive-and-purge-in-one-step: if the edge fn silently fails for a
-- week, nothing is lost.
--
-- pg_net.http_post is async — the insert into net.http_request_queue is
-- fire-and-forget, and the response goes into net._http_response. This cron
-- row only enqueues; observability of failures is Andrew's job via
-- `SELECT * FROM net._http_response WHERE url LIKE '%export-audit-log-to-storage%'
--  ORDER BY created DESC`.
--
-- The edge fn needs SUPABASE_SERVICE_ROLE_KEY in its env and reads it at
-- runtime; this SQL layer does NOT embed any service-role JWT (plan §2 is
-- specifically about removing service-role JWTs from embeddable surfaces).
-- The Authorization header here is the fn's own invocation JWT, read from
-- the vault via a secret that Andrew populates post-migration (see the
-- runbook comment in Section 7 below).

DO $cron_archive$
DECLARE
    v_job_id bigint;
BEGIN
    -- Remove any prior schedule with the same name to keep this migration idempotent.
    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'audit-log-archive-daily';

    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;

    PERFORM cron.schedule(
        'audit-log-archive-daily',
        '0 3 * * *',
        $cmd$
        SELECT net.http_post(
            url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/export-audit-log-to-storage',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || COALESCE(
                    (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'AUDIT_ARCHIVE_FN_JWT' LIMIT 1),
                    ''
                )
            ),
            body := jsonb_build_object(
                'date', (now() AT TIME ZONE 'UTC')::date - 1
            ),
            timeout_milliseconds := 120000
        );
        $cmd$
    );
END
$cron_archive$;

-- -----------------------------------------------------------------------------
-- Section 4: pg_cron job — audit-log-partition-prune-monthly
-- -----------------------------------------------------------------------------
-- Runs 04:00 UTC on the 1st of each month (one hour after the archive job
-- finishes its last daily run of the previous month). DROPs any audit_log
-- partition whose entire range is older than 90 days AND which has at least
-- one archived file in the audit-archive bucket under the matching year/month
-- prefix. This is the archive-then-purge guard: without an archive file,
-- partition stays.
--
-- Partition naming (established by fn_create_audit_log_partition in Phase 0):
--   audit_log_YYYY_MM
-- Storage key convention (agreed with Wave 1 Agent H):
--   audit-archive/YYYY/MM/YYYY-MM-DD.parquet
-- A partition for month YYYY_MM is eligible for drop only when:
--   (a) first-of-next-month is more than 90 days ago, AND
--   (b) at least one storage.objects row exists with bucket_id='audit-archive'
--       and name LIKE 'YYYY/MM/%'.

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
BEGIN
    FOR v_partition IN
        SELECT c.relname AS part_name,
               -- Parse YYYY / MM out of the audit_log_YYYY_MM suffix.
               substring(c.relname FROM 'audit_log_(\d{4})_(\d{2})') AS match_ignored,
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

        -- Partition covers [YYYY-MM-01, first-of-next-month). Eligible only
        -- when first-of-next-month <= cutoff (i.e. every row is >90 days old).
        IF (to_date(v_year || '-' || v_month || '-01', 'YYYY-MM-DD')
            + interval '1 month')::date > v_cutoff_date THEN
            CONTINUE;
        END IF;

        -- Guard: require at least one archive file at audit-archive/YYYY/MM/*.
        v_prefix := v_year || '/' || v_month || '/';
        SELECT COUNT(*) INTO v_archive_count
        FROM storage.objects
        WHERE bucket_id = 'audit-archive'
          AND name LIKE v_prefix || '%';

        IF v_archive_count = 0 THEN
            RAISE NOTICE 'audit-log-partition-prune: skipping %, no archive file at prefix %',
                v_partition.part_name, v_prefix;
            CONTINUE;
        END IF;

        -- Drop. Detach first for cleanliness (belt-and-braces — DROP TABLE on
        -- a partition cascades detach internally, but being explicit keeps
        -- publication wiring tidy).
        EXECUTE format('ALTER TABLE public.audit_log DETACH PARTITION public.%I;',
                       v_partition.part_name);
        EXECUTE format('DROP TABLE IF EXISTS public.%I;', v_partition.part_name);

        RAISE NOTICE 'audit-log-partition-prune: dropped % (archived % files at %)',
            v_partition.part_name, v_archive_count, v_prefix;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_prune_audit_log_partitions() FROM PUBLIC;
-- Invoked only by pg_cron (runs as postgres) + manually by superadmin via psql.

DO $cron_prune$
DECLARE
    v_job_id bigint;
BEGIN
    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'audit-log-partition-prune-monthly';

    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;

    PERFORM cron.schedule(
        'audit-log-partition-prune-monthly',
        '0 4 1 * *',
        $cmd$SELECT public.fn_prune_audit_log_partitions();$cmd$
    );
END
$cron_prune$;

-- -----------------------------------------------------------------------------
-- Section 5: partition-create cron job (already created in Phase 0)
-- -----------------------------------------------------------------------------
-- The 'audit-log-partition-create' job at '0 2 25 * *' is created by
-- 20260424_01_audit_foundations.sql (Phase 0) Section 9. Verified present
-- against cron.job on 2026-04-24. This Phase 5 migration does NOT recreate
-- it — nothing to do here. If a future cleanup drops the Phase 0 migration
-- without replaying it, re-add the cron row manually.

-- -----------------------------------------------------------------------------
-- Section 6: Drop dead public.custom_access_token_hook(jsonb)
-- -----------------------------------------------------------------------------
-- Per plan §4.7 Andrew chose to delete the function body. GoTrue has this
-- hook disabled (`hook_custom_access_token_enabled=false` — verified in
-- 04-supabase-audit.md §A.2), so dropping it has zero runtime impact and
-- removes a footgun for future readers who might assume it's wired.
--
-- Note: 04 §D#13 recommended keeping the function as a dashboard-configured
-- target slot. That recommendation is superseded by Andrew's explicit §4.7
-- decision in the plan. If claim injection is ever wanted, re-author the
-- function from scratch; the original body in fn_custom_access_token_hook.sql
-- in the audit repo is preserved as reference.

DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb);

-- -----------------------------------------------------------------------------
-- Section 7: Legacy HTTP-webhook triggers on public.members
-- -----------------------------------------------------------------------------
-- Three triggers still fire on every members write to retired Make.com +
-- Zapier endpoints (supabase_functions.hooks logs >40K attempts to dead URLs
-- per plan §5 risk #12). Verified via pg_trigger on 2026-04-24 — all three
-- present and enabled on public.members. Wave 1 Agent E confirmed:
--
--   tgname                          | table_name | tgenabled
--   --------------------------------+------------+----------
--   attempt 2                       | members    | O
--   make.com google contacts update | members    | O
--   zapier-sd-hd-update             | members    | O
--
-- These fired ~40K times to dead endpoints. Dropping them is safe — the
-- receiving sides were decommissioned during the Zapier→n8n migration. If
-- any of the three destinations ever comes back, a new clean trigger can
-- be authored then.

DROP TRIGGER IF EXISTS "attempt 2" ON public.members;
DROP TRIGGER IF EXISTS "make.com google contacts update" ON public.members;
DROP TRIGGER IF EXISTS "zapier-sd-hd-update" ON public.members;

-- -----------------------------------------------------------------------------
-- Section 8: Manual steps (runbook — NOT executed by this migration)
-- -----------------------------------------------------------------------------
-- The following steps must be performed by Andrew from his shell after this
-- migration lands. They touch Supabase Management API / Vault, which are not
-- reachable from SQL running as `postgres` on the database.
--
-- (1) Store the edge-fn invocation JWT in Vault so the archive cron job can
--     read it. The JWT is the project's anon or a fresh service_role token
--     issued for this fn; Agent H will provide the exact value. Example:
--
--     SELECT vault.create_secret(
--         '<jwt-value>',
--         'AUDIT_ARCHIVE_FN_JWT',
--         'Bearer token for export-audit-log-to-storage edge fn'
--     );
--
-- (2) Bump Supabase Auth `rate_limit_email_sent` from 2 → 10 (plan §4 / 04 §D#8):
--
--     curl -X PATCH \
--       -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
--       -H "Content-Type: application/json" \
--       -d '{"rate_limit_email_sent": 10}' \
--       https://api.supabase.com/v1/projects/faajpcarasilbfndzkmd/config/auth
--
-- (3) Flip `site_url` from members.moyoungdemocrats.org → https://moyd.app
--     (plan §4.6, Andrew's §4.6 decision). Members Portal + Job Poster portal
--     already pass explicit redirect_to overrides so this is a no-op for them,
--     and it makes the CRM exec flow cleaner:
--
--     curl -X PATCH \
--       -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
--       -H "Content-Type: application/json" \
--       -d '{"site_url": "https://moyd.app"}' \
--       https://api.supabase.com/v1/projects/faajpcarasilbfndzkmd/config/auth
--
-- (4) Verify the archive cron row enqueues correctly after Vault seeding:
--
--     SELECT cron.schedule_in_database('audit-log-archive-daily', ...) -- N/A, already scheduled
--     -- instead, trigger a test run via:
--     SELECT net.http_post(
--         url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/export-audit-log-to-storage',
--         headers := jsonb_build_object(
--             'Content-Type', 'application/json',
--             'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'AUDIT_ARCHIVE_FN_JWT')
--         ),
--         body := jsonb_build_object('date', (now()::date - 1))
--     );
--     -- Then inspect net._http_response for the result.

-- =============================================================================
-- End of 20260505_01_audit_retention.sql
-- =============================================================================
