-- 2026-07-23: Tighten anon access on tables created this week (security review finding).
-- Anon retains read-only; writes stay with authenticated (where policies allow),
-- service_role (bypasses RLS), and postgres (sync pipeline).
-- NOTE: pre-existing fec_contributions/fec_candidates/fec_committees (and MEC bucket)
-- share the same permissive pattern; tightening those is DRAFTED (see
-- drafts/20260723_tighten_legacy_fec_mec_grants_DRAFT.sql) pending Andrew sign-off.

BEGIN;

REVOKE INSERT, UPDATE, TRIGGER, REFERENCES ON public.fec_expenditures,
  public.fec_committee_totals, public.fec_filings, public.fec_superseded_filings,
  public.money_profiles, public.money_profile_queue FROM anon;

DROP POLICY IF EXISTS fec_expenditures_read ON public.fec_expenditures;
CREATE POLICY fec_expenditures_read ON public.fec_expenditures FOR SELECT USING (true);
DROP POLICY IF EXISTS fec_committee_totals_read ON public.fec_committee_totals;
CREATE POLICY fec_committee_totals_read ON public.fec_committee_totals FOR SELECT USING (true);
DROP POLICY IF EXISTS fec_filings_read ON public.fec_filings;
CREATE POLICY fec_filings_read ON public.fec_filings FOR SELECT USING (true);

-- writes for the app/service paths (service_role bypasses RLS; postgres owns the tables)
DROP POLICY IF EXISTS fec_expenditures_service_write ON public.fec_expenditures;
CREATE POLICY fec_expenditures_service_write ON public.fec_expenditures FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS fec_committee_totals_service_write ON public.fec_committee_totals;
CREATE POLICY fec_committee_totals_service_write ON public.fec_committee_totals FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS fec_filings_service_write ON public.fec_filings;
CREATE POLICY fec_filings_service_write ON public.fec_filings FOR ALL TO service_role USING (true) WITH CHECK (true);

COMMIT;

-- ROLLBACK: re-grant with
--   GRANT INSERT, UPDATE, TRIGGER, REFERENCES ON <tables> TO anon;
--   and recreate each <table>_read policy FOR ALL USING (true) WITH CHECK (true).
