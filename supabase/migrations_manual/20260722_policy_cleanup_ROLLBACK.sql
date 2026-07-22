-- ROLLBACK for 20260722_policy_cleanup.sql — recreates every dropped policy
-- with its exact pre-drop definition (captured from pg_policy 2026-07-22).
--
-- ============================================================================
-- Part 1: members_staff_read  (recreate — was dropped 2026-07-21)
-- ============================================================================
-- Included for completeness; only run if you also want to reverse the
-- 2026-07-21 status-update drop. Original definition: SELECT / authenticated /
-- USING is_staff(). (InitPlan-wrapped form to match current convention.)
--
--   CREATE POLICY members_staff_read ON public.members
--     FOR SELECT TO authenticated
--     USING ((SELECT is_staff()));
--
-- ============================================================================
-- Part 2: Legacy service_role ALL policies
-- ============================================================================

CREATE POLICY "Service role full access" ON public.bank_transactions
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.campaign_recipients
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.mec_reports
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- meeting_attendance: original had no WITH CHECK (NULL -> defers to USING).
CREATE POLICY "Service role full access to attendance" ON public.meeting_attendance
  FOR ALL TO service_role USING (true);

CREATE POLICY "Service role full access" ON public.member_email_history
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- member_portal_meetings: original had no WITH CHECK (NULL -> defers to USING).
CREATE POLICY "Service role full access to meeting minutes" ON public.member_portal_meetings
  FOR ALL TO service_role USING (true);

CREATE POLICY "Service role full access" ON public.plaid_connections
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access" ON public.slack_analytics_cache
  FOR ALL TO service_role USING (true) WITH CHECK (true);
