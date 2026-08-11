-- Applied to production as version 20260811230407,
-- recorded name: 20260811_03_cron_jobs_read_service_role_key_from_vault
--
-- Same rotation-safety problem as 20260811_08, different hiding place.
-- Fifteen pg_cron jobs (thirteen of them active, some every minute) also carried
-- the service_role JWT as a literal inside cron.job.command. Rotating the key
-- would have left every one of them posting a dead credential on schedule.
-- These are arguably the worse exposure of the two: cron.job is readable by
-- more roles than a function body, and the failure is just as quiet.
--
-- TO ROTATE: nothing extra. These jobs read the same vault secret as the
-- functions, so the single vault.update_secret call documented in
-- 20260811_08_read_api_keys_from_vault_not_literals.sql covers them too.
--
-- TRANSFORM
-- Each command is rewritten to a DO block that reads the key from the vault and
-- EXECUTEs the original command text with a placeholder substituted back in.
-- The point of doing it this way rather than editing each command by hand is
-- that the SQL finally executed is byte-for-byte the command that runs today.
-- No quoting, cast-precedence or header-shape difference can creep in, and the
-- two different header styles in use (jsonb literal vs jsonb_build_object) need
-- no special casing. The migration asserts that byte-equality per job, and
-- compiles each generated block before installing it.
--
-- One deliberate behaviour change: if the vault secret is missing or empty the
-- job now RAISEs instead of posting an unauthenticated request. That records a
-- failure in cron.job_run_details, which is the whole point. A silent 401 was
-- how this class of bug stayed invisible.

DO $mig$
DECLARE
  r          record;
  v_key      text;
  v_template text;
  v_block    text;
  v_new      text;
  v_count    int := 0;
BEGIN
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key';

  IF v_key IS NULL OR v_key = '' THEN
    RAISE EXCEPTION 'vault secret service_role_key must exist before this migration runs';
  END IF;

  FOR r IN
    SELECT jobid, jobname, command
    FROM cron.job
    WHERE position(v_key in command) > 0
    ORDER BY jobid
  LOOP
    -- Refuse anything whose shape would make the wrapper unsafe.
    IF r.command LIKE '%$sql$%' OR r.command LIKE '%$cron$%' THEN
      RAISE EXCEPTION 'job % (%) contains a conflicting dollar-quote tag; refusing to rewrite', r.jobid, r.jobname;
    END IF;
    IF r.command LIKE '%__SERVICE_ROLE_KEY__%' THEN
      RAISE EXCEPTION 'job % (%) already contains the placeholder token; refusing to rewrite', r.jobid, r.jobname;
    END IF;

    v_template := replace(r.command, v_key, '__SERVICE_ROLE_KEY__');

    -- Byte-equality proof: substituting the key back must reproduce the
    -- current command exactly, or we do not touch this job.
    IF replace(v_template, '__SERVICE_ROLE_KEY__', v_key) IS DISTINCT FROM r.command THEN
      RAISE EXCEPTION 'job % (%) failed the round-trip equality check; refusing to rewrite', r.jobid, r.jobname;
    END IF;

    v_block :=
      'DECLARE'                                                                         || E'\n' ||
      '  k text;'                                                                       || E'\n' ||
      'BEGIN'                                                                           || E'\n' ||
      '  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets'                   || E'\n' ||
      '   WHERE name = ''service_role_key'';'                                           || E'\n' ||
      '  IF k IS NULL OR k = '''' THEN'                                                 || E'\n' ||
      '    RAISE EXCEPTION ''vault secret service_role_key is missing or empty; '        ||
      'cron job ' || replace(r.jobname, '''', '''''') || ' did not run'';'              || E'\n' ||
      '  END IF;'                                                                       || E'\n' ||
      '  EXECUTE replace($sql$' || v_template || '$sql$, ''__SERVICE_ROLE_KEY__'', k);' || E'\n' ||
      'END';

    -- Compile the block before installing it. Creating a plpgsql function
    -- validates its syntax without running it; the inner EXECUTE string is
    -- never parsed here, and it is already proven identical to today's command.
    EXECUTE 'CREATE OR REPLACE FUNCTION pg_temp.cron_syntax_check() RETURNS void '
         || 'LANGUAGE plpgsql AS $chk$' || v_block || '$chk$';

    v_new := 'DO $cron$' || E'\n' || v_block || E'\n' || '$cron$;';

    PERFORM cron.alter_job(job_id := r.jobid, command := v_new);
    v_count := v_count + 1;
    RAISE NOTICE 'rewrote cron job % (%)', r.jobid, r.jobname;
  END LOOP;

  DROP FUNCTION IF EXISTS pg_temp.cron_syntax_check();

  IF v_count = 0 THEN
    RAISE EXCEPTION 'no cron jobs matched; expected 15';
  END IF;
  RAISE NOTICE 'rewrote % cron jobs', v_count;
END
$mig$;
