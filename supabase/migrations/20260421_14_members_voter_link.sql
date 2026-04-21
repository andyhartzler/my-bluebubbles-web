-- 20260421_14_members_voter_link.sql
-- Expand members.dob_source CHECK constraint to allow 'voter_file_birth_year_only',
-- which is the provenance we use for members who have NO self-reported DOB but
-- we filled public.members.birth_year from the Missouri voter file. In that case
-- date_of_birth stays NULL (we only have year resolution from the voter file)
-- and the UI treats birth_year as reference.
--
-- Critically: we NEVER overwrite a self-reported date_of_birth with voter-file data.
-- Self-reported DOBs on members keep dob_source = 'self_reported'; we only add
-- the mo_voter_file_id FK so the Flutter app can JOIN to voting history + districts.

BEGIN;

ALTER TABLE public.members
  DROP CONSTRAINT IF EXISTS members_dob_source_check;

ALTER TABLE public.members
  ADD CONSTRAINT members_dob_source_check
    CHECK (
      dob_source IS NULL
      OR dob_source IN (
        'voter_file',
        'voter_file_birth_year_only',
        'self_reported',
        'ai_estimate'
      )
    );

COMMIT;

NOTIFY pgrst, 'reload schema';
