-- Superseded in part by 20260820_06: the explicit timeout_milliseconds this
-- originally set was removed there. Shown here without it.
-- Applied to production as version 20260821005653.
--
-- Job 78 (analyze-bills-local) posted only
-- `Authorization: Bearer <service_role_key>`. analyze-bill-local's gate calls
-- auth.getUser(), which by design accepts only a *user* JWT; a service_role key
-- has no `sub`, so GoTrue rejected it and the function returned its own
-- 401 {"error":"Invalid or expired JWT"} to every tick.
--
-- Verified in edge logs before the fix:
--   POST | 401 | .../analyze-bill-local, every 5 minutes.
--
-- The function had NO service path at all, so unlike job 45 this needed a code
-- change first: analyze-bill-local v32 adds the x-cron-secret path (deployed by
-- hand with --no-verify-jwt to preserve verify_jwt=false; there is no
-- supabase/config.toml, so the CLI would otherwise have flipped it to true).
-- This points the job at that path.
SELECT cron.alter_job(
  78,
  command := $job$
DO $cron$
DECLARE
  k text;
BEGIN
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets
   WHERE name = 'cron_secret';
  IF k IS NULL OR k = '' THEN
    RAISE EXCEPTION 'vault secret cron_secret is missing or empty; cron job analyze-bills-local did not run';
  END IF;
  PERFORM net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/analyze-bill-local',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', k
    ),
    body := jsonb_build_object(
      'processQueue', true,
      'batchSize', 10
    )
  );
END
$cron$;
$job$
);
