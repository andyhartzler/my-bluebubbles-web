-- 20260421_10_enrich_donor_enrichment.sql
-- Enrich donor_enrichment (470k rows) with voter file matches.
-- Name shape: full_name as single text (e.g. "JOHN SMITH"); we split on first space.
-- Scope: MO state only, individuals only (skip LLC/PAC/COMMITTEE/etc).

BEGIN;

SET LOCAL statement_timeout = '30min';

-- Step 1: derive first/last name into temp columns on the fly via the query
-- Step 2: exact match first_name + last_name + zip (unique only)

WITH candidates AS (
  SELECT e.id AS enr_id,
         lower(split_part(trim(e.full_name), ' ', 1))              AS fn,
         lower(regexp_replace(trim(e.full_name), '^\S+\s+', ''))   AS ln,
         e.current_zip
  FROM public.donor_enrichment e
  WHERE e.mo_voter_file_id IS NULL
    AND e.current_state = 'MO'
    AND e.full_name IS NOT NULL AND e.full_name <> ''
    AND e.current_zip IS NOT NULL AND e.current_zip <> ''
    AND e.full_name NOT ILIKE '%LLC%' AND e.full_name NOT ILIKE '%PAC%'
    AND e.full_name NOT ILIKE '%INC%' AND e.full_name NOT ILIKE '%CORP%'
    AND e.full_name NOT ILIKE '%COMPANY%' AND e.full_name NOT ILIKE '%COMMITTEE%'
    AND e.full_name NOT ILIKE '%UNION%' AND e.full_name NOT ILIKE '%FUND%'
    AND e.full_name NOT ILIKE '%FOUNDATION%' AND e.full_name NOT ILIKE '%ASSOC%'
),
match_candidates AS (
  SELECT c.enr_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY c.enr_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY c.enr_id) AS n
  FROM candidates c
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = c.fn
   AND lower(v.last_name)  = c.ln
   AND v.residential_zip5   = c.current_zip
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.donor_enrichment e
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    dob_year         = mc.birth_year
FROM match_candidates mc
WHERE e.id = mc.enr_id AND mc.rn = 1 AND mc.n = 1;

COMMIT;

SELECT
  COUNT(*) AS total,
  COUNT(mo_voter_file_id) AS matched,
  COUNT(date_of_birth) AS with_dob
FROM public.donor_enrichment;
