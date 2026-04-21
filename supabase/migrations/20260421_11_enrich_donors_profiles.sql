-- 20260421_11_enrich_donors_profiles.sql
-- Enrich MOYD's own donors (49) + donor_profiles (49) with voter-file DOBs.
-- These are small tables; a single SQL statement handles both.

BEGIN;

-- Step 1: populate first_name/last_name on donors from the `name` text field
UPDATE public.donors
SET first_name = split_part(trim(name), ' ', 1),
    last_name  = regexp_replace(trim(name), '^\S+\s+', '')
WHERE first_name IS NULL AND name IS NOT NULL AND name <> '';

-- Step 2: match donors (49) — use name + zip_code
WITH match_candidates AS (
  SELECT d.id AS donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY d.id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY d.id) AS n
  FROM public.donors d
  JOIN public.mo_voter_file v
    ON lower(d.first_name) = lower(v.first_name)
   AND lower(d.last_name)  = lower(v.last_name)
   AND d.zip_code           = v.residential_zip5
  WHERE d.state = 'MO'
    AND v.birth_year IS NOT NULL
)
UPDATE public.donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1;

-- Step 3: match donor_profiles (49) — use first_name/last_name/zip
WITH match_candidates AS (
  SELECT p.id AS profile_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY p.id) AS n
  FROM public.donor_profiles p
  JOIN public.mo_voter_file v
    ON lower(p.first_name) = lower(v.first_name)
   AND lower(p.last_name)  = lower(v.last_name)
   AND p.zip                = v.residential_zip5
  WHERE p.state = 'MO'
    AND v.birth_year IS NOT NULL
)
UPDATE public.donor_profiles p
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file'
FROM match_candidates mc
WHERE p.id = mc.profile_id AND mc.rn = 1 AND mc.n = 1;

COMMIT;

SELECT 'donors' AS t, COUNT(*) total, COUNT(date_of_birth) with_dob FROM public.donors
UNION ALL
SELECT 'donor_profiles', COUNT(*), COUNT(date_of_birth) FROM public.donor_profiles;
