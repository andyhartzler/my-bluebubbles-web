-- Schedule the onboarding-followups Edge Function every 10 minutes.
-- The function is deployed --no-verify-jwt and gates on the x-cron-secret
-- header matching ONBOARDING_CRON_SECRET. We keep that value in Vault (NOT in
-- this file / git) and read it at dispatch time, so the migration carries no
-- literal secret.
--
-- Prereq (run once, out of band, value NOT committed):
--   SELECT vault.create_secret('<ONBOARDING_CRON_SECRET value>', 'onboarding_cron_secret');
--
-- Safety: the function itself honors ONBOARDING_MODE. While mode is dry_run
-- (the default), this job sends no email and performs no Slack writes; it just
-- drains the (currently empty) queue as a no-op.
SET search_path = public, pg_temp;

SELECT cron.schedule(
  'onboarding-followups-10min',
  '*/10 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.functions.supabase.co/onboarding-followups',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'onboarding_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
