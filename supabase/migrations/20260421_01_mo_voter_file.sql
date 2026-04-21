-- 20260421_01_mo_voter_file.sql
-- Missouri statewide voter file (PSR) — April 2026 edition.
-- Source: PSR_VotersList_04012026_8-12-37 AM.txt, 4.34M rows, tab-delimited, 54 cols.
-- Privacy note: MO SOS releases BIRTH YEAR ONLY (no month/day).
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.mo_voter_file (
  voter_id                text PRIMARY KEY,        -- column 2 "Voter ID"
  county                  text,                    -- column 1
  first_name              text,
  middle_name             text,
  last_name               text,
  suffix                  text,
  -- Residence address components
  house_number            text,
  house_suffix            text,
  pre_direction           text,
  street_name             text,
  street_type             text,
  post_direction          text,
  unit_type               text,
  unit_number             text,
  non_standard_address    text,
  residential_city        text,
  residential_state       text,
  residential_zip5        text,
  -- Mailing address
  mailing_address         text,
  mailing_city            text,
  mailing_state           text,
  mailing_zip             text,
  -- Core voter data
  birth_year              int,                     -- column 23 "Birthdate" — year only
  political_party         text,                    -- always blank for MO
  registration_date       date,
  voter_status            text,                    -- Active/Inactive/Cancelled
  -- Political geography
  precinct                text,
  precinct_name           text,
  split                   text,
  township                text,
  ward                    text,
  congressional_district  text,
  legislative_district    text,
  senate_district         text,
  -- Voter history (20 past elections rolled into one array)
  voter_history           jsonb,                    -- e.g. ["11/05/2024 General", "11/03/2020 General"]
  -- Provenance
  file_date               date      NOT NULL DEFAULT '2026-04-01',
  imported_at             timestamptz NOT NULL DEFAULT now()
);

-- Indexes for matching
CREATE INDEX IF NOT EXISTS idx_mvf_name_zip
  ON public.mo_voter_file (lower(last_name), lower(first_name), residential_zip5);
CREATE INDEX IF NOT EXISTS idx_mvf_name_county
  ON public.mo_voter_file (lower(last_name), lower(first_name), lower(county));
CREATE INDEX IF NOT EXISTS idx_mvf_trgm
  ON public.mo_voter_file USING gin ((lower(first_name || ' ' || last_name)) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_mvf_county ON public.mo_voter_file (lower(county));
CREATE INDEX IF NOT EXISTS idx_mvf_zip5 ON public.mo_voter_file (residential_zip5);
CREATE INDEX IF NOT EXISTS idx_mvf_birth_year ON public.mo_voter_file (birth_year);

COMMENT ON TABLE public.mo_voter_file IS
  'Missouri statewide voter file. Loaded 2026-04-21 from PSR_VotersList_04012026. '
  'Shared by Alex Withers @ MO Dems instead of $30 SOS purchase. Birth year only '
  '(not full DOB) per SOS privacy policy. 20-column voter history rolled into jsonb.';
COMMENT ON COLUMN public.mo_voter_file.birth_year IS
  'Year of birth only — MO SOS does not release month/day. Sufficient for age/eligibility ± 6mo.';

COMMIT;

NOTIFY pgrst, 'reload schema';
