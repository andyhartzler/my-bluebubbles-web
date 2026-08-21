-- Applied to production as version 20260821011135.
--
-- Follow-up to 20260820_01/_03/_04/_05. Those fixed the AUTH on jobs 45, 78, 74
-- and 29 but also set explicit timeout_milliseconds (60000/60000/120000/60000).
-- None of the four carried an explicit timeout before, so that was a change
-- beyond the defect, and it introduced a NEW failure mode.
--
-- pg_net processes queued requests in batches and waits for the batch to drain,
-- so one slow request head-of-line blocks every request enqueued behind it.
-- Observed directly: a 180000 ms test call to openstates-sync-tracked-bills held
-- the queue for ~78 s, and the every-minute extract-large-bill-text job did not
-- run until it cleared.
--
-- The long timeout also buys nothing, which was tested rather than assumed. The
-- edge function runs to completion regardless of when the pg_net client gives
-- up. openstates-sync-tracked-bills takes ~78 s for a batch of 10 and completed
-- all 10 bills under BOTH a 180000 ms and a 5000 ms timeout:
--   180000 ms -> 200, duration_ms 77872, bills 01:03:52 -> 01:05:08
--     5000 ms -> pg_net timeout recorded, bills 01:05:52 -> 01:07:04, all 10
-- and the scheduled 01:00 run under the 60000 ms setting likewise synced 10
-- bills, 01:00:05 -> 01:01:24, despite pg_net recording a timeout.
--
-- So: restore the default (5000 ms) on all four. Auth is the only change these
-- jobs needed.
--
-- CONSEQUENCE, worth knowing: for the slow jobs net._http_response will record
-- a timeout rather than the body, so it is NOT the place to judge whether the
-- work succeeded. Judge openstates from legislation_tracked_bills.last_synced_at,
-- analyze-bill-local from ai_analysis_pending / ai_analyzed_at, and plaid from
-- plaid_connections.last_synced_at. pg_cron's own "succeeded" means only that
-- the DO block ran, which is the same trap this batch of fixes was hiding behind.
DO $mig$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT jobid, jobname, command FROM cron.job WHERE jobid IN (29, 45, 74, 78)
  LOOP
    PERFORM cron.alter_job(
      r.jobid,
      command := regexp_replace(
        r.command,
        ',\s*\n?\s*timeout_milliseconds := \d+',
        '',
        'g'
      )
    );
  END LOOP;
END
$mig$;
