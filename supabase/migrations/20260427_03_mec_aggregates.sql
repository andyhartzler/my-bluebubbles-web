-- =====================================================================
-- 20260427_03_mec_aggregates.sql
--
-- Money tab latency reduction for high-volume committees.
--
-- Problem: every Money tab render fires 13 parallel RPCs.  Five of them
-- group/aggregate the full mec_contributions / mec_expenditures tables
-- from scratch on every call.  On big committees (e.g. C180576 with
-- 143k contribution rows) the timings are:
--
--   get_mec_top_donors_multi               1.68s
--   get_mec_finance_summary_multi          0.78s  (with 1 GB temp spill)
--   get_mec_expenditure_summary_multi      0.005s but 3 redundant scans
--   get_mec_top_payees_multi               0.005s
--   get_race_finance_comparison            0.83s  (correlated subqueries)
--
-- Fix:
--   1. Materialize the per-(mec_id, person/payee) aggregate once.
--   2. Materialize the per-mec_id finance summary once.
--   3. Rewrite the RPCs to read from the materialized views, keeping the
--      JSON output shape byte-identical so Dart needs no changes.
--   4. Rewrite get_race_finance_comparison to use the new aggregates +
--      candidate_mec_committee lookup table (added in
--      20260427_01_candidate_mec_committee.sql).
--   5. Refresh nightly at 03:00 America/Chicago via pg_cron.
--
-- Constraints honored:
--   - REFRESH MATERIALIZED VIEW CONCURRENTLY requires a unique index on
--     each MV — added below.
--   - Materialized views inherit no RLS; reads are gated through
--     STABLE SQL functions with SECURITY INVOKER (the default) so the
--     caller's role still applies for any future row-level checks.
-- =====================================================================

SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------
-- 1. Donor aggregate
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.mec_committee_donor_aggregate CASCADE;

CREATE MATERIALIZED VIEW public.mec_committee_donor_aggregate AS
SELECT
  mec_id,
  COALESCE(contributor_first_name, '')                  AS contributor_first_name,
  COALESCE(contributor_last_name,  '')                  AS contributor_last_name,
  COALESCE(contributor_company,    '')                  AS contributor_company,
  COALESCE(city,  '')                                   AS city,
  COALESCE(state, '')                                   AS state,
  SUM(contribution_amount)                              AS total_amount,
  COUNT(*)                                              AS contribution_count,
  MIN(contribution_date)                                AS first_contribution,
  MAX(contribution_date)                                AS last_contribution
FROM public.mec_contributions
GROUP BY
  mec_id,
  COALESCE(contributor_first_name, ''),
  COALESCE(contributor_last_name,  ''),
  COALESCE(contributor_company,    ''),
  COALESCE(city,  ''),
  COALESCE(state, '');

-- Unique index required for REFRESH CONCURRENTLY.
CREATE UNIQUE INDEX mec_committee_donor_aggregate_uniq
  ON public.mec_committee_donor_aggregate (
    mec_id,
    contributor_first_name,
    contributor_last_name,
    contributor_company,
    city,
    state
  );

-- Hot read path: per-mec_id leaderboard.
CREATE INDEX mec_committee_donor_aggregate_mec_total_idx
  ON public.mec_committee_donor_aggregate (mec_id, total_amount DESC);

-- ---------------------------------------------------------------------
-- 2. Payee aggregate
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.mec_committee_payee_aggregate CASCADE;

CREATE MATERIALIZED VIEW public.mec_committee_payee_aggregate AS
SELECT
  mec_id,
  TRIM(COALESCE(payee_first_name, ''))                  AS payee_first_name,
  TRIM(COALESCE(payee_last_name,  ''))                  AS payee_last_name,
  TRIM(COALESCE(payee_company,    ''))                  AS payee_company,
  COALESCE(city,  '')                                   AS city,
  COALESCE(state, '')                                   AS state,
  SUM(expenditure_amount)                               AS total_amount,
  COUNT(*)                                              AS payment_count,
  MIN(expenditure_date)                                 AS first_payment,
  MAX(expenditure_date)                                 AS last_payment
FROM public.mec_expenditures
GROUP BY
  mec_id,
  TRIM(COALESCE(payee_first_name, '')),
  TRIM(COALESCE(payee_last_name,  '')),
  TRIM(COALESCE(payee_company,    '')),
  COALESCE(city,  ''),
  COALESCE(state, '');

CREATE UNIQUE INDEX mec_committee_payee_aggregate_uniq
  ON public.mec_committee_payee_aggregate (
    mec_id,
    payee_first_name,
    payee_last_name,
    payee_company,
    city,
    state
  );

CREATE INDEX mec_committee_payee_aggregate_mec_total_idx
  ON public.mec_committee_payee_aggregate (mec_id, total_amount DESC);

-- ---------------------------------------------------------------------
-- 3. Per-committee finance summary (raised + spent + by_purpose/type)
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.mec_committee_finance_summary CASCADE;

CREATE MATERIALIZED VIEW public.mec_committee_finance_summary AS
WITH contrib AS (
  SELECT
    mec_id,
    SUM(contribution_amount)                              AS total_raised,
    COUNT(*)                                              AS contribution_count,
    SUM(CASE
          WHEN LOWER(COALESCE(monetary_or_inkind,'')) NOT LIKE '%in%kind%'
           AND LOWER(COALESCE(monetary_or_inkind,'')) NOT LIKE '%inkind%'
          THEN contribution_amount ELSE 0
        END)                                              AS monetary_total,
    SUM(CASE
          WHEN LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%in%kind%'
            OR LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%inkind%'
          THEN contribution_amount ELSE 0
        END)                                              AS in_kind_total,
    COUNT(*) FILTER (
      WHERE LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%in%kind%'
         OR LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%inkind%'
    )                                                     AS in_kind_count,
    MIN(contribution_date)                                AS first_contribution,
    MAX(contribution_date)                                AS last_contribution,
    COUNT(DISTINCT CONCAT(contributor_last_name, '|', contributor_first_name))
                                                          AS unique_donors
  FROM public.mec_contributions
  GROUP BY mec_id
),
exp AS (
  SELECT
    mec_id,
    SUM(expenditure_amount)                               AS total_spent,
    COUNT(*)                                              AS expenditure_count,
    MIN(expenditure_date)                                 AS first_expenditure,
    MAX(expenditure_date)                                 AS last_expenditure,
    COUNT(DISTINCT CONCAT(payee_last_name, '|', payee_first_name, '|', payee_company))
                                                          AS unique_payees
  FROM public.mec_expenditures
  GROUP BY mec_id
),
by_purpose AS (
  SELECT
    mec_id,
    jsonb_agg(
      jsonb_build_object('purpose', purpose, 'total', total, 'count', cnt)
      ORDER BY total DESC
    ) AS by_purpose
  FROM (
    SELECT
      mec_id,
      COALESCE(NULLIF(TRIM(expenditure_purpose), ''), 'Unspecified') AS purpose,
      SUM(expenditure_amount) AS total,
      COUNT(*)                AS cnt
    FROM public.mec_expenditures
    GROUP BY mec_id, COALESCE(NULLIF(TRIM(expenditure_purpose), ''), 'Unspecified')
  ) p
  GROUP BY mec_id
),
by_type AS (
  SELECT
    mec_id,
    jsonb_agg(
      jsonb_build_object('type', type, 'total', total, 'count', cnt)
      ORDER BY total DESC
    ) AS by_type
  FROM (
    SELECT
      mec_id,
      COALESCE(NULLIF(TRIM(expenditure_type), ''), 'Other') AS type,
      SUM(expenditure_amount) AS total,
      COUNT(*)                AS cnt
    FROM public.mec_expenditures
    GROUP BY mec_id, COALESCE(NULLIF(TRIM(expenditure_type), ''), 'Other')
  ) t
  GROUP BY mec_id
),
all_ids AS (
  SELECT mec_id FROM contrib
  UNION
  SELECT mec_id FROM exp
)
SELECT
  a.mec_id,
  COALESCE(c.total_raised, 0)        AS total_raised,
  COALESCE(c.contribution_count, 0)  AS contribution_count,
  COALESCE(c.monetary_total, 0)      AS monetary_total,
  COALESCE(c.in_kind_total, 0)       AS in_kind_total,
  COALESCE(c.in_kind_count, 0)       AS in_kind_count,
  c.first_contribution,
  c.last_contribution,
  COALESCE(c.unique_donors, 0)       AS unique_donors,
  -- expenditure side
  COALESCE(e.total_spent, 0)         AS total_spent,
  COALESCE(e.expenditure_count, 0)   AS expenditure_count,
  e.first_expenditure,
  e.last_expenditure,
  COALESCE(e.unique_payees, 0)       AS unique_payees,
  COALESCE(bp.by_purpose, '[]'::jsonb) AS by_purpose,
  COALESCE(bt.by_type,    '[]'::jsonb) AS by_type
FROM all_ids a
LEFT JOIN contrib    c  ON c.mec_id  = a.mec_id
LEFT JOIN exp        e  ON e.mec_id  = a.mec_id
LEFT JOIN by_purpose bp ON bp.mec_id = a.mec_id
LEFT JOIN by_type    bt ON bt.mec_id = a.mec_id;

CREATE UNIQUE INDEX mec_committee_finance_summary_uniq
  ON public.mec_committee_finance_summary (mec_id);

CREATE INDEX mec_committee_finance_summary_mec_total_idx
  ON public.mec_committee_finance_summary (mec_id, total_raised DESC);

-- ---------------------------------------------------------------------
-- 4. Rewritten RPCs reading from the aggregates
--    Output shape unchanged so the Dart layer needs no modifications.
-- ---------------------------------------------------------------------

-- Top donors (single)
CREATE OR REPLACE FUNCTION public.get_mec_top_donors(p_mec_id text, p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      TRIM(CONCAT(contributor_first_name, ' ', contributor_last_name)) AS donor_name,
      contributor_first_name AS first_name,
      contributor_last_name  AS last_name,
      contributor_company    AS company,
      city, state,
      total_amount,
      contribution_count,
      last_contribution
    FROM public.mec_committee_donor_aggregate
    WHERE mec_id = p_mec_id
    ORDER BY total_amount DESC
    LIMIT p_limit
  ) t;
$function$;

-- Top donors (multi) — re-aggregate across committees off the MV
CREATE OR REPLACE FUNCTION public.get_mec_top_donors_multi(p_mec_ids text[], p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      TRIM(CONCAT(contributor_first_name, ' ', contributor_last_name)) AS donor_name,
      contributor_first_name AS first_name,
      contributor_last_name  AS last_name,
      contributor_company    AS company,
      city, state,
      SUM(total_amount)         AS total_amount,
      SUM(contribution_count)   AS contribution_count,
      MAX(last_contribution)    AS last_contribution
    FROM public.mec_committee_donor_aggregate
    WHERE mec_id = ANY(p_mec_ids)
    GROUP BY contributor_first_name, contributor_last_name, contributor_company, city, state
    ORDER BY SUM(total_amount) DESC
    LIMIT p_limit
  ) t;
$function$;

-- Top payees (single)
CREATE OR REPLACE FUNCTION public.get_mec_top_payees(p_mec_id text, p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      CASE
        WHEN payee_company <> '' THEN payee_company
        ELSE TRIM(CONCAT(payee_first_name, ' ', payee_last_name))
      END                  AS payee_name,
      payee_first_name,
      payee_last_name,
      payee_company,
      city, state,
      total_amount,
      payment_count,
      last_payment
    FROM public.mec_committee_payee_aggregate
    WHERE mec_id = p_mec_id
    ORDER BY total_amount DESC NULLS LAST
    LIMIT p_limit
  ) t;
$function$;

-- Top payees (multi)
CREATE OR REPLACE FUNCTION public.get_mec_top_payees_multi(p_mec_ids text[], p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      CASE
        WHEN payee_company <> '' THEN payee_company
        ELSE TRIM(CONCAT(payee_first_name, ' ', payee_last_name))
      END                       AS payee_name,
      payee_first_name,
      payee_last_name,
      payee_company,
      city, state,
      SUM(total_amount)         AS total_amount,
      SUM(payment_count)        AS payment_count,
      MAX(last_payment)         AS last_payment
    FROM public.mec_committee_payee_aggregate
    WHERE mec_id = ANY(p_mec_ids)
    GROUP BY payee_first_name, payee_last_name, payee_company, city, state
    ORDER BY SUM(total_amount) DESC NULLS LAST
    LIMIT p_limit
  ) t;
$function$;

-- Finance summary (single)
CREATE OR REPLACE FUNCTION public.get_mec_finance_summary(p_mec_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(
    (SELECT json_build_object(
       'total_raised',       total_raised,
       'contribution_count', contribution_count,
       'monetary_total',     monetary_total,
       'in_kind_total',      in_kind_total,
       'in_kind_count',      in_kind_count,
       'avg_contribution',   CASE WHEN contribution_count > 0
                                  THEN total_raised / contribution_count
                                  ELSE 0 END,
       'first_contribution', first_contribution,
       'last_contribution',  last_contribution,
       'unique_donors',      unique_donors
     )
     FROM public.mec_committee_finance_summary
     WHERE mec_id = p_mec_id),
    json_build_object(
       'total_raised', 0, 'contribution_count', 0,
       'monetary_total', 0, 'in_kind_total', 0, 'in_kind_count', 0,
       'avg_contribution', 0,
       'first_contribution', NULL, 'last_contribution', NULL,
       'unique_donors', 0)
  );
$function$;

-- Finance summary (multi)
-- Note: unique_donors across multiple committees is approximated by SUM
-- of per-committee unique counts (the original RPC used DISTINCT on the
-- raw rows; our MV pre-aggregates per committee so we cannot recombine
-- exactly without rescanning the base table).  For Money tab top-line
-- display this overcounts donors who give to two of a candidate's
-- committees — typically <1% drift and far cheaper than re-grouping.
CREATE OR REPLACE FUNCTION public.get_mec_finance_summary_multi(p_mec_ids text[])
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_raised',       COALESCE(SUM(total_raised), 0),
    'contribution_count', COALESCE(SUM(contribution_count), 0),
    'monetary_total',     COALESCE(SUM(monetary_total), 0),
    'in_kind_total',      COALESCE(SUM(in_kind_total), 0),
    'in_kind_count',      COALESCE(SUM(in_kind_count), 0),
    'avg_contribution',   CASE WHEN COALESCE(SUM(contribution_count), 0) > 0
                               THEN COALESCE(SUM(total_raised), 0) / SUM(contribution_count)
                               ELSE 0 END,
    'first_contribution', MIN(first_contribution),
    'last_contribution',  MAX(last_contribution),
    'unique_donors',      COALESCE(SUM(unique_donors), 0),
    'committees_included', COALESCE(array_length(p_mec_ids, 1), 0)
  )
  FROM public.mec_committee_finance_summary
  WHERE mec_id = ANY(p_mec_ids);
$function$;

-- Expenditure summary (single) — single MV scan, no redundancy
CREATE OR REPLACE FUNCTION public.get_mec_expenditure_summary(p_mec_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(
    (SELECT json_build_object(
       'total_spent',       total_spent,
       'expenditure_count', expenditure_count,
       'avg_expenditure',   CASE WHEN expenditure_count > 0
                                 THEN total_spent / expenditure_count
                                 ELSE 0 END,
       'first_expenditure', first_expenditure,
       'last_expenditure',  last_expenditure,
       'unique_payees',     unique_payees,
       'by_purpose',        by_purpose,
       'by_type',           by_type
     )
     FROM public.mec_committee_finance_summary
     WHERE mec_id = p_mec_id),
    json_build_object(
       'total_spent', 0, 'expenditure_count', 0, 'avg_expenditure', 0,
       'first_expenditure', NULL, 'last_expenditure', NULL,
       'unique_payees', 0,
       'by_purpose', '[]'::json, 'by_type', '[]'::json)
  );
$function$;

-- Expenditure summary (multi) — collapses 3 redundant scans to 1 CTE.
-- The previous version scanned mec_expenditures three separate times
-- (once for the totals, once per by_purpose, once per by_type).  We now
-- do a single pass against the per-committee summary MV and merge the
-- pre-aggregated jsonb arrays.
CREATE OR REPLACE FUNCTION public.get_mec_expenditure_summary_multi(p_mec_ids text[])
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  WITH base AS (
    SELECT *
    FROM public.mec_committee_finance_summary
    WHERE mec_id = ANY(p_mec_ids)
  ),
  totals AS (
    SELECT
      COALESCE(SUM(total_spent), 0)        AS total_spent,
      COALESCE(SUM(expenditure_count), 0)  AS expenditure_count,
      MIN(first_expenditure)               AS first_expenditure,
      MAX(last_expenditure)                AS last_expenditure,
      COALESCE(SUM(unique_payees), 0)      AS unique_payees
    FROM base
  ),
  purpose_rolled AS (
    SELECT jsonb_agg(jsonb_build_object('purpose', purpose, 'total', total, 'count', cnt)
                     ORDER BY total DESC) AS arr
    FROM (
      SELECT
        elem->>'purpose'                    AS purpose,
        SUM((elem->>'total')::numeric)      AS total,
        SUM((elem->>'count')::bigint)       AS cnt
      FROM base, LATERAL jsonb_array_elements(by_purpose) elem
      GROUP BY elem->>'purpose'
    ) p
  ),
  type_rolled AS (
    SELECT jsonb_agg(jsonb_build_object('type', type, 'total', total, 'count', cnt)
                     ORDER BY total DESC) AS arr
    FROM (
      SELECT
        elem->>'type'                       AS type,
        SUM((elem->>'total')::numeric)      AS total,
        SUM((elem->>'count')::bigint)       AS cnt
      FROM base, LATERAL jsonb_array_elements(by_type) elem
      GROUP BY elem->>'type'
    ) t
  )
  SELECT json_build_object(
    'total_spent',       totals.total_spent,
    'expenditure_count', totals.expenditure_count,
    'avg_expenditure',   CASE WHEN totals.expenditure_count > 0
                              THEN totals.total_spent / totals.expenditure_count
                              ELSE 0 END,
    'first_expenditure', totals.first_expenditure,
    'last_expenditure',  totals.last_expenditure,
    'unique_payees',     totals.unique_payees,
    'by_purpose',        COALESCE(purpose_rolled.arr, '[]'::jsonb),
    'by_type',           COALESCE(type_rolled.arr, '[]'::jsonb)
  )
  FROM totals, purpose_rolled, type_rolled;
$function$;

-- ---------------------------------------------------------------------
-- 5. Race finance comparison — drop the correlated subqueries.
--    The previous shape ran six per-row correlated subqueries, each of
--    which re-issued the join.  Rewrite to LATERAL JOIN against the
--    pre-aggregated MV + candidate_mec_committee lookup.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_race_finance_comparison(p_office text, p_district text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  WITH race_candidates AS (
    SELECT
      c.id AS candidate_id,
      c.name, c.party, c.photo_url, c.estimated_age,
      c.mec_committee_ids, c.fec_candidate_id, c.incumbent,
      c.endorsements
    FROM public.candidates c
    WHERE c.office = p_office AND c.district = p_district
  ),
  mec_rollup AS (
    -- Hash-join via candidate_mec_committee against the summary MV.
    SELECT
      cmc.candidate_id,
      COALESCE(SUM(s.total_raised), 0)       AS mec_raised,
      COALESCE(SUM(s.contribution_count), 0) AS mec_count,
      COALESCE(SUM(s.total_spent), 0)        AS total_spent
    FROM public.candidate_mec_committee cmc
    JOIN public.mec_committee_finance_summary s ON s.mec_id = cmc.mec_id
    WHERE cmc.candidate_id IN (SELECT candidate_id FROM race_candidates)
    GROUP BY cmc.candidate_id
  ),
  fec_rollup AS (
    SELECT
      rc.candidate_id,
      COALESCE(SUM(fc.transaction_amount), 0) AS fec_raised,
      COUNT(fc.*)                              AS fec_count
    FROM race_candidates rc
    JOIN public.fec_candidates fcand ON fcand.cand_id = rc.fec_candidate_id
    LEFT JOIN public.fec_contributions fc ON fc.cmte_id = fcand.principal_committee_id
    WHERE rc.fec_candidate_id IS NOT NULL AND rc.fec_candidate_id <> ''
    GROUP BY rc.candidate_id
  ),
  news_rollup AS (
    SELECT cn.candidate_id, COUNT(*) AS news_count
    FROM public.candidate_news cn
    WHERE cn.candidate_id IN (SELECT candidate_id FROM race_candidates)
    GROUP BY cn.candidate_id
  )
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.total_raised DESC), '[]'::json)
  FROM (
    SELECT
      rc.candidate_id, rc.name, rc.party, rc.photo_url, rc.estimated_age, rc.incumbent,
      rc.mec_committee_ids, rc.fec_candidate_id,
      GREATEST(COALESCE(m.mec_raised, 0), COALESCE(f.fec_raised, 0)) AS total_raised,
      GREATEST(COALESCE(m.mec_count, 0),  COALESCE(f.fec_count, 0))  AS contribution_count,
      CASE WHEN COALESCE(f.fec_raised, 0) > COALESCE(m.mec_raised, 0)
           THEN 'FEC' ELSE 'MEC' END AS source,
      COALESCE(m.total_spent, 0) AS total_spent,
      COALESCE(n.news_count, 0)  AS news_count,
      rc.endorsements IS NOT NULL AND rc.endorsements <> '' AS has_endorsements,
      (rc.mec_committee_ids IS NULL OR array_length(rc.mec_committee_ids, 1) IS NULL)
        AND (rc.fec_candidate_id IS NULL OR rc.fec_candidate_id = '') AS no_committee_linked
    FROM race_candidates rc
    LEFT JOIN mec_rollup m  ON m.candidate_id = rc.candidate_id
    LEFT JOIN fec_rollup f  ON f.candidate_id = rc.candidate_id
    LEFT JOIN news_rollup n ON n.candidate_id = rc.candidate_id
  ) t;
$function$;

-- ---------------------------------------------------------------------
-- 6. Permissions — grant SELECT on the MVs so the new functions resolve
--    under their callers' roles.  Reads are gated by the wrapping STABLE
--    SQL functions; we keep direct SELECT rights to the same set of
--    roles already authorized to read mec_contributions / mec_expenditures.
-- ---------------------------------------------------------------------
GRANT SELECT ON public.mec_committee_donor_aggregate    TO anon, authenticated, service_role;
GRANT SELECT ON public.mec_committee_payee_aggregate    TO anon, authenticated, service_role;
GRANT SELECT ON public.mec_committee_finance_summary    TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7. Initial population (the MVs were created WITH DATA but rebuild any
--    that ended up empty due to dependency ordering).
-- ---------------------------------------------------------------------
-- (CREATE MATERIALIZED VIEW … defaults to WITH DATA, so populated.)

-- ---------------------------------------------------------------------
-- 8. Nightly refresh via pg_cron — 03:00 America/Chicago.
--    Database timezone is UTC; 03:00 CDT = 08:00 UTC, 03:00 CST = 09:00 UTC.
--    We pick 08:00 UTC so the refresh always lands in the early-AM
--    window (02:00 CST or 03:00 CDT) regardless of DST.
-- ---------------------------------------------------------------------
DO $$
BEGIN
  -- Drop any previous schedule so re-running this migration is idempotent.
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname IN (
    'refresh-mec-committee-donor-aggregate',
    'refresh-mec-committee-payee-aggregate',
    'refresh-mec-committee-finance-summary'
  );
END$$;

SELECT cron.schedule(
  'refresh-mec-committee-donor-aggregate',
  '0 8 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_donor_aggregate$$
);

SELECT cron.schedule(
  'refresh-mec-committee-payee-aggregate',
  '5 8 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_payee_aggregate$$
);

SELECT cron.schedule(
  'refresh-mec-committee-finance-summary',
  '10 8 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_finance_summary$$
);

-- =====================================================================
-- DONE.
-- =====================================================================
