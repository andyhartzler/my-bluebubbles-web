-- 20260421_08_enrich_mec_donors.sql
-- Backfill DOB on mec_donors (1M rows) from the voter file.
-- Strategy:
--   1. Mark non-individuals + non-MO + corporate-looking rows as 'not_applicable'
--   2. SQL pass: exact (first, last, zip) match where unique
--   3. (Python follow-up: nickname expansion for the remainder)

BEGIN;

-- Step 1: not_applicable for everyone we won't match
UPDATE public.mec_donors
SET match_status = 'not_applicable'
WHERE match_status IS NULL
  AND (
       donor_type <> 'individual'
    OR state IS DISTINCT FROM 'MO'
    OR first_name IS NULL OR last_name IS NULL
    OR zip IS NULL OR zip = ''
  );

-- Step 2: pending on everyone else
UPDATE public.mec_donors
SET match_status = 'pending'
WHERE match_status IS NULL;

-- Step 3: exact match on (first, last, zip) — unique only
WITH match_candidates AS (
  SELECT d.id AS donor_id,
         v.voter_id,
         v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY d.id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY d.id) AS n_matches
  FROM public.mec_donors d
  JOIN public.mo_voter_file v
    ON lower(d.first_name) = lower(v.first_name)
   AND lower(d.last_name)  = lower(v.last_name)
   AND d.zip                = v.residential_zip5
  WHERE d.match_status = 'pending'
    AND v.birth_year IS NOT NULL
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n_matches = 1;

COMMIT;

-- Status rollup
SELECT match_status, COUNT(*) FROM public.mec_donors GROUP BY 1 ORDER BY 2 DESC;
