-- Restore read access to the FEC amendment-guard table for signed-in CRM users.
-- Refs FLUTTER-2 (the 403 pair on get_fec_spending_by_purpose /
-- get_fec_recent_expenditures, 22 of that catch-all group's 79 events in 30d).
--
-- MECHANISM, verified by impersonation against the running system rather than by
-- reading definitions. Both RPCs are SECURITY INVOKER, so their bodies run as the
-- caller. They are the only two of the nine get_fec_* functions that reference
-- public.fec_superseded_filings, and as `authenticated` both raise
--   42501 :: permission denied for table fec_superseded_filings
-- while get_fec_top_donors and get_fec_finance_summary, which do not touch it,
-- return OK. PostgREST renders 42501 as HTTP 403, which is what the CRM's
-- Finances tab was filing to Sentry.
--
-- THIS IS DRIFT, NOT A DELIBERATE CLOSURE, which is why restoring it does not run
-- against the standing prohibition on granting permissions away to clear a log
-- line. The table's own creating migration,
-- supabase/migrations_manual/20260722_fec_accuracy.sql, already carries
--   GRANT SELECT ON public.fec_superseded_filings TO anon, authenticated, service_role;
-- and the live ACL carries neither anon nor authenticated. The later
-- 20260723_tighten_new_table_grants.sql revoked only INSERT/UPDATE/TRIGGER/
-- REFERENCES from anon on this table and never touched SELECT. So the committed
-- design says authenticated reads this table and production disagrees.
--
-- Scoped deliberately to `authenticated` and NOT to `anon`, which is a considered
-- divergence from that committed line: the CRM is exec-only, no anonymous caller
-- reaches these RPCs, and granting a role that has no consumer would fight the
-- anon-surface cleanup done on 2026-08-07. service_role already holds the grant.
GRANT SELECT ON public.fec_superseded_filings TO authenticated;

-- The grant alone is NOT sufficient and shipping it alone would be worse than the
-- 403. RLS is enabled on this table with zero policies, so `authenticated` would
-- read zero of its 6 rows, every NOT EXISTS guard in the two RPCs would match
-- nothing, and superseded (amended) filings would be silently counted back into
-- candidate spending totals. A wrong number reported confidently beats a visible
-- error, so the row-visibility half is the load-bearing half.
--
-- USING (true) matches the sibling pattern this table's neighbours already use,
-- e.g. fec_expenditures_read. The content is public FEC filing metadata,
-- (cmte_id, file_num) of superseded filings, with no PII, and is strictly less
-- sensitive than fec_expenditures, which anon can already read.
DROP POLICY IF EXISTS fec_superseded_filings_read ON public.fec_superseded_filings;
CREATE POLICY fec_superseded_filings_read
  ON public.fec_superseded_filings
  FOR SELECT
  TO authenticated
  USING (true);
