-- =====================================================================
-- 20260425_08_mail_vacation_prefs.sql
-- Per-user vacation auto-responder preferences for the MOYD CRM mail
-- client. Phase 6.
--
-- Rationale: Gmail's vacation responder is per-mailbox, but our shared
-- crm@moyoungdemocrats.org seat carries multiple per-exec aliases. We
-- can't actually flip Gmail's vacation responder per alias. Instead we
-- persist per-user prefs here; a future mail-pubsub-receiver enhancement
-- will fire auto-responses via mail-send when the period is active.
-- For now this row is the source of truth surfaced in tmail's manage-
-- account vacation UI.
-- =====================================================================

SET search_path = public, pg_temp;

CREATE TABLE IF NOT EXISTS public.mail_vacation_prefs (
  user_id        uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_enabled     boolean NOT NULL DEFAULT false,
  from_date      date,
  to_date        date,
  subject        text,
  text_body      text,
  html_body      text,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mail_vacation_prefs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mvp_self ON public.mail_vacation_prefs;
CREATE POLICY mvp_self ON public.mail_vacation_prefs
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin())
  WITH CHECK (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS mvp_service_role ON public.mail_vacation_prefs;
CREATE POLICY mvp_service_role ON public.mail_vacation_prefs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_mvp_updated_at ON public.mail_vacation_prefs;
CREATE TRIGGER trg_mvp_updated_at
  BEFORE UPDATE ON public.mail_vacation_prefs
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();
