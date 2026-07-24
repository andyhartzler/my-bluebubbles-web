-- 20260723_03_fec_independent_expenditures.sql
-- FEC federal outside-spending capture: independent expenditures (Schedule E /
-- Form F24 24/48-hour notices) TARGETING our federal candidates.
--
-- Source: FEC bulk independent_expenditure_<cycle>.csv. One row per reported
-- IE transaction line. The spender is the committee (spe_id/spe_nam); the
-- target is the candidate (cand_id/cand_name); sup_opp flags support vs oppose.
--
-- GRANTS/RLS POSTURE: tightened (least-privilege), matching the
-- 20260723_tighten_new_table_grants.sql posture -- NOT the older permissive
-- fec_contributions/fec_expenditures pattern that granted INSERT/UPDATE to anon
-- with a FOR ALL USING(true) policy. Here:
--   * anon / authenticated  -> SELECT only, via a FOR SELECT USING(true) policy
--   * service_role          -> full write, via a dedicated FOR ALL policy
--   * postgres              -> owner (bulk loader / daily sync runs as postgres)

BEGIN;

CREATE TABLE IF NOT EXISTS public.fec_independent_expenditures (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cmte_id          text,            -- spe_id  : the spending committee
  spender_name     text,            -- spe_nam
  cand_id          text,            -- cand_id : the targeted candidate
  candidate_name   text,            -- cand_name
  support_oppose   char(1),         -- sup_opp : 'S' support / 'O' oppose
  transaction_dt   date,            -- exp_date
  transaction_amt  numeric,         -- exp_amo
  purpose          text,            -- pur
  payee_name       text,            -- pay
  sub_id           text UNIQUE,     -- synthetic: file_num || '-' || tran_id
  file_num         bigint,          -- file_num of the filing carrying this row
  amndt_ind        text,            -- N new / A amended / T terminated
  memo_cd          text,            -- (not present in bulk IE file; kept for parity)
  cycle            int,             -- 2026 / 2024
  is_notice        boolean,         -- true = F24 24/48-hr notice, false = periodic report
  -- provenance columns supporting the documented amendment/notice dedup rule
  tran_id          text,
  prev_file_num    bigint,          -- amendment linkage (0/blank when none)
  form_type        text,            -- F24 / F3X / F3 / F3P / F5 / F7 ...
  cand_office_state text,           -- can_office_state (used for blank-cand_id MO flags)
  agg_amount       numeric,         -- agg_amo (cycle-to-date aggregate as filed)
  election_type    text,            -- ele_type (P/G/S/R ...)
  needs_review     boolean DEFAULT false,  -- flagged: matched by name+MO, cand_id blank
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fec_ie_cand_cycle
  ON public.fec_independent_expenditures USING btree (cand_id, cycle);
CREATE INDEX IF NOT EXISTS idx_fec_ie_cmte_cycle
  ON public.fec_independent_expenditures USING btree (cmte_id, cycle);

ALTER TABLE public.fec_independent_expenditures ENABLE ROW LEVEL SECURITY;

-- Read: anon + authenticated, SELECT only.
DROP POLICY IF EXISTS fec_independent_expenditures_read ON public.fec_independent_expenditures;
CREATE POLICY fec_independent_expenditures_read
  ON public.fec_independent_expenditures
  FOR SELECT TO anon, authenticated
  USING (true);

-- Write: service_role only.
DROP POLICY IF EXISTS fec_independent_expenditures_service_write ON public.fec_independent_expenditures;
CREATE POLICY fec_independent_expenditures_service_write
  ON public.fec_independent_expenditures
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- Grants mirror the tightened posture: read-only for anon/authenticated.
GRANT SELECT ON public.fec_independent_expenditures TO anon;
GRANT SELECT ON public.fec_independent_expenditures TO authenticated;
GRANT ALL    ON public.fec_independent_expenditures TO service_role;
GRANT ALL    ON public.fec_independent_expenditures TO postgres;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------
-- RPC: get_fec_outside_spending(p_fec_cand_id text, p_cycle int DEFAULT 2026)
-- Support/oppose totals + per-spender breakdown of independent expenditures
-- TARGETING a federal candidate for a given cycle. EXECUTE granted to
-- authenticated + anon, matching the sibling get_fec_* RPCs.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fec_outside_spending(
  p_fec_cand_id text,
  p_cycle       int DEFAULT 2026
)
RETURNS json
LANGUAGE sql
STABLE
AS $function$
  WITH ie AS (
    SELECT cmte_id, spender_name, support_oppose, transaction_amt, transaction_dt
    FROM public.fec_independent_expenditures
    WHERE cand_id = p_fec_cand_id AND cycle = p_cycle
  )
  SELECT json_build_object(
    'fec_cand_id',       p_fec_cand_id,
    'cycle',             p_cycle,
    'support_total',     COALESCE(SUM(transaction_amt) FILTER (WHERE support_oppose = 'S'), 0),
    'oppose_total',      COALESCE(SUM(transaction_amt) FILTER (WHERE support_oppose = 'O'), 0),
    'total',             COALESCE(SUM(transaction_amt), 0),
    'transaction_count', COUNT(*),
    'spender_count',     COUNT(DISTINCT cmte_id),
    'by_spender', COALESCE((
      SELECT json_agg(s ORDER BY s.amount DESC)
      FROM (
        SELECT
          cmte_id                 AS spender_id,
          MAX(spender_name)       AS spender_name,
          support_oppose,
          SUM(transaction_amt)    AS amount,
          COUNT(*)                AS transaction_count,
          MAX(transaction_dt)     AS latest_date
        FROM ie
        GROUP BY cmte_id, support_oppose
      ) s
    ), '[]'::json)
  )
  FROM ie;
$function$;

GRANT EXECUTE ON FUNCTION public.get_fec_outside_spending(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_fec_outside_spending(text, int) TO anon;
GRANT EXECUTE ON FUNCTION public.get_fec_outside_spending(text, int) TO service_role;

NOTIFY pgrst, 'reload schema';
