-- =====================================================================
-- 20260427_01_candidate_mec_committee.sql
--
-- Fix the "blank navy → 2 min wait → Not Found" symptom on the donor
-- and payee detail screens, plus the multi-second Money tab loads on
-- high-volume committees.
--
-- Root cause: the donor / payee detail RPCs and several Money tab
-- aggregates do
--   LEFT JOIN candidates c ON me.mec_id = ANY(c.mec_committee_ids)
-- The GIN index on `candidates.mec_committee_ids` only accelerates the
-- shape `WHERE <literal> = ANY(c.mec_committee_ids)` — when `me.mec_id`
-- is the OUTER row of a nested loop the planner falls back to a join
-- filter and seq-scans the 520-row candidates table once per outer row.
-- For high-volume vendors (USPS = 5k expenditure rows, ActBlue = millions
-- of contribution rows) that's 2.6M+ comparisons → 569ms-3.7s per call.
-- The Supabase client times out at the 504 boundary and the screen
-- silently renders "Not Found".
--
-- Fix: a normalized two-column lookup table + b-tree index on mec_id.
-- Hash-joinable, sub-50ms on the same workload.
-- =====================================================================

SET search_path = public, pg_temp;

CREATE TABLE IF NOT EXISTS public.candidate_mec_committee (
  mec_id       text NOT NULL,
  candidate_id uuid NOT NULL REFERENCES public.candidates(id) ON DELETE CASCADE,
  PRIMARY KEY (mec_id, candidate_id)
);

CREATE INDEX IF NOT EXISTS idx_cmc_mec_id
  ON public.candidate_mec_committee (mec_id);

CREATE INDEX IF NOT EXISTS idx_cmc_candidate_id
  ON public.candidate_mec_committee (candidate_id);

-- Backfill from the existing array column. Idempotent: ON CONFLICT
-- DO NOTHING in case partial data is already present.
INSERT INTO public.candidate_mec_committee (mec_id, candidate_id)
SELECT DISTINCT unnest(mec_committee_ids), id
  FROM public.candidates
 WHERE mec_committee_ids IS NOT NULL
   AND array_length(mec_committee_ids, 1) > 0
ON CONFLICT (mec_id, candidate_id) DO NOTHING;

-- Trigger to keep candidate_mec_committee in sync with future updates
-- of candidates.mec_committee_ids. Diff the OLD vs NEW arrays so we
-- only touch the rows that actually changed.
CREATE OR REPLACE FUNCTION public.fn_sync_candidate_mec_committee()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  old_set text[];
  new_set text[];
BEGIN
  old_set := COALESCE(OLD.mec_committee_ids, ARRAY[]::text[]);
  new_set := COALESCE(NEW.mec_committee_ids, ARRAY[]::text[]);

  -- Remove rows whose mec_id was dropped from the array.
  IF TG_OP IN ('UPDATE','DELETE') THEN
    DELETE FROM public.candidate_mec_committee
     WHERE candidate_id = OLD.id
       AND mec_id <> ALL (new_set);
  END IF;

  -- Insert any newly-added mec_ids.
  IF TG_OP IN ('INSERT','UPDATE') THEN
    INSERT INTO public.candidate_mec_committee (mec_id, candidate_id)
    SELECT mec, NEW.id
      FROM unnest(new_set) AS mec
     WHERE mec <> ALL (old_set)
    ON CONFLICT (mec_id, candidate_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_cmc ON public.candidates;
CREATE TRIGGER trg_sync_cmc
  AFTER INSERT OR UPDATE OF mec_committee_ids OR DELETE
  ON public.candidates
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_candidate_mec_committee();

-- RLS: read-allowed for any user who can read candidates. Mirror the
-- existing candidates RLS by allowing authenticated to SELECT freely
-- (the table is a view-equivalent of an already-readable column).
ALTER TABLE public.candidate_mec_committee ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cmc_authenticated_read ON public.candidate_mec_committee;
CREATE POLICY cmc_authenticated_read ON public.candidate_mec_committee
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS cmc_service_role ON public.candidate_mec_committee;
CREATE POLICY cmc_service_role ON public.candidate_mec_committee
  FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT SELECT ON public.candidate_mec_committee TO authenticated;

-- =====================================================================
-- End migration.
-- =====================================================================
