-- DIAGNOSTIC INSTRUMENTATION (temporary).
-- Captures pointer events from the iOS PWA top-bar tap-target investigation.
-- Will be dropped once the root cause of the hamburger/search dead-tap bug
-- is identified (commit message tagged DIAG-PWA-TOPBAR).

CREATE TABLE IF NOT EXISTS public.pwa_debug_log (
  id BIGSERIAL PRIMARY KEY,
  ts_client TIMESTAMPTZ,
  ts_server TIMESTAMPTZ NOT NULL DEFAULT now(),
  layer TEXT NOT NULL,             -- 'js' | 'flutter' | 'meta'
  event_type TEXT NOT NULL,        -- pointerdown / pointerup / touchstart / click / etc.
  x DOUBLE PRECISION,
  y DOUBLE PRECISION,
  target_path TEXT,
  user_agent TEXT,
  display_mode TEXT,
  standalone BOOLEAN,
  session_id TEXT,                 -- random per-pageload id, ties JS+Flutter rows together
  metadata JSONB
);

CREATE INDEX IF NOT EXISTS pwa_debug_log_ts_server_idx
  ON public.pwa_debug_log (ts_server DESC);
CREATE INDEX IF NOT EXISTS pwa_debug_log_session_idx
  ON public.pwa_debug_log (session_id, ts_server);

-- Anyone (including anon) can INSERT. Reads are gated to authenticated only.
ALTER TABLE public.pwa_debug_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pwa_debug_log_anon_insert ON public.pwa_debug_log;
CREATE POLICY pwa_debug_log_anon_insert ON public.pwa_debug_log
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS pwa_debug_log_auth_select ON public.pwa_debug_log;
CREATE POLICY pwa_debug_log_auth_select ON public.pwa_debug_log
  FOR SELECT TO authenticated
  USING (true);
