-- 20260421_02_universal_dob_columns.sql
-- Add date_of_birth + mo_voter_file_id + dob_source to every person-keyed table
-- that lacks them, so the PSR voter-file backfill can run against a uniform schema.

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- historical_candidates: has `name` only, no DOB, no voter link
ALTER TABLE public.historical_candidates
  ADD COLUMN IF NOT EXISTS first_name       text,
  ADD COLUMN IF NOT EXISTS last_name        text,
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text,
  ADD COLUMN IF NOT EXISTS is_young_dem     boolean;

ALTER TABLE public.historical_candidates
  DROP CONSTRAINT IF EXISTS historical_candidates_dob_source_check;
ALTER TABLE public.historical_candidates
  ADD CONSTRAINT historical_candidates_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- donor_profiles (49 rows): first/last + zip exist; no DOB
ALTER TABLE public.donor_profiles
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text;

ALTER TABLE public.donor_profiles
  DROP CONSTRAINT IF EXISTS donor_profiles_dob_source_check;
ALTER TABLE public.donor_profiles
  ADD CONSTRAINT donor_profiles_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- mec_donors (1M rows): huge; add DOB + match_status for batched matching
ALTER TABLE public.mec_donors
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text,
  ADD COLUMN IF NOT EXISTS match_status     text;

ALTER TABLE public.mec_donors
  DROP CONSTRAINT IF EXISTS mec_donors_dob_source_check;
ALTER TABLE public.mec_donors
  ADD CONSTRAINT mec_donors_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));
ALTER TABLE public.mec_donors
  DROP CONSTRAINT IF EXISTS mec_donors_match_status_check;
ALTER TABLE public.mec_donors
  ADD CONSTRAINT mec_donors_match_status_check
    CHECK (match_status IS NULL OR match_status IN ('pending','matched','no_match','not_applicable'));

-- ─────────────────────────────────────────────────────────────────────────────
-- fec_candidates (1113 rows): has cand_name (LAST, FIRST MIDDLE); needs split + DOB
ALTER TABLE public.fec_candidates
  ADD COLUMN IF NOT EXISTS first_name       text,
  ADD COLUMN IF NOT EXISTS last_name        text,
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text;

ALTER TABLE public.fec_candidates
  DROP CONSTRAINT IF EXISTS fec_candidates_dob_source_check;
ALTER TABLE public.fec_candidates
  ADD CONSTRAINT fec_candidates_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- legislation_legislators (193 rows): has first_name, last_name. No DOB.
ALTER TABLE public.legislation_legislators
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text;

ALTER TABLE public.legislation_legislators
  DROP CONSTRAINT IF EXISTS legislation_legislators_dob_source_check;
ALTER TABLE public.legislation_legislators
  ADD CONSTRAINT legislation_legislators_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- donors (49): already has date_of_birth. Add first_name/last_name split + voter link.
ALTER TABLE public.donors
  ADD COLUMN IF NOT EXISTS first_name       text,
  ADD COLUMN IF NOT EXISTS last_name        text,
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text;

ALTER TABLE public.donors
  DROP CONSTRAINT IF EXISTS donors_dob_source_check;
ALTER TABLE public.donors
  ADD CONSTRAINT donors_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- members (409): already has DOB. Just add voter link + dob_source.
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS dob_source       text DEFAULT 'self_reported';

ALTER TABLE public.members
  DROP CONSTRAINT IF EXISTS members_dob_source_check;
ALTER TABLE public.members
  ADD CONSTRAINT members_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- subscribers (73K): already has DOB. Just add voter link.
ALTER TABLE public.subscribers
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS birth_year       int,
  ADD COLUMN IF NOT EXISTS dob_source       text;

ALTER TABLE public.subscribers
  DROP CONSTRAINT IF EXISTS subscribers_dob_source_check;
ALTER TABLE public.subscribers
  ADD CONSTRAINT subscribers_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- donor_enrichment (470K): already has DOB + birth-related cols. Just add voter link.
ALTER TABLE public.donor_enrichment
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text;

ALTER TABLE public.donor_enrichment
  DROP CONSTRAINT IF EXISTS donor_enrichment_dob_source_check;
ALTER TABLE public.donor_enrichment
  ADD CONSTRAINT donor_enrichment_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- ─────────────────────────────────────────────────────────────────────────────
-- candidates: rename the unused voter_match_id UUID → mo_voter_file_id text.
-- Safe because 0 rows have voter_match_id set.
ALTER TABLE public.candidates
  DROP COLUMN IF EXISTS voter_match_id,
  ADD  COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD  COLUMN IF NOT EXISTS birth_year       int,
  ADD  COLUMN IF NOT EXISTS dob_source       text,
  ADD  COLUMN IF NOT EXISTS match_confidence numeric,
  ADD  COLUMN IF NOT EXISTS match_method     text;

ALTER TABLE public.candidates
  DROP CONSTRAINT IF EXISTS candidates_dob_source_check;
ALTER TABLE public.candidates
  ADD CONSTRAINT candidates_dob_source_check
    CHECK (dob_source IS NULL OR dob_source IN ('voter_file','self_reported','ai_estimate'));

-- Mark existing DOBs with their provenance
UPDATE public.candidates SET dob_source='ai_estimate'
  WHERE date_of_birth IS NOT NULL AND dob_source IS NULL;

UPDATE public.members SET dob_source='self_reported'
  WHERE date_of_birth IS NOT NULL AND dob_source IS NULL;

UPDATE public.donors SET dob_source='self_reported'
  WHERE date_of_birth IS NOT NULL AND dob_source IS NULL;

COMMIT;

NOTIFY pgrst, 'reload schema';
