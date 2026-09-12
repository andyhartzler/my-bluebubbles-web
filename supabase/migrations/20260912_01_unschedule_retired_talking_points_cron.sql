-- Retire the cron that was still calling a function retired three weeks ago.
--
-- talking-points-batch-check, talking-points-batch-submit and
-- analyze-bills-batch-check were all deliberately retired on 2026-08-23 when the
-- project left the Anthropic Message Batches API; each now answers HTTP 410 with
-- a use_instead pointer. The analyze-bills-batch-check CRON was disabled at the
-- same time. The talking-points-batch-check cron was missed and has been firing
-- every ten minutes into a 410 ever since: 36 of them in a single six hour
-- window, roughly 2,900 since the retirement.
--
-- It was unscheduled live on 2026-09-12 after confirming the endpoint still
-- answers 410. This migration records that so the deletion exists in git rather
-- than only in the database, since the job had never been defined in a migration
-- in the first place.
--
-- For the record, the definition that was removed (schedule '*/10 * * * *'):
--   DO $cron$
--   DECLARE k text;
--   BEGIN
--     SELECT decrypted_secret INTO k FROM vault.decrypted_secrets
--      WHERE name = 'cron_secret';
--     IF k IS NULL OR k = '' THEN
--       RAISE EXCEPTION 'vault secret cron_secret is missing or empty';
--     END IF;
--     PERFORM net.http_post(
--       url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/talking-points-batch-check',
--       headers := jsonb_build_object('Content-Type','application/json','x-cron-secret', k)
--     );
--   END $cron$;
-- Do NOT recreate it. The endpoint it calls is retired by design; the
-- replacement named in its 410 body is generate-talking-points.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'talking-points-batch-check') then
    perform cron.unschedule('talking-points-batch-check');
  end if;
end
$$;
