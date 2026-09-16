-- ============================================================================
-- 20260916_01_query_layer_aggregates.sql
--
-- Three grouped read RPCs that replace client-side aggregation the Dart query
-- layer was doing over truncated result sets. Each one fixes a WRONG-ANSWER
-- bug, not just a slow one:
--
--   1. get_subscriber_event_counts() replaces _enrichWithEventCounts(), which
--      ran ceil(N/50) UNFILTERED reads of public.event_attendees per
--      fetchSubscribers() call and derived attendance from the first 1000 rows
--      PostgREST returns. event_attendees is 0 rows today, so the truncation
--      is invisible now and certain later.
--   2. get_knowledge_stats() replaces three `.select()` + exact-count calls
--      and an ~80-round-trip pagination loop over public.knowledge_documents
--      (79k rows / 1664 MB, avg 9.9 kB/row including `content` and the
--      pgvector `embedding`). The three counts pulled up to 1000 FULL rows
--      each and read only `.count`.
--   3. get_mec_contributor_profile() replaces an unranged select over
--      public.mec_contributions (3.27M rows) whose totals were computed in
--      Dart from the 1000 most recent rows. A contributor with more than 1000
--      contributions reported a total that was simply wrong, with no error.
--
-- House conventions, matching 20260722_stats_rpcs.sql:
--   * SECURITY DEFINER with a hard staff guard: (SELECT public.is_staff())
--   * search_path pinned to public
--   * STABLE (read-only)
--   * REVOKE ALL FROM PUBLIC, GRANT EXECUTE TO authenticated
--
-- DEPLOY ORDER: apply this BEFORE the Flutter build that calls these RPCs.
-- The Dart callers have no legacy fallback path (the old one is deleted in the
-- same change, per the standing no-back-compat rule), so a build deployed
-- ahead of this migration shows empty stats rather than slow stats.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- get_subscriber_event_counts(): event attendance per subscriber email
--
-- One grouped read for a whole page of subscribers. Emails are matched
-- against public.members.email, which is the same join the client was doing
-- by hand via the `member:members!member_id(email)` embed.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_subscriber_event_counts(p_emails text[])
RETURNS TABLE (email text, attendance_count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (SELECT public.is_staff()) THEN
    RAISE EXCEPTION 'insufficient_privilege: staff role required'
      USING ERRCODE = '42501';
  END IF;

  IF p_emails IS NULL OR array_length(p_emails, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT m.email::text, count(*)::bigint
  FROM public.event_attendees ea
  JOIN public.members m ON m.id = ea.member_id
  WHERE ea.member_id IS NOT NULL
    AND m.email = ANY (p_emails)
  GROUP BY m.email;
END;
$$;

COMMENT ON FUNCTION public.get_subscriber_event_counts(text[]) IS
  'Per-email event attendance counts for the subscribers list. Replaces the '
  'per-50-subscriber unfiltered scan of event_attendees in '
  'SubscriberRepository._enrichWithEventCounts, which was capped at 1000 rows '
  'by PostgREST and so derived counts from an arbitrary slice.';

REVOKE ALL ON FUNCTION public.get_subscriber_event_counts(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_subscriber_event_counts(text[]) TO authenticated;


-- ─────────────────────────────────────────────────────────────────────────
-- get_knowledge_stats(): totals + embedding status + source breakdowns
--
-- Counts stay EXACT rather than becoming reltuples estimates: the AI
-- Assistant admin screen shows pending/failed embedding counts that an
-- operator acts on, and a grouped count over 79k rows is cheap once it runs
-- server-side. The expensive part was never the counting, it was shipping
-- ~1000 rows of `content` + `embedding` across the wire three times and then
-- paging the whole table to build two tallies.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_knowledge_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total    bigint;
  v_pending  bigint;
  v_failed   bigint;
  v_by_table jsonb;
  v_by_type  jsonb;
BEGIN
  IF NOT (SELECT public.is_staff()) THEN
    RAISE EXCEPTION 'insufficient_privilege: staff role required'
      USING ERRCODE = '42501';
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE embedding_status = 'pending'),
    count(*) FILTER (WHERE embedding_status = 'failed')
  INTO v_total, v_pending, v_failed
  FROM public.knowledge_documents;

  SELECT COALESCE(jsonb_object_agg(source_table, cnt), '{}'::jsonb)
  INTO v_by_table
  FROM (
    SELECT source_table, count(*) AS cnt
    FROM public.knowledge_documents
    WHERE source_table IS NOT NULL
    GROUP BY source_table
  ) t;

  SELECT COALESCE(jsonb_object_agg(source_type, cnt), '{}'::jsonb)
  INTO v_by_type
  FROM (
    SELECT source_type, count(*) AS cnt
    FROM public.knowledge_documents
    WHERE source_type IS NOT NULL
    GROUP BY source_type
  ) t;

  RETURN jsonb_build_object(
    'total_documents',   COALESCE(v_total, 0),
    'pending_embeddings', COALESCE(v_pending, 0),
    'failed_embeddings',  COALESCE(v_failed, 0),
    'by_table',          v_by_table,
    'by_type',           v_by_type
  );
END;
$$;

COMMENT ON FUNCTION public.get_knowledge_stats() IS
  'Single-round-trip knowledge base stats. Replaces three bare select() + '
  'exact-count calls and an ~80-page pagination loop in '
  'AIAssistantService.getStats(). Counts are exact by design: operators act '
  'on the pending and failed embedding figures.';

REVOKE ALL ON FUNCTION public.get_knowledge_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_knowledge_stats() TO authenticated;


-- ─────────────────────────────────────────────────────────────────────────
-- get_mec_contributor_profile(): totals, year bounds and per-committee
-- rollup for one contributor, over ALL matching rows.
--
-- Match semantics mirror the Dart exactly: ILIKE on each supplied field with
-- the caller's value passed through verbatim (no wildcards added here), and
-- the optional first-name / company predicates applied only when non-empty.
-- Year uses COALESCE(filing_year, year(contribution_date)), matching
-- `c.filingYear ?? c.contributionDate?.year`.
-- Committee grouping key is COALESCE(mec_id, committee_name, 'unknown'),
-- matching the Dart map key, ordered by total descending.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_mec_contributor_profile(
  p_last_name  text,
  p_first_name text DEFAULT NULL,
  p_company    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total      numeric;
  v_count      bigint;
  v_first_year int;
  v_last_year  int;
  v_committees jsonb;
BEGIN
  IF NOT (SELECT public.is_staff()) THEN
    RAISE EXCEPTION 'insufficient_privilege: staff role required'
      USING ERRCODE = '42501';
  END IF;

  -- Guard against the degenerate call. `contributor_last_name ILIKE ''` is
  -- not a contributor identity: it matches 1,438,577 rows, cannot use the
  -- trigram index, and plans a Seq Scan plus HashAggregate measured at
  -- 11,255 ms on production. The `authenticated` role carries
  -- statement_timeout = 8s, so that call does not return slowly, it returns
  -- error 57014 and the profile panel shows nothing at all.
  -- An empty identity has no answer worth computing, so return the empty
  -- shape instead of scanning the table to discover that.
  IF (p_last_name IS NULL OR p_last_name = '')
     AND (p_first_name IS NULL OR p_first_name = '')
     AND (p_company IS NULL OR p_company = '') THEN
    RETURN jsonb_build_object(
      'total_amount', 0,
      'count',        0,
      'first_year',   NULL,
      'last_year',    NULL,
      'committees',   '[]'::jsonb
    );
  END IF;

  -- One scan, not two. The expensive predicate below used to be evaluated
  -- in two separate statements, once for the totals and once for the
  -- per-committee rollup, so the only costly part of this function ran
  -- twice. MATERIALIZED forces the CTE to be computed exactly once and
  -- reused by both consumers, roughly halving the call.
  -- A temp table would also work but is not an option here: this function
  -- is STABLE, and STABLE forbids DDL.
  WITH matched AS MATERIALIZED (
    SELECT
      c.mec_id,
      c.committee_name,
      COALESCE(c.contribution_amount, 0) AS amount,
      COALESCE(c.filing_year, EXTRACT(YEAR FROM c.contribution_date)::int) AS yr
    FROM public.mec_contributions c
    WHERE (p_last_name IS NULL OR p_last_name = ''
           OR c.contributor_last_name ILIKE p_last_name)
      AND (p_first_name IS NULL OR p_first_name = ''
           OR c.contributor_first_name ILIKE p_first_name)
      AND (p_company IS NULL OR p_company = ''
           OR c.contributor_company ILIKE p_company)
  ),
  totals AS (
    SELECT
      COALESCE(sum(amount), 0) AS total_amount,
      count(*)                 AS row_count,
      min(yr)                  AS first_year,
      max(yr)                  AS last_year
    FROM matched
  ),
  rolled AS (
    SELECT
      min(mec_id)         AS mec_id,
      min(committee_name) AS committee_name,
      sum(amount)         AS total,
      count(*)            AS cnt
    FROM matched
    GROUP BY COALESCE(mec_id, committee_name, 'unknown')
  ),
  committees AS (
    SELECT COALESCE(
             jsonb_agg(
               jsonb_build_object(
                 'mecId',         mec_id,
                 'committeeName', committee_name,
                 'total',         total,
                 'count',         cnt
               )
               ORDER BY total DESC
             ),
             '[]'::jsonb
           ) AS payload
    FROM rolled
  )
  SELECT t.total_amount, t.row_count, t.first_year, t.last_year, c.payload
    INTO v_total, v_count, v_first_year, v_last_year, v_committees
    FROM totals t CROSS JOIN committees c;

  RETURN jsonb_build_object(
    'total_amount', COALESCE(v_total, 0),
    'count',        COALESCE(v_count, 0),
    'first_year',   v_first_year,
    'last_year',    v_last_year,
    'committees',   v_committees
  );
END;
$$;

COMMENT ON FUNCTION public.get_mec_contributor_profile(text, text, text) IS
  'Server-side totals, year bounds and per-committee rollup for one MEC '
  'contributor. Replaces MecRepository.getContributorProfile''s client-side '
  'fold over an unranged select of public.mec_contributions (3.27M rows), '
  'which PostgREST silently truncated at 1000 date-ordered rows, understating '
  'every figure for any contributor above that.';

REVOKE ALL ON FUNCTION public.get_mec_contributor_profile(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_mec_contributor_profile(text, text, text) TO authenticated;
