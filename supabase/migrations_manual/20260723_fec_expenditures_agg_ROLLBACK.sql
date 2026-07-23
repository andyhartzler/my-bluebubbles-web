-- ============================================================================
-- 20260723_fec_expenditures_agg_ROLLBACK.sql
-- Reverses 20260723_fec_expenditures_agg.sql. Drops the spending MV, the three
-- spending RPCs, and the pg_cron refresh job. Leaves public.fec_expenditures
-- and all pre-existing FEC infra untouched.
-- ============================================================================

SELECT cron.unschedule('refresh-fec-committee-payee-aggregate');

DROP FUNCTION IF EXISTS public.get_fec_recent_expenditures(text, integer, integer);
DROP FUNCTION IF EXISTS public.get_fec_spending_by_purpose(text, integer);
DROP FUNCTION IF EXISTS public.get_fec_top_payees(text, integer, integer);

DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_payee_aggregate CASCADE;
