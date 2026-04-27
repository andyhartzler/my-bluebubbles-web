-- =====================================================================
-- 20260427_04_candidate_score_rubric.sql
--
-- Replaces the arbitrary "Young Democrat Score" + radar with a real
-- 10-category rubric. Each category is scored 0..10. Total /100 is the
-- new candidates.young_dem_score (cached for list views).
--
-- Categories (10):
--   democratic_affiliation      — auto. Dem=10, party_confidence-scaled otherwise
--   filed_for_office            — auto. filing_status='filed' → 10; withdrew → 0
--   incumbent_or_prior_office   — auto. incumbent=10, legislator_id no-incumbent=7,
--                                 prior winner from historical_candidates=5, prior
--                                 loser=3, none=0.
--   primary_voting_record       — auto. Last 4 cycles: voted/eligible × 10 from
--                                 mo_voter_file.voter_history (label LIKE primary).
--   general_voting_record       — auto. Same source, generals only.
--   voter_registration_tenure   — auto. years since mo_voter_file.registration_date:
--                                 <2yr=2, 2-5=5, 5-10=8, 10+=10.
--   fundraising_threshold       — auto. total_raised: 0=0, $1-5k=3, $5-25k=6,
--                                 $25-100k=8, $100k+=10.
--   fundraising_velocity        — auto. contribution_count: 0=0, 1-10=2, 10-50=5,
--                                 50-200=8, 200+=10.
--   moyd_membership             — auto. member_id IS NOT NULL → 10; else 0.
--   age_eligibility             — auto. estimated_age 14-36=10, 37-40=5, 41+=0.
--
-- Each component carries an `is_auto` flag (true by default). Exec
-- committee can override via the new CandidateRubricCard UI; overrides
-- land as is_auto=false rows that the recompute function leaves alone.
-- =====================================================================

SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------
-- 1. candidate_score_components — one row per (candidate_id, category)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.candidate_score_components (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id  uuid NOT NULL REFERENCES public.candidates(id) ON DELETE CASCADE,
  category      text NOT NULL,
  score         smallint NOT NULL CHECK (score BETWEEN 0 AND 10),
  is_auto       boolean NOT NULL DEFAULT true,
  computed_at   timestamptz NOT NULL DEFAULT now(),
  scored_by     uuid REFERENCES public.members(id) ON DELETE SET NULL,
  justification text,
  source_data   jsonb,
  UNIQUE (candidate_id, category)
);

CREATE INDEX IF NOT EXISTS idx_csc_candidate_id
  ON public.candidate_score_components (candidate_id);

ALTER TABLE public.candidate_score_components ENABLE ROW LEVEL SECURITY;

-- Reads: any authenticated user; matches the rest of candidate analytics.
DROP POLICY IF EXISTS csc_authenticated_read ON public.candidate_score_components;
CREATE POLICY csc_authenticated_read ON public.candidate_score_components
  FOR SELECT TO authenticated
  USING (true);

-- Writes: exec committee only. Falls back to current_user_is_superadmin()
-- for service flexibility.
DROP POLICY IF EXISTS csc_exec_write ON public.candidate_score_components;
CREATE POLICY csc_exec_write ON public.candidate_score_components
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = auth.uid() AND m.executive_committee = true
    )
    OR public.current_user_is_superadmin()
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = auth.uid() AND m.executive_committee = true
    )
    OR public.current_user_is_superadmin()
  );

DROP POLICY IF EXISTS csc_service_role ON public.candidate_score_components;
CREATE POLICY csc_service_role ON public.candidate_score_components
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 2. recompute_candidate_score — derives all 10 auto categories
-- ---------------------------------------------------------------------
-- Skips rows whose is_auto=false so manual overrides survive.
CREATE OR REPLACE FUNCTION public.recompute_candidate_score(p_candidate_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  c                 record;
  v                 record;
  primary_voted     int;
  primary_total     int;
  general_voted     int;
  general_total     int;
  reg_years         numeric;
  total_raised_num  numeric;
  contrib_count     int;
  est_age           int;
  party_score       smallint;
  filing_score      smallint;
  incumbent_score   smallint;
  reg_score         smallint;
  funding_score     smallint;
  velocity_score    smallint;
  membership_score  smallint;
  age_score         smallint;
  primary_score     smallint;
  general_score     smallint;
  rubric_total      int;
BEGIN
  SELECT * INTO c FROM public.candidates WHERE id = p_candidate_id;
  IF c IS NULL THEN RETURN; END IF;

  -- Voter file (may be null)
  SELECT * INTO v FROM public.mo_voter_file WHERE voter_id = c.mo_voter_file_id;

  -- ---- democratic_affiliation ----
  -- party_confidence ships as a text label ('high'/'medium'/'low' or empty
  -- for non-Dem rows). We map it to a 0–10 score for non-Dem candidates so
  -- a high-confidence Independent who caucuses with Dems isn't penalized
  -- as hard as a Republican.
  party_score := CASE
    WHEN c.party = 'Democratic' THEN 10
    WHEN c.party_confidence = 'high' THEN 7
    WHEN c.party_confidence = 'medium' THEN 4
    WHEN c.party_confidence = 'low' THEN 2
    ELSE 0
  END;

  -- ---- filed_for_office ----
  filing_score := CASE
    WHEN c.filing_status = 'filed' THEN 10
    WHEN c.filing_status = 'withdrew' THEN 0
    WHEN c.filing_status = 'pending' THEN 5
    ELSE 0
  END;

  -- ---- incumbent_or_prior_office ----
  incumbent_score := CASE
    WHEN c.incumbent = true THEN 10
    WHEN c.legislator_id IS NOT NULL THEN 7
    WHEN EXISTS (
      SELECT 1 FROM public.election_history eh
      WHERE lower(eh.candidate_name) = lower(c.name)
        AND eh.winner = true
    ) THEN 5
    WHEN EXISTS (
      SELECT 1 FROM public.election_history eh
      WHERE lower(eh.candidate_name) = lower(c.name)
    ) THEN 3
    ELSE 0
  END;

  -- ---- primary + general voting record (last 4 cycles ≈ 8 years) ----
  primary_voted := 0; primary_total := 0;
  general_voted := 0; general_total := 0;

  IF v.voter_history IS NOT NULL THEN
    SELECT
      COUNT(*) FILTER (WHERE elem->>'label' ILIKE '%primary%'),
      0  -- "total primaries available" computed below as years × 2 (state+fed)
    INTO primary_voted, primary_total
    FROM jsonb_array_elements(v.voter_history) elem
    WHERE (elem->>'date')::date >= now() - interval '8 years';

    SELECT
      COUNT(*) FILTER (WHERE elem->>'label' ILIKE '%general%'),
      0
    INTO general_voted, general_total
    FROM jsonb_array_elements(v.voter_history) elem
    WHERE (elem->>'date')::date >= now() - interval '8 years';

    -- 4 cycles x 2 primary types (state/federal) = 8 chances; cap voted there.
    primary_total := 8;
    general_total := 4;
  END IF;

  primary_score := CASE
    WHEN primary_total > 0 THEN LEAST(10, (primary_voted::numeric / primary_total * 10))::smallint
    ELSE 0
  END;
  general_score := CASE
    WHEN general_total > 0 THEN LEAST(10, (general_voted::numeric / general_total * 10))::smallint
    ELSE 0
  END;

  -- ---- voter_registration_tenure ----
  reg_years := CASE
    WHEN v.registration_date IS NOT NULL
      THEN EXTRACT(EPOCH FROM (now() - v.registration_date)) / 31557600
    ELSE NULL
  END;
  reg_score := CASE
    WHEN reg_years IS NULL THEN 0
    WHEN reg_years >= 10 THEN 10
    WHEN reg_years >= 5  THEN 8
    WHEN reg_years >= 2  THEN 5
    ELSE 2
  END;

  -- ---- fundraising_threshold ----
  total_raised_num := COALESCE(c.total_raised, 0);
  funding_score := CASE
    WHEN total_raised_num >= 100000 THEN 10
    WHEN total_raised_num >=  25000 THEN 8
    WHEN total_raised_num >=   5000 THEN 6
    WHEN total_raised_num >=   1000 THEN 3
    ELSE 0
  END;

  -- ---- fundraising_velocity ----
  contrib_count := COALESCE(c.contribution_count, 0);
  velocity_score := CASE
    WHEN contrib_count >= 200 THEN 10
    WHEN contrib_count >=  50 THEN 8
    WHEN contrib_count >=  10 THEN 5
    WHEN contrib_count >=   1 THEN 2
    ELSE 0
  END;

  -- ---- moyd_membership ----
  membership_score := CASE WHEN c.member_id IS NOT NULL THEN 10 ELSE 0 END;

  -- ---- age_eligibility ----
  est_age := COALESCE(c.estimated_age, 99);
  age_score := CASE
    WHEN est_age BETWEEN 14 AND 36 THEN 10
    WHEN est_age BETWEEN 37 AND 40 THEN 5
    ELSE 0
  END;

  -- ---- upsert all 10 components ----
  -- For each category: only overwrite when is_auto=true (preserve overrides).
  WITH inputs(category, score, source) AS (
    VALUES
      ('democratic_affiliation',     party_score,
        jsonb_build_object('party', c.party, 'party_confidence', c.party_confidence)),
      ('filed_for_office',           filing_score,
        jsonb_build_object('filing_status', c.filing_status)),
      ('incumbent_or_prior_office',  incumbent_score,
        jsonb_build_object('incumbent', c.incumbent, 'legislator_id', c.legislator_id)),
      ('primary_voting_record',      primary_score,
        jsonb_build_object('voted', primary_voted, 'total', primary_total)),
      ('general_voting_record',      general_score,
        jsonb_build_object('voted', general_voted, 'total', general_total)),
      ('voter_registration_tenure',  reg_score,
        jsonb_build_object('registration_date', v.registration_date, 'years', reg_years)),
      ('fundraising_threshold',      funding_score,
        jsonb_build_object('total_raised', total_raised_num)),
      ('fundraising_velocity',       velocity_score,
        jsonb_build_object('contribution_count', contrib_count)),
      ('moyd_membership',            membership_score,
        jsonb_build_object('member_id', c.member_id)),
      ('age_eligibility',            age_score,
        jsonb_build_object('estimated_age', est_age))
  )
  INSERT INTO public.candidate_score_components
    (candidate_id, category, score, is_auto, source_data)
  SELECT p_candidate_id, i.category, i.score, true, i.source
    FROM inputs i
  ON CONFLICT (candidate_id, category) DO UPDATE
    SET score       = EXCLUDED.score,
        source_data = EXCLUDED.source_data,
        computed_at = now()
    WHERE candidate_score_components.is_auto = true;

  -- ---- cache the rolled-up total back onto candidates.young_dem_score ----
  SELECT SUM(score) INTO rubric_total
    FROM public.candidate_score_components WHERE candidate_id = p_candidate_id;
  UPDATE public.candidates
     SET young_dem_score = LEAST(100, COALESCE(rubric_total, 0))
   WHERE id = p_candidate_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recompute_candidate_score(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Trigger to recompute on candidate row updates of relevant cols
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trigger_recompute_score()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.recompute_candidate_score(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_recompute_score ON public.candidates;
CREATE TRIGGER trg_recompute_score
  AFTER INSERT OR UPDATE OF
    party, party_confidence, filing_status, incumbent, legislator_id,
    total_raised, contribution_count, member_id, estimated_age,
    mo_voter_file_id
  ON public.candidates
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trigger_recompute_score();

-- ---------------------------------------------------------------------
-- 4. Backfill all 520 candidates
-- ---------------------------------------------------------------------
DO $$
DECLARE
  cid uuid;
BEGIN
  FOR cid IN SELECT id FROM public.candidates LOOP
    PERFORM public.recompute_candidate_score(cid);
  END LOOP;
END $$;

-- =====================================================================
-- End migration.
-- =====================================================================
