# mec_contributions.donor_id repair — natural-key relinking

> **For agentic workers:** Use superpowers:executing-plans (inline) — every phase has a STOP gate where the operator must verify SQL output and approve before proceeding to the next.

**Goal:** Repair the `mec_contributions.donor_id` foreign key so that every contribution row links to the correct `mec_donors.id` (matched by natural key on first/last/state for individuals, company+state for companies, committee for committees), then recompute the cached aggregates on `mec_donors` (`total_contributed`, `contribution_count`, `first_contribution_date`, `last_contribution_date`) so the donor research list view and donor profile view show the same totals.

**Architecture:**
1. Investigation phase produces evidence and locks down the matcher logic.
2. A staging table (`mec_contrib_repair_proposal`) is built with `(contrib_id, current_donor_id, proposed_donor_id, match_kind, match_confidence)`. This is read-only against `mec_contributions` — no writes.
3. Diff verification against samples (Thomas Strong + 49 other donors) confirms the proposal makes sense before any UPDATE.
4. A backup column `donor_id_pre_repair` is added to `mec_contributions` so the repair is reversible.
5. UPDATE applied in 100k-row batches (each in its own transaction).
6. Aggregates recomputed via `UPDATE mec_donors … FROM SUM`.
7. Materialized views refreshed concurrently.
8. Post-verify with same 50 samples and the search-timeout test.

**Tech Stack:** Postgres / Supabase MCP migration tools. No Flutter changes.

**Evidence collected during investigation (drives the matcher):**

- Total `mec_contributions` rows: 3,180,931
  - Individuals (first+last set): 1,735,958 (54.6%)
  - Pure company (no individual names, company set): 211,238 (6.6%)
  - Pure committee (no individual/company, committee set): 1,210,528 (38.1%)
  - Unidentified (no name fields at all): 14 (negligible)
- Currently linked (`donor_id IS NOT NULL`): 2,546,543 (80%)
- Currently orphan (`donor_id IS NULL`): 634,388 (20%)
- **Sample of 8,644 currently-linked individual rows:**
  - 494 (5.7%) link to a donor whose `(first, last, state)` matches the contribution
  - 8,150 (94.3%) link to a donor with a DIFFERENT natural key
  - **The original matcher was 94% wrong — almost every existing linkage needs to be replaced.**
- `mec_donors` (1,022,008 rows total):
  - 424,076 distinct natural-key tuples for individuals
  - 376,119 (88.7%) are unambiguous (one donor row per tuple)
  - 47,957 (11.3%) are duplicate tuples (multiple donor rows share the natural key)
  - Max duplicates per tuple = 30
  - 68,928 "extra" duplicate rows (these will be losers in the tiebreaker; should later be merged)
  - `match_key` populated only on 315,813 of 1M (31%) — UNRELIABLE as a primary matcher

**Tiebreaker rule for duplicate-natural-key donors:** pick the lowest `mec_donors.id`. Reason: deterministic, stable across reruns, and the lowest id is typically the "canonical" oldest record from the original import.

**Out of scope of this plan:**
- Merging duplicate `mec_donors` rows (the 47k dup tuples). After repair, all contributions for a duplicate tuple will point at the canonical (lowest-id) donor; the 68k "extra" donor rows will become unreferenced. They remain valid mec_donors rows for now — future cleanup task.
- FEC contribution donor_id repair (parallel problem on `fec_contributions` — separate plan).
- The 14 unidentified rows (no name fields) — leave `donor_id IS NULL`.

---

## Phase 0 — Pre-flight verification

Confirm the project state hasn't drifted since the investigation. **No writes.**

### Task 0.1: Confirm row counts match investigation

- [ ] **Step 0.1.1: Run pre-flight count check**

```sql
SELECT
  (SELECT count(*) FROM mec_contributions) AS contribs_total,
  (SELECT count(*) FROM mec_contributions WHERE donor_id IS NOT NULL) AS contribs_linked,
  (SELECT count(*) FROM mec_contributions WHERE donor_id IS NULL) AS contribs_orphan,
  (SELECT count(*) FROM mec_donors) AS donors_total,
  (SELECT count(*) FROM mec_donors WHERE donor_type='individual') AS donors_individual;
```

Expected (within ±10k drift due to live writes):
- contribs_total: 3,180,931
- contribs_linked: 2,546,543
- contribs_orphan: 634,388
- donors_total: 1,022,008
- donors_individual: ~990,000

**STOP if drift is > 1%** — investigate before continuing.

### Task 0.2: Lock the project schema for the duration of repair

- [ ] **Step 0.2.1: Verify no concurrent writers**

```sql
SELECT pid, application_name, state, query_start, left(query, 200) AS query
FROM pg_stat_activity
WHERE datname = current_database()
  AND query ILIKE '%mec_contributions%'
  AND pid <> pg_backend_pid()
  AND state = 'active'
ORDER BY query_start;
```

Expected: zero rows. If any active writer found, abort and let it finish first.

---

## Phase 1 — Build the matcher in a staging table

Build `mec_contrib_repair_proposal` with the proposed donor_id for every contribution row. **Read-only against production tables — no UPDATE on `mec_contributions` or `mec_donors`.**

### Task 1.1: Create the staging table

- [ ] **Step 1.1.1: DDL for staging table**

```sql
CREATE TABLE IF NOT EXISTS public.mec_contrib_repair_proposal (
  contrib_id     bigint PRIMARY KEY,
  current_donor_id  bigint,
  proposed_donor_id bigint,
  match_kind     text NOT NULL CHECK (match_kind IN ('individual','company','committee','unidentified','no_match')),
  natural_key    text  -- the lowercased+trimmed key used for matching, for audit
);

-- Helpful indexes
CREATE INDEX idx_repair_proposal_current ON public.mec_contrib_repair_proposal (current_donor_id);
CREATE INDEX idx_repair_proposal_proposed ON public.mec_contrib_repair_proposal (proposed_donor_id);
CREATE INDEX idx_repair_proposal_kind ON public.mec_contrib_repair_proposal (match_kind);

ALTER TABLE public.mec_contrib_repair_proposal DISABLE ROW LEVEL SECURITY;
GRANT ALL ON public.mec_contrib_repair_proposal TO postgres;
```

This table is staging-only — RLS off, deleted at end of repair.

### Task 1.2: Build the donor lookup CTE — individuals

The matcher: for each individual `mec_donors` row, build a key. For tuples with multiple donors, pick the lowest id (DISTINCT ON pattern).

- [ ] **Step 1.2.1: Materialize the canonical individual lookup**

```sql
CREATE TABLE IF NOT EXISTS public.mec_donor_natural_key_lookup_individual AS
SELECT DISTINCT ON (l, f, s)
  lower(trim(last_name)) AS l,
  lower(trim(first_name)) AS f,
  lower(trim(coalesce(state, ''))) AS s,
  id AS canonical_donor_id
FROM mec_donors
WHERE donor_type = 'individual'
  AND first_name IS NOT NULL AND first_name <> ''
  AND last_name IS NOT NULL AND last_name <> ''
ORDER BY l, f, s, id;  -- DISTINCT ON picks lowest id within each tuple

ALTER TABLE public.mec_donor_natural_key_lookup_individual
  ADD PRIMARY KEY (l, f, s);

ANALYZE public.mec_donor_natural_key_lookup_individual;
```

Expected: ~424,076 rows (one per distinct individual tuple).

### Task 1.3: Build the donor lookup for companies

- [ ] **Step 1.3.1: Materialize canonical company lookup**

```sql
CREATE TABLE IF NOT EXISTS public.mec_donor_natural_key_lookup_company AS
SELECT DISTINCT ON (c, s)
  lower(trim(company_name)) AS c,
  lower(trim(coalesce(state, ''))) AS s,
  id AS canonical_donor_id
FROM mec_donors
WHERE donor_type = 'company'
  AND company_name IS NOT NULL AND company_name <> ''
ORDER BY c, s, id;

ALTER TABLE public.mec_donor_natural_key_lookup_company
  ADD PRIMARY KEY (c, s);

ANALYZE public.mec_donor_natural_key_lookup_company;
```

### Task 1.4: Build the donor lookup for committees

- [ ] **Step 1.4.1: Materialize canonical committee-donor lookup**

```sql
CREATE TABLE IF NOT EXISTS public.mec_donor_natural_key_lookup_committee AS
SELECT DISTINCT ON (k)
  lower(trim(committee_name)) AS k,
  id AS canonical_donor_id
FROM mec_donors
WHERE donor_type = 'committee'
  AND committee_name IS NOT NULL AND committee_name <> ''
ORDER BY k, id;

ALTER TABLE public.mec_donor_natural_key_lookup_committee
  ADD PRIMARY KEY (k);

ANALYZE public.mec_donor_natural_key_lookup_committee;
```

### Task 1.5: Populate the proposal — individuals first

- [ ] **Step 1.5.1: Insert proposals for individual contributions**

```sql
INSERT INTO public.mec_contrib_repair_proposal (contrib_id, current_donor_id, proposed_donor_id, match_kind, natural_key)
SELECT
  c.id,
  c.donor_id,
  l.canonical_donor_id,
  CASE WHEN l.canonical_donor_id IS NULL THEN 'no_match' ELSE 'individual' END,
  lower(trim(c.contributor_last_name)) || '|' || lower(trim(c.contributor_first_name)) || '|' || lower(trim(coalesce(c.state,'')))
FROM mec_contributions c
LEFT JOIN public.mec_donor_natural_key_lookup_individual l
  ON l.l = lower(trim(c.contributor_last_name))
 AND l.f = lower(trim(c.contributor_first_name))
 AND l.s = lower(trim(coalesce(c.state,'')))
WHERE c.contributor_first_name <> ''
  AND c.contributor_last_name <> ''
ON CONFLICT (contrib_id) DO NOTHING;
```

Expected insert count: ~1,735,958 (matches the individual count from investigation).

### Task 1.6: Populate the proposal — pure-company rows

- [ ] **Step 1.6.1: Insert proposals for company contributions**

```sql
INSERT INTO public.mec_contrib_repair_proposal (contrib_id, current_donor_id, proposed_donor_id, match_kind, natural_key)
SELECT
  c.id,
  c.donor_id,
  l.canonical_donor_id,
  CASE WHEN l.canonical_donor_id IS NULL THEN 'no_match' ELSE 'company' END,
  lower(trim(c.contributor_company)) || '|' || lower(trim(coalesce(c.state,'')))
FROM mec_contributions c
LEFT JOIN public.mec_donor_natural_key_lookup_company l
  ON l.c = lower(trim(c.contributor_company))
 AND l.s = lower(trim(coalesce(c.state,'')))
WHERE c.contributor_company <> ''
  AND (c.contributor_first_name = '' OR c.contributor_first_name IS NULL)
  AND (c.contributor_last_name = '' OR c.contributor_last_name IS NULL)
ON CONFLICT (contrib_id) DO NOTHING;
```

Expected insert count: ~211,238.

### Task 1.7: Populate the proposal — pure-committee rows

- [ ] **Step 1.7.1: Insert proposals for committee contributions**

```sql
INSERT INTO public.mec_contrib_repair_proposal (contrib_id, current_donor_id, proposed_donor_id, match_kind, natural_key)
SELECT
  c.id,
  c.donor_id,
  l.canonical_donor_id,
  CASE WHEN l.canonical_donor_id IS NULL THEN 'no_match' ELSE 'committee' END,
  lower(trim(c.contributor_committee))
FROM mec_contributions c
LEFT JOIN public.mec_donor_natural_key_lookup_committee l
  ON l.k = lower(trim(c.contributor_committee))
WHERE c.contributor_committee <> ''
  AND (c.contributor_first_name = '' OR c.contributor_first_name IS NULL)
  AND (c.contributor_last_name = '' OR c.contributor_last_name IS NULL)
  AND (c.contributor_company = '' OR c.contributor_company IS NULL)
ON CONFLICT (contrib_id) DO NOTHING;
```

Expected insert count: ~1,210,528.

### Task 1.8: Populate the proposal — unidentified rows

- [ ] **Step 1.8.1: Insert no-name rows so the proposal table covers all 3.18M**

```sql
INSERT INTO public.mec_contrib_repair_proposal (contrib_id, current_donor_id, proposed_donor_id, match_kind, natural_key)
SELECT
  c.id, c.donor_id, NULL, 'unidentified', NULL
FROM mec_contributions c
WHERE (c.contributor_first_name = '' OR c.contributor_first_name IS NULL)
  AND (c.contributor_last_name = '' OR c.contributor_last_name IS NULL)
  AND (c.contributor_company = '' OR c.contributor_company IS NULL)
  AND (c.contributor_committee = '' OR c.contributor_committee IS NULL)
ON CONFLICT (contrib_id) DO NOTHING;
```

Expected: 14 rows.

### Task 1.9: Verify proposal table covers every contribution

- [ ] **Step 1.9.1: Coverage check**

```sql
SELECT
  (SELECT count(*) FROM mec_contributions) AS expected,
  (SELECT count(*) FROM mec_contrib_repair_proposal) AS actual,
  (SELECT count(*) FROM mec_contributions) - (SELECT count(*) FROM mec_contrib_repair_proposal) AS missing;
```

Expected: `missing = 0`.

**STOP if missing != 0** — find the rows that fell through the classification CASE.

---

## Phase 2 — Verify the matcher (no writes to mec_contributions yet)

### Task 2.1: Diff statistics — what will change?

- [ ] **Step 2.1.1: Categorize proposed changes**

```sql
SELECT
  match_kind,
  count(*) AS rows,
  count(*) FILTER (WHERE current_donor_id IS NULL AND proposed_donor_id IS NOT NULL) AS newly_matched,
  count(*) FILTER (WHERE current_donor_id IS NOT NULL AND proposed_donor_id IS NOT NULL AND current_donor_id = proposed_donor_id) AS unchanged,
  count(*) FILTER (WHERE current_donor_id IS NOT NULL AND proposed_donor_id IS NOT NULL AND current_donor_id <> proposed_donor_id) AS relinked,
  count(*) FILTER (WHERE current_donor_id IS NOT NULL AND proposed_donor_id IS NULL) AS unlink,
  count(*) FILTER (WHERE current_donor_id IS NULL AND proposed_donor_id IS NULL) AS still_orphan
FROM mec_contrib_repair_proposal
GROUP BY match_kind
ORDER BY match_kind;
```

**Expected pattern** (based on investigation sample):
- `individual`: bulk of rows; ~94% relinked (changed donor_id), small fraction unchanged or newly matched, tiny fraction no_match
- `company`: similar pattern
- `committee`: most relinked (committees are heavily matched against current names but bad linkage)
- `unidentified`: 14 rows still_orphan
- `no_match`: rows where the natural key has no match in mec_donors at all (probably <1% of total)

**STOP and review the numbers with Andrew.** A reasonable proposal should:
- Have `unchanged` < 10% (since investigation said 5.7% match correctly)
- Have `still_orphan + no_match` < 5% (most rows should now have a proposed donor)
- Have `unlink = 0` (we never propose null when the row has a name)

### Task 2.2: Spot-check Thomas Strong

- [ ] **Step 2.2.1: Verify the proposal for Thomas Strong**

```sql
-- All Thomas Strong contributions and what we'd link them to
SELECT
  c.id AS contrib_id,
  c.contributor_first_name,
  c.contributor_last_name,
  c.city,
  c.state,
  c.contribution_amount,
  c.contribution_date,
  p.current_donor_id,
  p.proposed_donor_id,
  p.match_kind
FROM mec_contributions c
JOIN mec_contrib_repair_proposal p ON p.contrib_id = c.id
WHERE lower(trim(c.contributor_first_name)) = 'thomas'
  AND lower(trim(c.contributor_last_name)) = 'strong'
  AND lower(trim(coalesce(c.state,''))) = 'mo'
ORDER BY c.contribution_date;

-- Verify the proposed donor_id is 1335 (Thomas Strong, Springfield MO)
SELECT
  count(*) AS total,
  count(*) FILTER (WHERE proposed_donor_id = 1335) AS proposed_to_strong,
  count(*) FILTER (WHERE proposed_donor_id <> 1335 OR proposed_donor_id IS NULL) AS proposed_elsewhere,
  sum(c.contribution_amount) FILTER (WHERE p.proposed_donor_id = 1335)::text AS sum_to_strong
FROM mec_contributions c
JOIN mec_contrib_repair_proposal p ON p.contrib_id = c.id
WHERE lower(trim(c.contributor_first_name)) = 'thomas'
  AND lower(trim(c.contributor_last_name)) = 'strong'
  AND lower(trim(coalesce(c.state,''))) = 'mo';
```

**Expected:** `proposed_to_strong` ≈ 33 rows (the natural-key matches), `sum_to_strong` ≈ $267,620 — confirming we'd repair the linkage so his profile shows the right total.

### Task 2.3: Sample check — 50 random heavy donors

- [ ] **Step 2.3.1: Pick 50 donors with cached `total_contributed` > $50k and compare proposed vs current sums**

```sql
WITH heavy_donors AS (
  SELECT id, first_name, last_name, state, total_contributed
  FROM mec_donors
  WHERE donor_type = 'individual'
    AND total_contributed > 50000
  ORDER BY random()
  LIMIT 50
),
current_sum AS (
  SELECT d.id AS donor_id, sum(c.contribution_amount) AS sum_now
  FROM heavy_donors d
  LEFT JOIN mec_contributions c ON c.donor_id = d.id
  GROUP BY d.id
),
proposed_sum AS (
  SELECT d.id AS donor_id, sum(c.contribution_amount) AS sum_proposed
  FROM heavy_donors d
  LEFT JOIN mec_contrib_repair_proposal p ON p.proposed_donor_id = d.id
  LEFT JOIN mec_contributions c ON c.id = p.contrib_id
  GROUP BY d.id
)
SELECT
  hd.id,
  hd.first_name || ' ' || hd.last_name || ' / ' || hd.state AS donor,
  hd.total_contributed::text AS cached_total,
  cs.sum_now::text AS sum_by_current_fk,
  ps.sum_proposed::text AS sum_by_proposed_fk,
  CASE
    WHEN abs(coalesce(ps.sum_proposed, 0) - coalesce(hd.total_contributed, 0)) < 100
    THEN 'OK (matches cache within $100)'
    ELSE 'DRIFT'
  END AS verdict
FROM heavy_donors hd
LEFT JOIN current_sum cs ON cs.donor_id = hd.id
LEFT JOIN proposed_sum ps ON ps.donor_id = hd.id
ORDER BY hd.total_contributed DESC;
```

**Expected:** at least 80% of the 50 sampled donors should show `verdict = 'OK'` — meaning the proposed FK linkage produces a sum within $100 of the cached aggregate (the cache was always accurate, just unreachable via FK). The other 20% are likely cases where the cache itself is wrong (legitimate drift) or where the donor has multiple natural-key duplicates.

**STOP and review with Andrew.** If <60% match, the matcher logic has a flaw — likely the natural key needs city included, or zip suffix matching, or company-mode-when-individual fields are partially set. Investigate before proceeding.

### Task 2.4: How many `mec_donors` rows would become unreferenced after repair?

- [ ] **Step 2.4.1: Orphan-donor count check**

```sql
SELECT
  count(*) AS total_donors,
  count(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1 FROM mec_contrib_repair_proposal p WHERE p.proposed_donor_id = mec_donors.id
    )
  ) AS would_be_unreferenced
FROM mec_donors;
```

Expected: 68k–80k unreferenced (the duplicate-loser donors). These remain in `mec_donors` after repair — they just have zero contributions linked to them. They become candidates for a separate dup-merge cleanup task. Not deleted by this repair.

---

## Phase 3 — Backup `mec_contributions.donor_id` before any UPDATE

### Task 3.1: Add backup column + populate

- [ ] **Step 3.1.1: Snapshot column**

```sql
ALTER TABLE public.mec_contributions
  ADD COLUMN IF NOT EXISTS donor_id_pre_repair bigint;

UPDATE public.mec_contributions
SET donor_id_pre_repair = donor_id
WHERE donor_id_pre_repair IS NULL
  AND donor_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mec_contributions_donor_id_pre_repair
  ON public.mec_contributions (donor_id_pre_repair)
  WHERE donor_id_pre_repair IS NOT NULL;
```

This gives us a rollback path: `UPDATE mec_contributions SET donor_id = donor_id_pre_repair`.

### Task 3.2: Verify backup integrity

- [ ] **Step 3.2.1: Backup count check**

```sql
SELECT
  count(*) FILTER (WHERE donor_id IS NOT NULL) AS donor_id_now,
  count(*) FILTER (WHERE donor_id_pre_repair IS NOT NULL) AS backed_up,
  count(*) FILTER (WHERE donor_id IS DISTINCT FROM donor_id_pre_repair) AS divergence
FROM mec_contributions;
```

Expected: `donor_id_now == backed_up` and `divergence = 0`.

**STOP and verify** before any UPDATE in phase 4.

---

## Phase 4 — Apply the UPDATE in batches

3.18M rows. Don't do it in one transaction — batch by `id` ranges of 100k each, each in its own transaction. Postgres can handle a single UPDATE that big but it'd lock the whole table; batching keeps it incremental and resumable.

### Task 4.1: Batched UPDATE driver — write the procedure

- [ ] **Step 4.1.1: Create the apply procedure**

```sql
CREATE OR REPLACE PROCEDURE public.apply_donor_id_repair_batch(
  p_batch_start bigint,
  p_batch_end bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.mec_contributions c
  SET donor_id = p.proposed_donor_id
  FROM public.mec_contrib_repair_proposal p
  WHERE p.contrib_id = c.id
    AND c.id >= p_batch_start
    AND c.id < p_batch_end
    AND c.donor_id IS DISTINCT FROM p.proposed_donor_id;
END;
$$;
```

### Task 4.2: Run batches

- [ ] **Step 4.2.1: Find id range and batch loop**

```sql
SELECT min(id) AS min_id, max(id) AS max_id FROM mec_contributions;
```

Suppose min_id=1, max_id=3500000. Run a batch loop, ~35 batches of 100k:

```sql
DO $$
DECLARE
  v_min bigint;
  v_max bigint;
  v_batch_size bigint := 100000;
  v_cur bigint;
  v_done int := 0;
BEGIN
  SELECT min(id), max(id) INTO v_min, v_max FROM mec_contributions;
  v_cur := v_min;
  WHILE v_cur <= v_max LOOP
    CALL public.apply_donor_id_repair_batch(v_cur, v_cur + v_batch_size);
    v_cur := v_cur + v_batch_size;
    v_done := v_done + 1;
    RAISE NOTICE 'batch % done at %', v_done, v_cur;
  END LOOP;
END $$;
```

Run via Supabase MCP `execute_sql`. Expect ~5-10 minutes total (Supabase isn't great at huge UPDATEs but 100k rows per batch is well within its limits).

**STOP after batch loop completes.** Check `pg_stat_user_tables.n_dead_tup` on `mec_contributions` — likely needs VACUUM after all those updates. Run `VACUUM ANALYZE public.mec_contributions;` to reclaim space and refresh planner stats.

### Task 4.3: Post-UPDATE sanity

- [ ] **Step 4.3.1: Verify all rows match the proposal**

```sql
SELECT
  count(*) AS mismatches
FROM mec_contributions c
JOIN mec_contrib_repair_proposal p ON p.contrib_id = c.id
WHERE c.donor_id IS DISTINCT FROM p.proposed_donor_id;
```

Expected: 0 mismatches.

---

## Phase 5 — Recompute `mec_donors` aggregates

### Task 5.1: Recompute `total_contributed`, `contribution_count`, dates

- [ ] **Step 5.1.1: Save current aggregates as pre-repair backup**

```sql
ALTER TABLE public.mec_donors
  ADD COLUMN IF NOT EXISTS total_contributed_pre_repair numeric,
  ADD COLUMN IF NOT EXISTS contribution_count_pre_repair int,
  ADD COLUMN IF NOT EXISTS first_contribution_date_pre_repair date,
  ADD COLUMN IF NOT EXISTS last_contribution_date_pre_repair date;

UPDATE public.mec_donors
SET total_contributed_pre_repair = total_contributed,
    contribution_count_pre_repair = contribution_count,
    first_contribution_date_pre_repair = first_contribution_date,
    last_contribution_date_pre_repair = last_contribution_date;
```

- [ ] **Step 5.1.2: Recompute aggregates from re-linked rows**

```sql
WITH donor_aggs AS (
  SELECT
    donor_id,
    sum(contribution_amount) AS total,
    count(*)::int AS cnt,
    min(contribution_date)::date AS first_d,
    max(contribution_date)::date AS last_d
  FROM mec_contributions
  WHERE donor_id IS NOT NULL
  GROUP BY donor_id
)
UPDATE public.mec_donors d
SET total_contributed = a.total,
    contribution_count = a.cnt,
    first_contribution_date = a.first_d,
    last_contribution_date = a.last_d
FROM donor_aggs a
WHERE d.id = a.donor_id;

-- Donors with zero contributions after repair (the 68k duplicates that lost the tiebreaker)
UPDATE public.mec_donors d
SET total_contributed = 0,
    contribution_count = 0,
    first_contribution_date = NULL,
    last_contribution_date = NULL
WHERE NOT EXISTS (SELECT 1 FROM mec_contributions c WHERE c.donor_id = d.id);
```

This UPDATE rewrites 1M rows. Single transaction — Postgres handles it but it'll lock briefly. Run during low-traffic window.

### Task 5.2: Verify aggregates against re-linked rows

- [ ] **Step 5.2.1: Cross-check 50 random donors**

```sql
WITH sample AS (
  SELECT id FROM mec_donors WHERE donor_type='individual' ORDER BY random() LIMIT 50
)
SELECT
  d.id,
  d.first_name || ' ' || d.last_name AS name,
  d.total_contributed::text AS cached,
  (SELECT sum(contribution_amount) FROM mec_contributions WHERE donor_id = d.id)::text AS recomputed,
  CASE
    WHEN d.total_contributed = (SELECT coalesce(sum(contribution_amount),0) FROM mec_contributions WHERE donor_id = d.id)
    THEN 'OK' ELSE 'DRIFT'
  END AS verdict
FROM mec_donors d
WHERE d.id IN (SELECT id FROM sample)
ORDER BY d.total_contributed DESC NULLS LAST;
```

Expected: 100% `OK`. Any DRIFT row means the UPDATE didn't run for some reason — investigate.

---

## Phase 6 — Refresh materialized views

The 3 MEC MVs (`mec_committee_donor_aggregate`, `mec_committee_payee_aggregate`, `mec_committee_finance_summary`) are derived from `mec_contributions` / `mec_expenditures`. They have unique indexes, so we can use `REFRESH … CONCURRENTLY` (no blocking).

### Task 6.1: Refresh MVs concurrently

- [ ] **Step 6.1.1: REFRESH commands**

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_donor_aggregate;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_finance_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_payee_aggregate;
```

Each takes a few minutes. The Money tab on candidates pages reads from these — verify after refresh that totals are unchanged or improved (the donor-aggregate MV groups by name+city+state, not by donor_id, so it's unaffected by the donor_id fix; the finance summary is also by mec_id; only sums move slightly if previously some contributions had bogus donor_ids that affected anything).

---

## Phase 7 — Post-repair verification

### Task 7.1: Thomas Strong end-to-end

- [ ] **Step 7.1.1: Verify Thomas Strong now shows the correct totals**

```sql
SELECT
  d.id, d.first_name, d.last_name, d.city, d.state,
  d.total_contributed::text AS cached_total,
  d.contribution_count,
  d.fec_total_contributed::text AS fec_cached,
  (SELECT sum(contribution_amount) FROM mec_contributions WHERE donor_id = d.id)::text AS sum_by_fk_now,
  (SELECT count(*) FROM mec_contributions WHERE donor_id = d.id) AS count_by_fk_now
FROM mec_donors d
WHERE d.id = 1335;
```

Expected: `cached_total ≈ sum_by_fk_now`, both around $267k.

### Task 7.2: Run the Donor Research search timeout test

- [ ] **Step 7.2.1: Test party-filter search latency**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM search_donors_v3(
  p_name_query := 'lee',
  p_state := 'MO',
  p_party := 'democrat',
  p_individuals_only := true,
  p_limit := 100
);
```

Expected: <1s execution. Was 2.5+ seconds before the index migrations.

### Task 7.3: Top-50 vs profile alignment

- [ ] **Step 7.3.1: Pick the top-50 donors by cached total and verify their profile sum matches**

```sql
WITH top50 AS (
  SELECT id FROM mec_donors WHERE donor_type='individual'
  ORDER BY total_contributed DESC NULLS LAST LIMIT 50
)
SELECT
  d.id,
  d.first_name || ' ' || d.last_name AS name,
  d.total_contributed::text AS list_view_total,
  (SELECT coalesce(sum(contribution_amount),0) FROM mec_contributions WHERE donor_id = d.id)::text AS profile_view_total,
  CASE
    WHEN d.total_contributed = (SELECT coalesce(sum(contribution_amount),0) FROM mec_contributions WHERE donor_id = d.id)
    THEN '✓' ELSE '✗ DRIFT'
  END AS aligned
FROM mec_donors d
WHERE d.id IN (SELECT id FROM top50)
ORDER BY d.total_contributed DESC;
```

Expected: 50/50 ✓ aligned. Any ✗ means the recompute step missed that donor — investigate before declaring victory.

### Task 7.4: Andrew clicks around live

- [ ] **Step 7.4.1: User-side verification (manual)**

After the deploy, Andrew visits Donor Research:
- Top-50 list amount === click-through profile amount for the same donor
- Search "smith" with party=Democrat returns in <1s
- Click into a donor — committee names tappable, drill into committee detail

If all green, mark complete. If anything red, ROLLBACK via Phase 8.

---

## Phase 8 — Rollback procedure (use only if Phase 7 fails)

### Task 8.1: Restore `mec_contributions.donor_id` from backup column

- [ ] **Step 8.1.1: Single-transaction rollback**

```sql
BEGIN;
UPDATE public.mec_contributions
SET donor_id = donor_id_pre_repair
WHERE donor_id IS DISTINCT FROM donor_id_pre_repair;
COMMIT;
```

### Task 8.2: Restore `mec_donors` aggregates

- [ ] **Step 8.2.1: Restore aggregate snapshot**

```sql
BEGIN;
UPDATE public.mec_donors
SET total_contributed = total_contributed_pre_repair,
    contribution_count = contribution_count_pre_repair,
    first_contribution_date = first_contribution_date_pre_repair,
    last_contribution_date = last_contribution_date_pre_repair;
COMMIT;
```

### Task 8.3: Refresh MVs again

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_donor_aggregate;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_finance_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY public.mec_committee_payee_aggregate;
```

---

## Phase 9 — Cleanup (only after Phase 7 passes and 7+ days have elapsed)

### Task 9.1: Drop staging tables and backup columns

After 7 days of stable operation:

- [ ] **Step 9.1.1: Drop staging**

```sql
DROP PROCEDURE IF EXISTS public.apply_donor_id_repair_batch(bigint, bigint);
DROP TABLE IF EXISTS public.mec_contrib_repair_proposal;
DROP TABLE IF EXISTS public.mec_donor_natural_key_lookup_individual;
DROP TABLE IF EXISTS public.mec_donor_natural_key_lookup_company;
DROP TABLE IF EXISTS public.mec_donor_natural_key_lookup_committee;
```

- [ ] **Step 9.1.2: Drop backup columns**

```sql
ALTER TABLE public.mec_contributions DROP COLUMN IF EXISTS donor_id_pre_repair;
ALTER TABLE public.mec_donors
  DROP COLUMN IF EXISTS total_contributed_pre_repair,
  DROP COLUMN IF EXISTS contribution_count_pre_repair,
  DROP COLUMN IF EXISTS first_contribution_date_pre_repair,
  DROP COLUMN IF EXISTS last_contribution_date_pre_repair;
```

### Task 9.2: Refresh `match_key` on `mec_donors`

The 706k null match_keys could be backfilled via the same natural-key construction used in this repair. Separate task — not part of this plan.

---

## Open questions / risks

1. **Tiebreaker (lowest id) might pick the wrong canonical donor.** Some duplicates have only an "old import shell" with little metadata as the lowest-id, and a richer "later merge target" as a higher id. After repair, contributions will all link to the shell; the rich record becomes orphaned. Mitigation: a follow-up dup-merge task (`mec_donor_merges` table is wired but empty — designed for exactly this) can canonicalize after repair completes.

2. **City not in the natural key** for individuals. Two distinct people named "John Smith" in MO would collapse into one donor entity. The existing index `idx_mec_donors_name_match` doesn't include city either, so this matches the original schema's matching intent, but it's lossy. Worth noting; not changing in this plan.

3. **Companies/committees with same name in different states.** Pure-company key is `(company_name, state)` — companies with multi-state operations may have separate `mec_donors` entries per state. Plan honors that. Committees use only `(committee_name)` — a multi-state committee with same name would collapse. Rare in practice.

4. **fec_contributions.donor_id has the same problem.** 361k orphans + likely high mis-link rate. Out of scope of this plan but Andrew should expect a parallel repair.

5. **Statement timeout during batches.** Supabase has an 8-second statement timeout by default. 100k-row UPDATE may exceed that on some batches. If so, drop batch size to 50k or 25k. Procedure body is safe to retry — `IS DISTINCT FROM` predicate makes it idempotent.

6. **The `donor_zip5_lookup` table caches per-zip donor counts** — these change after repair. Out of scope; rebuild via existing job afterwards if anyone notices stale numbers.

---

## Summary checklist

- [ ] Phase 0 — Pre-flight (read-only) — verified counts match
- [ ] Phase 1 — Build matcher staging tables — proposal table covers 100% of contribs
- [ ] Phase 2 — Verify matcher (Thomas Strong + 50 samples) — Andrew approves the diff stats
- [ ] Phase 3 — Backup `donor_id` to `donor_id_pre_repair`
- [ ] Phase 4 — Apply UPDATE in 100k batches — 0 mismatches post-update
- [ ] Phase 5 — Recompute `mec_donors` aggregates — 50/50 sample matches
- [ ] Phase 6 — Refresh 3 MEC MVs concurrently
- [ ] Phase 7 — Post-verify (Thomas Strong / search timing / top-50 alignment) — Andrew clicks live
- [ ] Phase 8 — (Only if needed) Rollback procedure
- [ ] Phase 9 — Cleanup after 7+ days stable

**Approval gate:** Phase 4 (the UPDATE) does NOT execute until Andrew reviews the Phase 2 diff stats and signs off in writing.
