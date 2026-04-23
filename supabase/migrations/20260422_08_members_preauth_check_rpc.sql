-- 2026-04-22 P0 RLS bootstrap fix — SECURITY DEFINER RPC for anon OTP pre-check
--
-- `lib/app/layouts/startup/password_screen.dart:240-244` queries
--     .from('members').select('id, executive_committee')
--       .or('email.eq.$email,school_email.eq.$email')
-- as anon, BEFORE OTP is sent, to validate that the email maps to a member.
--
-- Phase 2 (20260422_05) revoked anon SELECT on `members`. That query now
-- fails with 42501 and the sign-in flow breaks. Even if it succeeded, it
-- would leak `id` and `executive_committee` to an unauthenticated caller —
-- enough signal to enumerate members.
--
-- Fix: expose a SECURITY DEFINER RPC that returns only 3 booleans. The
-- function bypasses RLS (runs as owner) and returns no PII — just
-- { found, executive_committee, active }. Callable by anon.

-- Note: `members` has no `active` column. We derive `active` as
-- "has any committee membership OR is on the executive committee" — this
-- matches `public.is_staff()` and is what the CRM actually gates on.
CREATE OR REPLACE FUNCTION public.members_preauth_check(p_email text)
RETURNS TABLE (
  found boolean,
  executive_committee boolean,
  active boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE lower(m.email) = lower(p_email)
         OR lower(coalesce(m.school_email,'')) = lower(p_email)
    ) AS found,
    COALESCE((
      SELECT m.executive_committee
      FROM public.members m
      WHERE (lower(m.email) = lower(p_email) OR lower(coalesce(m.school_email,'')) = lower(p_email))
      LIMIT 1
    ), false) AS executive_committee,
    COALESCE((
      SELECT (m.executive_committee = true OR m.committee IS NOT NULL)
      FROM public.members m
      WHERE (lower(m.email) = lower(p_email) OR lower(coalesce(m.school_email,'')) = lower(p_email))
      LIMIT 1
    ), false) AS active;
$$;

COMMENT ON FUNCTION public.members_preauth_check(text) IS
  'Anon-callable pre-OTP membership check. Returns 3 booleans (found, executive_committee, active) — no PII. SECURITY DEFINER so it bypasses the Phase 2 RLS revocation of anon SELECT on members. Called from password_screen.dart before signInWithOtp.';

GRANT EXECUTE ON FUNCTION public.members_preauth_check(text) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
