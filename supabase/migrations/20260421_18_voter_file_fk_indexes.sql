-- 20260421_18_voter_file_fk_indexes.sql
-- Add missing indexes on every FK column that points at public.mo_voter_file(voter_id).
--
-- Postgres does NOT auto-index the referencing side of a foreign key. At 4.34M rows
-- in mo_voter_file and 1M+ rows in mec_donors, a join like
--   SELECT ... FROM mec_donors md JOIN mo_voter_file mvf ON mvf.voter_id = md.mo_voter_file_id
-- would otherwise trigger a seq scan on mec_donors whenever the planner walks from
-- voter_file back to donors. We add partial indexes (WHERE mo_voter_file_id IS NOT NULL)
-- because most rows are unmatched and we only care about traversal for matched rows.
--
-- All CREATE INDEX IF NOT EXISTS, so this is safe to re-run. Using plain CREATE INDEX
-- (not CONCURRENTLY) because this must run inside a migration transaction; tables are
-- small enough (largest is mec_donors at ~1M rows) that the brief exclusive lock is fine.
--
-- Tables covered (10 total — every FK to mo_voter_file.voter_id):
--   candidates, donor_enrichment, donor_profiles, donors, fec_candidates,
--   historical_candidates, legislation_legislators, mec_donors, members, subscribers

BEGIN;

CREATE INDEX IF NOT EXISTS idx_candidates_mo_voter_file_id
  ON public.candidates (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_donor_enrichment_mo_voter_file_id
  ON public.donor_enrichment (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_donor_profiles_mo_voter_file_id
  ON public.donor_profiles (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_donors_mo_voter_file_id
  ON public.donors (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fec_candidates_mo_voter_file_id
  ON public.fec_candidates (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_historical_candidates_mo_voter_file_id
  ON public.historical_candidates (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_legislation_legislators_mo_voter_file_id
  ON public.legislation_legislators (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mec_donors_mo_voter_file_id
  ON public.mec_donors (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_members_mo_voter_file_id
  ON public.members (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_subscribers_mo_voter_file_id
  ON public.subscribers (mo_voter_file_id) WHERE mo_voter_file_id IS NOT NULL;

COMMIT;

NOTIFY pgrst, 'reload schema';
