-- trigger_calendar_sync() sent a hardcoded x-cron-secret that no longer matches
-- the sync-google-calendar function's CRON_SECRET, so every hourly run has been
-- rejected 401 "Missing Authorization header" since 2026-08-05 06:00 UTC. The
-- cron branch never fired, the request fell through to the user-JWT path, and
-- with no Authorization header at all the gate refused it. calendar_events
-- stopped being written on that date: max(synced_at) sat at 2026-08-05 06:00:06
-- while cron.job_run_details showed 600+ consecutive "succeeded" runs, because
-- pg_cron only records that net.http_post was queued, never the HTTP outcome.
--
-- The stale literal is why the hourly `invalid input syntax for type uuid:
-- "cron"` line disappeared from the logs around the same date. That looked like
-- 1cdb96e having been deployed. It was not: the function never got far enough to
-- attempt the audit insert.
--
-- Fix: read the secret from vault at call time, which is what every other cron
-- job in this project already does (archive-slack-messages-every-12h,
-- daily-slack-avatar-sync, process-embeddings, slack-committee-sync-10min,
-- slack-config-token-rotate-3h). vault.decrypted_secrets.cron_secret was
-- verified to be the function's CRON_SECRET by comparing its sha256 against the
-- digest the Management API returns for that secret. Keeping the value out of
-- this file also keeps it out of a PUBLIC repo, which the old literal did not.
create or replace function public.trigger_calendar_sync()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
begin
  perform net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/sync-google-calendar',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
end
$$;
