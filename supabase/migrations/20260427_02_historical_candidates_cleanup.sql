-- =====================================================================
-- 20260427_02_historical_candidates_cleanup.sql
--
-- Fixes the District tab → Past Candidates section:
--   (1) duplicate tiles for the same person across cycles or for the
--       same year, and
--   (2) a single "Libertarian" tile that, when clicked, groups every
--       Libertarian candidate statewide.
--
-- Root cause is data quality, not query shape: the scraper that
-- populated `historical_candidates` and `election_history` left two
-- categories of garbage:
--   a. "Bare-party" rows where the name slot is just "Libertarian" /
--      "Republican" / "Democrat" / "Submit photo" — created when the
--      Ballotpedia row had no parsed candidate name.
--   b. Multiple rows per real person across cycles, each with its own
--      (name, party, district) tuple — usually because party was
--      missing on one cycle and got stored as "Unknown".
--
-- This migration:
--   1. Quarantines the bare-party + single-token rows by deleting them
--      (they have no recoverable real candidate behind them).
--   2. Adds a CHECK constraint to prevent future inserts of those
--      pseudo-names.
--   3. Merges duplicate (lower(name), office, district) groups: union
--      the years_ran arrays, prefer the non-Unknown party, sum
--      total_races, keep the most recently-updated photo_url.
--   4. Adds a unique index on (lower(name), office, district) so the
--      scraper has to upsert next time instead of insert-each-cycle.
--   5. Updates `get_district_historical_candidates` to require an
--      `p_office` argument — without it, "District 81 State Rep"
--      collided with "District 81 State Senate" and dumped both
--      into the same panel.
--
-- After this, the Dart caller must pass `p_office`. That's a separate
-- code change in the same commit landing alongside this migration.
-- =====================================================================

SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------
-- 1. Quarantine the bare-name garbage.
-- ---------------------------------------------------------------------
-- Capture what we're about to delete so a future audit can recover.
CREATE TABLE IF NOT EXISTS public._historical_candidates_quarantine (
  LIKE public.historical_candidates INCLUDING ALL
);

INSERT INTO public._historical_candidates_quarantine
SELECT * FROM public.historical_candidates
 WHERE name IN ('Libertarian','Republican','Democrat','Constitution',
                'Independent','Green','Submit photo','Write-in')
    OR name !~ ' ';  -- single-token names = no first/last split

DELETE FROM public.historical_candidates
 WHERE name IN ('Libertarian','Republican','Democrat','Constitution',
                'Independent','Green','Submit photo','Write-in')
    OR name !~ ' ';

-- Same scrub on election_history (the candidate-detail screen reads
-- this table; without it, a phantom Libertarian tile click would still
-- fan out across districts).
DELETE FROM public.election_history
 WHERE candidate_name IN ('Libertarian','Republican','Democrat',
                          'Constitution','Independent','Green',
                          'Submit photo','Write-in')
    OR candidate_name !~ ' ';

-- ---------------------------------------------------------------------
-- 2. Hard guard at insert.
-- ---------------------------------------------------------------------
ALTER TABLE public.historical_candidates
  DROP CONSTRAINT IF EXISTS historical_candidates_name_real_chk;
ALTER TABLE public.historical_candidates
  ADD CONSTRAINT historical_candidates_name_real_chk
  CHECK (
    name NOT IN ('Libertarian','Republican','Democrat','Constitution',
                 'Independent','Green','Submit photo','Write-in')
    AND name ~ ' '
  );

-- ---------------------------------------------------------------------
-- 3. Merge duplicate (lower(name), office, district) groups.
-- ---------------------------------------------------------------------
-- Two-step: first flatten years_ran inline per row, then aggregate.
-- Picks the row with the most informative party (non-Unknown wins;
-- otherwise just keep MAX), unions years_ran arrays, and sums
-- total_races.
WITH years_flat AS (
  SELECT id, lower(name) AS lname, office, district, name, party,
         total_races, photo_url, created_at,
         y AS year_value
    FROM public.historical_candidates
    LEFT JOIN LATERAL unnest(years_ran) AS y ON true
),
merged AS (
  SELECT
    lname,
    office,
    district,
    COALESCE(MAX(NULLIF(party, 'Unknown')), 'Unknown') AS canonical_party,
    array_agg(DISTINCT year_value ORDER BY year_value)
      FILTER (WHERE year_value IS NOT NULL)
                                                         AS canonical_years_ran,
    SUM(DISTINCT total_races)                            AS canonical_total_races,
    MAX(photo_url)                                       AS canonical_photo_url
  FROM years_flat
  GROUP BY lname, office, district
  HAVING COUNT(DISTINCT id) > 1
)
UPDATE public.historical_candidates t
   SET party       = m.canonical_party,
       years_ran   = m.canonical_years_ran,
       total_races = m.canonical_total_races,
       photo_url   = COALESCE(t.photo_url, m.canonical_photo_url)
  FROM merged m
 WHERE lower(t.name) = m.lname
   AND t.office = m.office
   AND t.district = m.district;

-- Now drop the duplicate rows, keeping one per (lower(name), office, district).
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY lower(name), office, district
           ORDER BY (party <> 'Unknown') DESC, created_at DESC NULLS LAST, id
         ) AS rn
    FROM public.historical_candidates
)
DELETE FROM public.historical_candidates
 WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- ---------------------------------------------------------------------
-- 4. Unique index — scraper now has to upsert.
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_historical_candidates_name_office_district
  ON public.historical_candidates (lower(name), office, district);

-- ---------------------------------------------------------------------
-- 5. RPC: scope by office in addition to district.
-- ---------------------------------------------------------------------
-- Drop both the legacy single-arg signature and any prior 2-arg version
-- so the new definition wins cleanly. Callers must pass p_office now.
DROP FUNCTION IF EXISTS public.get_district_historical_candidates(text);
DROP FUNCTION IF EXISTS public.get_district_historical_candidates(text, text);

CREATE OR REPLACE FUNCTION public.get_district_historical_candidates(
  p_district text,
  p_office   text
)
RETURNS TABLE (
  id          uuid,
  name        text,
  party       text,
  office      text,
  district    text,
  years_ran   integer[],
  total_races integer,
  photo_url   text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, name, party, office, district, years_ran, total_races, photo_url
    FROM public.historical_candidates
   WHERE district = p_district
     AND office   = p_office
   ORDER BY (party <> 'Unknown') DESC,
            COALESCE((SELECT MAX(y) FROM unnest(years_ran) y), 0) DESC,
            name;
$$;

REVOKE EXECUTE ON FUNCTION public.get_district_historical_candidates(text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_district_historical_candidates(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 6. Profile-by-id RPC so the click handler can scope by uuid instead
--    of bare name (which is how Libertarian fanned across the state).
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_historical_candidate_profile_by_id(uuid);
CREATE OR REPLACE FUNCTION public.get_historical_candidate_profile_by_id(
  p_id uuid
)
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH hc AS (
    SELECT * FROM public.historical_candidates WHERE id = p_id
  ),
  history AS (
    SELECT eh.*
      FROM public.election_history eh
      JOIN hc ON lower(eh.candidate_name) = lower(hc.name)
             AND eh.office   = hc.office
             AND eh.district = hc.district
  )
  SELECT json_build_object(
    'id',          (SELECT id          FROM hc),
    'name',        (SELECT name        FROM hc),
    'party',       (SELECT party       FROM hc),
    'office',      (SELECT office      FROM hc),
    'district',    (SELECT district    FROM hc),
    'years_ran',   (SELECT years_ran   FROM hc),
    'total_races', (SELECT total_races FROM hc),
    'photo_url',   (SELECT photo_url   FROM hc),
    'history',     (SELECT COALESCE(json_agg(row_to_json(history) ORDER BY election_year DESC), '[]'::json) FROM history)
  );
$$;

REVOKE EXECUTE ON FUNCTION public.get_historical_candidate_profile_by_id(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_historical_candidate_profile_by_id(uuid) TO authenticated, service_role;

-- =====================================================================
-- End migration.
-- =====================================================================
