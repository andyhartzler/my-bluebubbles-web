-- MOYD Supabase Policy Cleanup — Draft D2 from supabase/perf-2026-07-21.md
-- Applied 2026-07-22 (postgres role, direct connection). Approved: Andrew (perf work greenlit).
--
-- Goal: remove redundant permissive RLS policies that force extra per-row OR
-- evaluation. Every DROP below is verified to leave access coverage unchanged:
-- each dropped policy is a permissive policy whose grant is fully subsumed by a
-- surviving permissive policy on the same table (permissive policies are OR'd).
--
-- Rollback: migrations_manual/20260722_policy_cleanup_ROLLBACK.sql
--
-- ============================================================================
-- Part 1: members_staff_read  (ALREADY APPLIED earlier on 2026-07-21)
-- ============================================================================
-- members_staff_read (SELECT / authenticated / USING is_staff()) is fully
-- redundant with members_staff_write, which is cmd ALL / authenticated /
-- USING is_staff() / WITH CHECK is_staff() — an ALL policy covers SELECT.
-- Verified equivalent from pg_policy. This DROP was already executed as part of
-- the 2026-07-21 status-update batch; members_staff_read no longer exists in
-- pg_policies, so it is documented here (not re-executed) for completeness.
--
--   DROP POLICY IF EXISTS members_staff_read ON public.members;
--
-- ============================================================================
-- Part 2: Legacy service_role ALL policies duplicated by rls_phase2_service_role_all
-- ============================================================================
-- Each table below carries rls_phase2_service_role_all
-- (ALL / service_role / USING true / WITH CHECK true, permissive) AND a legacy
-- hand-authored service_role ALL policy with identical effective coverage
-- (USING true; WITH CHECK true, or NULL which for an ALL policy defers to the
-- USING true expression). Dropping the legacy copy cannot reduce service_role
-- access because the phase2 policy already grants ALL/true/true. Roles on every
-- dropped policy are {service_role} only — no authenticated grant is touched.
--
-- donor_enrichment's legacy "Allow service role all" was already dropped in the
-- 2026-07-21 status-update batch and is intentionally omitted here.

DROP POLICY IF EXISTS "Service role full access" ON public.bank_transactions;
DROP POLICY IF EXISTS "Service role full access" ON public.campaign_recipients;
DROP POLICY IF EXISTS "Service role full access" ON public.mec_reports;
DROP POLICY IF EXISTS "Service role full access to attendance" ON public.meeting_attendance;
DROP POLICY IF EXISTS "Service role full access" ON public.member_email_history;
DROP POLICY IF EXISTS "Service role full access to meeting minutes" ON public.member_portal_meetings;
DROP POLICY IF EXISTS "Service role full access" ON public.plaid_connections;
DROP POLICY IF EXISTS "Service role full access" ON public.slack_analytics_cache;
