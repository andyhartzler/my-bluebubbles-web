-- Superseded in part by 20260820_06: the explicit timeout_milliseconds this
-- originally set was removed there. Shown here without it.
-- Applied to production as version 20260821005503, name
-- "20260820_01_fix_openstates_sync_cron_auth". It shares the _01 sequence
-- number with 20260820_01_meetings_processing_status_is_derived.sql from a
-- concurrent session; that one applied first, at 20260821005411. The filename
-- matches the recorded migration name so the repo matches production.
--
-- Job 45 (openstates-sync-tracked-bills) posted only
-- `Authorization: Bearer <service_role_key>`. The function's gate is:
-- x-cron-secret == env CRON_SECRET, OR a *user* JWT that passes
-- auth.getUser() + is_staff(). A service_role key is not a user JWT, so
-- auth.getUser() rejects it and the function returns its own
-- 401 {"error":"Invalid or expired JWT"}.
--
-- Verified in edge logs before the fix:
--   POST | 401 | .../openstates-sync-tracked-bills, every 15 minutes.
--
-- Switch to the x-cron-secret path the function actually supports (the same
-- pattern slack-sync-to-slack uses, which returns 200 with vault `cron_secret`).
SELECT cron.alter_job(
  45,
  command := $job$
DO $cron$
DECLARE
  k text;
BEGIN
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets
   WHERE name = 'cron_secret';
  IF k IS NULL OR k = '' THEN
    RAISE EXCEPTION 'vault secret cron_secret is missing or empty; cron job openstates-sync-tracked-bills did not run';
  END IF;
  PERFORM net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/openstates-sync-tracked-bills',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', k
    ),
    body := '{}'::jsonb
  );
END
$cron$;
$job$
);
