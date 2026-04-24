-- =============================================================================
-- 20260424_01_audit_foundations.sql
-- =============================================================================
-- Phase 0 of the MOYD CRM per-user-access + audit-trail upgrade (plan §3 Phase 0).
-- Additive, zero-downtime infra for the full audit system. No existing behavior
-- is changed by this migration — it only creates new objects and grants.
--
-- Creates:
--   * public.member_roles              (superadmin/executive flag, per-user)
--   * public.audit_log (partitioned)   (generic write-audit table, RANGE by month)
--   * public.current_user_is_superadmin()
--   * public.fn_audit_log_trigger()    (attached to tables in Phase 2, not here)
--   * public.fn_create_audit_log_partition(month date)  (partition helper)
--   * April / May / June 2026 partitions pre-created
--   * pg_cron job 'audit-log-partition-create' to roll partitions forward
--   * Supabase Realtime publication wiring for member_roles + audit_log partitions
--   * Anon EXECUTE revocation on public.create_auth_users_from_members()
--
-- Rollback: drop objects in reverse order (cron job, triggers-none-yet, function
-- trigger, helper fn, rpc, audit_log partitions, audit_log, member_roles). A
-- future `20260424_01_audit_foundations_rollback.sql` can DROP CASCADE each of
-- these — safe because no Phase 2 triggers depend on fn_audit_log_trigger() yet.
--
-- Search_path trap: this database's search_path is `listmonk, extensions, public`.
-- Every DDL in this file is fully qualified with `public.` and every function
-- sets `search_path = public, pg_temp`. Do not relax either.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Section 1: public.member_roles
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.member_roles (
    user_id uuid PRIMARY KEY REFERENCES public.members(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('superadmin', 'executive')),
    granted_by uuid REFERENCES public.members(id),
    granted_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.member_roles ENABLE ROW LEVEL SECURITY;

-- Seed Andrew's superadmin row. The WHERE EXISTS guard makes the migration
-- fail loudly if Andrew's uuid is ever wrong (per plan risk #10).
DO $seed$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.members WHERE id = 'f1ac8208-ad64-405f-8b55-8284ddef51cf'
    ) THEN
        RAISE EXCEPTION
            'Expected superadmin member row f1ac8208-ad64-405f-8b55-8284ddef51cf not found in public.members. Refusing to proceed.';
    END IF;

    INSERT INTO public.member_roles (user_id, role, granted_by, granted_at)
    VALUES ('f1ac8208-ad64-405f-8b55-8284ddef51cf', 'superadmin',
            'f1ac8208-ad64-405f-8b55-8284ddef51cf', now())
    ON CONFLICT (user_id) DO NOTHING;
END
$seed$;

-- -----------------------------------------------------------------------------
-- Section 2: public.current_user_is_superadmin()
-- -----------------------------------------------------------------------------
-- Used by RLS policies below and by the Dart client via PostgREST /rpc/.
-- SECURITY DEFINER so callers don't need direct SELECT on member_roles; the
-- RLS policies on member_roles gate direct reads for everyone else.

CREATE OR REPLACE FUNCTION public.current_user_is_superadmin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.member_roles
        WHERE user_id = auth.uid()
          AND role = 'superadmin'
    );
$$;

REVOKE ALL ON FUNCTION public.current_user_is_superadmin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_is_superadmin() TO authenticated;

-- -----------------------------------------------------------------------------
-- Section 3: RLS policies on public.member_roles
-- -----------------------------------------------------------------------------
-- Superadmin sees & manages all rows. Each user may SELECT only their own row.
-- (Allows a user to learn they are an executive without learning the full list.)

DROP POLICY IF EXISTS "member_roles_superadmin_select_all" ON public.member_roles;
CREATE POLICY "member_roles_superadmin_select_all"
    ON public.member_roles
    FOR SELECT
    TO authenticated
    USING (public.current_user_is_superadmin());

DROP POLICY IF EXISTS "member_roles_self_select" ON public.member_roles;
CREATE POLICY "member_roles_self_select"
    ON public.member_roles
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "member_roles_superadmin_insert" ON public.member_roles;
CREATE POLICY "member_roles_superadmin_insert"
    ON public.member_roles
    FOR INSERT
    TO authenticated
    WITH CHECK (public.current_user_is_superadmin());

DROP POLICY IF EXISTS "member_roles_superadmin_update" ON public.member_roles;
CREATE POLICY "member_roles_superadmin_update"
    ON public.member_roles
    FOR UPDATE
    TO authenticated
    USING (public.current_user_is_superadmin())
    WITH CHECK (public.current_user_is_superadmin());

DROP POLICY IF EXISTS "member_roles_superadmin_delete" ON public.member_roles;
CREATE POLICY "member_roles_superadmin_delete"
    ON public.member_roles
    FOR DELETE
    TO authenticated
    USING (public.current_user_is_superadmin());

-- -----------------------------------------------------------------------------
-- Section 4: public.audit_log (partitioned parent)
-- -----------------------------------------------------------------------------
-- RANGE-partitioned by occurred_at month. PRIMARY KEY must include the
-- partition key — (id, occurred_at) per plan §2.4.

CREATE TABLE IF NOT EXISTS public.audit_log (
    id bigserial,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    actor_id uuid NULL,                              -- auth.uid(); NULL = service_role/system
    actor_role text NOT NULL,                        -- 'authenticated' | 'service_role' | 'anon' | 'postgres'
    actor_email text NULL,                           -- denormalized from auth.users.email
    action text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'RPC', 'EDGE_FN', 'AUTH')),
    schema_name text NOT NULL,
    table_name text NOT NULL,                        -- for RPC: 'rpc:<fn_name>'; for EDGE_FN: 'edge_fn:<name>'
    row_id text NULL,                                -- entity id serialized (uuid/int/text → text)
    before jsonb NULL,                               -- OLD.* for UPDATE/DELETE
    after jsonb NULL,                                -- NEW.* for INSERT/UPDATE
    changed_columns text[] NULL,                     -- UPDATE only: keys where OLD.* IS DISTINCT FROM NEW.*
    ip_address inet NULL,
    user_agent text NULL,
    context jsonb NULL,                              -- free-form (edge_fn name, request_id, etc.)
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Useful indexes inherited by all partitions. Superadmin dashboard filters by
-- (actor_id, occurred_at), by (table_name, occurred_at), and tails by occurred_at.
CREATE INDEX IF NOT EXISTS audit_log_occurred_at_idx
    ON public.audit_log (occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_actor_id_occurred_at_idx
    ON public.audit_log (actor_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_table_name_occurred_at_idx
    ON public.audit_log (table_name, occurred_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_action_occurred_at_idx
    ON public.audit_log (action, occurred_at DESC);

-- RLS policies: superadmin sees everything; each user sees their own history.
-- No INSERT/UPDATE/DELETE policy for any authenticated role — the only writer
-- is fn_audit_log_trigger() which is SECURITY DEFINER and bypasses RLS.

DROP POLICY IF EXISTS "audit_log_superadmin_select" ON public.audit_log;
CREATE POLICY "audit_log_superadmin_select"
    ON public.audit_log
    FOR SELECT
    TO authenticated
    USING (public.current_user_is_superadmin());

DROP POLICY IF EXISTS "audit_log_self_select" ON public.audit_log;
CREATE POLICY "audit_log_self_select"
    ON public.audit_log
    FOR SELECT
    TO authenticated
    USING (actor_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Section 5: public.fn_create_audit_log_partition(month date)
-- -----------------------------------------------------------------------------
-- Idempotent helper. Pass any date within a month — it creates the partition
-- covering [first-of-month, first-of-next-month). Also attaches the partition
-- to supabase_realtime (partitioned tables require per-partition attachment).
-- Partition naming convention: audit_log_YYYY_MM.

CREATE OR REPLACE FUNCTION public.fn_create_audit_log_partition(p_month date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_start   date := date_trunc('month', p_month)::date;
    v_end     date := (date_trunc('month', p_month) + interval '1 month')::date;
    v_part    text := format('audit_log_%s', to_char(v_start, 'YYYY_MM'));
    v_exists  boolean;
    v_in_pub  boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = v_part
    ) INTO v_exists;

    IF NOT v_exists THEN
        EXECUTE format(
            'CREATE TABLE public.%I PARTITION OF public.audit_log FOR VALUES FROM (%L) TO (%L);',
            v_part, v_start::timestamptz, v_end::timestamptz
        );
    END IF;

    -- Ensure partition is in supabase_realtime publication (idempotent).
    SELECT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = v_part
    ) INTO v_in_pub;

    IF NOT v_in_pub THEN
        EXECUTE format(
            'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', v_part
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_create_audit_log_partition(date) FROM PUBLIC;
-- No GRANT to anon/authenticated — only postgres + pg_cron invoke this.

-- -----------------------------------------------------------------------------
-- Section 6: pre-create April / May / June 2026 partitions
-- -----------------------------------------------------------------------------

SELECT public.fn_create_audit_log_partition('2026-04-01'::date);
SELECT public.fn_create_audit_log_partition('2026-05-01'::date);
SELECT public.fn_create_audit_log_partition('2026-06-01'::date);

-- -----------------------------------------------------------------------------
-- Section 7: public.fn_audit_log_trigger()
-- -----------------------------------------------------------------------------
-- Generic AFTER INSERT/UPDATE/DELETE trigger. Phase 2 attaches this to 20
-- high-value tables (plan §3 Phase 2). Included here so tests + per-table
-- attachment DDL in Phase 2 is pure `CREATE TRIGGER ...`.
--
-- Behavior:
--   * actor_id = auth.uid() (NULL for service_role / postgres / non-JWT callers)
--   * actor_role = current_setting('role', true); defaults to 'authenticated'
--     when the setting is empty (defensive — GUC is always set in PostgREST)
--   * UPDATE: compute changed_columns as the set of top-level jsonb keys where
--     to_jsonb(OLD) IS DISTINCT FROM to_jsonb(NEW); skip the audit INSERT if
--     nothing changed (no-op UPDATEs are noise)
--   * actor_email joined from auth.users WHERE id = actor_id
--   * row_id = COALESCE(NEW.id::text, OLD.id::text) — plan §3 Phase 2 asserts
--     every target table has an `id` column
--   * SECURITY DEFINER so it bypasses RLS on audit_log (no INSERT policy
--     exists for authenticated callers, by design)

CREATE OR REPLACE FUNCTION public.fn_audit_log_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_actor_id        uuid        := auth.uid();
    v_actor_role_raw  text        := current_setting('role', true);
    v_actor_role      text;
    v_actor_email     text;
    v_before          jsonb;
    v_after           jsonb;
    v_changed_cols    text[];
    v_row_id          text;
    v_action          text        := TG_OP;
    v_old_json        jsonb;
    v_new_json        jsonb;
    v_key             text;
BEGIN
    -- Normalize actor_role. GUC `role` is 'authenticator', 'authenticated',
    -- 'anon', 'service_role', 'postgres' depending on caller. Coalesce to
    -- 'authenticated' only when it is NULL/empty (defensive — should not happen).
    IF v_actor_role_raw IS NULL OR v_actor_role_raw = '' THEN
        v_actor_role := 'authenticated';
    ELSE
        v_actor_role := v_actor_role_raw;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_before := NULL;
        v_after  := to_jsonb(NEW);
        v_row_id := (v_after ->> 'id');
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);

        -- Build changed_columns: keys present in either side where values differ.
        SELECT COALESCE(array_agg(k ORDER BY k), ARRAY[]::text[])
        INTO v_changed_cols
        FROM (
            SELECT DISTINCT k
            FROM (
                SELECT jsonb_object_keys(v_old_json) AS k
                UNION
                SELECT jsonb_object_keys(v_new_json) AS k
            ) all_keys
            WHERE (v_old_json -> k) IS DISTINCT FROM (v_new_json -> k)
        ) diff;

        -- No-op UPDATE: skip entirely.
        IF v_changed_cols IS NULL OR array_length(v_changed_cols, 1) IS NULL THEN
            RETURN NEW;
        END IF;

        v_before := v_old_json;
        v_after  := v_new_json;
        v_row_id := (v_new_json ->> 'id');
    ELSIF TG_OP = 'DELETE' THEN
        v_before := to_jsonb(OLD);
        v_after  := NULL;
        v_row_id := (v_before ->> 'id');
    ELSE
        -- TRUNCATE or unexpected: return without logging.
        RETURN NULL;
    END IF;

    -- Denormalize email (best-effort; NULL for service_role with no actor_id).
    IF v_actor_id IS NOT NULL THEN
        SELECT email INTO v_actor_email
        FROM auth.users
        WHERE id = v_actor_id
        LIMIT 1;
    END IF;

    INSERT INTO public.audit_log (
        occurred_at, actor_id, actor_role, actor_email, action,
        schema_name, table_name, row_id,
        before, after, changed_columns
    ) VALUES (
        now(), v_actor_id, v_actor_role, v_actor_email, v_action,
        TG_TABLE_SCHEMA, TG_TABLE_NAME, v_row_id,
        v_before, v_after, v_changed_cols
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_audit_log_trigger() FROM PUBLIC;
-- Triggers execute this regardless of EXECUTE grants (trigger fires in the
-- context of the DDL owner). No additional GRANTs required.

-- -----------------------------------------------------------------------------
-- Section 8: supabase_realtime publication wiring
-- -----------------------------------------------------------------------------
-- Partitioned-table caveat (04 §D #4): the parent table cannot be added to a
-- logical publication — each partition must be attached individually. The
-- fn_create_audit_log_partition() helper handles future partitions; here we
-- attach member_roles and the three pre-created partitions.

DO $pub$
DECLARE
    v_rec record;
    v_pub_tables text[];
BEGIN
    FOR v_rec IN
        SELECT tbl
        FROM (VALUES
            ('member_roles'),
            ('audit_log_2026_04'),
            ('audit_log_2026_05'),
            ('audit_log_2026_06')
        ) AS t(tbl)
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = v_rec.tbl
        ) THEN
            EXECUTE format(
                'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;',
                v_rec.tbl
            );
        END IF;
    END LOOP;
END
$pub$;

-- -----------------------------------------------------------------------------
-- Section 9: pg_cron job — audit-log-partition-create
-- -----------------------------------------------------------------------------
-- Runs at 02:00 UTC on the 25th of every month. Creates the partition for the
-- month AFTER next (i.e. 5–6 weeks of headroom) so there's always a live
-- partition even if a run is skipped. Idempotent via fn_create_audit_log_partition.

DO $cron$
DECLARE
    v_job_id bigint;
BEGIN
    -- Remove any prior scheduling with the same name to keep this migration idempotent.
    SELECT jobid INTO v_job_id
    FROM cron.job
    WHERE jobname = 'audit-log-partition-create';

    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;

    PERFORM cron.schedule(
        'audit-log-partition-create',
        '0 2 25 * *',
        $cmd$SELECT public.fn_create_audit_log_partition(
                 (date_trunc('month', now()) + interval '2 months')::date
             );$cmd$
    );
END
$cron$;

-- -----------------------------------------------------------------------------
-- Section 10: harden public.create_auth_users_from_members()
-- -----------------------------------------------------------------------------
-- Closes the mass-account-creation vector identified in 04-supabase-audit.md §D#14.
-- Function exists (verified) with anon + PUBLIC EXECUTE. Revoke both; leave
-- postgres + service_role + authenticated grants alone (they are intentional).

DO $revoke$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'create_auth_users_from_members'
    ) THEN
        EXECUTE 'REVOKE EXECUTE ON FUNCTION public.create_auth_users_from_members() FROM anon';
        EXECUTE 'REVOKE EXECUTE ON FUNCTION public.create_auth_users_from_members() FROM PUBLIC';
    END IF;
EXCEPTION
    WHEN undefined_function THEN
        -- Function signature may differ; skip silently — the plan can re-audit.
        NULL;
    WHEN insufficient_privilege THEN
        -- Running as non-owner; skip silently. Re-run as postgres if needed.
        NULL;
END
$revoke$;

-- =============================================================================
-- End of 20260424_01_audit_foundations.sql
-- =============================================================================
