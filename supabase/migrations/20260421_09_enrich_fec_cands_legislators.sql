-- 20260421_09_enrich_fec_cands_legislators.sql
-- Enrich fec_candidates (1113) and legislation_legislators (193) with voter file DOBs.
BEGIN;

-- ─── fec_candidates ─────────────────────────────────────────────────
-- cand_name format: "LASTNAME, FIRSTNAME MIDDLE" (standard FEC shape)
-- Split into first_name / last_name columns we added in migration 02.
UPDATE public.fec_candidates
SET last_name  = split_part(cand_name, ',', 1),
    first_name = split_part(trim(split_part(cand_name, ',', 2)), ' ', 1)
WHERE first_name IS NULL AND cand_name IS NOT NULL AND cand_name LIKE '%,%';

-- Match MO FEC candidates against voter file (only accept unique matches)
WITH match_candidates AS (
  SELECT f.id AS fec_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY f.id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY f.id) AS n
  FROM public.fec_candidates f
  JOIN public.mo_voter_file v
    ON lower(f.first_name) = lower(v.first_name)
   AND lower(f.last_name)  = lower(v.last_name)
   AND (f.state = 'MO' OR lower(v.county) IS NOT NULL)
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.fec_candidates f
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file'
FROM match_candidates mc
WHERE f.id = mc.fec_id AND mc.rn = 1 AND mc.n = 1;

-- ─── legislation_legislators ────────────────────────────────────────
-- This table has first_name + last_name columns already. No city/zip though,
-- so use name-only unique matches scoped by state (everyone in this table is MO).
WITH match_candidates AS (
  SELECT l.id AS leg_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY l.id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY l.id) AS n
  FROM public.legislation_legislators l
  JOIN public.mo_voter_file v
    ON lower(l.first_name) = lower(v.first_name)
   AND lower(l.last_name)  = lower(v.last_name)
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.legislation_legislators l
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file'
FROM match_candidates mc
WHERE l.id = mc.leg_id AND mc.rn = 1 AND mc.n = 1;

COMMIT;

SELECT 'fec_candidates' AS t, COUNT(*) total, COUNT(date_of_birth) with_dob FROM public.fec_candidates
UNION ALL
SELECT 'legislation_legislators', COUNT(*), COUNT(date_of_birth) FROM public.legislation_legislators;
