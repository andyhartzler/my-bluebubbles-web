-- mail-poll was reachable by anyone on the internet, and the cron that calls it
-- had never authenticated once.
--
-- Job 87 (mail-poll-fallback-5min) posted URL-only with no Authorization header:
--     SELECT net.http_post(url := '.../mail-poll');
-- so it took 401 every five minutes, 288 times a day, for months. pg_cron still
-- recorded every run as succeeded, because the DO block itself ran. The mail
-- polling fallback has therefore never done any work.
--
-- The earlier repair removed the check instead of supplying a credential: the
-- function was deployed --no-verify-jwt, which silenced the 401 by making it
-- public. An unauthenticated POST then returned 200 plus a per-mailbox result
-- list naming every mailbox we watch. That discloses internal addresses and lets
-- a stranger drive Gmail history walks on demand. Verified live before this fix.
--
-- Correct shape, and the one the rest of this project already uses: the cron
-- carries x-cron-secret from the vault, and the function verifies it. The vault
-- secret cron_secret was confirmed to hash-match the CRON_SECRET edge function
-- secret before wiring, so the two sides genuinely agree.
--
-- RAISES rather than proceeding when the vault lookup is empty. A missing secret
-- must be loud; posting unauthenticated is what created this situation.
--
-- Verified both directions on the running system after applying:
--   unauthenticated POST      -> 401 {"error":"unauthorized"}
--   the 01:35 cron tick       -> 200 with per-mailbox results
select cron.alter_job(
  job_id  := 87,
  command := $cmd$
DO $mp$
DECLARE k text;
BEGIN
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets WHERE name = 'cron_secret';
  IF k IS NULL OR k = '' THEN
    RAISE EXCEPTION 'mail-poll cron: vault secret cron_secret is missing; refusing to call unauthenticated';
  END IF;
  PERFORM net.http_post(
    url     := 'https://faajpcarasilbfndzkmd.functions.supabase.co/mail-poll',
    headers := jsonb_build_object('Content-Type','application/json','x-cron-secret',k),
    body    := '{}'::jsonb
  );
END
$mp$;
  $cmd$
);
