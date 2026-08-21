-- Superseded in part by 20260820_06: the explicit timeout_milliseconds this
-- originally set was removed there. Shown here without it.
-- Applied to production as version 20260821010246.
--
-- Job 29 (discover-new-tables, 00:00 Sunday) posted only
-- `Authorization: Bearer <service_role_key>`. discover-tables' gate calls
-- auth.getUser(), which by design accepts only a *user* JWT; a service_role key
-- has no `sub`, so GoTrue rejects it and the function returns its own 401.
--
-- Unlike jobs 45, 74 and 78 this was NOT observable in the edge logs, because
-- the job last fired 00:00 Sunday, outside the 24h retention window. The
-- evidence was the source read plus the identical shape. It was then PROVEN
-- after the fix by invoking the new path directly:
--   x-cron-secret -> 200, {"success":true,"discovered_tables":[...]}
--   (2026-08-21T01:02:35Z, discover-tables v42)
SELECT cron.alter_job(
  29,
  command := $job$
DO $cron$
DECLARE
  k text;
BEGIN
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets
   WHERE name = 'cron_secret';
  IF k IS NULL OR k = '' THEN
    RAISE EXCEPTION 'vault secret cron_secret is missing or empty; cron job discover-new-tables did not run';
  END IF;
  PERFORM net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/discover-tables',
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
