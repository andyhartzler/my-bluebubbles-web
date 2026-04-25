-- =====================================================================
-- 20260425_05_mail_client.sql
-- Per-exec Gmail mail client tables. RLS: owner + superadmin.
-- =====================================================================

SET search_path = public, pg_temp;

CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------
-- 1. mail_aliases
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_aliases (
  user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  alias_email      citext UNIQUE NOT NULL CHECK (alias_email ~ '^[a-z0-9._-]+@moyoungdemocrats\.org$'),
  display_name     text NOT NULL,
  provisioned_at   timestamptz NOT NULL DEFAULT now(),
  revoked_at       timestamptz,
  gmail_send_as_verified boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- STABLE SECURITY DEFINER scalar so RLS policies can call it without
-- recursing into the mail_aliases policy itself, and the planner can
-- cache the result for one query.
CREATE OR REPLACE FUNCTION public.current_user_alias()
RETURNS citext
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT alias_email FROM public.mail_aliases
  WHERE user_id = auth.uid()
    AND revoked_at IS NULL
    AND gmail_send_as_verified = true
  LIMIT 1;
$$;
REVOKE EXECUTE ON FUNCTION public.current_user_alias() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_alias() TO authenticated, service_role;

ALTER TABLE public.mail_aliases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ma_self ON public.mail_aliases;
CREATE POLICY ma_self ON public.mail_aliases
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS ma_service_role ON public.mail_aliases;
CREATE POLICY ma_service_role ON public.mail_aliases
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_ma_updated_at ON public.mail_aliases;
CREATE TRIGGER trg_ma_updated_at
  BEFORE UPDATE ON public.mail_aliases
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

DROP TRIGGER IF EXISTS trg_audit_mail_aliases ON public.mail_aliases;
CREATE TRIGGER trg_audit_mail_aliases
  AFTER INSERT OR UPDATE OR DELETE ON public.mail_aliases
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 2. mail_messages_cache
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_messages_cache (
  gmail_message_id text PRIMARY KEY,
  thread_id        text NOT NULL,
  alias_email      citext NOT NULL,
  from_addr        text NOT NULL,
  to_addrs         text[] NOT NULL DEFAULT '{}',
  cc_addrs         text[] DEFAULT '{}',
  subject          text,
  snippet          text,
  internal_date    timestamptz NOT NULL,
  labels           text[] NOT NULL DEFAULT '{}',
  delivered_to     text,
  fetched_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mmc_alias_internal_date
  ON public.mail_messages_cache (alias_email, internal_date DESC);
CREATE INDEX IF NOT EXISTS idx_mmc_thread
  ON public.mail_messages_cache (thread_id);

ALTER TABLE public.mail_messages_cache ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE ON public.mail_messages_cache FROM authenticated;

DROP POLICY IF EXISTS mmc_self ON public.mail_messages_cache;
CREATE POLICY mmc_self ON public.mail_messages_cache
  FOR SELECT TO authenticated
  USING (
    alias_email = public.current_user_alias()
    OR public.current_user_is_superadmin()
  );

DROP POLICY IF EXISTS mmc_service_role ON public.mail_messages_cache;
CREATE POLICY mmc_service_role ON public.mail_messages_cache
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------
-- 3. mail_threads_cache — DEFERRED to Phase 2 (receiver doesn't write
--    rollups in Phase 1; inbox UI groups locally from messages_cache).
--
-- 4. mail_send_log (append-only)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_send_log (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_user_id   uuid NOT NULL REFERENCES auth.users(id),
  alias_email      citext NOT NULL,
  gmail_message_id text,
  rfc822_message_id text,
  thread_id        text,
  recipients       jsonb NOT NULL,
  subject          text,
  sent_at          timestamptz NOT NULL DEFAULT now(),
  status           text NOT NULL CHECK (status IN ('queued','sent','failed')),
  error_detail     text,
  related_entity_type text,
  related_entity_id   uuid
);

CREATE INDEX IF NOT EXISTS idx_msl_sender_sent_at
  ON public.mail_send_log (sender_user_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_msl_thread
  ON public.mail_send_log (thread_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_msl_rfc822
  ON public.mail_send_log (rfc822_message_id) WHERE rfc822_message_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_msl_gmail_id
  ON public.mail_send_log (gmail_message_id) WHERE gmail_message_id IS NOT NULL;

ALTER TABLE public.mail_send_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS msl_self ON public.mail_send_log;
CREATE POLICY msl_self ON public.mail_send_log
  FOR SELECT TO authenticated
  USING (sender_user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS msl_service_role ON public.mail_send_log;
CREATE POLICY msl_service_role ON public.mail_send_log
  FOR ALL TO service_role USING (true) WITH CHECK (true);

REVOKE UPDATE, DELETE ON public.mail_send_log FROM authenticated;

DROP TRIGGER IF EXISTS trg_audit_mail_send_log ON public.mail_send_log;
CREATE TRIGGER trg_audit_mail_send_log
  AFTER INSERT ON public.mail_send_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 5. mail_pubsub_state (singleton)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mail_pubsub_state (
  id               int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  history_id       text NOT NULL,
  watch_expires_at timestamptz NOT NULL,
  last_event_at    timestamptz,
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.mail_pubsub_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mps_superadmin ON public.mail_pubsub_state;
CREATE POLICY mps_superadmin ON public.mail_pubsub_state
  FOR SELECT TO authenticated
  USING (public.current_user_is_superadmin());

DROP POLICY IF EXISTS mps_service_role ON public.mail_pubsub_state;
CREATE POLICY mps_service_role ON public.mail_pubsub_state
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_mps_updated_at ON public.mail_pubsub_state;
CREATE TRIGGER trg_mps_updated_at
  BEFORE UPDATE ON public.mail_pubsub_state
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

-- =====================================================================
-- End migration.
-- =====================================================================
