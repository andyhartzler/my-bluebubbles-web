-- 2026-04-22 RLS Phase 2.1 — tighten anon writes on event_attendees + subscribers
--
-- Follow-up to 20260422_05_rls_phase2.sql. Phase 2 kept two anon write paths
-- slightly too permissive:
--
--   * `event_attendees_guest_update` — USING/WITH CHECK (guest_email IS NOT NULL)
--     let any anon request rewrite any row whose guest_email column was set.
--     The intended "guest can correct their RSVP" flow is done by staff via
--     the CRM, not by unauthenticated clients. Close the UPDATE path to anon
--     entirely; rely on the already-present staff write policy.
--
--   * `subscribers_public_insert` — WITH CHECK (true) allowed arbitrary anon
--     inserts with no validation. Tighten to require a minimally-valid email.
--     The email-format regex matches the same shape used by the /subscribe
--     endpoint validator, so legitimate signups are unaffected.
--
-- Additional (no-op) note re: the `candidate_endorsement_responses` view that
-- the moydforms migration 20260422000000_endorsement_questionnaire_link.sql
-- introduced: views don't own RLS policies. Access control is inherited from
-- the underlying tables (`form_submissions`, `form_schemas`), and Phase 2
-- already gates `form_submissions` SELECT to staff via
-- `form_submissions_staff_read` plus `form_submissions_self_read`. So no new
-- policy is needed on the view itself — intentionally skipped.
--
-- Idempotent: policy drops are guarded; re-running is safe.
-- No schema changes.

BEGIN;

-- ============================================================================
-- 1. event_attendees — remove anon UPDATE path; keep anon INSERT (RSVP).
-- ============================================================================
-- Before: event_attendees_guest_update allowed anon+authenticated UPDATE
--   where guest_email IS NOT NULL → any row with a guest_email could be
--   rewritten by any anon client.
-- After:  policy dropped. Anon still has INSERT via event_attendees_public_rsvp.
--   Staff continue to read/write via event_attendees_staff_read +
--   event_attendees_staff_write. Service role unchanged.

DROP POLICY IF EXISTS "event_attendees_guest_update" ON public.event_attendees;

-- Revoke the GRANT that let anon even attempt UPDATE. The Phase 2 migration
-- only revoked SELECT + DELETE; UPDATE was still grantable by default.
REVOKE UPDATE ON public.event_attendees FROM anon, PUBLIC;

-- ============================================================================
-- 2. subscribers — tighten public insert to require a valid-looking email.
-- ============================================================================
-- Before: subscribers_public_insert WITH CHECK (true) — zero validation.
-- After:  WITH CHECK validates email is non-null and matches a basic
--   local@domain.tld pattern (same shape the Next.js /subscribe route enforces).

DROP POLICY IF EXISTS "subscribers_public_insert" ON public.subscribers;

CREATE POLICY "subscribers_public_insert"
  ON public.subscribers FOR INSERT TO anon, authenticated
  WITH CHECK (
    email IS NOT NULL
    AND email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  );

-- ============================================================================
-- 3. candidate_endorsement_responses view — intentional no-op.
-- ============================================================================
-- The view was created by moydforms migration
-- 20260422000000_endorsement_questionnaire_link.sql (already live). Views
-- inherit RLS from the underlying tables — querying the view runs the
-- policies on `form_submissions` and `form_schemas`. Phase 2 already scoped
-- `form_submissions` SELECT to staff (`form_submissions_staff_read`) plus
-- the submitter's own rows (`form_submissions_self_read`). So the view is
-- already effectively staff-gated and no new policy is needed here.
--
-- Double-check in a psql session:
--   SET ROLE anon;
--   SELECT * FROM public.candidate_endorsement_responses; -- should return 0 rows
--   RESET ROLE;
-- ============================================================================

-- Tell PostgREST to reload so the new policy takes effect without a restart.
NOTIFY pgrst, 'reload schema';

COMMIT;
