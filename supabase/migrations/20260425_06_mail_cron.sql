-- Daily refresh of users.watch on crm@. Gmail expires the watch within
-- 7 days; running daily gives us ~6+ days of headroom on every renewal.
-- The receiver function is deployed with --no-verify-jwt so the cron
-- doesn't need to send an Authorization header.

SET search_path = public, pg_temp;

SELECT cron.schedule(
  'mail-watch-renew-daily',
  '15 9 * * *', -- 09:15 UTC daily (4:15am Central)
  $$ SELECT net.http_post(
       url := 'https://faajpcarasilbfndzkmd.functions.supabase.co/mail-watch-renew'
     ); $$
);
