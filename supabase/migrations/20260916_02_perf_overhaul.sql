-- =====================================================================
-- 20260916_02_perf_overhaul.sql
-- Database half of the 2026-09-16 performance overhaul, TRANSACTION-SAFE
-- part. Project ref: faajpcarasilbfndzkmd  Postgres 17.6
-- =====================================================================
--
-- This file is applied by ~/moyd-ops/dbrunner, which wraps the whole file
-- in one explicit transaction. Everything here is therefore restricted to
-- statements that are legal inside a transaction block.
--
-- The other half of this overhaul lives in
--   supabase/migrations_manual/20260916_02_perf_overhaul_concurrent.sql
-- and MUST be applied separately with psql in autocommit. It holds the
-- VACUUM FULL and every CONCURRENTLY index statement, none of which can
-- run inside a transaction. Apply this file FIRST, then that one.
--
-- WHAT THIS FILE DOES
--   2. Consolidates duplicate permissive RLS policies on the hot CRM read
--      paths so each (role, command) evaluates public.is_staff() once
--      instead of two or more times.
--   6. Moves FEC materialized-view refreshes out of business hours,
--      shortens mautic_sync_log retention, removes 2 inactive cron rows.
--   7.1 Drops 3 completed scratch tables.
--   7.2 Adds a primary key to the 493k-row dedup table.
--   7.4 Refreshes planner statistics.
--
-- LOCK SAFETY
--   lock_timeout is set to 3s before the two sections that take
--   ACCESS EXCLUSIVE locks on live CRM tables. Without it, a policy swap
--   that queues behind an in-flight query blocks every later reader on
--   that table for the duration. With it, the migration fails fast and is
--   simply re-run, which is the correct trade against locking the CRM.
--   lock_timeout is deliberately NOT set around index builds; there are
--   none in this file.
--
-- Every statement is idempotent. Re-running the file is safe.
-- Run as the `postgres` role.
-- EXPECTED RUNTIME: under 30 seconds.
--
-- ROLLBACK
--   Section 2: each consolidated policy carries the definitions of the
--     policies it replaced in the comment above it; recreate those and
--     drop the consolidated one.
--   Section 6: the prior cron schedules are named in each comment.
--   Section 7.1: NOT REVERSIBLE (the scratch tables are dropped).
--   Section 7.2: ALTER TABLE public.mec_donor_dedup_candidates
--                  DROP CONSTRAINT mec_donor_dedup_candidates_pkey;
-- =====================================================================

-- Fail fast rather than queue behind a long read and block the CRM.
SET lock_timeout = '3s';

-- =====================================================================
-- SECTION 2: RLS policy consolidation on hot CRM read paths
-- =====================================================================
-- public.is_staff() and public.is_executive() are STABLE SECURITY DEFINER
-- functions that each run
--   SELECT COALESCE((SELECT m.executive_committee FROM public.members m
--                     WHERE m.user_id = auth.uid() LIMIT 1), false)
-- Every distinct permissive policy that references one of them produces
-- its own InitPlan, so a table carrying two such policies for the same
-- (role, command) evaluates the members lookup twice per query. That is
-- the source of 182,833,261 scans of idx_members_user_id against a
-- 447-row table over 147 days.
--
-- Postgres combines permissive policies for a command by OR-ing all USING
-- expressions together and OR-ing all WITH CHECK expressions together, so
-- folding N permissive policies into one policy whose qual is the OR of
-- the N quals is exactly equivalent. That is what this section does.
--
-- Ordering rule used throughout: the new policies are CREATEd first and
-- the ones they replace are DROPped afterwards, so there is never an
-- instant where a caller loses access. While both sets exist the effective
-- permission is unchanged, because the old policies are subsets of the new.
--
-- is_staff() is placed first in each OR so the cheap common case for exec
-- users short-circuits the more expensive EXISTS arms.

-- ---------------------------------------------------------------------
-- 2.1  public.members
-- ---------------------------------------------------------------------
-- REPLACES (exact current definitions):
--   members_staff_write  FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
--   members_self_read    FOR SELECT TO authenticated
--     USING ((user_id = ( SELECT auth.uid() AS uid))
--            OR (email = (( SELECT auth.jwt() AS jwt) ->> 'email'::text))
--            OR (school_email = (( SELECT auth.jwt() AS jwt) ->> 'email'::text)))
--   members_self_update  FOR UPDATE TO authenticated
--     USING      ((user_id = ( SELECT auth.uid() AS uid)))
--     WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)))
-- members_service_role (FOR ALL TO service_role USING true) is untouched.
-- The BEFORE trigger that stops a member making themselves an exec is
-- untouched and still governs which columns a self-update may change.
-- The (select ...) initplan wrapping is preserved exactly.

-- SELECT: one policy instead of two (staff arm plus the three self arms).
DROP POLICY IF EXISTS members_select ON public.members;
CREATE POLICY members_select ON public.members
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR (user_id = (SELECT auth.uid()))
    OR (email = ((SELECT auth.jwt()) ->> 'email'::text))
    OR (school_email = ((SELECT auth.jwt()) ->> 'email'::text))
  );

-- UPDATE: one policy instead of two. USING and WITH CHECK are each the OR
-- of the two originals, which is what Postgres already computed.
DROP POLICY IF EXISTS members_update ON public.members;
CREATE POLICY members_update ON public.members
  FOR UPDATE TO authenticated
  USING      ((SELECT public.is_staff()) OR (user_id = (SELECT auth.uid())))
  WITH CHECK ((SELECT public.is_staff()) OR (user_id = (SELECT auth.uid())));

-- INSERT and DELETE were staff-only under members_staff_write; unchanged.
DROP POLICY IF EXISTS members_staff_insert ON public.members;
CREATE POLICY members_staff_insert ON public.members
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS members_staff_delete ON public.members;
CREATE POLICY members_staff_delete ON public.members
  FOR DELETE TO authenticated
  USING ((SELECT public.is_staff()));

-- Now retire the originals. Effective permission set is identical.
DROP POLICY IF EXISTS members_staff_write ON public.members;
DROP POLICY IF EXISTS members_self_read ON public.members;
DROP POLICY IF EXISTS members_self_update ON public.members;

-- ---------------------------------------------------------------------
-- 2.2  public.events
-- ---------------------------------------------------------------------
-- REPLACES (exact current definition):
--   events_staff_write  FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
-- KEPT UNCHANGED:
--   events_authenticated_read  FOR SELECT TO authenticated USING (true)
--   events_public_read         FOR SELECT TO anon, authenticated
--                              USING ((status = 'published'::text))
--   events_service_role        FOR ALL TO service_role USING (true)
-- Rule A: an existing read policy is already USING (true) for the same
-- role, and true OR is_staff() is true, so narrowing the FOR ALL policy to
-- the three write commands removes an is_staff() InitPlan from every
-- authenticated SELECT and changes nothing else. The anon arm lives in
-- events_public_read and is not touched.
DROP POLICY IF EXISTS events_staff_insert ON public.events;
CREATE POLICY events_staff_insert ON public.events
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS events_staff_update ON public.events;
CREATE POLICY events_staff_update ON public.events
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS events_staff_delete ON public.events;
CREATE POLICY events_staff_delete ON public.events
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS events_staff_write ON public.events;

-- ---------------------------------------------------------------------
-- 2.3  public.committees
-- ---------------------------------------------------------------------
-- REPLACES:
--   committees_staff_write  FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
-- KEPT UNCHANGED:
--   committees_authenticated_read  FOR SELECT TO authenticated USING (true)
--   committees_service_role        FOR ALL TO service_role USING (true)
-- Rule A again. The committees dashboard reads this table 7 times per open,
-- so removing an is_staff() InitPlan per read is worth having.
DROP POLICY IF EXISTS committees_staff_insert ON public.committees;
CREATE POLICY committees_staff_insert ON public.committees
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS committees_staff_update ON public.committees;
CREATE POLICY committees_staff_update ON public.committees
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS committees_staff_delete ON public.committees;
CREATE POLICY committees_staff_delete ON public.committees
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS committees_staff_write ON public.committees;

-- ---------------------------------------------------------------------
-- 2.4  public.subscribers
-- ---------------------------------------------------------------------
-- REPLACES:
--   subscribers_staff_write  FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
-- KEPT UNCHANGED:
--   subscribers_staff_read      FOR SELECT TO authenticated
--                               USING ( SELECT is_staff() AS is_staff)
--   subscribers_public_insert   FOR INSERT TO anon, authenticated
--     WITH CHECK ((email IS NOT NULL) AND (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'))
--   subscribers_service_role    FOR ALL TO service_role USING (true)
-- Both SELECT policies were literally is_staff(), so the read arm was
-- evaluating the members lookup twice for every subscribers page. Effective
-- SELECT stays exactly is_staff(). The anon insert arm is untouched.
DROP POLICY IF EXISTS subscribers_staff_insert ON public.subscribers;
CREATE POLICY subscribers_staff_insert ON public.subscribers
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS subscribers_staff_update ON public.subscribers;
CREATE POLICY subscribers_staff_update ON public.subscribers
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS subscribers_staff_delete ON public.subscribers;
CREATE POLICY subscribers_staff_delete ON public.subscribers
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS subscribers_staff_write ON public.subscribers;

-- ---------------------------------------------------------------------
-- 2.5  public.form_submissions
-- ---------------------------------------------------------------------
-- REPLACES:
--   form_submissions_staff_write  FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
--   form_submissions_staff_read   FOR SELECT TO authenticated
--     USING ( SELECT is_staff() AS is_staff)
--   form_submissions_self_read    FOR SELECT TO authenticated
--     USING ((member_id = ( SELECT members.id FROM members
--                            WHERE (members.user_id = ( SELECT auth.uid() AS uid)))))
-- KEPT UNCHANGED:
--   form_submissions_public_insert_active  FOR INSERT TO anon, authenticated
--   form_submissions_service_role          FOR ALL TO service_role
-- Three permissive SELECT policies became one; is_staff() went from two
-- InitPlans per read to one. The self-read scalar subquery is preserved
-- verbatim, including its single-row expectation.
DROP POLICY IF EXISTS form_submissions_select ON public.form_submissions;
CREATE POLICY form_submissions_select ON public.form_submissions
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR (member_id = (SELECT m.id FROM public.members m
                      WHERE m.user_id = (SELECT auth.uid())))
  );

DROP POLICY IF EXISTS form_submissions_staff_insert ON public.form_submissions;
CREATE POLICY form_submissions_staff_insert ON public.form_submissions
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS form_submissions_staff_update ON public.form_submissions;
CREATE POLICY form_submissions_staff_update ON public.form_submissions
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS form_submissions_staff_delete ON public.form_submissions;
CREATE POLICY form_submissions_staff_delete ON public.form_submissions
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS form_submissions_staff_write ON public.form_submissions;
DROP POLICY IF EXISTS form_submissions_staff_read ON public.form_submissions;
DROP POLICY IF EXISTS form_submissions_self_read ON public.form_submissions;

-- ---------------------------------------------------------------------
-- 2.6  public.meetings
-- ---------------------------------------------------------------------
-- REPLACES:
--   rls_phase2_staff_all    FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
--   meetings_self_attended  FOR SELECT TO authenticated
--     USING ((EXISTS ( SELECT 1 FROM (meeting_attendance ma
--               JOIN members m ON ((m.id = ma.member_id)))
--              WHERE ((ma.meeting_id = meetings.id)
--                     AND (m.user_id = ( SELECT auth.uid() AS uid)))))
--            OR (EXISTS ( SELECT 1 FROM members m
--              WHERE ((m.id = meetings.meeting_host)
--                     AND (m.user_id = ( SELECT auth.uid() AS uid))))))
-- KEPT UNCHANGED:
--   rls_phase2_service_role_all  FOR ALL TO service_role USING (true)
-- Putting is_staff() first means an exec never runs the two EXISTS joins.
DROP POLICY IF EXISTS meetings_select ON public.meetings;
CREATE POLICY meetings_select ON public.meetings
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR EXISTS (
      SELECT 1 FROM public.meeting_attendance ma
        JOIN public.members m ON m.id = ma.member_id
       WHERE ma.meeting_id = meetings.id
         AND m.user_id = (SELECT auth.uid())
    )
    OR EXISTS (
      SELECT 1 FROM public.members m
       WHERE m.id = meetings.meeting_host
         AND m.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS meetings_staff_insert ON public.meetings;
CREATE POLICY meetings_staff_insert ON public.meetings
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS meetings_staff_update ON public.meetings;
CREATE POLICY meetings_staff_update ON public.meetings
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS meetings_staff_delete ON public.meetings;
CREATE POLICY meetings_staff_delete ON public.meetings
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS rls_phase2_staff_all ON public.meetings;
DROP POLICY IF EXISTS meetings_self_attended ON public.meetings;

-- ---------------------------------------------------------------------
-- 2.7  public.meeting_attendance
-- ---------------------------------------------------------------------
-- REPLACES:
--   rls_phase2_staff_all            FOR ALL TO authenticated
--     USING / WITH CHECK ( SELECT is_staff() AS is_staff)
--   meeting_attendance_self_select  FOR SELECT TO authenticated
--     USING ((EXISTS ( SELECT 1 FROM members m
--              WHERE ((m.id = meeting_attendance.member_id)
--                     AND (m.user_id = ( SELECT auth.uid() AS uid))))))
-- KEPT UNCHANGED: rls_phase2_service_role_all FOR ALL TO service_role.
DROP POLICY IF EXISTS meeting_attendance_select ON public.meeting_attendance;
CREATE POLICY meeting_attendance_select ON public.meeting_attendance
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR EXISTS (
      SELECT 1 FROM public.members m
       WHERE m.id = meeting_attendance.member_id
         AND m.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS meeting_attendance_staff_insert ON public.meeting_attendance;
CREATE POLICY meeting_attendance_staff_insert ON public.meeting_attendance
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS meeting_attendance_staff_update ON public.meeting_attendance;
CREATE POLICY meeting_attendance_staff_update ON public.meeting_attendance
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS meeting_attendance_staff_delete ON public.meeting_attendance;
CREATE POLICY meeting_attendance_staff_delete ON public.meeting_attendance
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS rls_phase2_staff_all ON public.meeting_attendance;
DROP POLICY IF EXISTS meeting_attendance_self_select ON public.meeting_attendance;

-- ---------------------------------------------------------------------
-- 2.8  public.meeting_invitees
-- ---------------------------------------------------------------------
-- REPLACES:
--   rls_phase2_staff_all          FOR ALL TO authenticated
--     USING / WITH CHECK ( SELECT is_staff() AS is_staff)
--   meeting_invitees_self_select  FOR SELECT TO authenticated
--     USING ((EXISTS ( SELECT 1 FROM members m
--              WHERE ((m.id = meeting_invitees.member_id)
--                     AND (m.user_id = ( SELECT auth.uid() AS uid))))))
-- KEPT UNCHANGED: rls_phase2_service_role_all FOR ALL TO service_role.
DROP POLICY IF EXISTS meeting_invitees_select ON public.meeting_invitees;
CREATE POLICY meeting_invitees_select ON public.meeting_invitees
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR EXISTS (
      SELECT 1 FROM public.members m
       WHERE m.id = meeting_invitees.member_id
         AND m.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS meeting_invitees_staff_insert ON public.meeting_invitees;
CREATE POLICY meeting_invitees_staff_insert ON public.meeting_invitees
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS meeting_invitees_staff_update ON public.meeting_invitees;
CREATE POLICY meeting_invitees_staff_update ON public.meeting_invitees
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS meeting_invitees_staff_delete ON public.meeting_invitees;
CREATE POLICY meeting_invitees_staff_delete ON public.meeting_invitees
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS rls_phase2_staff_all ON public.meeting_invitees;
DROP POLICY IF EXISTS meeting_invitees_self_select ON public.meeting_invitees;

-- ---------------------------------------------------------------------
-- 2.9  public.scheduled_meetings
-- ---------------------------------------------------------------------
-- REPLACES:
--   rls_phase2_staff_all             FOR ALL TO authenticated
--     USING / WITH CHECK ( SELECT is_staff() AS is_staff)
--   scheduled_meetings_self_invited  FOR SELECT TO authenticated
--     USING (((created_by = ( SELECT auth.uid() AS uid))
--             OR (EXISTS ( SELECT 1 FROM (meeting_invitees mi
--                   JOIN members m ON ((m.id = mi.member_id)))
--                  WHERE ((mi.meeting_id = scheduled_meetings.id)
--                         AND (m.user_id = ( SELECT auth.uid() AS uid)))))))
-- KEPT UNCHANGED: rls_phase2_service_role_all FOR ALL TO service_role.
DROP POLICY IF EXISTS scheduled_meetings_select ON public.scheduled_meetings;
CREATE POLICY scheduled_meetings_select ON public.scheduled_meetings
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR (created_by = (SELECT auth.uid()))
    OR EXISTS (
      SELECT 1 FROM public.meeting_invitees mi
        JOIN public.members m ON m.id = mi.member_id
       WHERE mi.meeting_id = scheduled_meetings.id
         AND m.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS scheduled_meetings_staff_insert ON public.scheduled_meetings;
CREATE POLICY scheduled_meetings_staff_insert ON public.scheduled_meetings
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS scheduled_meetings_staff_update ON public.scheduled_meetings;
CREATE POLICY scheduled_meetings_staff_update ON public.scheduled_meetings
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS scheduled_meetings_staff_delete ON public.scheduled_meetings;
CREATE POLICY scheduled_meetings_staff_delete ON public.scheduled_meetings
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS rls_phase2_staff_all ON public.scheduled_meetings;
DROP POLICY IF EXISTS scheduled_meetings_self_invited ON public.scheduled_meetings;

-- ---------------------------------------------------------------------
-- 2.10  public.endorsement_votes
-- ---------------------------------------------------------------------
-- REPLACES:
--   endorsement_votes_own_write  FOR ALL TO authenticated
--     USING      ((is_executive() AND (voter_id = ( SELECT auth.uid() AS uid))))
--     WITH CHECK ((is_executive() AND (voter_id = ( SELECT auth.uid() AS uid))))
-- KEPT UNCHANGED:
--   endorsement_votes_exec_read  FOR SELECT TO authenticated
--     USING ( SELECT is_executive() AS is_executive)
--   endorsement_votes_service    FOR ALL TO service_role USING (true)
-- Effective SELECT was is_executive() OR (is_executive() AND own row),
-- which is just is_executive(), so dropping the redundant SELECT arm
-- changes nothing and removes a second is_executive() InitPlan from the
-- ballot list read. The write quals are reproduced exactly, with the bare
-- is_executive() call now wrapped in (select ...) so it is evaluated once
-- per statement rather than once per row. Same result, STABLE function.
DROP POLICY IF EXISTS endorsement_votes_own_insert ON public.endorsement_votes;
CREATE POLICY endorsement_votes_own_insert ON public.endorsement_votes
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.is_executive()) AND (voter_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS endorsement_votes_own_update ON public.endorsement_votes;
CREATE POLICY endorsement_votes_own_update ON public.endorsement_votes
  FOR UPDATE TO authenticated
  USING      ((SELECT public.is_executive()) AND (voter_id = (SELECT auth.uid())))
  WITH CHECK ((SELECT public.is_executive()) AND (voter_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS endorsement_votes_own_delete ON public.endorsement_votes;
CREATE POLICY endorsement_votes_own_delete ON public.endorsement_votes
  FOR DELETE TO authenticated
  USING ((SELECT public.is_executive()) AND (voter_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS endorsement_votes_own_write ON public.endorsement_votes;

-- ---------------------------------------------------------------------
-- 2.11  public.jobs
-- ---------------------------------------------------------------------
-- REPLACES (four permissive SELECT policies for authenticated became one):
--   "Anyone can view approved jobs"  FOR SELECT TO anon, authenticated
--     USING (((status = 'approved'::text)
--             AND ((expires_at IS NULL) OR (expires_at > now()))))
--   "Public can view approved jobs"  FOR SELECT TO anon, authenticated
--     USING (((status = 'approved'::text)
--             AND ((expires_at IS NULL) OR (expires_at > now()))))
--     [byte-for-byte identical to the previous one]
--   "Job posters can view own jobs"  FOR SELECT TO authenticated
--     USING ((submitter_email = ( SELECT auth.email() AS email)))
--   rls_phase3_jobs_staff_all        FOR ALL TO authenticated
--     USING      ( SELECT is_staff() AS is_staff)
--     WITH CHECK ( SELECT is_staff() AS is_staff)
-- KEPT UNCHANGED:
--   "Anyone can create jobs"            FOR INSERT TO public
--     WITH CHECK ((status = 'pending'::text))
--   "Job posters can update own jobs"   FOR UPDATE TO public
--   "Users can update their submissions" FOR UPDATE TO authenticated
--   "Service role full access"          FOR ALL TO service_role
-- Staff must keep SELECT on pending and rejected jobs for the jobs admin
-- screen, so the is_staff() arm is folded into the new SELECT policy
-- rather than dropped. The anon half of the approved-jobs read is
-- preserved as its own anon-only policy so the public jobs board is
-- unaffected.
DROP POLICY IF EXISTS jobs_select_authenticated ON public.jobs;
CREATE POLICY jobs_select_authenticated ON public.jobs
  FOR SELECT TO authenticated
  USING (
    (SELECT public.is_staff())
    OR ((status = 'approved'::text) AND ((expires_at IS NULL) OR (expires_at > now())))
    OR (submitter_email = (SELECT auth.email()))
  );

DROP POLICY IF EXISTS jobs_select_anon ON public.jobs;
CREATE POLICY jobs_select_anon ON public.jobs
  FOR SELECT TO anon
  USING ((status = 'approved'::text) AND ((expires_at IS NULL) OR (expires_at > now())));

DROP POLICY IF EXISTS jobs_staff_insert ON public.jobs;
CREATE POLICY jobs_staff_insert ON public.jobs
  FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS jobs_staff_update ON public.jobs;
CREATE POLICY jobs_staff_update ON public.jobs
  FOR UPDATE TO authenticated
  USING ((SELECT public.is_staff())) WITH CHECK ((SELECT public.is_staff()));

DROP POLICY IF EXISTS jobs_staff_delete ON public.jobs;
CREATE POLICY jobs_staff_delete ON public.jobs
  FOR DELETE TO authenticated USING ((SELECT public.is_staff()));

DROP POLICY IF EXISTS "Anyone can view approved jobs" ON public.jobs;
DROP POLICY IF EXISTS "Public can view approved jobs" ON public.jobs;
DROP POLICY IF EXISTS "Job posters can view own jobs" ON public.jobs;
DROP POLICY IF EXISTS rls_phase3_jobs_staff_all ON public.jobs;

-- ---------------------------------------------------------------------
-- 2.12  public.candidate_score_components
-- ---------------------------------------------------------------------
-- REPLACES:
--   csc_exec_write  FOR ALL TO authenticated
--     USING / WITH CHECK
--       ((EXISTS ( SELECT 1 FROM members m
--          WHERE ((m.id = ( SELECT auth.uid() AS uid))
--                 AND (m.executive_committee = true))))
--        OR ( SELECT current_user_is_superadmin() AS current_user_is_superadmin))
--   csc_select  FOR SELECT TO authenticated USING (true)
--     [byte-for-byte identical to csc_authenticated_read]
-- KEPT UNCHANGED, DELIBERATELY NOT MERGED:
--   csc_authenticated_read  FOR SELECT TO authenticated USING (true)
--   csc_insert / csc_update / csc_delete  ( SELECT is_executive() )
--   csc_service_role        FOR ALL TO service_role USING (true)
-- csc_exec_write tests m.id = auth.uid() while csc_insert/update/delete
-- test m.user_id = auth.uid() through is_executive(). Those are different
-- columns and not equivalent, so the write policies are NOT merged. All
-- that changes here is that csc_exec_write stops contributing a SELECT
-- arm, which was redundant against USING (true) and was running an EXISTS
-- against members for every score component read, and the byte-identical
-- duplicate read policy is removed.
DROP POLICY IF EXISTS csc_exec_insert ON public.candidate_score_components;
CREATE POLICY csc_exec_insert ON public.candidate_score_components
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.members m
             WHERE m.id = (SELECT auth.uid()) AND m.executive_committee = true)
    OR (SELECT public.current_user_is_superadmin())
  );

DROP POLICY IF EXISTS csc_exec_update ON public.candidate_score_components;
CREATE POLICY csc_exec_update ON public.candidate_score_components
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.members m
             WHERE m.id = (SELECT auth.uid()) AND m.executive_committee = true)
    OR (SELECT public.current_user_is_superadmin())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.members m
             WHERE m.id = (SELECT auth.uid()) AND m.executive_committee = true)
    OR (SELECT public.current_user_is_superadmin())
  );

DROP POLICY IF EXISTS csc_exec_delete ON public.candidate_score_components;
CREATE POLICY csc_exec_delete ON public.candidate_score_components
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.members m
             WHERE m.id = (SELECT auth.uid()) AND m.executive_committee = true)
    OR (SELECT public.current_user_is_superadmin())
  );

DROP POLICY IF EXISTS csc_exec_write ON public.candidate_score_components;
DROP POLICY IF EXISTS csc_select ON public.candidate_score_components;

-- ---------------------------------------------------------------------
-- 2.13  public.form_analytics and public.form_field_analytics
-- ---------------------------------------------------------------------
-- Pure duplicate removal. No policy is rewritten, so the effective
-- permission set cannot move.
--   "Service role full access to X" is byte-identical to
--   "Service role full access on X" (FOR ALL TO service_role USING true).
--   "Anon can insert X" (TO anon, WITH CHECK true) is a strict subset of
--   "Anyone can insert (field) analytics" (TO anon, authenticated, true).
--   "Form creators can view (field) analytics" runs
--     EXISTS (SELECT 1 FROM form_schemas WHERE id = ... AND created_by = auth.uid())
--   for every row, but "Authenticated can view X" is already USING (true)
--   for the same role, so that EXISTS can never change the outcome.
DROP POLICY IF EXISTS "Service role full access to form_analytics" ON public.form_analytics;
DROP POLICY IF EXISTS "Anon can insert form_analytics" ON public.form_analytics;
DROP POLICY IF EXISTS "Form creators can view analytics" ON public.form_analytics;

DROP POLICY IF EXISTS "Service role full access to form_field_analytics" ON public.form_field_analytics;
DROP POLICY IF EXISTS "Anon can insert form_field_analytics" ON public.form_field_analytics;
DROP POLICY IF EXISTS "Form creators can view field analytics" ON public.form_field_analytics;

-- ---------------------------------------------------------------------
-- 2.14  legislation history tables: exact duplicate policies
-- ---------------------------------------------------------------------
-- Each table carries two byte-identical service_role FOR ALL USING (true)
-- policies and two byte-identical authenticated FOR SELECT USING (true)
-- policies. The descriptively named one is kept in each pair.
DROP POLICY IF EXISTS "Service role full access" ON public.legislation_ai_analysis_history;
DROP POLICY IF EXISTS "Users can view AI analysis history" ON public.legislation_ai_analysis_history;

DROP POLICY IF EXISTS "Service role full access" ON public.legislation_talking_points_history;
DROP POLICY IF EXISTS "Users can view talking points history" ON public.legislation_talking_points_history;


-- =====================================================================
-- SECTION 6: cron cadence
-- =====================================================================
-- All six materialized-view refreshes are pg_cron jobs owned by the
-- postgres role, so cron.alter_job works from this migration. Each block
-- looks the job up by name rather than by jobid so it stays correct if
-- ids shift, and does nothing if the job is absent.
-- COST: catalog updates only, no locks on user tables.

-- 6.1  Move the FEC refresh second slot out of business hours.
--   jobid 96 refresh-fec-committee-finance-summary  was '20 8,20 * * *'
--   jobid 97 refresh-fec-committee-donor-aggregate  was '25 8,20 * * *'
--   jobid 98 refresh-fec-committee-payee-aggregate  was '30 8,20 * * *'
-- 20:20 to 20:30 UTC is 15:20 to 15:30 Central, inside the working day,
-- and costs about 41 s of REFRESH CONCURRENTLY. CONCURRENTLY does not
-- block readers, so the problem is buffer-pool and CPU contention: with
-- 512 MB of shared_buffers and max_parallel_workers = 2, a refresh that
-- reads hundreds of thousands of rows evicts the cache the CRM was using.
-- Moving the second slot to 02:xx UTC (21:xx Central the previous evening)
-- is behaviourally neutral; the views still refresh twice a day.
DO $cron_fec$
DECLARE
  j record;
BEGIN
  FOR j IN
    SELECT jobid, jobname,
           CASE jobname
             WHEN 'refresh-fec-committee-finance-summary' THEN '20 8,2 * * *'
             WHEN 'refresh-fec-committee-donor-aggregate' THEN '25 8,2 * * *'
             WHEN 'refresh-fec-committee-payee-aggregate' THEN '30 8,2 * * *'
           END AS new_schedule
    FROM cron.job
    WHERE jobname IN ('refresh-fec-committee-finance-summary',
                      'refresh-fec-committee-donor-aggregate',
                      'refresh-fec-committee-payee-aggregate')
  LOOP
    PERFORM cron.alter_job(job_id := j.jobid, schedule := j.new_schedule);
    RAISE NOTICE 'cron % rescheduled to %', j.jobname, j.new_schedule;
  END LOOP;
END
$cron_fec$;

-- 6.2  Leave refresh-mec-committee-donor-aggregate on its DAILY schedule.
--   jobid 90 refresh-mec-committee-donor-aggregate, schedule '0 8 * * *'
-- This section originally downgraded the job to weekly on the grounds that
-- "nothing in lib/ reads this view by name; access is through RPCs".
-- That sentence is true and misleading, and the downgrade is withdrawn.
-- public.mec_committee_donor_aggregate IS read, by get_mec_top_donors and
-- get_mec_top_donors_multi (confirmed in pg_proc.prosrc), and both are
-- called from the live CRM at lib/services/crm/candidate_repository.dart
-- lines 1420 and 1491. Going weekly would have put up to 7-day-old donor
-- figures in the candidate finance panel with nothing on screen saying so.
--
-- The cost being avoided is 91.3 s of refresh, once a day, at 08:00 UTC,
-- which is 03:00 Central and outside all CRM traffic. Section 6.1 already
-- moved the refreshes that did overlap business hours. Buying a 91 s
-- off-hours saving with silently stale finance data is a bad trade, so
-- this job is deliberately left alone.
--
-- If this refresh ever needs to go weekly, the honest version ships a
-- "data as of <date>" label on the candidate finance top-donor panel in
-- the same change. Do not downgrade it without that label.


-- 6.3  Shorten mautic_sync_log retention from 180 days to 30.
--   jobid 109 prune-mautic-sync-log-weekly, schedule '10 4 * * 0',
--   command was: SELECT public.fn_prune_mautic_sync_log(180);
-- The table is 439 MB for 90,071 rows, 325 MB of it TOAST, because it
-- keeps full request and response jsonb bodies. At 30 days it lands around
-- 75 MB. Combined with the section 1 reclaim that frees roughly 690 MB of
-- pages competing for a 512 MB buffer pool.
-- BEHAVIOUR NOTE: Mautic sync history older than 30 days is destroyed on
-- the next Sunday run. Confirm nothing audits sync beyond a month.
DO $cron_prune$
DECLARE
  v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job
   WHERE jobname = 'prune-mautic-sync-log-weekly';
  IF FOUND THEN
    PERFORM cron.alter_job(job_id := v_jobid,
                           command := 'SELECT public.fn_prune_mautic_sync_log(30);');
    RAISE NOTICE 'cron prune-mautic-sync-log-weekly now keeps 30 days';
  END IF;
END
$cron_prune$;

-- 6.4  Remove two inactive cron rows that show up in every audit.
--   jobid 46 analyze-bills-batch-check          active = false
--   jobid 71 extract-large-bill-text-chunked    active = false
-- Both are already disabled, so this changes no behaviour. jobid 71 is an
-- inactive duplicate of the live jobid 68 extract-large-bill-text-simple,
-- which stays exactly as it is.
DO $cron_cleanup$
DECLARE
  n text;
BEGIN
  FOREACH n IN ARRAY ARRAY['analyze-bills-batch-check',
                           'extract-large-bill-text-chunked']
  LOOP
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = n AND active = false) THEN
      PERFORM cron.unschedule(n);
      RAISE NOTICE 'cron job % unscheduled (was inactive)', n;
    ELSIF EXISTS (SELECT 1 FROM cron.job WHERE jobname = n) THEN
      RAISE WARNING 'cron job % is ACTIVE; not unscheduling it', n;
    END IF;
  END LOOP;
END
$cron_cleanup$;


-- =====================================================================
-- SECTION 7: remaining items the investigation ranked as real
-- =====================================================================

-- 7.1  Drop the three completed scratch tables from the 2026-07-22 MEC
--      link repair. 568 kB total, zero CRM read path, and they appear in
--      every advisor run as no-primary-key noise.
--      COST: ACCESS EXCLUSIVE on each, instant, 417 / 9 / 6 rows.
--      NOT REVERSIBLE. The MEC link audit completed on 2026-07-22.
DROP TABLE IF EXISTS public.tmp_mec_link_audit_20260722;
DROP TABLE IF EXISTS public.tmp_mec_link_apply_20260722;
DROP TABLE IF EXISTS public.tmp_fec_amendment_dedup_20260722;

-- 7.2  Give public.mec_donor_dedup_candidates a primary key.
--      493,004 rows, 77 MB, 611,320,040 tuples read by sequential scan and
--      no primary key at all. Verified on 2026-09-16 that the existing
--      bigint `id` column is non-null and distinct across all 493,004 rows,
--      so it is a valid key with no data change needed.
--      Without a replica identity, logical replication and Supabase
--      Realtime cannot stream UPDATE or DELETE on this table, and that
--      fails at write time rather than at configuration time.
--      COST: ADD PRIMARY KEY takes ACCESS EXCLUSIVE on the table while it
--      scans 77 MB, sets id NOT NULL and builds the unique index. Expect
--      1 to 3 s. This table is offline dedup output with no CRM traffic,
--      so a short exclusive lock on it is not user visible.
--      The build is done in one statement rather than
--      CREATE UNIQUE INDEX CONCURRENTLY plus ADD CONSTRAINT USING INDEX,
--      because USING INDEX renames the index to the constraint name and a
--      re-run of this file would then build a second, duplicate index.
--      The guard below keeps the whole step idempotent.
DO $dedup_pk$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid = 'public.mec_donor_dedup_candidates'::regclass
       AND contype = 'p'
  ) THEN
    ALTER TABLE public.mec_donor_dedup_candidates
      ADD CONSTRAINT mec_donor_dedup_candidates_pkey PRIMARY KEY (id);
    RAISE NOTICE 'mec_donor_dedup_candidates primary key added';
  ELSE
    RAISE NOTICE 'mec_donor_dedup_candidates already has a primary key';
  END IF;
END
$dedup_pk$;


-- 7.4  Refresh planner statistics on the tables whose index set changed,
--      so the planner immediately picks the surviving index rather than
--      running on stale counts.
--      COST: ANALYZE takes SHARE UPDATE EXCLUSIVE only and samples rows;
--      seconds per table.
ANALYZE public.members;
ANALYZE public.donor_enrichment;
ANALYZE public.donor_contacts;
ANALYZE public.mec_contributions;
ANALYZE public.mec_donors;
ANALYZE public.mec_committees;
ANALYZE public.subscribers;
ANALYZE public.translations;
ANALYZE public.legislation_tracked_bills;
ANALYZE public.legislation_bill_sponsors;
ANALYZE public.candidates;
ANALYZE public.candidate_score_components;
ANALYZE public.mautic_sync_log;
ANALYZE public.calendar_events;


-- lock_timeout is session scoped and ends with this transaction, but reset
-- it explicitly so the value cannot leak into anything the runner does next.
RESET lock_timeout;

-- =====================================================================
-- END OF TRANSACTION-SAFE HALF
-- Now apply supabase/migrations_manual/20260916_02_perf_overhaul_concurrent.sql
-- =====================================================================
