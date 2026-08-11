-- Applied to production as version 20260811230807,
-- recorded name: 20260811_04_job_notification_key_from_vault_not_config_table
--
-- The third hiding place for the same credential, and the one a grep of
-- function bodies cannot find: public.job_notification_config stored the
-- service_role key as an ordinary TABLE ROW, keyed 'service_role_key', and
-- public.call_job_notification_edge_function read it from there.
--
-- Found by firing the jobs trigger inside a rolled-back transaction and noticing
-- a SECOND enqueued request (to send-job-notification) carrying a valid Bearer
-- token that no function body contained.
--
-- Exposure today: the table has RLS enabled with ZERO policies, so PostgREST
-- denies anon and authenticated by default-deny. It is not currently readable.
-- But anon and authenticated already hold SELECT/INSERT/UPDATE/DELETE grants on
-- it, so the key was exactly one permissive policy away from being world
-- readable, and it would have gone stale silently on rotation like the rest.
--
-- TO ROTATE: nothing extra. This now reads the same vault secret as everything
-- else, so the single vault.update_secret call documented in
-- 20260811_08_read_api_keys_from_vault_not_literals.sql covers it.
--
-- The endpoint URL stays in the config table. It is not a secret.

CREATE OR REPLACE FUNCTION public.call_job_notification_edge_function(
  p_trigger_type text,
  p_job_id uuid,
  p_application_id uuid DEFAULT NULL::uuid,
  p_old_status text DEFAULT NULL::text
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
  v_payload JSONB;
BEGIN
  -- URL still comes from config; the key now comes from the vault.
  SELECT value INTO v_url FROM public.job_notification_config WHERE key = 'edge_function_url';

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1;

  IF v_url IS NULL THEN
    RAISE WARNING 'Job notification config not set. Please update job_notification_config table.';
    RETURN;
  END IF;

  IF v_service_role_key IS NULL OR v_service_role_key = '' THEN
    RAISE WARNING 'vault secret service_role_key is missing or empty; job notification not sent';
    RETURN;
  END IF;

  -- Build payload
  v_payload := jsonb_build_object(
    'trigger_type', p_trigger_type,
    'job_id', p_job_id
  );

  IF p_application_id IS NOT NULL THEN
    v_payload := v_payload || jsonb_build_object('application_id', p_application_id);
  END IF;

  IF p_old_status IS NOT NULL THEN
    v_payload := v_payload || jsonb_build_object('old_status', p_old_status);
  END IF;

  SELECT net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := v_payload,
    timeout_milliseconds := 5000
  ) INTO v_request_id;

  RAISE LOG 'Job notification sent: type=%, job=%, app=%, request_id=%',
    p_trigger_type, p_job_id, p_application_id, v_request_id;

EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send job notification: % - %', SQLSTATE, SQLERRM;
END;
$function$;

-- Remove the stored credential now that nothing reads it.
DELETE FROM public.job_notification_config WHERE key = 'service_role_key';
