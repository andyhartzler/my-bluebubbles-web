-- ============================================================================
-- 20260723_fec_expenditures_agg.sql
-- FEC SPENDING aggregation layer, mirroring the MEC payee pattern
-- (public.mec_committee_payee_aggregate + get_mec_top_payees).
--
-- Source: public.fec_expenditures (Schedule B itemized disbursements).
-- Grain of the MV: per (cmte_id, cycle, normalized payee identity).
--
-- FEC / amendment methodology applied at the base scan so excluded rows never
-- form a group:
--   * EXCLUDE memo_cd='X' (memo itemizations, not real disbursements)
--   * EXCLUDE any row whose (cmte_id, file_num) is registered superseded in
--     public.fec_superseded_filings (durable amendment guard). file_num is
--     bigint in BOTH fec_expenditures and fec_superseded_filings -> direct
--     equality, NULL file_num => NOT EXISTS true => row kept (correct).
--
-- Money-aggregating candidate rollups use AUTHORIZED committees only
-- (designation IS NULL OR designation IN ('P','A')), matching the get_fec_*
-- money family. get_fec_recent_expenditures is a pass-through listing but is
-- also scoped to authorized committees for consistency with the money tab.
--
-- Refresh: pg_cron 2x daily at 08:30 / 20:30 UTC, offset from the FEC finance
--          MVs (jobs 96/97 at :20 / :25).
--
-- Rollback: 20260723_fec_expenditures_agg_ROLLBACK.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. MV: public.fec_committee_payee_aggregate
--    One row per (cmte_id, cycle, normalized payee identity). Normalized
--    identity mirrors MEC's payee MV: trimmed/coalesced parsed company / last /
--    first plus city / state. Display name resolves company -> "last, first" ->
--    raw payee_name. top_purpose / category_desc are the modal (most frequent)
--    values within the group; per-purpose totals are served live by
--    get_fec_spending_by_purpose (the MV grain intentionally does not keep them).
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.fec_committee_payee_aggregate CASCADE;

CREATE MATERIALIZED VIEW public.fec_committee_payee_aggregate AS
SELECT
  fe.cmte_id,
  fe.cycle,
  TRIM(BOTH FROM COALESCE(fe.parsed_payee_first, ''::text))   AS payee_first_name,
  TRIM(BOTH FROM COALESCE(fe.parsed_payee_last,  ''::text))   AS payee_last_name,
  TRIM(BOTH FROM COALESCE(fe.parsed_payee_company, ''::text)) AS payee_company,
  COALESCE(fe.city,  ''::text)                                AS city,
  COALESCE(fe.state, ''::text)                                AS state,
  -- display name: company, else "last, first", else raw payee_name
  COALESCE(
    NULLIF(TRIM(BOTH FROM COALESCE(fe.parsed_payee_company, ''::text)), ''),
    NULLIF(TRIM(BOTH FROM COALESCE(fe.parsed_payee_last, ''::text))
           || ', ' ||
           TRIM(BOTH FROM COALESCE(fe.parsed_payee_first, ''::text)), ', '),
    MAX(fe.payee_name)
  )                                                           AS payee_display_name,
  COALESCE(SUM(fe.transaction_amt), 0::numeric)               AS total_spent,
  COUNT(*)                                                    AS payment_count,
  MIN(fe.transaction_dt) FILTER (WHERE fe.transaction_dt <= CURRENT_DATE) AS first_transaction_dt,
  MAX(fe.transaction_dt) FILTER (WHERE fe.transaction_dt <= CURRENT_DATE) AS last_transaction_dt,
  -- modal (most frequent) purpose / category within this payee group
  mode() WITHIN GROUP (ORDER BY NULLIF(TRIM(BOTH FROM fe.purpose), ''))       AS top_purpose,
  mode() WITHIN GROUP (ORDER BY NULLIF(TRIM(BOTH FROM fe.category_desc), '')) AS category_desc
FROM public.fec_expenditures fe
WHERE COALESCE(fe.memo_cd, '') <> 'X'
  AND NOT EXISTS (
    SELECT 1 FROM public.fec_superseded_filings sf
    WHERE sf.cmte_id = fe.cmte_id
      AND sf.file_num = fe.file_num
  )
GROUP BY
  fe.cmte_id,
  fe.cycle,
  TRIM(BOTH FROM COALESCE(fe.parsed_payee_first, ''::text)),
  TRIM(BOTH FROM COALESCE(fe.parsed_payee_last,  ''::text)),
  TRIM(BOTH FROM COALESCE(fe.parsed_payee_company, ''::text)),
  COALESCE(fe.city,  ''::text),
  COALESCE(fe.state, ''::text)
WITH DATA;

-- Unique index REQUIRED for REFRESH MATERIALIZED VIEW CONCURRENTLY. All grain
-- columns are COALESCE'd to '' so none are null; no NULLS NOT DISTINCT needed.
CREATE UNIQUE INDEX fec_committee_payee_aggregate_uniq
  ON public.fec_committee_payee_aggregate
     (cmte_id, cycle, payee_first_name, payee_last_name, payee_company, city, state);

-- Supports get_fec_top_payees (ORDER BY total_spent DESC per committee/cycle).
CREATE INDEX fec_committee_payee_aggregate_cmte_total_idx
  ON public.fec_committee_payee_aggregate (cmte_id, cycle, total_spent DESC);

-- Grants mirror the sibling FEC MVs.
GRANT SELECT ON public.fec_committee_payee_aggregate TO anon, authenticated, service_role;

ANALYZE public.fec_committee_payee_aggregate;

-- ----------------------------------------------------------------------------
-- 2a. get_fec_top_payees: top payees for a candidate's AUTHORIZED committees in
--     a cycle, read from the MV. Normalized-payee identity is aggregated ACROSS
--     the candidate's committees (a vendor paid by two authorized committees
--     rolls up to one row).
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_fec_top_payees(text, integer, integer);

CREATE OR REPLACE FUNCTION public.get_fec_top_payees(
  p_fec_cand_id text,
  p_limit integer DEFAULT 25,
  p_cycle integer DEFAULT 2026
)
RETURNS TABLE(payee_name text, city text, state text, total_spent numeric,
              payment_count integer, first_transaction_dt date,
              last_transaction_dt date, top_purpose text, category_desc text)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    COALESCE(
      NULLIF(a.payee_company, ''),
      NULLIF(TRIM(BOTH FROM (a.payee_last_name || ', ' || a.payee_first_name)), ','),
      MAX(a.payee_display_name)
    )                            AS payee_name,
    MAX(NULLIF(a.city, ''))      AS city,
    MAX(NULLIF(a.state, ''))     AS state,
    SUM(a.total_spent)::numeric  AS total_spent,
    SUM(a.payment_count)::int    AS payment_count,
    MIN(a.first_transaction_dt)  AS first_transaction_dt,
    MAX(a.last_transaction_dt)   AS last_transaction_dt,
    MAX(a.top_purpose)           AS top_purpose,
    MAX(a.category_desc)         AS category_desc
  FROM public.fec_committee_payee_aggregate a
  WHERE a.cmte_id IN (
      SELECT cmte_id FROM public.fec_committees
      WHERE cand_id = p_fec_cand_id
        AND (designation IS NULL OR designation IN ('P','A'))
    )
    AND (p_cycle IS NULL OR a.cycle = p_cycle)
  GROUP BY a.payee_company, a.payee_last_name, a.payee_first_name
  HAVING SUM(a.total_spent) <> 0
  ORDER BY total_spent DESC
  LIMIT p_limit;
$function$;

GRANT EXECUTE ON FUNCTION public.get_fec_top_payees(text, integer, integer)
  TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2b. get_fec_spending_by_purpose: purpose / category breakdown with totals for
--     a candidate's AUTHORIZED committees in a cycle. Read live (the MV keeps
--     only the modal purpose per payee, not per-purpose totals); bounded by
--     committee size, with the same memo-X + superseded exclusions as the MV.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_fec_spending_by_purpose(text, integer);

CREATE OR REPLACE FUNCTION public.get_fec_spending_by_purpose(
  p_fec_cand_id text,
  p_cycle integer DEFAULT 2026
)
RETURNS TABLE(purpose text, category_desc text, total_spent numeric,
              payment_count integer)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    COALESCE(NULLIF(TRIM(BOTH FROM fe.purpose), ''), '(unspecified)')       AS purpose,
    COALESCE(NULLIF(TRIM(BOTH FROM fe.category_desc), ''), '(uncategorized)') AS category_desc,
    SUM(fe.transaction_amt)::numeric AS total_spent,
    COUNT(*)::int                    AS payment_count
  FROM public.fec_expenditures fe
  WHERE fe.cmte_id IN (
      SELECT cmte_id FROM public.fec_committees
      WHERE cand_id = p_fec_cand_id
        AND (designation IS NULL OR designation IN ('P','A'))
    )
    AND COALESCE(fe.memo_cd, '') <> 'X'
    AND NOT EXISTS (
      SELECT 1 FROM public.fec_superseded_filings sf
      WHERE sf.cmte_id = fe.cmte_id
        AND sf.file_num = fe.file_num
    )
    AND (p_cycle IS NULL OR fe.cycle = p_cycle)
  GROUP BY
    COALESCE(NULLIF(TRIM(BOTH FROM fe.purpose), ''), '(unspecified)'),
    COALESCE(NULLIF(TRIM(BOTH FROM fe.category_desc), ''), '(uncategorized)')
  ORDER BY total_spent DESC;
$function$;

GRANT EXECUTE ON FUNCTION public.get_fec_spending_by_purpose(text, integer)
  TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2c. get_fec_recent_expenditures: most-recent disbursements for a candidate's
--     AUTHORIZED committees, live from fec_expenditures, excluding memo_cd='X'
--     and superseded (cmte_id,file_num). committee name resolved via the most
--     recent fec_committees row for the cmte_id.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_fec_recent_expenditures(text, integer, integer);

CREATE OR REPLACE FUNCTION public.get_fec_recent_expenditures(
  p_fec_cand_id text,
  p_limit integer DEFAULT 50,
  p_cycle integer DEFAULT 2026
)
RETURNS TABLE(payee_name text, city text, state text, transaction_amt numeric,
              transaction_dt date, purpose text, category_desc text,
              committee_name text, cycle integer)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    fe.payee_name,
    fe.city,
    fe.state,
    fe.transaction_amt,
    fe.transaction_dt,
    fe.purpose,
    fe.category_desc,
    (SELECT c.cmte_name FROM public.fec_committees c
      WHERE c.cmte_id = fe.cmte_id ORDER BY c.cycle DESC LIMIT 1) AS committee_name,
    fe.cycle
  FROM public.fec_expenditures fe
  WHERE fe.cmte_id IN (
      SELECT cmte_id FROM public.fec_committees
      WHERE cand_id = p_fec_cand_id
        AND (designation IS NULL OR designation IN ('P','A'))
    )
    AND COALESCE(fe.memo_cd, '') <> 'X'
    AND NOT EXISTS (
      SELECT 1 FROM public.fec_superseded_filings sf
      WHERE sf.cmte_id = fe.cmte_id
        AND sf.file_num = fe.file_num
    )
    AND (p_cycle IS NULL OR fe.cycle = p_cycle)
  ORDER BY fe.transaction_dt DESC NULLS LAST
  LIMIT p_limit;
$function$;

GRANT EXECUTE ON FUNCTION public.get_fec_recent_expenditures(text, integer, integer)
  TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Refresh scheduling (pg_cron). Offset from the FEC finance MVs
--    (jobs 96/97 at :20 / :25) -> :30, 2x daily.
-- ----------------------------------------------------------------------------
SELECT cron.schedule(
  'refresh-fec-committee-payee-aggregate',
  '30 8,20 * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY public.fec_committee_payee_aggregate$$
);
