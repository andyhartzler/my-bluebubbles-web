-- Migration : 20260422_02_mec_donors_empty_sources_cleanup
-- Author    : Andrew (via Claude, 2026-04-21)
-- Purpose   : Backfill and tag the 255,321 legacy mec_donors rows that have
--             sources = '{}' after the 2026-04-21 dedup pass (commit 8989a7310).
--
-- Investigation findings (all 255,321 empty-sources rows share these properties):
--   * Created in a single batch on 2026-03-09 (pre-dedup legacy import).
--   * Zero rows in mec_contributions FK'd to them (donor_id never wired back).
--   * Zero rows in fec_contributions FK'd to them.
--   * 100% have non-zero `total_contributed` and `contribution_count`
--     (aggregates computed at import time from MEC CD1_A rows).
--   * 100% have `fec_total_contributed = 0` and `fec_contribution_count = 0`.
--   * 100% have `committees_donated_to` populated with MEC committee NAMES
--     (e.g. "Friends of Bob Nolte"), not FEC committee IDs (C00XXXXX) —
--     unambiguous MEC provenance.
--   * 99.96% have at least one of first_contribution_date / last_contribution_date.
--   * 89,301 have mo_voter_file_id populated (matched to MO voter file).
--   * 186,438 are referenced by donor_enrichment FK (cannot delete).
--   * Zero are referenced by call_time_list_items or mo_business_entities.
--   * Breakdown by donor_type : 202,800 individual / 37,297 committee / 15,224 company.
--   * Breakdown by match_status: 123,299 not_applicable / 89,292 matched / 42,730 no_match.
--
-- Conclusion: these are LEGACY MEC ROWS whose contribution-level FK linkage was
-- never established during their original import. The source is unambiguous
-- from the data itself. Correct fix is to backfill sources = {'mec'} so they
-- flow through the downstream MEC/FEC-aware pipelines correctly, and to leave
-- a notes marker so the legacy origin is auditable.
--
-- Safety:
--   * Wrapped in a single transaction; any failure rolls back.
--   * Idempotent : re-running is a no-op (guarded by NOT ('mec' = ANY(sources))
--     and notes-marker presence check).
--   * No rows deleted. No match_status changes. No FK reassignment.
--   * Pre/post integrity counts asserted inside the transaction; a mismatch
--     raises and rolls back.

BEGIN;
SET LOCAL statement_timeout = '30min';

-- ---------------------------------------------------------------------------
-- Snapshot pre-state into a temp table so we can both log and assert invariants.
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE _empty_sources_before ON COMMIT DROP AS
SELECT id
FROM public.mec_donors
WHERE sources = '{}' OR sources IS NULL;

DO $$
DECLARE
  v_before_count           bigint;
  v_before_with_mec_fk     bigint;
  v_before_with_fec_fk     bigint;
  v_before_with_fec_totals bigint;
BEGIN
  SELECT count(*) INTO v_before_count FROM _empty_sources_before;

  -- Sanity : none of these should have FK contribution rows.
  SELECT count(DISTINCT c.donor_id)
    INTO v_before_with_mec_fk
    FROM public.mec_contributions c
    JOIN _empty_sources_before b ON b.id = c.donor_id;

  SELECT count(DISTINCT c.donor_id)
    INTO v_before_with_fec_fk
    FROM public.fec_contributions c
    JOIN _empty_sources_before b ON b.id = c.donor_id;

  -- Sanity : none should have FEC aggregates.
  SELECT count(*)
    INTO v_before_with_fec_totals
    FROM public.mec_donors d
    JOIN _empty_sources_before b ON b.id = d.id
   WHERE d.fec_total_contributed > 0 OR d.fec_contribution_count > 0;

  RAISE NOTICE 'pre-state : empty_sources=% mec_fk_linked=% fec_fk_linked=% rows_with_fec_totals=%',
               v_before_count, v_before_with_mec_fk, v_before_with_fec_fk, v_before_with_fec_totals;

  IF v_before_with_mec_fk > 0 OR v_before_with_fec_fk > 0 THEN
    RAISE EXCEPTION 'integrity surprise : empty-sources rows unexpectedly have FK contribution links (mec=%, fec=%) — aborting',
                    v_before_with_mec_fk, v_before_with_fec_fk;
  END IF;

  IF v_before_with_fec_totals > 0 THEN
    RAISE EXCEPTION 'integrity surprise : % empty-sources rows unexpectedly have non-zero FEC aggregates — aborting',
                    v_before_with_fec_totals;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Backfill : sources = {'mec'} + notes marker.
-- Guard clauses make this idempotent even if partially re-run.
-- ---------------------------------------------------------------------------
UPDATE public.mec_donors d
   SET sources    = ARRAY['mec']::text[],
       notes      = CASE
                      WHEN d.notes IS NULL OR d.notes = '' THEN
                        'legacy-mec-import (empty-sources backfill 2026-04-22)'
                      WHEN d.notes LIKE '%legacy-mec-import%' THEN
                        d.notes
                      ELSE
                        d.notes || ' | legacy-mec-import (empty-sources backfill 2026-04-22)'
                    END,
       updated_at = now()
  FROM _empty_sources_before b
 WHERE d.id = b.id
   AND (d.sources = '{}' OR d.sources IS NULL);

-- ---------------------------------------------------------------------------
-- Post-state assertions.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_before_count          bigint;
  v_still_empty           bigint;
  v_now_mec_tagged        bigint;
  v_unexpected_fec_tagged bigint;
BEGIN
  SELECT count(*) INTO v_before_count FROM _empty_sources_before;

  SELECT count(*)
    INTO v_still_empty
    FROM public.mec_donors d
    JOIN _empty_sources_before b ON b.id = d.id
   WHERE d.sources = '{}' OR d.sources IS NULL;

  SELECT count(*)
    INTO v_now_mec_tagged
    FROM public.mec_donors d
    JOIN _empty_sources_before b ON b.id = d.id
   WHERE 'mec' = ANY(d.sources);

  SELECT count(*)
    INTO v_unexpected_fec_tagged
    FROM public.mec_donors d
    JOIN _empty_sources_before b ON b.id = d.id
   WHERE 'fec' = ANY(d.sources);

  RAISE NOTICE 'post-state: before=% still_empty=% now_mec_tagged=% unexpected_fec_tagged=%',
               v_before_count, v_still_empty, v_now_mec_tagged, v_unexpected_fec_tagged;

  IF v_still_empty <> 0 THEN
    RAISE EXCEPTION 'integrity failure : % target rows still have empty sources after backfill — aborting',
                    v_still_empty;
  END IF;

  IF v_now_mec_tagged <> v_before_count THEN
    RAISE EXCEPTION 'integrity failure : expected % rows to carry mec source after backfill, got %',
                    v_before_count, v_now_mec_tagged;
  END IF;

  IF v_unexpected_fec_tagged <> 0 THEN
    RAISE EXCEPTION 'integrity failure : % target rows unexpectedly carry fec source after backfill — aborting',
                    v_unexpected_fec_tagged;
  END IF;
END $$;

COMMIT;
