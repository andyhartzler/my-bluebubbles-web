-- ============================================================================
-- 20260722_fec_accuracy_ROLLBACK.sql
-- Restores the MV + 5 FEC RPCs to their exact definitions captured immediately
-- before 20260722_fec_accuracy.sql (via pg_get_viewdef / pg_get_functiondef).
--
-- NOTE: the trailing default params added by the forward migration mean the new
-- functions and these originals differ ONLY in signature length; CREATE OR
-- REPLACE cannot drop a parameter, so we DROP the added overloads first.
-- ============================================================================

BEGIN;

-- Drop the widened signatures introduced by the forward migration.
DROP FUNCTION IF EXISTS public.get_fec_finance_summary(text, integer);
DROP FUNCTION IF EXISTS public.get_fec_top_donors(text, integer, integer);
DROP FUNCTION IF EXISTS public.get_fec_contribution_timeline(text, integer);
DROP FUNCTION IF EXISTS public.get_fec_recent_contributions(text, integer, integer);
DROP FUNCTION IF EXISTS public.get_fec_committees_for_candidate(text, integer);

-- ----------------------------------------------------------------------------
-- MV: original naive-sum definition + unique index + grants
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_finance_summary;

CREATE MATERIALIZED VIEW public.fec_committee_finance_summary AS
 SELECT cmte_id,
    cycle,
    sum(transaction_amount) AS total_raised,
    count(*) AS contribution_count,
    count(*) FILTER (WHERE NOT COALESCE(is_pac_contribution, false)) AS individual_count,
    count(*) FILTER (WHERE COALESCE(is_pac_contribution, false)) AS pac_count,
    COALESCE(sum(transaction_amount) FILTER (WHERE NOT COALESCE(is_pac_contribution, false)), 0::numeric) AS individual_total,
    COALESCE(sum(transaction_amount) FILTER (WHERE COALESCE(is_pac_contribution, false)), 0::numeric) AS pac_total,
    min(transaction_date) AS first_contribution,
    max(transaction_date) AS last_contribution,
    count(DISTINCT COALESCE(donor_id::text, contributor_name)) AS unique_donors
   FROM fec_contributions fc
  GROUP BY cmte_id, cycle;

CREATE UNIQUE INDEX fec_committee_finance_summary_pk
  ON public.fec_committee_finance_summary USING btree (cmte_id, cycle);

GRANT SELECT ON public.fec_committee_finance_summary TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- get_fec_finance_summary (original, single-arg)
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- get_fec_top_donors (original)
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- get_fec_recent_contributions (original)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_recent_contributions(p_fec_cand_id text, p_limit integer DEFAULT 50)
 RETURNS TABLE(contributor_name text, city text, state text, transaction_amount numeric, transaction_date date, employer text, occupation text, is_pac_contribution boolean, committee_name text, cycle smallint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT fc.contributor_name, fc.city, fc.state, fc.transaction_amount, fc.transaction_date,
    fc.employer, fc.occupation, COALESCE(fc.is_pac_contribution,false), fc.committee_name, fc.cycle
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
  ORDER BY fc.transaction_date DESC NULLS LAST
  LIMIT p_limit;
$function$;

-- ----------------------------------------------------------------------------
-- get_fec_contribution_timeline (original)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_contribution_timeline(p_fec_cand_id text)
 RETURNS TABLE(month_year text, total numeric, contribution_count integer)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    to_char(date_trunc('month', fc.transaction_date), 'YYYY-MM') AS month_year,
    SUM(fc.transaction_amount)::numeric AS total,
    COUNT(*)::int AS contribution_count
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
    AND fc.transaction_date IS NOT NULL
  GROUP BY date_trunc('month', fc.transaction_date)
  ORDER BY date_trunc('month', fc.transaction_date);
$function$;

-- ----------------------------------------------------------------------------
-- get_fec_committees_for_candidate (original)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_committees_for_candidate(p_fec_cand_id text)
 RETURNS TABLE(cmte_id text, cmte_name text, cmte_type text, designation text, party text, cycle smallint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT DISTINCT cmte_id, cmte_name, cmte_type, designation, party, cycle
  FROM public.fec_committees WHERE cand_id = p_fec_cand_id
  ORDER BY cycle DESC, cmte_id;
$function$;

COMMIT;

REFRESH MATERIALIZED VIEW public.fec_committee_finance_summary;
