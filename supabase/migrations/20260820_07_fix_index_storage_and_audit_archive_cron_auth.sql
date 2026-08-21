-- Applied to production as version 20260821010818.
--
-- Two more instances of the same defect, both found at the 03:00 daily window
-- and both confirmed on the running system BEFORE the fix:
--   POST | 401 | .../index-storage-files          2026-08-20T03:00:03Z
--   POST | 401 | .../export-audit-log-to-storage  2026-08-20T03:00:02Z
--
-- (1) Job 28, index-storage-files. The function's gate is
--     "user-JWT + is_staff() OR x-cron-secret", and it already HAS the cron
--     path. The job was posting Bearer <service_role_key>, which is not a user
--     JWT, so auth.getUser() rejected it. Switch to the path that exists.
--
-- (2) Job 84, audit-log-archive-daily, via fn_audit_log_archive_dispatch.
--     Worse: wrong secret AND wrong header. export-audit-log-to-storage accepts
--     ONLY `x-cron-secret: <CRON_SECRET>`, which its own header comment states,
--     but the dispatcher sent `Authorization: Bearer <AUDIT_ARCHIVE_FN_JWT>`.
--     The vault secret it used is a 64-char hex string rather than a JWT, and
--     the function never reads that header at all. So the nightly audit-log
--     archive has been failing silently, which matters because it is a
--     compliance/retention path: the partition prune (job 83) drops old audit
--     partitions on the assumption they were archived first.
--
--     Also upgraded RAISE WARNING to RAISE EXCEPTION on a missing vault secret,
--     so a bad rotation is loud rather than a skipped run, matching the pattern
--     20260811_09 established for the other jobs.
--
-- VERIFIED after the fix, on the running system:
--   fn_audit_log_archive_dispatch() -> 200
--   {"ok":true,"archived_date":"2026-08-20","row_count":569,
--    "storage_path":"daily/2026/08/audit_log_2026-08-20.ndjson",
--    "bucket":"audit-archive","bytes":1714412}
--
-- The vault secret AUDIT_ARCHIVE_FN_JWT is now unused by this path. It is left
-- in place rather than deleted: nothing here establishes that no other caller
-- reads it.
SELECT cron.alter_job(
  28,
  command := $job$
DO $cron$
DECLARE
  k text;
BEGIN
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets
   WHERE name = 'cron_secret';
  IF k IS NULL OR k = '' THEN
    RAISE EXCEPTION 'vault secret cron_secret is missing or empty; cron job index-storage-files did not run';
  END IF;
  PERFORM net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/index-storage-files',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', k
    ),
    body := '{"limit": 100}'::jsonb
  );
END
$cron$;
$job$
);

CREATE OR REPLACE FUNCTION public.fn_audit_log_archive_dispatch()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $fn$
DECLARE
  v_secret      text;
  v_target_date date := (now() AT TIME ZONE 'UTC')::date - 1;
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'cron_secret' LIMIT 1;

  IF v_secret IS NULL OR v_secret = '' THEN
    RAISE EXCEPTION
      'vault secret cron_secret is missing or empty; audit-log-archive-daily did not run for %', v_target_date;
  END IF;

  PERFORM net.http_post(
    url     := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/export-audit-log-to-storage',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-cron-secret',  v_secret
    ),
    body    := jsonb_build_object('date', v_target_date::text),
    timeout_milliseconds := 120000
  );
END;
$fn$;
