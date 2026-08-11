-- Applied to production 2026-08-11 as 20260811_03_mautic_sync_log_retention.
--
-- Retention for public.mautic_sync_log.
--
-- The table reached 534,882 rows / 638 MB because a feedback loop wrote ~46,000
-- rows a day for six days (fixed in 20260811_02) and because nothing had ever
-- pruned it. It is an audit log with no readers: no view, no RPC, and no Flutter
-- code selects from it. Only sync-to-mautic, bulk-sync-to-mautic, mautic-webhook
-- and link-mautic-ids write to it.
--
-- Policy:
--   * success = false  -> kept indefinitely. Failures are the diagnostic value
--                         of this table and there are only ~71k of them.
--   * success = true   -> kept 180 days. A successful sync receipt older than
--                         six months has no consumer; the authoritative
--                         members.mautic_id / subscribers.mautic_id linkage
--                         lives on the entity rows, not here.
--
-- First run 2026-08-11 removed 1,303 rows (everything successful and older than
-- 180 days at that point).
--
-- Deletes in 25k chunks so a large first pass cannot hold one long transaction.

CREATE OR REPLACE FUNCTION public.fn_prune_mautic_sync_log(p_keep_days integer DEFAULT 180)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted bigint;
  v_total   bigint := 0;
BEGIN
  LOOP
    WITH victims AS (
      SELECT id
      FROM public.mautic_sync_log
      WHERE success = true
        AND created_at < now() - make_interval(days => p_keep_days)
      LIMIT 25000
    )
    DELETE FROM public.mautic_sync_log l
    USING victims v
    WHERE l.id = v.id;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    v_total := v_total + v_deleted;
    EXIT WHEN v_deleted = 0;
  END LOOP;

  RETURN v_total;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_prune_mautic_sync_log(integer) FROM PUBLIC, anon, authenticated;

SELECT cron.schedule(
  'prune-mautic-sync-log-weekly',
  '10 4 * * 0',
  $cron$SELECT public.fn_prune_mautic_sync_log(180);$cron$
);

-- One-off cleanup performed 2026-08-11 alongside this migration, recorded here
-- for the history. 273,056 rows were deleted: the redundant successful
-- to_mautic member-update receipts written by the loop for member
-- d3b78425-e543-4cc5-ad3f-5ed8834dce1c between 2026-08-05 19:46 and
-- 2026-08-11 16:44. Every one carried an identical payload and an identical
-- {"mautic_id": 277977} response. The first 100 and last 100 were kept as
-- evidence of the incident, along with all 89 other rows for that member.
-- Followed by VACUUM (FULL, ANALYZE), which took the table from 638 MB to
-- 436 MB.
--
-- WITH ranked AS (
--   SELECT id, row_number() OVER (ORDER BY id) AS rn, count(*) OVER () AS c
--   FROM public.mautic_sync_log
--   WHERE entity_type = 'member' AND action = 'update' AND success = true
--     AND entity_id = 'd3b78425-e543-4cc5-ad3f-5ed8834dce1c'
--     AND created_at >= '2026-08-05 19:46:00+00'
-- )
-- DELETE FROM public.mautic_sync_log l USING ranked v
--  WHERE l.id = v.id AND v.rn > 100 AND v.rn <= v.c - 100;
