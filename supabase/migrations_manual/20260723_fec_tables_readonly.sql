-- APPLIED 2026-07-23 (Andrew approved). Audit: anon/authenticated SELECT-only
-- verified via REST + role simulation; all 9 get_fec_* RPCs green as
-- authenticated; service_role writes intact; daily sync connects as postgres
-- (unaffected); legacy fec-scraper/scraper.py switched anon->service key.
--
-- Flagged by automated security review 2026-07-23: fec_expenditures and
-- fec_contributions carry FOR ALL USING(true) policies and grant
-- INSERT/UPDATE to anon, so the public anon key can write to both research
-- mirrors. Public FEC data, so integrity risk only, but the sync pipeline
-- writes as service_role and needs none of this.
--
-- Apply with: psql "$DB" -f 20260723_fec_tables_readonly_DRAFT.sql

BEGIN;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.fec_expenditures, public.fec_contributions FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.fec_expenditures, public.fec_contributions FROM authenticated;

DROP POLICY IF EXISTS fec_expenditures_read ON public.fec_expenditures;
CREATE POLICY fec_expenditures_read
  ON public.fec_expenditures FOR SELECT
  TO anon, authenticated USING (true);

DROP POLICY IF EXISTS fec_contributions_read ON public.fec_contributions;
CREATE POLICY fec_contributions_read
  ON public.fec_contributions FOR SELECT
  TO anon, authenticated USING (true);

-- service_role bypasses RLS; the daily 06:45 sync is unaffected.

COMMIT;

-- ROLLBACK (restore prior state):
-- GRANT INSERT, UPDATE, REFERENCES, TRIGGER
--   ON public.fec_expenditures, public.fec_contributions TO anon;
-- GRANT INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
--   ON public.fec_expenditures, public.fec_contributions TO authenticated;
-- then recreate the FOR ALL USING(true) policies named *_read.
