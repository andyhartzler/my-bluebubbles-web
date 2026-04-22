-- 2026-04-22 P0 RLS bootstrap fix — widen `members_self_read` to match school_email
--
-- Today's line-by-line audit of the Phase 2 RLS policies against the Flutter
-- bootstrap path found a hole: `lib/providers/user_session_provider.dart`
-- lines 148-152 fall back to `members.select().eq('school_email', email)`
-- when the primary `email` lookup returns null. That fallback exists because
-- some members sign in with their school email — the Supabase Auth user's
-- JWT email matches `members.school_email`, not `members.email`.
--
-- Phase 2's `members_self_read` policy only allows:
--     user_id = auth.uid() OR email = auth.jwt() ->> 'email'
--
-- For a school-email signer whose `members.user_id` is still null (first
-- login, bootstrap path hasn't linked them yet) and whose `email` column
-- holds a different personal address, the row is invisible. The fallback
-- query returns empty → UserSessionProvider throws "Member record not
-- found" → login blocked.
--
-- Fix: add the third branch `school_email = auth.jwt() ->> 'email'` so the
-- self-read policy covers the bootstrap case.
--
-- Idempotent: drops the existing policy first. Re-runnable without error.

BEGIN;

DROP POLICY IF EXISTS "members_self_read" ON public.members;

CREATE POLICY "members_self_read"
  ON public.members FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR email = auth.jwt() ->> 'email'
    OR school_email = auth.jwt() ->> 'email'
  );

NOTIFY pgrst, 'reload schema';

COMMIT;
