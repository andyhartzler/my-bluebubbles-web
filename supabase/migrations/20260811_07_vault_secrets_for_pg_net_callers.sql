-- Applied to production as version 20260811225943,
-- recorded name: 20260811_01_vault_secrets_for_pg_net_callers
--
-- Purpose: stage the API keys that seven database functions currently carry as
-- hardcoded literals into Supabase Vault, so those literals can be removed and
-- so a future key rotation is a single vault.update_secret call.
--
-- The values are NOT written into this file. They are extracted at apply time,
-- by regex, out of the live function bodies that already hold them. That keeps
-- the key out of the migration history of a PUBLIC repo.
--
-- Two secrets, not one, because the seven functions do not all carry the same
-- key: four carry the service_role JWT, three carry an anon JWT. Collapsing
-- them onto one secret would send a service_role credential to endpoints that
-- only ever needed anon, which is a privilege escalation, not a refactor.

DO $mig$
DECLARE
  v_service_role text;
  v_anon         text;
BEGIN
  -- service_role JWT: read from a function that demonstrably holds it.
  SELECT (regexp_match(
            pg_get_functiondef('public.trigger_notify_exec_job_submitted()'::regprocedure),
            'Bearer (eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'))[1]
    INTO v_service_role;

  -- anon JWT: read from the member Mautic trigger, which carries the CURRENT
  -- anon key (verified against the project's published anon key).
  SELECT (regexp_match(
            pg_get_functiondef('extensions.trigger_sync_member_to_mautic()'::regprocedure),
            'Bearer (eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'))[1]
    INTO v_anon;

  IF v_service_role IS NULL OR v_anon IS NULL THEN
    RAISE EXCEPTION 'Could not extract key literals from the source functions (service_role null: %, anon null: %)',
      v_service_role IS NULL, v_anon IS NULL;
  END IF;

  -- Sanity: confirm each extracted token really carries the role we think it does.
  IF convert_from(decode(translate(split_part(v_service_role, '.', 2), '-_', '+/')
                         || repeat('=', (4 - length(split_part(v_service_role, '.', 2)) % 4) % 4),
                         'base64'), 'utf8')
     NOT LIKE '%"service_role"%' THEN
    RAISE EXCEPTION 'Token extracted for service_role_key does not claim role service_role';
  END IF;

  IF convert_from(decode(translate(split_part(v_anon, '.', 2), '-_', '+/')
                         || repeat('=', (4 - length(split_part(v_anon, '.', 2)) % 4) % 4),
                         'base64'), 'utf8')
     NOT LIKE '%"anon"%' THEN
    RAISE EXCEPTION 'Token extracted for anon_key does not claim role anon';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'service_role_key') THEN
    PERFORM vault.create_secret(
      v_service_role,
      'service_role_key',
      'Project service_role API key. Read at call time by the database functions that '
      'post to Edge Functions via pg_net. TO ROTATE: rotate the key in the Supabase '
      'dashboard, then run exactly one statement -- '
      'SELECT vault.update_secret((SELECT id FROM vault.secrets WHERE name = ''service_role_key''), ''<new key>''); '
      '-- no function needs to be redefined.'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'anon_key') THEN
    PERFORM vault.create_secret(
      v_anon,
      'anon_key',
      'Project anon (publishable, legacy JWT) API key. Read at call time by the database '
      'functions that post to Edge Functions via pg_net. TO ROTATE: '
      'SELECT vault.update_secret((SELECT id FROM vault.secrets WHERE name = ''anon_key''), ''<new key>'');'
    );
  END IF;
END
$mig$;
