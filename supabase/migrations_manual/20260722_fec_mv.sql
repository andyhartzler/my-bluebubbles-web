-- =====================================================================
-- 20260722_fec_mv.sql
-- FEC money surfaces: materialize aggregates to stop live-scanning
-- public.fec_contributions (~1.76M rows, growing with the 2026 load).
--
-- Mirrors the MEC pattern (public.mec_committee_finance_summary +
-- public.mec_committee_donor_aggregate).  Two materialized views:
--
--   1. public.fec_committee_finance_summary  -- grain: (cmte_id, cycle)
--        additive money/count aggregates for get_fec_finance_summary.
--
--   2. public.fec_committee_donor_aggregate   -- grain: one row per
--        (cmte_id, donor_id, contributor_name, parsed_last_name,
--         parsed_first_name).  Serves BOTH the exact per-candidate
--        unique-donor count (finance summary) AND get_fec_top_donors.
--        A per-(cmte,cycle) MV cannot reconstruct COUNT(DISTINCT donor)
--        across a candidate's committees/cycles (distinct is not
--        additive), so the donor grain is required for exactness.
--
-- RPCs rewritten (identical signatures, verified byte-identical output
-- for S6MO00305, S2MO00528, S8MO00160):
--   * get_fec_finance_summary(text)  -> reads MV1 (additive) + MV2 (unique_donors)
--   * get_fec_top_donors(text,int)   -> reads MV2
--
-- Left LIVE on purpose:
--   * get_fec_recent_contributions  -- ORDER BY transaction_date only is
--       tie-nondeterministic; a (cmte_id,date) index only helps a LATERAL
--       rewrite, which would change the observable tie order. Not worth a
--       semantics change. ~150ms, bounded by committee size not table size.
--   * get_fec_contribution_timeline -- full per-month group aggregate; no
--       index avoids the scan and the (cmte,cycle) MV has no month grain.
--       ~165ms, bounded by committee size.
--
-- Refresh: pg_cron, 2x daily, offset from the MEC MV refreshes
--          (08:00 / 08:05 / 08:10 UTC).  See bottom of file.
-- =====================================================================

-- ---------------------------------------------------------------------
-- MV 1: per-(cmte_id, cycle) finance summary
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_finance_summary CASCADE;

CREATE MATERIALIZED VIEW public.fec_committee_finance_summary AS
SELECT
  fc.cmte_id,
  fc.cycle,
  SUM(fc.transaction_amount)                                                    AS total_raised,
  COUNT(*)                                                                      AS contribution_count,
  COUNT(*) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))            AS individual_count,
  COUNT(*) FILTER (WHERE COALESCE(fc.is_pac_contribution,false))                AS pac_count,
  COALESCE(SUM(fc.transaction_amount) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false)),0) AS individual_total,
  COALESCE(SUM(fc.transaction_amount) FILTER (WHERE COALESCE(fc.is_pac_contribution,false)),0)     AS pac_total,
  MIN(fc.transaction_date)                                                      AS first_contribution,
  MAX(fc.transaction_date)                                                      AS last_contribution,
  COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name))              AS unique_donors
FROM public.fec_contributions fc
GROUP BY fc.cmte_id, fc.cycle
WITH DATA;

-- Unique index REQUIRED for REFRESH MATERIALIZED VIEW CONCURRENTLY.
CREATE UNIQUE INDEX fec_committee_finance_summary_pk
  ON public.fec_committee_finance_summary (cmte_id, cycle);

ANALYZE public.fec_committee_finance_summary;

-- ---------------------------------------------------------------------
-- MV 2: per-(cmte_id, donor) aggregate
--   * total_all / count_all  : ALL contributions (feeds unique_donors)
--   * indiv_total/indiv_count: FILTER NOT pac (feeds get_fec_top_donors,
--                              whose original applies NOT-pac BEFORE grouping)
--   * max_*                  : MAX over NOT-pac rows (matches original MAX())
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_donor_aggregate CASCADE;

CREATE MATERIALIZED VIEW public.fec_committee_donor_aggregate AS
SELECT
  fc.cmte_id,
  fc.donor_id,
  fc.contributor_name,
  fc.parsed_last_name,
  fc.parsed_first_name,
  COALESCE(SUM(fc.transaction_amount),0)                                              AS total_all,
  COUNT(*)                                                                            AS count_all,
  COALESCE(SUM(fc.transaction_amount) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false)),0) AS indiv_total,
  COUNT(*) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))                  AS indiv_count,
  MAX(fc.city)       FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))        AS max_city,
  MAX(fc.state)      FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))        AS max_state,
  MAX(fc.employer)   FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))        AS max_employer,
  MAX(fc.occupation) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))        AS max_occupation,
  MAX(fc.donor_id)   FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false))        AS max_donor_id
FROM public.fec_contributions fc
GROUP BY fc.cmte_id, fc.donor_id, fc.contributor_name, fc.parsed_last_name, fc.parsed_first_name
WITH DATA;

-- Unique index for CONCURRENTLY refresh. Key columns are nullable, so
-- NULLS NOT DISTINCT (PG15+) guarantees a single row per null-combination.
CREATE UNIQUE INDEX fec_committee_donor_aggregate_pk
  ON public.fec_committee_donor_aggregate
     (cmte_id, donor_id, contributor_name, parsed_last_name, parsed_first_name)
  NULLS NOT DISTINCT;

-- Supports get_fec_top_donors (ORDER BY indiv_total DESC per committee).
CREATE INDEX fec_committee_donor_aggregate_cmte_total_idx
  ON public.fec_committee_donor_aggregate (cmte_id, indiv_total DESC);

ANALYZE public.fec_committee_donor_aggregate;

-- ---------------------------------------------------------------------
-- RPC rewrite: get_fec_finance_summary
--   additive fields  <- MV1 summed over the candidate's committees
--   cycles_active    <- COUNT(DISTINCT cycle)  over MV1 rows (exact)
--   committees_count <- COUNT(DISTINCT cmte_id) over MV1 rows (exact)
--   unique_donors    <- COUNT(DISTINCT donor key) over MV2 rows (exact)
--   JSON key order preserved to match the original output exactly.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_finance_summary(p_fec_cand_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  WITH cmtes AS (
    SELECT DISTINCT cmte_id
    FROM public.fec_committees
    WHERE cand_id = p_fec_cand_id
  ),
  agg AS (
    SELECT
      COALESCE(SUM(s.total_raised), 0)        AS total_raised,
      COALESCE(SUM(s.contribution_count), 0)  AS contribution_count,
      COALESCE(SUM(s.individual_count), 0)    AS individual_contribs,
      COALESCE(SUM(s.pac_count), 0)           AS pac_contribs,
      COALESCE(SUM(s.individual_total), 0)    AS individual_total,
      COALESCE(SUM(s.pac_total), 0)           AS pac_total,
      MIN(s.first_contribution)               AS first_contribution,
      MAX(s.last_contribution)                AS last_contribution,
      COUNT(DISTINCT s.cycle)                 AS cycles_active,
      COUNT(DISTINCT s.cmte_id)               AS committees_count
    FROM public.fec_committee_finance_summary s
    WHERE s.cmte_id IN (SELECT cmte_id FROM cmtes)
  ),
  ud AS (
    SELECT COUNT(DISTINCT COALESCE(d.donor_id::text, d.contributor_name)) AS unique_donors
    FROM public.fec_committee_donor_aggregate d
    WHERE d.cmte_id IN (SELECT cmte_id FROM cmtes)
  )
  SELECT json_build_object(
    'total_raised',        a.total_raised,
    'contribution_count',  a.contribution_count,
    'avg_contribution',    CASE WHEN a.contribution_count > 0
                                THEN a.total_raised / a.contribution_count ELSE 0 END,
    'unique_donors',       u.unique_donors,
    'individual_contribs', a.individual_contribs,
    'pac_contribs',        a.pac_contribs,
    'individual_total',    a.individual_total,
    'pac_total',           a.pac_total,
    'first_contribution',  a.first_contribution,
    'last_contribution',   a.last_contribution,
    'cycles_active',       a.cycles_active,
    'committees_count',    a.committees_count
  )
  FROM agg a, ud u;
$function$;

-- ---------------------------------------------------------------------
-- RPC rewrite: get_fec_top_donors
--   Group MV2 rows by the original donor_name expression across the
--   candidate's committees.  HAVING SUM(indiv_count) > 0 reproduces the
--   original's NOT-pac row filter (donors with only PAC money are absent).
--   ORDER BY total_amount DESC (no tie-break) matches the original; ties
--   are nondeterministic in both. Output verified set-identical.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_top_donors(p_fec_cand_id text, p_limit integer DEFAULT 10)
 RETURNS TABLE(donor_name text, city text, state text, employer text, occupation text, total_amount numeric, contribution_count integer, donor_id bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    COALESCE(d.contributor_name, d.parsed_last_name || ', ' || d.parsed_first_name) AS donor_name,
    MAX(d.max_city)       AS city,
    MAX(d.max_state)      AS state,
    MAX(d.max_employer)   AS employer,
    MAX(d.max_occupation) AS occupation,
    SUM(d.indiv_total)::numeric AS total_amount,
    SUM(d.indiv_count)::int     AS contribution_count,
    MAX(d.max_donor_id)   AS donor_id
  FROM public.fec_committee_donor_aggregate d
  WHERE d.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
  GROUP BY COALESCE(d.contributor_name, d.parsed_last_name || ', ' || d.parsed_first_name)
  HAVING SUM(d.indiv_count) > 0
  ORDER BY total_amount DESC
  LIMIT p_limit;
$function$;

-- ---------------------------------------------------------------------
-- Refresh scheduling (pg_cron).
-- MEC MVs already refresh staggered at 08:00 / 08:05 / 08:10 UTC
-- (jobs refresh-mec-committee-{donor-aggregate,payee-aggregate,finance-summary}).
-- Add the two FEC MVs 2x daily, offset from the MEC window:
--   08:20 & 20:20 UTC -> finance summary
--   08:25 & 20:25 UTC -> donor aggregate
-- ---------------------------------------------------------------------
SELECT cron.schedule(
  'refresh-fec-committee-finance-summary',
  '20 8,20 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.fec_committee_finance_summary$$
);
SELECT cron.schedule(
  'refresh-fec-committee-donor-aggregate',
  '25 8,20 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.fec_committee_donor_aggregate$$
);
