-- Phase 5 hardening crons for the mail client:
--   * mail-poll-fallback-5min — Pub/Sub silent-detection poll. If the
--     receiver hasn't been pinged in >5 min, runs an explicit
--     history.list walk. Catches Pub/Sub outages and watch lapses.
--   * mail-watch-health-hourly — alerts to Slack if the Gmail watch is
--     within 24h of expiry and the daily renew cron is stale.
--   * mail-reconcile-nightly — placeholder. The mail-reconcile edge
--     function isn't built yet; the cron schedule is registered now so
--     it's wired the moment the function lands.
--
-- All three are deployed as --no-verify-jwt edge functions, hit URL-only
-- with no auth header (matches the pattern of mail-watch-renew-daily).

SET search_path = public, pg_temp;

SELECT cron.schedule(
  'mail-poll-fallback-5min',
  '*/5 * * * *', -- every 5 minutes
  $$ SELECT net.http_post(
       url := 'https://faajpcarasilbfndzkmd.functions.supabase.co/mail-poll'
     ); $$
);

SELECT cron.schedule(
  'mail-watch-health-hourly',
  '0 * * * *', -- top of every hour
  $$ SELECT net.http_post(
       url := 'https://faajpcarasilbfndzkmd.functions.supabase.co/mail-watch-health'
     ); $$
);

SELECT cron.schedule(
  'mail-reconcile-nightly',
  '0 7 * * *', -- 07:00 UTC = 2am Central (placeholder; mail-reconcile not yet built)
  $$ SELECT net.http_post(
       url := 'https://faajpcarasilbfndzkmd.functions.supabase.co/mail-reconcile'
     ); $$
);
