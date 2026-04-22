-- ============================================================================
-- MIRRORED MIGRATION — DO NOT RE-APPLY FROM THIS REPO
-- ============================================================================
-- This file is a verbatim mirror of
--   /Users/moyd/moydforms/supabase/migrations/20260422000000_endorsement_questionnaire_link.sql
-- It is checked in here purely for repo completeness so readers of the CRM
-- repo can see the schema shape (form_submissions.candidate_id,
-- candidate_endorsement_responses view) that the Flutter CRM depends on.
--
-- The ACTUAL application to the live database happens via the moydforms
-- migration history. The `supabase/migrations` directory in that repo is
-- the canonical source of truth for this migration — do not apply this copy
-- again via `supabase db push` or `apply_migration`, or you'll duplicate the
-- ALTER TABLE / INDEX / VIEW / POLICY DDL.
-- ============================================================================
-- Original header preserved below:
-- ============================================================================
-- MIGRATION: Link form_submissions → candidates for endorsement questionnaires
-- Status: PROPOSED — DO NOT APPLY WITHOUT REVIEW
-- Author: claude / andrew (2026-04-22)
-- ============================================================================
--
-- Rationale:
--   The endorsement questionnaire at `endorsement-questionnaire-2026` needs
--   to render on each candidate's detail screen. form_submissions already has
--   member_id, but candidates are distinct entities — a candidate may not be
--   a member yet. We add an explicit candidate_id FK + index, plus a view
--   that exposes the joined record for the Flutter CRM.
--
-- Join strategy (in order of precedence):
--   1. Direct candidate_id column (populated by the submit handler when the
--      form is the endorsement questionnaire).
--   2. submitter_email ilike match against candidates.campaign_email /
--      members.email where candidates.member_id = members.id.
--   3. submitter_phone digits-only match against candidates.campaign_phone.
--
-- The column addition is the durable join. Email/phone fallbacks are only
-- for legacy/backfill — the submit route will always populate candidate_id
-- going forward.
-- ============================================================================

BEGIN;

-- 1. Add candidate_id column (nullable — most submissions aren't candidate-linked)
ALTER TABLE public.form_submissions
  ADD COLUMN IF NOT EXISTS candidate_id uuid
    REFERENCES public.candidates(id) ON DELETE SET NULL;

-- 2. Partial index — only candidate-linked submissions, keeps it tiny
CREATE INDEX IF NOT EXISTS idx_form_submissions_candidate_id
  ON public.form_submissions (candidate_id)
  WHERE candidate_id IS NOT NULL;

-- 3. Convenience view used by the CRM to render a candidate's endorsement answers
CREATE OR REPLACE VIEW public.candidate_endorsement_responses AS
SELECT
  fs.id                AS submission_id,
  fs.candidate_id,
  fs.created_at        AS submitted_at,
  fs.updated_at,
  fs.status,
  fs.data              AS responses,
  fs.submitter_name,
  fs.submitter_email,
  fs.submitter_phone,
  fs.file_urls,
  fsch.slug            AS form_slug,
  fsch.title           AS form_title
FROM public.form_submissions fs
JOIN public.form_schemas fsch ON fsch.id = fs.form_id
WHERE fsch.slug LIKE 'endorsement-questionnaire%'
  AND fs.status IN ('submitted', 'reviewed', 'processed')
  AND fs.candidate_id IS NOT NULL;

COMMENT ON VIEW public.candidate_endorsement_responses IS
  'Flattened view of endorsement questionnaire submissions joined to candidates. Used by the Flutter CRM candidate_detail_screen.';

-- 4. RLS policy: authenticated users can read responses for candidates
--    (adjust in review — may want to scope to MOYD staff role specifically)
ALTER TABLE public.form_submissions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'form_submissions'
      AND policyname = 'Staff can read endorsement submissions'
  ) THEN
    CREATE POLICY "Staff can read endorsement submissions"
      ON public.form_submissions
      FOR SELECT TO authenticated
      USING (
        candidate_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM public.form_schemas fs
          WHERE fs.id = form_submissions.form_id
            AND fs.slug LIKE 'endorsement-questionnaire%'
        )
      );
  END IF;
END $$;

COMMIT;

-- ============================================================================
-- BACKFILL (run manually after initial launch if needed):
-- ============================================================================
-- UPDATE public.form_submissions fs
-- SET candidate_id = c.id
-- FROM public.candidates c, public.form_schemas sch
-- WHERE fs.form_id = sch.id
--   AND sch.slug LIKE 'endorsement-questionnaire%'
--   AND fs.candidate_id IS NULL
--   AND (
--     (fs.submitter_email IS NOT NULL AND lower(fs.submitter_email) = lower(c.campaign_email))
--     OR regexp_replace(coalesce(fs.submitter_phone, ''), '\D', '', 'g')
--        = regexp_replace(coalesce(c.campaign_phone, ''), '\D', '', 'g')
--   );
