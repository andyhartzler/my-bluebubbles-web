-- Superseded in part by 20260820_06: the explicit timeout_milliseconds this
-- originally set was removed there. Shown here without it.
-- Applied to production as version 20260821010112.
--
-- Job 74 (plaid-daily-sync) posted only `Authorization: Bearer <service_role_key>`.
-- plaid's requireStaffUser() calls auth.getUser(), which by design accepts only
-- a *user* JWT; a service_role key has no `sub`, so GoTrue rejected it and the
-- function returned its own 401 to every run. Confirmed on the running system:
--   POST | 401 | .../plaid at 2026-08-20T06:00:01Z
-- The daily bank transaction sync has therefore never completed.
--
-- plaid v37 adds an x-cron-secret path scoped to `sync_transactions` ONLY;
-- link tokens, token exchange and MEC report generation still require a real
-- exec user JWT. Both halves of that were verified against the running system
-- after deploy:
--   x-cron-secret + {"action":"status"}            -> 401 (correctly refused)
--   x-cron-secret + {"action":"sync_transactions"} -> reaches the handler
--
-- NOTE: the sync still does not succeed, for a SEPARATE and pre-existing
-- reason. It now gets past the gate and fails at the Plaid API with
-- ITEM_LOGIN_REQUIRED: "the login details of this item have changed
-- (credentials, MFA, or required user action) and a user login is required".
-- That needs Andrew to re-authorise the UMB Bank connection through Plaid Link
-- update mode in the CRM. This migration fixes the auth defect only.
SELECT cron.alter_job(
  74,
  command := $job$
DO $cron$
DECLARE
  k text;
BEGIN
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets
   WHERE name = 'cron_secret';
  IF k IS NULL OR k = '' THEN
    RAISE EXCEPTION 'vault secret cron_secret is missing or empty; cron job plaid-daily-sync did not run';
  END IF;
  PERFORM net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/plaid',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', k
    ),
    body := '{"action": "sync_transactions"}'::jsonb
  );
END
$cron$;
$job$
);
