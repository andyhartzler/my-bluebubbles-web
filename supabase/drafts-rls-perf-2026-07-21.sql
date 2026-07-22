-- DRAFT ONLY - RLS performance remediation. DO NOT APPLY without Andrew's approval.
-- Root cause (MEASURED): bare is_staff()/auth.uid() in a policy qual is evaluated
-- PER ROW (shows as `Filter: is_staff()` on the scan). Wrapping in a scalar
-- subquery `(SELECT is_staff())` makes the planner hoist it to a One-Time
-- Filter / InitPlan evaluated ONCE per statement (proven: loops=1, 0.4ms).
-- subscribers count(*): 28ms (no RLS) -> 1077ms (bare) -> ~30ms expected (wrapped).

-- ============ WORST 5 (ranked by hot-screen impact) ============

-- 1. subscribers (73,123 rows) - subscribers screen fetchStats() fires ~7 full scans
ALTER POLICY subscribers_staff_read  ON public.subscribers USING ((SELECT is_staff()));
ALTER POLICY subscribers_staff_write ON public.subscribers USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));

-- 2. mec_contributions (3,207,035 rows) - ilike last-name search seq-scans w/ per-row is_staff()
ALTER POLICY rls_phase2_staff_all ON public.mec_contributions USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));

-- 3. candidates (2,870 rows) - candidates screen + dashboard count tiles
ALTER POLICY rls_phase2_staff_all ON public.candidates USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));

-- 4. members (419 rows) - login path; also collapse redundant double is_staff()
--    members_staff_write is ALL (already covers SELECT), so members_staff_read is redundant.
DROP POLICY members_staff_read ON public.members;
ALTER POLICY members_staff_write ON public.members USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));
ALTER POLICY members_self_read ON public.members USING (
  ((user_id = (SELECT auth.uid()))
   OR (email = ((SELECT auth.jwt()) ->> 'email'))
   OR (school_email = ((SELECT auth.jwt()) ->> 'email'))));
ALTER POLICY members_self_update ON public.members
  USING ((user_id = (SELECT auth.uid()))) WITH CHECK ((user_id = (SELECT auth.uid())));

-- 5. donor_enrichment (431,220 rows) - drop duplicate service_role policy + wrap staff
DROP POLICY "Allow service role all" ON public.donor_enrichment;  -- dup of rls_phase2_service_role_all
ALTER POLICY rls_phase2_staff_all ON public.donor_enrichment USING ((SELECT is_staff())) WITH CHECK ((SELECT is_staff()));

-- ============ SYSTEMIC (103 quals + 94 with_check bare is_staff(); 64 bare auth.uid()) ============
-- Every table carrying `rls_phase2_staff_all` uses bare is_staff() incl.
-- donor_contacts (9.8M), mec_donors (1M), mec_expenditures (706K), mautic_sync_log (259K).
-- A single generated migration should wrap is_staff()/current_user_is_superadmin()/
-- is_executive()/auth.uid()/auth.jwt() in (SELECT ...) across ALL public policies.
-- Semantically identical (same boolean), only changes evaluation frequency = SAFE.
