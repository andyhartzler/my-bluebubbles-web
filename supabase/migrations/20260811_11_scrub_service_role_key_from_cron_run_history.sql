-- Applied to production as version 20260811230923,
-- recorded name: 20260811_05_scrub_service_role_key_from_cron_run_history
--
-- cron.job_run_details keeps the full command text of every run, so ~141k rows
-- of run history still contained the live service_role JWT even after
-- 20260811_09 rewrote the job definitions themselves.
--
-- Not reachable by anon or authenticated: they hold SELECT on the table but no
-- USAGE on the cron schema, and PostgREST does not expose cron. So this is
-- hygiene, not an open door. It is worth doing anyway, because the whole point
-- of the rotation is that this string stops existing in places we did not
-- choose to put it.
--
-- The history itself is preserved. Only the credential is replaced.

UPDATE cron.job_run_details
SET command = replace(
      command,
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key'),
      '<redacted: now read from vault secret service_role_key>')
WHERE position((SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key') in command) > 0;
