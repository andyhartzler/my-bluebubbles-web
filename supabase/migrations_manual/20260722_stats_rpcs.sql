-- ============================================================================
-- 20260722_stats_rpcs.sql
-- Draft D3 (perf-2026-07-21.md): consolidate N-parallel-count "fetchStats"
-- patterns into single grouped SECURITY DEFINER RPCs.
--
-- Motivation: SubscriberRepository.fetchStats() fired 7 separate round-trips
-- (6 exact COUNT()s + a full-column pull of `source` for the client-side
-- _sourceBreakdown facet) against the 73k-row public.subscribers table on
-- every Subscribers overview load. The committees dashboard fired one
-- exact COUNT() over public.members PER committee (getMemberCountForCommittee
-- looped across CommitteeDefinitions.all). Both collapse to a single scan.
--
-- Each RPC:
--   * is SECURITY DEFINER with a hard staff guard: (SELECT public.is_staff())
--   * pins search_path = public (stable, injection-safe)
--   * is STABLE (read-only)
--   * returns jsonb the repository maps into its existing stats model
--
-- Semantics of get_subscriber_stats() mirror fetchStats() EXACTLY, including
-- the two fallbacks:
--   1. if the boolean `subscribed` split yields 0/0, fall back to the
--      `subscription_status` text column.
--   2. if unsubscribed is still 0 but total > active, derive it as total-active.
-- All facets scope to member_id IS NULL (subscribers that are not members),
-- matching the ..filter('member_id','is',null) applied throughout the repo.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- get_subscriber_stats(): 7-stat subscriber overview in one round-trip
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_subscriber_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total     int;
  v_active    int;
  v_unsub     int;
  v_donors    int;
  v_contact   int;
  v_recent    int;
  v_ss_sub    int;
  v_ss_unsub  int;
  v_by_source jsonb;
BEGIN
  -- Staff gate (matches RLS is_staff() used elsewhere). Wrapped in SELECT so
  -- the planner treats it as an InitPlan constant, not a per-row call.
  IF NOT (SELECT public.is_staff()) THEN
    RAISE EXCEPTION 'insufficient_privilege: staff role required'
      USING ERRCODE = '42501';
  END IF;

  -- Single scan of subscribers: all scalar facets via FILTER aggregates.
  SELECT
    count(*) FILTER (WHERE member_id IS NULL),
    count(*) FILTER (WHERE member_id IS NULL AND subscribed IS TRUE),
    count(*) FILTER (WHERE member_id IS NULL AND subscribed IS FALSE),
    count(*) FILTER (WHERE member_id IS NULL AND donor_id IS NOT NULL),
    count(*) FILTER (WHERE member_id IS NULL
                       AND (phone_e164 IS NOT NULL OR address IS NOT NULL)),
    count(*) FILTER (WHERE member_id IS NULL
                       AND subscribed IS TRUE
                       AND optin_date >= now() - interval '30 days'),
    count(*) FILTER (WHERE member_id IS NULL
                       AND subscription_status = 'subscribed'),
    count(*) FILTER (WHERE member_id IS NULL
                       AND subscription_status = 'unsubscribed')
  INTO v_total, v_active, v_unsub, v_donors, v_contact, v_recent,
       v_ss_sub, v_ss_unsub
  FROM public.subscribers;

  -- Fallback 1: boolean column unused -> derive from subscription_status text.
  IF v_active = 0 AND v_unsub = 0 THEN
    v_active := v_ss_sub;
    v_unsub  := v_ss_unsub;
  END IF;

  -- Fallback 2: still no explicit unsubscribes -> infer as remainder.
  IF v_unsub = 0 AND v_total > v_active THEN
    v_unsub := v_total - v_active;
  END IF;

  -- Source breakdown facet: empty/NULL source bucketed as 'unknown'.
  SELECT COALESCE(jsonb_object_agg(src, cnt), '{}'::jsonb)
  INTO v_by_source
  FROM (
    SELECT COALESCE(NULLIF(source, ''), 'unknown') AS src, count(*) AS cnt
    FROM public.subscribers
    WHERE member_id IS NULL
    GROUP BY 1
  ) s;

  RETURN jsonb_build_object(
    'total_subscribers',  v_total,
    'active_subscribers', v_active,
    'unsubscribed',       v_unsub,
    'donor_count',        v_donors,
    'contact_info_count', v_contact,
    'recent_opt_ins',     v_recent,
    'by_source',          v_by_source
  );
END;
$$;

COMMENT ON FUNCTION public.get_subscriber_stats() IS
  'D3: single-round-trip replacement for SubscriberRepository.fetchStats(). '
  'Staff-gated, STABLE, search_path pinned. Returns the 7 overview stats '
  '(total/active/unsubscribed/donor_count/contact_info_count/recent_opt_ins/by_source).';

REVOKE ALL ON FUNCTION public.get_subscriber_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_subscriber_stats() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- get_committee_member_counts(): all committee member counts in one round-trip
-- Replaces the per-committee getMemberCountForCommittee() COUNT() loop on the
-- committees dashboard. members.committee is text[]; a member counts toward
-- every committee it lists (matches the array `contains` semantics).
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_committee_member_counts()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT (SELECT public.is_staff()) THEN
    RAISE EXCEPTION 'insufficient_privilege: staff role required'
      USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_object_agg(committee, cnt), '{}'::jsonb)
  INTO v_result
  FROM (
    SELECT c AS committee, count(*) AS cnt
    FROM public.members m, unnest(m.committee) AS c
    WHERE c IS NOT NULL AND c <> ''
    GROUP BY c
  ) s;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.get_committee_member_counts() IS
  'Single-round-trip replacement for the per-committee getMemberCountForCommittee() '
  'loop on the committees dashboard. Staff-gated, STABLE, search_path pinned. '
  'Returns {committee_name: member_count} for every non-empty committee.';

REVOKE ALL ON FUNCTION public.get_committee_member_counts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_committee_member_counts() TO authenticated;
