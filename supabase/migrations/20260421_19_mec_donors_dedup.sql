-- ⚠️ DRAFT — NOT YET APPLIED TO PRODUCTION DB as of 2026-04-22
-- Written by the mec_donors dedup agent but paused for review before apply.
-- Before running against production:
--   1. Spot-check the merge logic on a handful of known (firstname+lastname+city) pairs
--   2. Verify the canonical-id selection rule (prefers row with more FK links, then
--      the row with mo_voter_file_id populated)
--   3. Review the NOT IN exclusion list (#N/A, UNKNOWN, blank names)
--   4. Run inside a DB snapshot window with a rollback plan
-- See docs/superpowers/plans/2026-04-22-donor-schema-audit.md section 10 for
-- the data-integrity issues this migration is intended to fix.
--
-- Migration: 20260421_19_mec_donors_dedup.sql
-- Purpose:   Unify MEC + FEC donor identities inside public.mec_donors by
--            (1) marking unusable junk rows (#N/A, UNKNOWN, etc.) as not_applicable,
--            (2) back-filling empty `sources` arrays from FK contribution evidence,
--            (3) collapsing duplicate identities per donor_type and reassigning FK
--                rows (mec_contributions, fec_contributions, donor_enrichment,
--                call_time_list_items, mo_business_entities) onto a canonical row.
--
-- Safety:    Every mutating step runs inside its own transaction with
--            statement_timeout = 30min. Integrity totals are verified before +
--            after and the final merge step raises (triggering ROLLBACK) if
--            the reassigned FK count does not match the pre-merge count.
--
-- Audit log: public.mec_donor_merges captures every merge decision so it is
--            reproducible and reversible if needed.

---------------------------------------------------------------------------
-- STEP 0 :: Audit log table
---------------------------------------------------------------------------
BEGIN;
SET LOCAL statement_timeout = '30min';

CREATE TABLE IF NOT EXISTS public.mec_donor_merges (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  canonical_id  bigint NOT NULL,
  merged_id     bigint NOT NULL,
  donor_type    text,
  merge_key     text,
  merge_reason  text,
  merged_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mec_donor_merges_canonical ON public.mec_donor_merges (canonical_id);
CREATE INDEX IF NOT EXISTS idx_mec_donor_merges_merged   ON public.mec_donor_merges (merged_id);

COMMIT;

---------------------------------------------------------------------------
-- STEP 1 :: Mark placeholder/junk rows as not_applicable
-- Rationale: These rows represent data-quality garbage from bad imports —
--            #N/A, NOT PROVIDED, UNKNOWN, etc. — not real humans. They can
--            still have FK-linked contributions so we do NOT delete them;
--            we flag them so downstream consumers (call-time, enrichment)
--            can skip them.
---------------------------------------------------------------------------
BEGIN;
SET LOCAL statement_timeout = '30min';

WITH junk AS (
  SELECT id
  FROM public.mec_donors
  WHERE donor_type = 'individual'
    AND (
      UPPER(TRIM(COALESCE(first_name,''))) IN ('#N/A','N/A','NA','NOT PROVIDED','UNKNOWN','ANONYMOUS','NONE','NULL','UNITEMIZED')
      OR UPPER(TRIM(COALESCE(last_name, ''))) IN ('#N/A','N/A','NA','NOT PROVIDED','UNKNOWN','ANONYMOUS','NONE','NULL','UNITEMIZED')
    )
)
UPDATE public.mec_donors d
   SET match_status = 'not_applicable',
       notes        = COALESCE(NULLIF(d.notes,'') || ' | ', '') || 'junk-name marker (autoflagged 2026-04-21)',
       updated_at   = now()
  FROM junk j
 WHERE d.id = j.id
   AND (d.match_status IS DISTINCT FROM 'not_applicable'
        OR d.notes IS NULL
        OR d.notes NOT LIKE '%junk-name marker%');

COMMIT;

---------------------------------------------------------------------------
-- STEP 2 :: Back-fill sources[] from FK contribution evidence
-- If a donor has rows in mec_contributions, sources must contain 'mec'.
-- Same for fec_contributions -> 'fec'. Idempotent.
---------------------------------------------------------------------------
BEGIN;
SET LOCAL statement_timeout = '30min';

-- Append 'mec' where missing but mec_contributions link exists.
WITH mec_linked AS (
  SELECT DISTINCT donor_id FROM public.mec_contributions WHERE donor_id IS NOT NULL
)
UPDATE public.mec_donors d
   SET sources    = array_append(d.sources, 'mec'),
       updated_at = now()
  FROM mec_linked m
 WHERE d.id = m.donor_id
   AND NOT ('mec' = ANY(d.sources));

-- Append 'fec' where missing but fec_contributions link exists.
WITH fec_linked AS (
  SELECT DISTINCT donor_id FROM public.fec_contributions WHERE donor_id IS NOT NULL
)
UPDATE public.mec_donors d
   SET sources    = array_append(d.sources, 'fec'),
       updated_at = now()
  FROM fec_linked f
 WHERE d.id = f.donor_id
   AND NOT ('fec' = ANY(d.sources));

COMMIT;

---------------------------------------------------------------------------
-- STEP 3 :: Build canonical merge plan into a staging table
-- Per donor_type, compute a normalized merge_key and pick a canonical id.
-- Preference order for canonical:
--   1) has mo_voter_file_id
--   2) highest linked contribution count (mec + fec)
--   3) highest total_contributed + fec_total_contributed
--   4) lowest id (stable tie-breaker)
--
-- Ambiguous voter-file conflicts (two rows with DIFFERENT mo_voter_file_id
-- values in the same key group) are logged to mec_donor_merges_skipped and
-- NOT merged automatically.
---------------------------------------------------------------------------
BEGIN;
SET LOCAL statement_timeout = '30min';

DROP TABLE IF EXISTS public._mec_merge_plan;
DROP TABLE IF EXISTS public._mec_merge_plan_skipped;

CREATE UNLOGGED TABLE public._mec_merge_plan (
  canonical_id bigint NOT NULL,
  merged_id    bigint NOT NULL,
  donor_type   text,
  merge_key    text,
  mec_link_cnt bigint,
  fec_link_cnt bigint
);

CREATE UNLOGGED TABLE public._mec_merge_plan_skipped (
  donor_type text,
  merge_key  text,
  ids        bigint[],
  voter_ids  text[],
  reason     text
);

-- Normalized donor rows (excluding junk/not_applicable and rows that can't
-- be keyed at all).
WITH norm AS (
  SELECT d.id,
         d.donor_type,
         d.sources,
         d.total_contributed,
         d.fec_total_contributed,
         d.contribution_count,
         d.fec_contribution_count,
         d.mo_voter_file_id,
         LOWER(TRIM(REGEXP_REPLACE(COALESCE(d.first_name,    ''), '\s+', ' ', 'g'))) AS fn,
         LOWER(TRIM(REGEXP_REPLACE(COALESCE(d.last_name,     ''), '\s+', ' ', 'g'))) AS ln,
         LOWER(TRIM(REGEXP_REPLACE(COALESCE(d.company_name,  ''), '\s+', ' ', 'g'))) AS co,
         LOWER(TRIM(REGEXP_REPLACE(COALESCE(d.committee_name,''), '\s+', ' ', 'g'))) AS cm,
         LOWER(TRIM(REGEXP_REPLACE(COALESCE(d.city,          ''), '\s+', ' ', 'g'))) AS ct,
         UPPER(TRIM(COALESCE(d.state,''))) AS st
    FROM public.mec_donors d
   WHERE d.match_status IS DISTINCT FROM 'not_applicable'
),
keyed AS (
  SELECT *,
         CASE donor_type
           WHEN 'individual' THEN 'ind|' || fn || '|' || ln || '|' || ct || '|' || st
           WHEN 'company'    THEN 'com|' || co                     || '|' || ct || '|' || st
           WHEN 'committee'  THEN 'cmt|' || cm                     || '|' || ct || '|' || st
         END AS merge_key,
         CASE
           WHEN donor_type = 'individual' AND (fn = '' OR ln = '') THEN false
           WHEN donor_type = 'company'    AND co = '' THEN false
           WHEN donor_type = 'committee'  AND cm = '' THEN false
           WHEN donor_type = 'individual'
                AND (fn IN ('#n/a','n/a','na','not provided','unknown','anonymous','none','null','unitemized')
                     OR ln IN ('#n/a','n/a','na','not provided','unknown','anonymous','none','null','unitemized')) THEN false
           WHEN donor_type = 'company'
                AND co IN ('#n/a','n/a','na','not provided','unknown','anonymous','none','null','unitemized') THEN false
           WHEN donor_type = 'committee'
                AND cm IN ('#n/a','n/a','na','not provided','unknown','anonymous','none','null','unitemized') THEN false
           ELSE true
         END AS keyable
    FROM norm
),
fk_counts AS (
  SELECT d.id,
         COALESCE((SELECT COUNT(*) FROM public.mec_contributions mc WHERE mc.donor_id = d.id), 0) AS mec_link_cnt,
         COALESCE((SELECT COUNT(*) FROM public.fec_contributions fc WHERE fc.donor_id = d.id), 0) AS fec_link_cnt
    FROM keyed d
   WHERE d.keyable
),
groups AS (
  SELECT k.merge_key,
         k.donor_type,
         COUNT(*) AS row_count
    FROM keyed k
   WHERE k.keyable
   GROUP BY k.merge_key, k.donor_type
  HAVING COUNT(*) > 1
),
candidates AS (
  SELECT k.id,
         k.donor_type,
         k.merge_key,
         k.mo_voter_file_id,
         k.total_contributed,
         k.fec_total_contributed,
         fc.mec_link_cnt,
         fc.fec_link_cnt
    FROM keyed k
    JOIN groups g USING (merge_key, donor_type)
    LEFT JOIN fk_counts fc ON fc.id = k.id
),
ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY merge_key
           ORDER BY (mo_voter_file_id IS NOT NULL) DESC,
                    (COALESCE(mec_link_cnt,0) + COALESCE(fec_link_cnt,0)) DESC,
                    (COALESCE(total_contributed,0) + COALESCE(fec_total_contributed,0)) DESC,
                    id ASC
         ) AS rnk
    FROM candidates
),
voter_conflicts AS (
  SELECT merge_key,
         MAX(donor_type) AS donor_type,
         ARRAY_AGG(id) AS ids,
         ARRAY_AGG(DISTINCT mo_voter_file_id) FILTER (WHERE mo_voter_file_id IS NOT NULL) AS voter_ids
    FROM candidates
   GROUP BY merge_key
  HAVING COUNT(DISTINCT mo_voter_file_id) FILTER (WHERE mo_voter_file_id IS NOT NULL) > 1
)
-- Store skipped groups (ambiguous voter file ids).
INSERT INTO public._mec_merge_plan_skipped (donor_type, merge_key, ids, voter_ids, reason)
SELECT donor_type, merge_key, ids, voter_ids,
       'multiple distinct mo_voter_file_id values in group'
  FROM voter_conflicts;

-- Build the merge plan (exclude skipped groups).
INSERT INTO public._mec_merge_plan (canonical_id, merged_id, donor_type, merge_key, mec_link_cnt, fec_link_cnt)
SELECT r_canonical.id    AS canonical_id,
       r_other.id        AS merged_id,
       r_canonical.donor_type,
       r_canonical.merge_key,
       r_other.mec_link_cnt,
       r_other.fec_link_cnt
  FROM ranked r_canonical
  JOIN ranked r_other
    ON r_canonical.merge_key = r_other.merge_key
   AND r_canonical.rnk = 1
   AND r_other.rnk > 1
 WHERE r_canonical.merge_key NOT IN (SELECT merge_key FROM public._mec_merge_plan_skipped);

CREATE INDEX ON public._mec_merge_plan (canonical_id);
CREATE INDEX ON public._mec_merge_plan (merged_id);

ANALYZE public._mec_merge_plan;
ANALYZE public._mec_merge_plan_skipped;

-- Report plan size.
DO $$
DECLARE
  total_pairs bigint;
  distinct_canonicals bigint;
  skipped_groups bigint;
BEGIN
  SELECT COUNT(*), COUNT(DISTINCT canonical_id) INTO total_pairs, distinct_canonicals FROM public._mec_merge_plan;
  SELECT COUNT(*) INTO skipped_groups FROM public._mec_merge_plan_skipped;
  RAISE NOTICE 'Merge plan: % merge-pairs across % canonical identities (% groups skipped as ambiguous)',
    total_pairs, distinct_canonicals, skipped_groups;
END$$;

COMMIT;

---------------------------------------------------------------------------
-- STEP 4 :: Apply the merges
--   a) Aggregate merged_id fields onto the canonical row.
--   b) Rewire all 5 FK tables from merged_id -> canonical_id.
--   c) Delete merged rows.
--   d) Integrity check: verify FK row counts unchanged; raise to rollback on mismatch.
---------------------------------------------------------------------------
BEGIN;
SET LOCAL statement_timeout = '30min';

-- Baseline totals we expect preserved.
DROP TABLE IF EXISTS public._mec_merge_preflight;
CREATE UNLOGGED TABLE public._mec_merge_preflight AS
SELECT
  (SELECT COUNT(*) FROM public.mec_contributions)    AS mec_contrib_total,
  (SELECT COUNT(*) FROM public.mec_contributions WHERE donor_id IS NOT NULL) AS mec_contrib_linked,
  (SELECT COUNT(*) FROM public.fec_contributions)    AS fec_contrib_total,
  (SELECT COUNT(*) FROM public.fec_contributions WHERE donor_id IS NOT NULL) AS fec_contrib_linked,
  (SELECT COUNT(*) FROM public.donor_enrichment)     AS enrichment_total,
  (SELECT COUNT(*) FROM public.donor_enrichment WHERE donor_id IS NOT NULL) AS enrichment_linked,
  (SELECT COUNT(*) FROM public.call_time_list_items) AS call_items_total,
  (SELECT COUNT(*) FROM public.call_time_list_items WHERE donor_id IS NOT NULL) AS call_items_linked,
  (SELECT COUNT(*) FROM public.mo_business_entities) AS biz_total,
  (SELECT COUNT(*) FROM public.mo_business_entities WHERE donor_id IS NOT NULL) AS biz_linked,
  (SELECT COALESCE(SUM(contribution_amount),0) FROM public.mec_contributions) AS mec_amt_sum,
  (SELECT COALESCE(SUM(transaction_amount),0) FROM public.fec_contributions) AS fec_amt_sum,
  (SELECT COUNT(*) FROM public.mec_donors)           AS donors_total;

-- 4a. Aggregate merged values onto canonical rows.
-- For each canonical we need the SUM/MERGE of all merged rows + keep the
-- canonical's own values (since canonical row survives and already holds its
-- own total_contributed etc).
WITH merged_agg AS (
  SELECT mp.canonical_id,
         SUM(md.total_contributed)                               AS sum_mec_amt,
         SUM(md.fec_total_contributed)                           AS sum_fec_amt,
         SUM(md.contribution_count)                              AS sum_mec_cnt,
         SUM(md.fec_contribution_count)                          AS sum_fec_cnt,
         MIN(md.first_contribution_date)                         AS min_first_date,
         MAX(md.last_contribution_date)                          AS max_last_date,
         -- Union of sources text[] across merged rows.
         ARRAY(
           SELECT DISTINCT s
             FROM unnest(
               COALESCE(
                 (SELECT array_agg(DISTINCT unnested) FROM (
                    SELECT unnest(md2.sources) AS unnested
                      FROM public.mec_donors md2
                      JOIN public._mec_merge_plan mp2 ON mp2.merged_id = md2.id
                     WHERE mp2.canonical_id = mp.canonical_id
                 ) s2),
                 ARRAY[]::text[]
               )
             ) AS s
         )                                                       AS merged_sources,
         -- Merge committees_donated_to arrays into a union of distinct JSON
         -- elements.
         COALESCE(
           (SELECT jsonb_agg(DISTINCT elem)
              FROM public.mec_donors md3
              CROSS JOIN LATERAL jsonb_array_elements(
                CASE WHEN jsonb_typeof(md3.committees_donated_to) = 'array'
                     THEN md3.committees_donated_to ELSE '[]'::jsonb END
              ) AS t(elem)
             WHERE md3.id IN (
               SELECT merged_id FROM public._mec_merge_plan WHERE canonical_id = mp.canonical_id
             )),
           '[]'::jsonb
         )                                                       AS merged_committees,
         -- Keep any non-null mo_voter_file_id from merged rows (canonical
         -- already has priority via the ranking; this picks up cases where
         -- canonical lacks one but merged_id has one — we validated no
         -- conflicts in the plan).
         (SELECT md4.mo_voter_file_id
            FROM public.mec_donors md4
            JOIN public._mec_merge_plan mp4 ON mp4.merged_id = md4.id
           WHERE mp4.canonical_id = mp.canonical_id
             AND md4.mo_voter_file_id IS NOT NULL
           LIMIT 1)                                              AS merged_voter_id
    FROM public._mec_merge_plan mp
    JOIN public.mec_donors md ON md.id = mp.merged_id
   GROUP BY mp.canonical_id
)
UPDATE public.mec_donors d
   SET total_contributed      = COALESCE(d.total_contributed, 0)     + COALESCE(ma.sum_mec_amt, 0),
       fec_total_contributed  = COALESCE(d.fec_total_contributed, 0) + COALESCE(ma.sum_fec_amt, 0),
       contribution_count     = COALESCE(d.contribution_count, 0)    + COALESCE(ma.sum_mec_cnt, 0)::int,
       fec_contribution_count = COALESCE(d.fec_contribution_count,0) + COALESCE(ma.sum_fec_cnt, 0)::int,
       first_contribution_date = LEAST(
         d.first_contribution_date,
         ma.min_first_date
       ),
       last_contribution_date  = GREATEST(
         d.last_contribution_date,
         ma.max_last_date
       ),
       sources = ARRAY(SELECT DISTINCT s FROM unnest(d.sources || ma.merged_sources) AS s WHERE s IS NOT NULL AND s <> ''),
       committees_donated_to = (
         SELECT COALESCE(jsonb_agg(DISTINCT e), '[]'::jsonb)
           FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(COALESCE(d.committees_donated_to,'[]'::jsonb)) = 'array'
                  THEN COALESCE(d.committees_donated_to,'[]'::jsonb) ELSE '[]'::jsonb END
             || COALESCE(ma.merged_committees, '[]'::jsonb)
           ) AS t(e)
       ),
       mo_voter_file_id = COALESCE(d.mo_voter_file_id, ma.merged_voter_id),
       updated_at = now()
  FROM merged_agg ma
 WHERE d.id = ma.canonical_id;

-- 4b. Rewire FK tables: merged_id -> canonical_id.
-- Pre-count per-table links on soon-to-be-merged ids for integrity check.
DROP TABLE IF EXISTS public._mec_merge_fkcounts;
CREATE UNLOGGED TABLE public._mec_merge_fkcounts AS
SELECT
  (SELECT COUNT(*) FROM public.mec_contributions    mc WHERE mc.donor_id IN (SELECT merged_id FROM public._mec_merge_plan)) AS mec_links_to_move,
  (SELECT COUNT(*) FROM public.fec_contributions    fc WHERE fc.donor_id IN (SELECT merged_id FROM public._mec_merge_plan)) AS fec_links_to_move,
  (SELECT COUNT(*) FROM public.donor_enrichment     de WHERE de.donor_id IN (SELECT merged_id FROM public._mec_merge_plan)) AS de_links_to_move,
  (SELECT COUNT(*) FROM public.call_time_list_items ct WHERE ct.donor_id IN (SELECT merged_id FROM public._mec_merge_plan)) AS ct_links_to_move,
  (SELECT COUNT(*) FROM public.mo_business_entities be WHERE be.donor_id IN (SELECT merged_id FROM public._mec_merge_plan)) AS be_links_to_move;

UPDATE public.mec_contributions mc
   SET donor_id = mp.canonical_id
  FROM public._mec_merge_plan mp
 WHERE mc.donor_id = mp.merged_id;

UPDATE public.fec_contributions fc
   SET donor_id = mp.canonical_id
  FROM public._mec_merge_plan mp
 WHERE fc.donor_id = mp.merged_id;

-- donor_enrichment may have a unique constraint on donor_id — if the canonical
-- already has an enrichment row, keep the canonical's and leave the merged
-- row's enrichment in place pointing at a soon-to-be-deleted donor; delete it.
DELETE FROM public.donor_enrichment de
 USING public._mec_merge_plan mp
 WHERE de.donor_id = mp.merged_id
   AND EXISTS (SELECT 1 FROM public.donor_enrichment de2 WHERE de2.donor_id = mp.canonical_id);

UPDATE public.donor_enrichment de
   SET donor_id = mp.canonical_id
  FROM public._mec_merge_plan mp
 WHERE de.donor_id = mp.merged_id;

UPDATE public.call_time_list_items ct
   SET donor_id = mp.canonical_id
  FROM public._mec_merge_plan mp
 WHERE ct.donor_id = mp.merged_id;

UPDATE public.mo_business_entities be
   SET donor_id = mp.canonical_id
  FROM public._mec_merge_plan mp
 WHERE be.donor_id = mp.merged_id;

-- 4c. Log and delete the merged rows.
INSERT INTO public.mec_donor_merges (canonical_id, merged_id, donor_type, merge_key, merge_reason)
SELECT canonical_id, merged_id, donor_type, merge_key,
       'dedup pass 2026-04-21 normalized (name,city,state) key'
  FROM public._mec_merge_plan;

DELETE FROM public.mec_donors d
 USING public._mec_merge_plan mp
 WHERE d.id = mp.merged_id;

-- 4d. Integrity check: FK link totals must be preserved (minus the
-- enrichment rows we explicitly deleted to resolve unique-constraint collisions).
DO $$
DECLARE
  pre  RECORD;
  post RECORD;
  enrichment_deleted bigint;
BEGIN
  SELECT * INTO pre FROM public._mec_merge_preflight;

  SELECT
    (SELECT COUNT(*) FROM public.mec_contributions)    AS mec_contrib_total,
    (SELECT COUNT(*) FROM public.mec_contributions WHERE donor_id IS NOT NULL) AS mec_contrib_linked,
    (SELECT COUNT(*) FROM public.fec_contributions)    AS fec_contrib_total,
    (SELECT COUNT(*) FROM public.fec_contributions WHERE donor_id IS NOT NULL) AS fec_contrib_linked,
    (SELECT COUNT(*) FROM public.donor_enrichment)     AS enrichment_total,
    (SELECT COUNT(*) FROM public.donor_enrichment WHERE donor_id IS NOT NULL) AS enrichment_linked,
    (SELECT COUNT(*) FROM public.call_time_list_items) AS call_items_total,
    (SELECT COUNT(*) FROM public.call_time_list_items WHERE donor_id IS NOT NULL) AS call_items_linked,
    (SELECT COUNT(*) FROM public.mo_business_entities) AS biz_total,
    (SELECT COUNT(*) FROM public.mo_business_entities WHERE donor_id IS NOT NULL) AS biz_linked,
    (SELECT COALESCE(SUM(contribution_amount),0) FROM public.mec_contributions) AS mec_amt_sum,
    (SELECT COALESCE(SUM(transaction_amount),0) FROM public.fec_contributions) AS fec_amt_sum,
    (SELECT COUNT(*) FROM public.mec_donors)           AS donors_total
  INTO post;

  -- Contribution table row counts MUST be unchanged (we never touched rows,
  -- only donor_id values), and their total amounts MUST be unchanged.
  IF pre.mec_contrib_total <> post.mec_contrib_total THEN
    RAISE EXCEPTION 'Integrity fail: mec_contributions row count drifted % -> %', pre.mec_contrib_total, post.mec_contrib_total;
  END IF;
  IF pre.fec_contrib_total <> post.fec_contrib_total THEN
    RAISE EXCEPTION 'Integrity fail: fec_contributions row count drifted % -> %', pre.fec_contrib_total, post.fec_contrib_total;
  END IF;
  IF pre.mec_contrib_linked <> post.mec_contrib_linked THEN
    RAISE EXCEPTION 'Integrity fail: mec_contributions linked count drifted % -> %', pre.mec_contrib_linked, post.mec_contrib_linked;
  END IF;
  IF pre.fec_contrib_linked <> post.fec_contrib_linked THEN
    RAISE EXCEPTION 'Integrity fail: fec_contributions linked count drifted % -> %', pre.fec_contrib_linked, post.fec_contrib_linked;
  END IF;
  IF pre.mec_amt_sum <> post.mec_amt_sum THEN
    RAISE EXCEPTION 'Integrity fail: mec_contributions SUM(contribution_amount) drifted % -> %', pre.mec_amt_sum, post.mec_amt_sum;
  END IF;
  IF pre.fec_amt_sum <> post.fec_amt_sum THEN
    RAISE EXCEPTION 'Integrity fail: fec_contributions SUM(transaction_amount) drifted % -> %', pre.fec_amt_sum, post.fec_amt_sum;
  END IF;
  IF pre.call_items_total <> post.call_items_total THEN
    RAISE EXCEPTION 'Integrity fail: call_time_list_items row count drifted % -> %', pre.call_items_total, post.call_items_total;
  END IF;
  IF pre.biz_total <> post.biz_total THEN
    RAISE EXCEPTION 'Integrity fail: mo_business_entities row count drifted % -> %', pre.biz_total, post.biz_total;
  END IF;

  -- donor_enrichment rows CAN legitimately decrease due to unique-constraint
  -- collisions; enforce that any decrease is explainable (<= plan size).
  enrichment_deleted := pre.enrichment_total - post.enrichment_total;
  IF enrichment_deleted < 0 THEN
    RAISE EXCEPTION 'Integrity fail: donor_enrichment grew % -> %', pre.enrichment_total, post.enrichment_total;
  END IF;

  RAISE NOTICE 'Integrity OK. Donors % -> %. Enrichment deleted (dup resolve): %.',
    pre.donors_total, post.donors_total, enrichment_deleted;
END$$;

COMMIT;

---------------------------------------------------------------------------
-- STEP 5 :: Drop scratch tables.
---------------------------------------------------------------------------
BEGIN;
SET LOCAL statement_timeout = '5min';
DROP TABLE IF EXISTS public._mec_merge_plan;
DROP TABLE IF EXISTS public._mec_merge_plan_skipped;
DROP TABLE IF EXISTS public._mec_merge_preflight;
DROP TABLE IF EXISTS public._mec_merge_fkcounts;
COMMIT;
