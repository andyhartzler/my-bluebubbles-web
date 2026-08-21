-- Applied to production as version 20260821005527.
--
-- fn_auth_anomaly_monitor (cron job 95, every 15 min) built its alert URL as the
-- literal 'https://api.telegram.org/bot/sendMessage' -- the bot token was never
-- interpolated. Probed live: that URL returns HTTP 404
-- {"ok":false,"error_code":404,"description":"Not Found"}.
-- So every CRM auth-storm / refresh-anomaly alert this monitor has ever raised
-- was silently discarded.
--
-- Worse, the old body advanced `auth_monitor_state.last_checked = now()` BEFORE
-- the post and unconditionally, so a failed dispatch also moved the watermark
-- past the anomaly: the alert was lost permanently, never retried.
--
-- Fixes:
--   1. Build the URL from vault `telegram_alert_bot_token` (the same pattern
--      fn_slack_token_rotation_watchdog uses, which delivers correctly).
--   2. Take chat_id from vault `telegram_alert_chat_id` instead of hardcoding it.
--   3. RAISE if either vault secret is missing/empty, so a bad rotation is loud.
--   4. Only advance last_checked AFTER the post is enqueued. On RAISE the whole
--      transaction rolls back, the watermark stays put, and the anomaly is
--      re-detected on the next run instead of being lost.
CREATE OR REPLACE FUNCTION public.fn_auth_anomaly_monitor()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $fn$
DECLARE
  v_since timestamptz;
  v_msg   text := '';
  v_row   record;
  v_token text;
  v_chat  text;
BEGIN
  SELECT last_checked INTO v_since FROM public.auth_monitor_state WHERE id = 1;

  -- Client-side storm diagnostics
  FOR v_row IN
    SELECT cd.kind,
           cd.created_at,
           coalesce(u.email, 'unknown') AS email,
           cd.detail->>'clock_skew_seconds' AS skew,
           cd.detail->>'refresh_count'      AS refreshes
      FROM public.client_diagnostics cd
      LEFT JOIN auth.users u ON u.id = cd.user_id
     WHERE cd.created_at > v_since
  LOOP
    v_msg := v_msg || 'CRM auth storm: ' || v_row.email || ' (' || v_row.kind || ', '
          || coalesce(v_row.refreshes, '?') || ' refreshes, clock skew '
          || coalesce(v_row.skew, '?') || 's) at '
          || to_char(v_row.created_at AT TIME ZONE 'America/Chicago', 'MM/DD HH12:MIam') || E'\n';
  END LOOP;

  -- Server-side refresh anomaly: any user >30 refreshes in the window
  FOR v_row IN
    SELECT payload->>'actor_username' AS email, count(*) AS n
      FROM auth.audit_log_entries
     WHERE payload->>'action' = 'token_refreshed'
       AND created_at > v_since
     GROUP BY 1
    HAVING count(*) > 30
  LOOP
    v_msg := v_msg || 'CRM refresh anomaly: ' || coalesce(v_row.email, '?')
          || ' rotated ' || v_row.n || ' tokens since '
          || to_char(v_since AT TIME ZONE 'America/Chicago', 'HH12:MIam') || E'\n';
  END LOOP;

  IF v_msg <> '' THEN
    SELECT decrypted_secret INTO v_token
      FROM vault.decrypted_secrets WHERE name = 'telegram_alert_bot_token';
    SELECT decrypted_secret INTO v_chat
      FROM vault.decrypted_secrets WHERE name = 'telegram_alert_chat_id';

    IF v_token IS NULL OR v_token = '' OR v_chat IS NULL OR v_chat = '' THEN
      RAISE EXCEPTION
        'fn_auth_anomaly_monitor: vault telegram_alert_bot_token/telegram_alert_chat_id missing or empty; auth anomaly alert NOT sent and watermark NOT advanced';
    END IF;

    PERFORM net.http_post(
      url     := 'https://api.telegram.org/bot' || v_token || '/sendMessage',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body    := jsonb_build_object('chat_id', v_chat, 'text', left(v_msg, 3900)),
      timeout_milliseconds := 20000
    );
  END IF;

  -- Advance the watermark only after a successful dispatch (or when there was
  -- nothing to send). A RAISE above rolls this back so the anomaly is retried.
  UPDATE public.auth_monitor_state SET last_checked = now() WHERE id = 1;
END
$fn$;
