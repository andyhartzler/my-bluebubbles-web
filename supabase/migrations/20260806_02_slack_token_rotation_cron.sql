-- Schedule for the Slack app-config token rotation.
--
-- CADENCE, AND WHY
-- The access token lives 12 hours. Rotating every 3 hours gives four attempts
-- inside every token lifetime, so three consecutive failed runs still leave a
-- live token and a working refresh token to recover from. A 6 hour cadence
-- would tolerate exactly one miss, which is not margin, it is luck. An hourly
-- cadence would buy nothing extra and would multiply the number of trips through
-- the one genuinely irreversible moment in the process (Slack has answered, the
-- new pair is not yet committed) for no benefit.
--
-- Offset to :17 so this does not pile onto the crowd of jobs at the top of the
-- hour.
select cron.schedule(
  'slack-config-token-rotate-3h',
  '17 */3 * * *',
  $job$
  select net.http_post(
    url     := 'https://faajpcarasilbfndzkmd.functions.supabase.co/slack-token-rotate',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body    := '{"mode":"rotate","source":"cron"}'::jsonb,
    timeout_milliseconds := 30000
  );
  $job$
);

-- The watchdog is SQL only on purpose. The rotation runs in the edge runtime and
-- alerts on its own failures, but that cannot cover the case where the edge
-- function never runs at all, which is exactly the "Andrew finds out weeks
-- later" failure. This job needs nothing but Postgres and pg_net.
select cron.schedule(
  'slack-config-token-watchdog-hourly',
  '47 * * * *',
  $job$ select public.fn_slack_token_rotation_watchdog(); $job$
);
