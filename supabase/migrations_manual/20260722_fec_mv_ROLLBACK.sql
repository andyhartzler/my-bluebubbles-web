-- =====================================================================
-- ROLLBACK for 20260722_fec_mv.sql
-- Restores the original live-scan FEC RPCs and drops the new MVs + cron.
-- =====================================================================

-- Unschedule the FEC MV refresh cron jobs (no-op if already absent).
SELECT cron.unschedule('refresh-fec-committee-finance-summary')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname='refresh-fec-committee-finance-summary');
SELECT cron.unschedule('refresh-fec-committee-donor-aggregate')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname='refresh-fec-committee-donor-aggregate');

-- Restore original get_fec_finance_summary (live scan of fec_contributions).
CREATE OR REPLACE FUNCTION public.get_fec_finance_summary(p_fec_cand_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_raised', COALESCE(SUM(fc.transaction_amount), 0),
    'contribution_count', COUNT(*),
    'avg_contribution', CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(fc.transaction_amount),0) / COUNT(*) ELSE 0 END,
    'unique_donors', COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name)),
    'individual_contribs', COUNT(*) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false)),
    'pac_contribs', COUNT(*) FILTER (WHERE COALESCE(fc.is_pac_contribution,false)),
    'individual_total', COALESCE(SUM(fc.transaction_amount) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false)), 0),
    'pac_total', COALESCE(SUM(fc.transaction_amount) FILTER (WHERE COALESCE(fc.is_pac_contribution,false)), 0),
    'first_contribution', MIN(fc.transaction_date),
    'last_contribution', MAX(fc.transaction_date),
    'cycles_active', COUNT(DISTINCT fc.cycle),
    'committees_count', COUNT(DISTINCT fc.cmte_id)
  )
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id);
$function$;

-- Restore original get_fec_top_donors (live scan of fec_contributions).
CREATE OR REPLACE FUNCTION public.get_fec_top_donors(p_fec_cand_id text, p_limit integer DEFAULT 10)
 RETURNS TABLE(donor_name text, city text, state text, employer text, occupation text, total_amount numeric, contribution_count integer, donor_id bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name) AS donor_name,
    MAX(fc.city) AS city, MAX(fc.state) AS state,
    MAX(fc.employer) AS employer, MAX(fc.occupation) AS occupation,
    SUM(fc.transaction_amount)::numeric AS total_amount,
    COUNT(*)::int AS contribution_count,
    MAX(fc.donor_id) AS donor_id
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
    AND NOT COALESCE(fc.is_pac_contribution, false)
  GROUP BY COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name)
  ORDER BY total_amount DESC
  LIMIT p_limit;
$function$;

-- Drop the materialized views (and their indexes).
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_donor_aggregate CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_finance_summary CASCADE;
