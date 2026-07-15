-- Client-side diagnostics for the auth refresh-storm guard (2026-07-15).
-- Applied to production the same day; committed here for review and so a
-- fresh environment reproduces it. All objects fully qualified to public.

-- Live server time, so clients can measure their real clock skew instead of
-- inferring it from token age (which false-alarmed and was removed).
CREATE OR REPLACE FUNCTION public.server_time()
RETURNS timestamptz
LANGUAGE sql
STABLE
AS 'SELECT now()';

GRANT EXECUTE ON FUNCTION public.server_time() TO authenticated, anon;

-- One row per detected auth refresh storm (kind = 'auth_refresh_storm' or
-- 'auth_refresh_storm_persistent'), detail carries measured clock skew,
-- refresh cadence fingerprint, and the SDK's session-expiry view.
CREATE TABLE IF NOT EXISTS public.client_diagnostics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid DEFAULT auth.uid(),
  kind text NOT NULL,
  detail jsonb
);

ALTER TABLE public.client_diagnostics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can insert own diagnostics"
  ON public.client_diagnostics;
CREATE POLICY "Authenticated can insert own diagnostics"
  ON public.client_diagnostics FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

DROP POLICY IF EXISTS "Staff can read diagnostics"
  ON public.client_diagnostics;
CREATE POLICY "Staff can read diagnostics"
  ON public.client_diagnostics FOR SELECT TO authenticated
  USING (public.is_staff());

-- Also applied 2026-07-15 (for the Endorsement HQ Live journey tab): staff
-- read access to the public-form autosave drafts.
DROP POLICY IF EXISTS "Staff can view form drafts" ON public.form_drafts;
CREATE POLICY "Staff can view form drafts"
  ON public.form_drafts FOR SELECT TO authenticated
  USING (public.is_staff());
