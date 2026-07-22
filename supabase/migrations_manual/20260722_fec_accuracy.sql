-- ============================================================================
-- 20260722_fec_accuracy.sql
-- FEC money-tab: make numbers CYCLE-CORRECT and METHODOLOGY-CORRECT.
--
-- Problems fixed:
--   (1) MV public.fec_committee_finance_summary naively SUM(transaction_amount)
--       with no memo/transfer exclusions -> overstated & methodology-wrong.
--   (2) get_fec_finance_summary aggregated ALL cycles (Smith showed $11.6M
--       lifetime instead of ~$1.5M for 2026).
--   (3) Nothing read public.fec_committee_totals (the OFFICIAL FEC numbers).
--
-- FEC "individual contributions" (Line 11a) methodology used throughout:
--   EXCLUDE memo_cd='X' (memo itemizations, not real receipts)
--   EXCLUDE transfer transaction types 15J / 15E / 18G
--   individual split = entity_tp='IND'
--
-- Grain of the MV stays per-cmte_id-per-cycle; unique index name preserved so
-- REFRESH MATERIALIZED VIEW CONCURRENTLY keeps working.
--
-- Rollback: 20260722_fec_accuracy_ROLLBACK.sql
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Redefine the finance-summary MV with FEC methodology exclusions.
--    DROP+CREATE is safe: no view depends on it and get_fec_finance_summary is
--    a string-body SQL function (no hard catalog dependency).
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_finance_summary;

CREATE MATERIALIZED VIEW public.fec_committee_finance_summary AS
SELECT
  fc.cmte_id,
  fc.cycle,
  -- itemized totals (FEC methodology: drop memo-X + transfers)
  COALESCE(SUM(fc.transaction_amount) FILTER (
    WHERE COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ), 0::numeric) AS itemized_total,
  COALESCE(SUM(fc.transaction_amount) FILTER (
    WHERE fc.entity_tp = 'IND'
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ), 0::numeric) AS itemized_individual,
  COALESCE(SUM(fc.transaction_amount) FILTER (
    WHERE COALESCE(fc.is_pac_contribution,false)
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ), 0::numeric) AS itemized_pac,
  -- counts (post-exclusion)
  COUNT(*) FILTER (
    WHERE COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS contribution_count,
  COUNT(*) FILTER (
    WHERE fc.entity_tp = 'IND'
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS individual_count,
  COUNT(*) FILTER (
    WHERE COALESCE(fc.is_pac_contribution,false)
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS pac_count,
  -- first/last real transaction dates, excluding future-dated rows
  MIN(fc.transaction_date) FILTER (
    WHERE fc.transaction_date <= CURRENT_DATE
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS first_contribution,
  MAX(fc.transaction_date) FILTER (
    WHERE fc.transaction_date <= CURRENT_DATE
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS last_contribution,
  -- distinct donors supporting this committee in this cycle (post-exclusion)
  COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name)) FILTER (
    WHERE COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS unique_donors
FROM public.fec_contributions fc
GROUP BY fc.cmte_id, fc.cycle;

-- keep the exact index name so REFRESH ... CONCURRENTLY still works
CREATE UNIQUE INDEX fec_committee_finance_summary_pk
  ON public.fec_committee_finance_summary USING btree (cmte_id, cycle);

GRANT SELECT ON public.fec_committee_finance_summary TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Drop the prior narrower-signature RPC overloads. CREATE OR REPLACE below adds
-- a trailing default param, which creates a NEW overload rather than replacing;
-- leaving the old ones in place makes the single-/two-arg app calls ambiguous.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_fec_finance_summary(text);
DROP FUNCTION IF EXISTS public.get_fec_top_donors(text, integer);
DROP FUNCTION IF EXISTS public.get_fec_contribution_timeline(text);
DROP FUNCTION IF EXISTS public.get_fec_recent_contributions(text, integer);
DROP FUNCTION IF EXISTS public.get_fec_committees_for_candidate(text);

-- ----------------------------------------------------------------------------
-- 2. get_fec_finance_summary: OFFICIAL headline from fec_committee_totals for
--    the requested cycle (default 2026), MV itemized fallback where totals are
--    missing (finance_source flags which). New TRAILING p_cycle param keeps the
--    existing single-arg call sites working. Return JSON is a SUPERSET of the
--    old shape (all prior keys retained + receipts/individual_contributions/
--    disbursements/cash_on_hand_end/coverage_end_date/finance_source/cycle/
--    lifetime_receipts added). lifetime_receipts keeps all-time visible without
--    letting it masquerade as the current-cycle headline.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_finance_summary(
  p_fec_cand_id text,
  p_cycle integer DEFAULT 2026
)
RETURNS json
LANGUAGE sql
STABLE
AS $function$
  WITH cmtes AS (
    SELECT DISTINCT cmte_id
    FROM public.fec_committees
    WHERE cand_id = p_fec_cand_id
  ),
  -- OFFICIAL FEC totals for the requested cycle (summed across the candidate's
  -- committees; in practice only authorized committees carry totals rows)
  tot AS (
    SELECT
      SUM(t.receipts)                 AS receipts,
      SUM(t.individual_contributions) AS individual_contributions,
      SUM(t.disbursements)            AS disbursements,
      SUM(t.cash_on_hand_end)         AS cash_on_hand_end,
      MAX(t.coverage_end_date)        AS coverage_end_date,
      COUNT(*)                        AS n_rows
    FROM public.fec_committee_totals t
    WHERE t.cmte_id IN (SELECT cmte_id FROM cmtes)
      AND t.cycle = p_cycle
  ),
  -- itemized aggregates for the requested cycle (fallback + counts/pac/dates)
  mv AS (
    SELECT
      COALESCE(SUM(s.itemized_total),0)      AS itemized_total,
      COALESCE(SUM(s.itemized_individual),0) AS itemized_individual,
      COALESCE(SUM(s.itemized_pac),0)        AS itemized_pac,
      COALESCE(SUM(s.contribution_count),0)  AS contribution_count,
      COALESCE(SUM(s.individual_count),0)    AS individual_count,
      COALESCE(SUM(s.pac_count),0)           AS pac_count,
      MIN(s.first_contribution)              AS first_contribution,
      MAX(s.last_contribution)               AS last_contribution,
      COUNT(DISTINCT s.cmte_id)              AS committees_count
    FROM public.fec_committee_finance_summary s
    WHERE s.cmte_id IN (SELECT cmte_id FROM cmtes)
      AND s.cycle = p_cycle
  ),
  -- cycle-correct unique individual donors (post-exclusion)
  ud AS (
    SELECT COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name)) AS unique_donors
    FROM public.fec_contributions fc
    WHERE fc.cmte_id IN (SELECT cmte_id FROM cmtes)
      AND fc.cycle = p_cycle
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ),
  -- lifetime receipts = best-available per cycle (official where present, else
  -- itemized), summed across all cycles
  life AS (
    SELECT COALESCE(SUM(best),0) AS lifetime_receipts
    FROM (
      SELECT c.cycle,
             COALESCE(
               (SELECT SUM(t.receipts)
                  FROM public.fec_committee_totals t
                 WHERE t.cmte_id IN (SELECT cmte_id FROM cmtes)
                   AND t.cycle = c.cycle),
               SUM(c.itemized_total)
             ) AS best
      FROM public.fec_committee_finance_summary c
      WHERE c.cmte_id IN (SELECT cmte_id FROM cmtes)
      GROUP BY c.cycle
    ) per_cycle
  ),
  cyc AS (
    SELECT COUNT(DISTINCT cycle) AS cycles_active
    FROM public.fec_committee_finance_summary
    WHERE cmte_id IN (SELECT cmte_id FROM cmtes)
  )
  SELECT json_build_object(
    'cycle',                    p_cycle,
    'finance_source',           CASE WHEN t.n_rows > 0 THEN 'fec_totals' ELSE 'itemized_fallback' END,
    -- headline: cycle-correct receipts (official, itemized fallback)
    'total_raised',             CASE WHEN t.n_rows > 0 THEN t.receipts ELSE m.itemized_total END,
    -- OFFICIAL columns (null when totals missing for the cycle)
    'receipts',                 t.receipts,
    'individual_contributions', t.individual_contributions,
    'disbursements',            t.disbursements,
    'cash_on_hand_end',         t.cash_on_hand_end,
    'coverage_end_date',        t.coverage_end_date,
    -- individual headline: official where present, itemized fallback
    'individual_total',         CASE WHEN t.n_rows > 0 AND t.individual_contributions IS NOT NULL
                                     THEN t.individual_contributions ELSE m.itemized_individual END,
    'pac_total',                m.itemized_pac,
    'contribution_count',       m.contribution_count,
    'individual_contribs',      m.individual_count,
    'pac_contribs',             m.pac_count,
    'avg_contribution',         CASE WHEN m.contribution_count > 0
                                     THEN m.itemized_total / m.contribution_count ELSE 0 END,
    'unique_donors',            u.unique_donors,
    'first_contribution',       m.first_contribution,
    'last_contribution',        m.last_contribution,
    'committees_count',         m.committees_count,
    'cycles_active',            cy.cycles_active,
    'lifetime_receipts',        l.lifetime_receipts
  )
  FROM tot t, mv m, ud u, life l, cyc cy;
$function$;

-- ----------------------------------------------------------------------------
-- 3a. get_fec_top_donors: read fec_contributions directly with FEC exclusions +
--     cycle default 2026 (per-cycle top donors). Same return shape; new trailing
--     p_cycle param (NULL = all cycles).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_top_donors(
  p_fec_cand_id text,
  p_limit integer DEFAULT 10,
  p_cycle integer DEFAULT 2026
)
RETURNS TABLE(donor_name text, city text, state text, employer text, occupation text,
              total_amount numeric, contribution_count integer, donor_id bigint)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name) AS donor_name,
    MAX(fc.city)       AS city,
    MAX(fc.state)      AS state,
    MAX(fc.employer)   AS employer,
    MAX(fc.occupation) AS occupation,
    SUM(fc.transaction_amount)::numeric AS total_amount,
    COUNT(*)::int      AS contribution_count,
    MAX(fc.donor_id)   AS donor_id
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
    AND fc.entity_tp = 'IND'
    AND COALESCE(fc.memo_cd,'') <> 'X'
    AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
    AND (p_cycle IS NULL OR fc.cycle = p_cycle)
  GROUP BY COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name)
  HAVING SUM(fc.transaction_amount) > 0
  ORDER BY total_amount DESC
  LIMIT p_limit;
$function$;

-- ----------------------------------------------------------------------------
-- 3b. get_fec_contribution_timeline: FEC exclusions + cycle default 2026 +
--     drop future-dated rows. New trailing p_cycle param (NULL = all cycles).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_contribution_timeline(
  p_fec_cand_id text,
  p_cycle integer DEFAULT 2026
)
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
    AND fc.transaction_date <= CURRENT_DATE
    AND COALESCE(fc.memo_cd,'') <> 'X'
    AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
    AND (p_cycle IS NULL OR fc.cycle = p_cycle)
  GROUP BY date_trunc('month', fc.transaction_date)
  ORDER BY date_trunc('month', fc.transaction_date);
$function$;

-- ----------------------------------------------------------------------------
-- 3c. get_fec_recent_contributions: stays all-cycles by default but now excludes
--     memo_cd='X'. New trailing p_cycle param (NULL = all cycles) for optional
--     filtering.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_recent_contributions(
  p_fec_cand_id text,
  p_limit integer DEFAULT 50,
  p_cycle integer DEFAULT NULL
)
RETURNS TABLE(contributor_name text, city text, state text, transaction_amount numeric,
              transaction_date date, employer text, occupation text,
              is_pac_contribution boolean, committee_name text, cycle smallint)
LANGUAGE sql
STABLE
AS $function$
  SELECT fc.contributor_name, fc.city, fc.state, fc.transaction_amount, fc.transaction_date,
    fc.employer, fc.occupation, COALESCE(fc.is_pac_contribution,false), fc.committee_name, fc.cycle
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
    AND COALESCE(fc.memo_cd,'') <> 'X'
    AND (p_cycle IS NULL OR fc.cycle = p_cycle)
  ORDER BY fc.transaction_date DESC NULLS LAST
  LIMIT p_limit;
$function$;

-- ----------------------------------------------------------------------------
-- 3d. get_fec_committees_for_candidate: dedup to ONE row per committee across
--     cycles (Cleaver -> a single committee set). cycle column = most recent
--     cycle the committee was active for this candidate. New trailing p_cycle
--     param (NULL = all cycles) for optional filtering.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_committees_for_candidate(
  p_fec_cand_id text,
  p_cycle integer DEFAULT NULL
)
RETURNS TABLE(cmte_id text, cmte_name text, cmte_type text, designation text, party text, cycle smallint)
LANGUAGE sql
STABLE
AS $function$
  SELECT cmte_id, cmte_name, cmte_type, designation, party, cycle
  FROM (
    SELECT DISTINCT ON (cmte_id)
      cmte_id, cmte_name, cmte_type, designation, party, cycle
    FROM public.fec_committees
    WHERE cand_id = p_fec_cand_id
      AND (p_cycle IS NULL OR cycle = p_cycle)
    ORDER BY cmte_id, cycle DESC
  ) dedup
  ORDER BY cycle DESC, cmte_id;
$function$;

COMMIT;

-- ----------------------------------------------------------------------------
-- 4. Populate the freshly recreated MV (outside the txn; CONCURRENTLY needs a
--    committed MV + cannot run in a transaction block). The first load after a
--    DROP/CREATE must be a plain (non-CONCURRENT) refresh.
-- ----------------------------------------------------------------------------
REFRESH MATERIALIZED VIEW public.fec_committee_finance_summary;


-- ============================================================================
-- Part 2: durable amendment guard
-- Added 2026-07-22 alongside the fec_daily_sync.py pipeline.
--
-- Goal: make superseded-amendment double-counting STRUCTURALLY impossible, so a
-- future itemized load that accidentally re-inserts rows from a report that has
-- since been amended can never inflate the money numbers again. Tonight's
-- one-off cleanup deleted the superseded rows from fec_contributions; this part
-- records which (cmte_id, file_num) filings were superseded in a durable table
-- and teaches the finance-summary MV to exclude them even if the rows reappear.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 2a. Durable registry of superseded filings. The daily sync appends to this as
--     it detects new amendments; the MV (2b) and the sync's contribution loader
--     both treat membership here as "these rows do not count".
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fec_superseded_filings (
  cmte_id       text        NOT NULL,
  file_num      bigint      NOT NULL,
  superseded_by bigint      NULL,
  reason        text,
  detected_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (cmte_id, file_num)
);

GRANT SELECT ON public.fec_superseded_filings TO anon, authenticated, service_role;

-- Seed from tonight's audit table. reason is 'superseded_by_<file_num>'; pull the
-- trailing digits into superseded_by. Idempotent (ON CONFLICT DO NOTHING).
INSERT INTO public.fec_superseded_filings (cmte_id, file_num, superseded_by, reason)
SELECT
  cmte_id,
  file_num::bigint,
  NULLIF(regexp_replace(reason, '\D', '', 'g'), '')::bigint AS superseded_by,
  reason
FROM public.tmp_fec_amendment_dedup_20260722
ON CONFLICT (cmte_id, file_num) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2b. Redefine fec_committee_finance_summary to EXCLUDE any fec_contributions
--     row whose (cmte_id, file_num) is registered as superseded. Everything else
--     is byte-for-byte identical to the Part-1 definition (same columns, same
--     FEC-methodology FILTERs, same grain, same unique index name so REFRESH ...
--     CONCURRENTLY keeps working). file_num is text in fec_contributions and
--     bigint here, so compare on ::text to avoid cast errors on non-numeric/NULL
--     file_num (NULL file_num => NOT EXISTS true => row kept, correct).
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_finance_summary;

CREATE MATERIALIZED VIEW public.fec_committee_finance_summary AS
SELECT
  fc.cmte_id,
  fc.cycle,
  COALESCE(SUM(fc.transaction_amount) FILTER (
    WHERE COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ), 0::numeric) AS itemized_total,
  COALESCE(SUM(fc.transaction_amount) FILTER (
    WHERE fc.entity_tp = 'IND'
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ), 0::numeric) AS itemized_individual,
  COALESCE(SUM(fc.transaction_amount) FILTER (
    WHERE COALESCE(fc.is_pac_contribution,false)
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ), 0::numeric) AS itemized_pac,
  COUNT(*) FILTER (
    WHERE COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS contribution_count,
  COUNT(*) FILTER (
    WHERE fc.entity_tp = 'IND'
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS individual_count,
  COUNT(*) FILTER (
    WHERE COALESCE(fc.is_pac_contribution,false)
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS pac_count,
  MIN(fc.transaction_date) FILTER (
    WHERE fc.transaction_date <= CURRENT_DATE
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS first_contribution,
  MAX(fc.transaction_date) FILTER (
    WHERE fc.transaction_date <= CURRENT_DATE
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS last_contribution,
  COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name)) FILTER (
    WHERE COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ) AS unique_donors
FROM public.fec_contributions fc
WHERE NOT EXISTS (
  SELECT 1 FROM public.fec_superseded_filings sf
  WHERE sf.cmte_id = fc.cmte_id
    AND sf.file_num::text = fc.file_num
)
GROUP BY fc.cmte_id, fc.cycle;

CREATE UNIQUE INDEX fec_committee_finance_summary_pk
  ON public.fec_committee_finance_summary USING btree (cmte_id, cycle);

GRANT SELECT ON public.fec_committee_finance_summary TO anon, authenticated, service_role;

COMMIT;

REFRESH MATERIALIZED VIEW public.fec_committee_finance_summary;

-- ----------------------------------------------------------------------------
-- 2c. fec_committees (cmte_id, cand_id) dedup — DELIBERATELY NOT PERFORMED.
--
-- The brief called for collapsing duplicate (cmte_id, cand_id) rows to one and
-- adding UNIQUE(cmte_id, cand_id) NULLS NOT DISTINCT. Investigation shows this
-- would be DATA-DESTRUCTIVE and is based on a misdiagnosis:
--
--   * fec_committees is grained per (cmte_id, cycle) and already carries a
--     UNIQUE index fec_committees_cmte_id_cycle on (cmte_id, cycle). There are
--     ZERO true duplicates at that natural grain (3236 rows = 3236 distinct
--     (cmte_id, cycle) pairs).
--   * The 359 "duplicate (cmte_id, cand_id) pairs" are NOT duplicates: they are
--     the same committee legitimately represented once per election cycle (e.g.
--     C00025973 / Ike Skelton across 2002, 2004, 2006, 2008, 2010, 2012). ALL
--     359 pairs span multiple distinct cycles; none is a same-cycle dupe.
--   * Keeping "lowest id per (cmte_id, cand_id)" would DELETE 668 legitimate
--     historical per-cycle rows, destroying cross-cycle committee history.
--   * UNIQUE(cmte_id, cand_id) would then PERMANENTLY BLOCK the daily sync (and
--     any future backfill) from inserting the next cycle's row for any existing
--     committee -> it would break the very pipeline this migration supports.
--   * The RPCs already tolerate the multiplicity: every call site uses
--     cmte_id IN (SELECT cmte_id FROM fec_committees WHERE cand_id = $1), and
--     IN de-duplicates cmte_ids, so no double-counting arises from these rows.
--
-- The existing UNIQUE(cmte_id, cycle) is the correct, already-present guard
-- against real duplication. No change made here on purpose. Flagged for Andrew.
-- ----------------------------------------------------------------------------

-- Part 3: authorized-committees-only money aggregation (applied 2026-07-22, before Part 2)
-- JFCs (designation 'J') and leadership PACs must not inflate a candidate's own money:
-- money-aggregating RPCs now select committees WHERE designation IS NULL OR designation IN ('P','A').
-- get_fec_committees_for_candidate intentionally still lists ALL committees.
CREATE OR REPLACE FUNCTION public.get_fec_finance_summary(p_fec_cand_id text, p_cycle integer DEFAULT 2026)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  WITH cmtes AS (
    SELECT DISTINCT cmte_id
    FROM public.fec_committees
    WHERE cand_id = p_fec_cand_id
      -- authorized committees only: JFCs (designation J) and leadership
      -- PACs must not inflate a candidate's own money
      AND (designation IS NULL OR designation IN ('P','A'))
  ),
  -- OFFICIAL FEC totals for the requested cycle (summed across the candidate's
  -- committees; in practice only authorized committees carry totals rows)
  tot AS (
    SELECT
      SUM(t.receipts)                 AS receipts,
      SUM(t.individual_contributions) AS individual_contributions,
      SUM(t.disbursements)            AS disbursements,
      SUM(t.cash_on_hand_end)         AS cash_on_hand_end,
      MAX(t.coverage_end_date)        AS coverage_end_date,
      COUNT(*)                        AS n_rows
    FROM public.fec_committee_totals t
    WHERE t.cmte_id IN (SELECT cmte_id FROM cmtes)
      AND t.cycle = p_cycle
  ),
  -- itemized aggregates for the requested cycle (fallback + counts/pac/dates)
  mv AS (
    SELECT
      COALESCE(SUM(s.itemized_total),0)      AS itemized_total,
      COALESCE(SUM(s.itemized_individual),0) AS itemized_individual,
      COALESCE(SUM(s.itemized_pac),0)        AS itemized_pac,
      COALESCE(SUM(s.contribution_count),0)  AS contribution_count,
      COALESCE(SUM(s.individual_count),0)    AS individual_count,
      COALESCE(SUM(s.pac_count),0)           AS pac_count,
      MIN(s.first_contribution)              AS first_contribution,
      MAX(s.last_contribution)               AS last_contribution,
      COUNT(DISTINCT s.cmte_id)              AS committees_count
    FROM public.fec_committee_finance_summary s
    WHERE s.cmte_id IN (SELECT cmte_id FROM cmtes)
      AND s.cycle = p_cycle
  ),
  -- cycle-correct unique individual donors (post-exclusion)
  ud AS (
    SELECT COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name)) AS unique_donors
    FROM public.fec_contributions fc
    WHERE fc.cmte_id IN (SELECT cmte_id FROM cmtes)
      AND fc.cycle = p_cycle
      AND COALESCE(fc.memo_cd,'') <> 'X'
      AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
  ),
  -- lifetime receipts = best-available per cycle (official where present, else
  -- itemized), summed across all cycles
  life AS (
    SELECT COALESCE(SUM(best),0) AS lifetime_receipts
    FROM (
      SELECT c.cycle,
             COALESCE(
               (SELECT SUM(t.receipts)
                  FROM public.fec_committee_totals t
                 WHERE t.cmte_id IN (SELECT cmte_id FROM cmtes)
                   AND t.cycle = c.cycle),
               SUM(c.itemized_total)
             ) AS best
      FROM public.fec_committee_finance_summary c
      WHERE c.cmte_id IN (SELECT cmte_id FROM cmtes)
      GROUP BY c.cycle
    ) per_cycle
  ),
  cyc AS (
    SELECT COUNT(DISTINCT cycle) AS cycles_active
    FROM public.fec_committee_finance_summary
    WHERE cmte_id IN (SELECT cmte_id FROM cmtes)
  )
  SELECT json_build_object(
    'cycle',                    p_cycle,
    'finance_source',           CASE WHEN t.n_rows > 0 THEN 'fec_totals' ELSE 'itemized_fallback' END,
    -- headline: cycle-correct receipts (official, itemized fallback)
    'total_raised',             CASE WHEN t.n_rows > 0 THEN t.receipts ELSE m.itemized_total END,
    -- OFFICIAL columns (null when totals missing for the cycle)
    'receipts',                 t.receipts,
    'individual_contributions', t.individual_contributions,
    'disbursements',            t.disbursements,
    'cash_on_hand_end',         t.cash_on_hand_end,
    'coverage_end_date',        t.coverage_end_date,
    -- individual headline: official where present, itemized fallback
    'individual_total',         CASE WHEN t.n_rows > 0 AND t.individual_contributions IS NOT NULL
                                     THEN t.individual_contributions ELSE m.itemized_individual END,
    'pac_total',                m.itemized_pac,
    'contribution_count',       m.contribution_count,
    'individual_contribs',      m.individual_count,
    'pac_contribs',             m.pac_count,
    'avg_contribution',         CASE WHEN m.contribution_count > 0
                                     THEN m.itemized_total / m.contribution_count ELSE 0 END,
    'unique_donors',            u.unique_donors,
    'first_contribution',       m.first_contribution,
    'last_contribution',        m.last_contribution,
    'committees_count',         m.committees_count,
    'cycles_active',            cy.cycles_active,
    'lifetime_receipts',        l.lifetime_receipts
  )
  FROM tot t, mv m, ud u, life l, cyc cy;
$function$;

CREATE OR REPLACE FUNCTION public.get_fec_top_donors(p_fec_cand_id text, p_limit integer DEFAULT 10, p_cycle integer DEFAULT 2026)
 RETURNS TABLE(donor_name text, city text, state text, employer text, occupation text, total_amount numeric, contribution_count integer, donor_id bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name) AS donor_name,
    MAX(fc.city)       AS city,
    MAX(fc.state)      AS state,
    MAX(fc.employer)   AS employer,
    MAX(fc.occupation) AS occupation,
    SUM(fc.transaction_amount)::numeric AS total_amount,
    COUNT(*)::int      AS contribution_count,
    MAX(fc.donor_id)   AS donor_id
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id AND (designation IS NULL OR designation IN ('P','A')))
    AND fc.entity_tp = 'IND'
    AND COALESCE(fc.memo_cd,'') <> 'X'
    AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
    AND (p_cycle IS NULL OR fc.cycle = p_cycle)
  GROUP BY COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name)
  HAVING SUM(fc.transaction_amount) > 0
  ORDER BY total_amount DESC
  LIMIT p_limit;
$function$;

CREATE OR REPLACE FUNCTION public.get_fec_contribution_timeline(p_fec_cand_id text, p_cycle integer DEFAULT 2026)
 RETURNS TABLE(month_year text, total numeric, contribution_count integer)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    to_char(date_trunc('month', fc.transaction_date), 'YYYY-MM') AS month_year,
    SUM(fc.transaction_amount)::numeric AS total,
    COUNT(*)::int AS contribution_count
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id AND (designation IS NULL OR designation IN ('P','A')))
    AND fc.transaction_date IS NOT NULL
    AND fc.transaction_date <= CURRENT_DATE
    AND COALESCE(fc.memo_cd,'') <> 'X'
    AND COALESCE(fc.transaction_tp,'') NOT IN ('15J','15E','18G')
    AND (p_cycle IS NULL OR fc.cycle = p_cycle)
  GROUP BY date_trunc('month', fc.transaction_date)
  ORDER BY date_trunc('month', fc.transaction_date);
$function$;
