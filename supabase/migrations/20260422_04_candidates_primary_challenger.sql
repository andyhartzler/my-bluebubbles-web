-- 2026-04-22 Candidates Phase 1 — primary-challenger detection
--
-- Supports the new "Young Dems primarying incumbent Democrats" view on the
-- Candidates page. Adds an `incumbent_party` column (backfilled for every
-- current YD whose office+district also contains an incumbent Democrat) and
-- a `get_yd_primary_challengers()` RPC the Flutter split-screen layout
-- calls to render the dedicated primary-challenger view.
--
-- Data audit that motivated this:
--   520 candidates, 32 is_young_dem=true, 29 incumbent=true, all incumbents
--   are party='Democratic', 5 distinct offices.

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. incumbent_party column + supporting index
-- ----------------------------------------------------------------------------

ALTER TABLE public.candidates
  ADD COLUMN IF NOT EXISTS incumbent_party text;

COMMENT ON COLUMN public.candidates.incumbent_party IS
  'Party of the incumbent currently holding this seat. Populated for
   challengers (is_young_dem=true + party=Democratic) whose (office,
   district) pair contains another candidate with incumbent=true. NULL
   for everyone else.';

CREATE INDEX IF NOT EXISTS idx_candidates_office_district
  ON public.candidates (office, district)
  WHERE district IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 2. Backfill incumbent_party for current YD challengers
-- ----------------------------------------------------------------------------

UPDATE public.candidates yd
SET incumbent_party = inc.party
FROM public.candidates inc
WHERE yd.is_young_dem = true
  AND yd.party = 'Democratic'
  AND inc.office    = yd.office
  AND inc.district  = yd.district
  AND inc.incumbent = true
  AND inc.id       != yd.id;

-- ----------------------------------------------------------------------------
-- 3. get_yd_primary_challengers() RPC
-- ----------------------------------------------------------------------------
-- SECURITY DEFINER so RLS on `candidates` (newly enabled in phase 1) can
-- still be tight for direct SELECTs while letting the app surface this
-- cross-reference. Returns one row per (young-dem-challenger,
-- incumbent-dem) pair; if a YD is running against multiple Dem incumbents
-- (shouldn't happen but possible with data glitches) you get multiple
-- rows.

CREATE OR REPLACE FUNCTION public.get_yd_primary_challengers()
RETURNS TABLE (
  challenger_id     text,
  challenger_name   text,
  incumbent_id      text,
  incumbent_name    text,
  office            text,
  district          text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    yd.id::text     AS challenger_id,
    yd.name         AS challenger_name,
    inc.id::text    AS incumbent_id,
    inc.name        AS incumbent_name,
    yd.office,
    yd.district
  FROM public.candidates yd
  JOIN public.candidates inc
    ON  inc.office   = yd.office
    AND inc.district = yd.district
    AND inc.party    = 'Democratic'
    AND inc.incumbent = true
    AND inc.id       != yd.id
  WHERE yd.is_young_dem = true
    AND yd.party        = 'Democratic'
    AND yd.district IS NOT NULL
  ORDER BY yd.office, yd.district, yd.name;
$$;

COMMENT ON FUNCTION public.get_yd_primary_challengers() IS
  'Return the set of (MOYD Young Democrat, incumbent Democrat) pairs
   running in the same seat. Used by the Candidates page
   primary-challenger view. SECURITY DEFINER so RLS tightening on
   `candidates` does not break this cross-reference.';

REVOKE ALL ON FUNCTION public.get_yd_primary_challengers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_yd_primary_challengers()
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
