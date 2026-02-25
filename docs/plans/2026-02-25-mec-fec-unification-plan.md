# MEC + FEC Donor Unification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify MEC (479K donors, 3.1M contributions) and FEC (705K contributions) donor data behind a single research donor profile, overhaul Committees and Donor Research tabs with full donor lists, clickable profiles, source filters, and premium UI.

**Architecture:** Create a `research_donor_id` linking system on `mec_donors` that maps both MEC and FEC contributions to a single donor identity. New plpgsql RPC functions (`search_donors_v3`, `get_donor_unified_profile`, `get_committee_donors_paginated`) handle the heavy lifting server-side. Flutter gets new FEC models, an updated `MecRepository` (renamed conceptually to handle both sources), and completely rewritten Committees + Donor Research tabs with source filter chips, full donor lists, and unified profile views.

**Tech Stack:** Supabase (PostgreSQL 15, PostgREST), Flutter/Dart (web), `intl` package for formatting

**CRITICAL:** All Supabase DDL MUST use `public.` prefix on every table, index, function, and policy reference. The search_path is `"listmonk, extensions, public"` so unqualified names resolve to `listmonk` schema.

---

## Phase 1: Database — Data Linkage & Backfill

### Task 1: Backfill `mec_contributions.donor_id`

**Context:** The `mec_contributions` table has 3.1M rows with a `donor_id` FK column pointing to `mec_donors.id`, but it's 0% populated. Each contribution has `contributor_last_name`, `contributor_first_name`, `contributor_company`, `city`, `state` that can be matched to `mec_donors` which has the same fields as `last_name`, `first_name`, `company_name`, `city`, `state`.

**Step 1: Run the backfill migration**

Execute this SQL via Supabase MCP `execute_sql`:

```sql
-- Backfill mec_contributions.donor_id by matching to mec_donors
-- Uses exact name + state match (most reliable)
-- Batch approach to avoid statement timeout

DO $$
DECLARE
  batch_size INT := 50000;
  total_updated INT := 0;
  batch_updated INT;
BEGIN
  LOOP
    WITH matched AS (
      SELECT c.id AS contribution_id, d.id AS donor_id
      FROM public.mec_contributions c
      JOIN public.mec_donors d
        ON lower(trim(c.contributor_last_name)) = lower(trim(d.last_name))
        AND lower(trim(coalesce(c.contributor_first_name, ''))) = lower(trim(coalesce(d.first_name, '')))
        AND lower(trim(coalesce(c.state, ''))) = lower(trim(coalesce(d.state, '')))
      WHERE c.donor_id IS NULL
      LIMIT batch_size
    )
    UPDATE public.mec_contributions c
    SET donor_id = matched.donor_id
    FROM matched
    WHERE c.id = matched.contribution_id;

    GET DIAGNOSTICS batch_updated = ROW_COUNT;
    total_updated := total_updated + batch_updated;
    RAISE NOTICE 'Batch updated: %, total: %', batch_updated, total_updated;

    EXIT WHEN batch_updated = 0;
  END LOOP;

  RAISE NOTICE 'Total mec_contributions updated: %', total_updated;
END $$;
```

**Step 2: Verify backfill results**

```sql
SELECT
  count(*) AS total,
  count(donor_id) AS linked,
  round(count(donor_id)::numeric / count(*)::numeric * 100, 1) AS pct
FROM public.mec_contributions;
```

Expected: >80% linked (some contributions may not match due to data quality).

**Step 3: Add index on donor_id for fast lookups**

```sql
CREATE INDEX IF NOT EXISTS idx_mec_contributions_donor_id
ON public.mec_contributions (donor_id)
WHERE donor_id IS NOT NULL;
```

**Step 4: Commit (no code changes yet, just DB migration notes)**

---

### Task 2: Parse FEC contributor names and backfill `fec_contributions.donor_id`

**Context:** FEC contributions have `contributor_name` in "LAST, FIRST" format (single field). We need to parse this, then fuzzy-match to `mec_donors`, creating new donor entries for unmatched FEC contributors.

**Step 1: Add helper columns to fec_contributions for parsed names**

```sql
ALTER TABLE public.fec_contributions
  ADD COLUMN IF NOT EXISTS parsed_last_name TEXT,
  ADD COLUMN IF NOT EXISTS parsed_first_name TEXT;
```

**Step 2: Parse FEC contributor names**

```sql
-- Parse "LAST, FIRST" format into separate columns
UPDATE public.fec_contributions
SET
  parsed_last_name = CASE
    WHEN contributor_name LIKE '%,%' THEN trim(split_part(contributor_name, ',', 1))
    ELSE trim(contributor_name)
  END,
  parsed_first_name = CASE
    WHEN contributor_name LIKE '%,%' THEN trim(split_part(contributor_name, ',', 2))
    ELSE NULL
  END
WHERE parsed_last_name IS NULL;
```

**Step 3: Match FEC contributors to existing mec_donors**

```sql
DO $$
DECLARE
  batch_size INT := 50000;
  total_updated INT := 0;
  batch_updated INT;
BEGIN
  LOOP
    WITH matched AS (
      SELECT c.id AS contribution_id, d.id AS donor_id
      FROM public.fec_contributions c
      JOIN public.mec_donors d
        ON lower(trim(c.parsed_last_name)) = lower(trim(d.last_name))
        AND lower(trim(coalesce(c.parsed_first_name, ''))) = lower(trim(coalesce(d.first_name, '')))
        AND lower(trim(coalesce(c.state, ''))) = lower(trim(coalesce(d.state, '')))
      WHERE c.donor_id IS NULL
        AND c.parsed_last_name IS NOT NULL
        AND c.parsed_last_name != ''
      LIMIT batch_size
    )
    UPDATE public.fec_contributions c
    SET donor_id = matched.donor_id
    FROM matched
    WHERE c.id = matched.contribution_id;

    GET DIAGNOSTICS batch_updated = ROW_COUNT;
    total_updated := total_updated + batch_updated;
    RAISE NOTICE 'FEC batch updated: %, total: %', batch_updated, total_updated;

    EXIT WHEN batch_updated = 0;
  END LOOP;

  RAISE NOTICE 'Total fec_contributions linked to existing donors: %', total_updated;
END $$;
```

**Step 4: Create new mec_donors entries for unmatched FEC contributors**

```sql
-- Insert unique unmatched FEC contributors as new mec_donors entries
INSERT INTO public.mec_donors (
  last_name, first_name, city, state, zip, employer, occupation,
  donor_type, total_contributed, contribution_count,
  first_contribution_date, last_contribution_date,
  fec_contribution_count, fec_total_contributed
)
SELECT
  parsed_last_name,
  parsed_first_name,
  city,
  state,
  zip,
  employer,
  occupation,
  'individual',
  0, -- MEC total (they have none)
  0,
  NULL,
  NULL,
  count(*),
  coalesce(sum(contribution_receipt_amount), 0)
FROM public.fec_contributions
WHERE donor_id IS NULL
  AND parsed_last_name IS NOT NULL
  AND parsed_last_name != ''
GROUP BY parsed_last_name, parsed_first_name,
         contributor_city, contributor_state, contributor_zip,
         contributor_employer, contributor_occupation
ON CONFLICT DO NOTHING;
```

**Step 5: Link newly created donors back to FEC contributions**

Re-run the matching query from Step 3 to catch the newly created donors.

**Step 6: Add index on fec_contributions.donor_id**

```sql
CREATE INDEX IF NOT EXISTS idx_fec_contributions_donor_id
ON public.fec_contributions (donor_id)
WHERE donor_id IS NOT NULL;
```

**Step 7: Verify**

```sql
SELECT
  count(*) AS total,
  count(donor_id) AS linked,
  round(count(donor_id)::numeric / count(*)::numeric * 100, 1) AS pct
FROM public.fec_contributions;
```

---

### Task 3: Update mec_donors FEC aggregate columns

**Context:** `mec_donors` already has `fec_contribution_count` and `fec_total_contributed` columns but they're unpopulated.

**Step 1: Populate FEC aggregates on mec_donors**

```sql
UPDATE public.mec_donors d
SET
  fec_contribution_count = agg.cnt,
  fec_total_contributed = agg.total
FROM (
  SELECT donor_id, count(*) AS cnt, coalesce(sum(contribution_receipt_amount), 0) AS total
  FROM public.fec_contributions
  WHERE donor_id IS NOT NULL
  GROUP BY donor_id
) agg
WHERE d.id = agg.donor_id;
```

**Step 2: Verify**

```sql
SELECT count(*) AS donors_with_fec
FROM public.mec_donors
WHERE fec_contribution_count > 0;
```

**Step 3: Reload PostgREST schema cache**

```sql
NOTIFY pgrst, 'reload schema';
```

---

## Phase 2: Database — New RPC Functions & Performance

### Task 4: Create `search_donors_v3` — Unified MEC+FEC search

**Context:** The current `search_donors_v2` only searches MEC data via `mec_donors`. The new v3 adds:
- Source filter parameter (`p_source`: 'mec', 'fec', 'both')
- FEC contribution count and total in results
- Combined total across both sources for sorting
- Same enrichment data join

**Step 1: Create the function**

```sql
CREATE OR REPLACE FUNCTION public.search_donors_v3(
  p_name_query TEXT DEFAULT NULL,
  p_state TEXT DEFAULT NULL,
  p_city TEXT DEFAULT NULL,
  p_zip TEXT DEFAULT NULL,
  p_year_from INT DEFAULT NULL,
  p_year_to INT DEFAULT NULL,
  p_min_total NUMERIC DEFAULT NULL,
  p_max_total NUMERIC DEFAULT NULL,
  p_party TEXT DEFAULT NULL,
  p_employer TEXT DEFAULT NULL,
  p_occupation TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_age_min INT DEFAULT NULL,
  p_age_max INT DEFAULT NULL,
  p_has_phone BOOLEAN DEFAULT NULL,
  p_has_email BOOLEAN DEFAULT NULL,
  p_is_homeowner BOOLEAN DEFAULT NULL,
  p_individuals_only BOOLEAN DEFAULT TRUE,
  p_source TEXT DEFAULT 'both',  -- 'mec', 'fec', 'both'
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  donor_id INT,
  donor_name TEXT,
  last_name TEXT,
  first_name TEXT,
  company_name TEXT,
  committee_name TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  employer TEXT,
  occupation TEXT,
  -- MEC data
  mec_total NUMERIC,
  mec_count INT,
  -- FEC data
  fec_total NUMERIC,
  fec_count INT,
  -- Combined
  total_amount NUMERIC,
  contribution_count INT,
  first_year INT,
  last_year INT,
  committees_donated_to TEXT[],
  -- Source indicator
  data_sources TEXT,
  -- Enrichment
  gender TEXT,
  age_estimate INT,
  generation TEXT,
  party_lean TEXT,
  party_lean_confidence NUMERIC,
  phone_mobile TEXT,
  phone_home TEXT,
  email_personal TEXT,
  social_profile_count INT,
  giving_capacity_estimate TEXT,
  wealth_score NUMERIC,
  engagement_score NUMERIC,
  is_homeowner BOOLEAN,
  current_employer TEXT,
  current_job_title TEXT,
  estimated_income_range TEXT,
  ethnicity TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  _date_from DATE;
  _date_to DATE;
  _has_enrichment_filter BOOLEAN;
BEGIN
  -- Convert year params to dates for index usage
  IF p_year_from IS NOT NULL THEN
    _date_from := make_date(p_year_from, 1, 1);
  END IF;
  IF p_year_to IS NOT NULL THEN
    _date_to := make_date(p_year_to, 12, 31);
  END IF;

  _has_enrichment_filter := (
    p_gender IS NOT NULL OR p_age_min IS NOT NULL OR p_age_max IS NOT NULL
    OR p_has_phone IS NOT NULL OR p_has_email IS NOT NULL
    OR p_is_homeowner IS NOT NULL OR p_party IS NOT NULL
  );

  IF _has_enrichment_filter THEN
    -- Path A: enrichment filters → INNER JOIN enrichment first
    RETURN QUERY
    WITH filtered_donors AS (
      SELECT d2.id
      FROM public.mec_donors d2
      INNER JOIN public.donor_enrichment e2 ON e2.donor_id = d2.id
      WHERE
        (p_name_query IS NULL OR (
          d2.last_name ILIKE '%' || p_name_query || '%'
          OR d2.first_name ILIKE '%' || p_name_query || '%'
          OR d2.company_name ILIKE '%' || p_name_query || '%'
          OR d2.committee_name ILIKE '%' || p_name_query || '%'
        ))
        AND (p_state IS NULL OR d2.state = p_state)
        AND (p_city IS NULL OR d2.city ILIKE '%' || p_city || '%')
        AND (p_zip IS NULL OR d2.zip LIKE p_zip || '%')
        AND (_date_from IS NULL OR d2.last_contribution_date >= _date_from)
        AND (_date_to IS NULL OR d2.first_contribution_date <= _date_to)
        AND (p_employer IS NULL OR d2.employer ILIKE '%' || p_employer || '%')
        AND (p_occupation IS NULL OR d2.occupation ILIKE '%' || p_occupation || '%')
        AND (NOT p_individuals_only OR d2.donor_type = 'individual')
        -- Source filter on having data
        AND (p_source = 'both'
             OR (p_source = 'mec' AND d2.contribution_count > 0)
             OR (p_source = 'fec' AND coalesce(d2.fec_contribution_count, 0) > 0))
        -- Combined total filter
        AND (p_min_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) >= p_min_total)
        AND (p_max_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) <= p_max_total)
        -- Enrichment filters
        AND (p_gender IS NULL OR e2.gender ILIKE p_gender)
        AND (p_age_min IS NULL OR e2.age_estimate >= p_age_min)
        AND (p_age_max IS NULL OR e2.age_estimate <= p_age_max)
        AND (p_has_phone IS NULL OR (p_has_phone = (coalesce(e2.phone_mobile, '') != '' OR coalesce(e2.phone_home, '') != '')))
        AND (p_has_email IS NULL OR (p_has_email = (coalesce(e2.email_personal, '') != '')))
        AND (p_is_homeowner IS NULL OR e2.is_homeowner = p_is_homeowner)
        AND (p_party IS NULL OR e2.party_lean ILIKE '%' || p_party || '%')
      ORDER BY (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) DESC NULLS LAST
      LIMIT p_limit OFFSET p_offset
    )
    SELECT
      d.id,
      CASE
        WHEN d.donor_type = 'individual' THEN coalesce(d.first_name || ' ' || d.last_name, d.last_name)
        WHEN d.company_name IS NOT NULL THEN d.company_name
        ELSE d.committee_name
      END,
      d.last_name, d.first_name, d.company_name, d.committee_name,
      d.city, d.state, d.zip, d.employer, d.occupation,
      coalesce(d.total_contributed, 0)::numeric,
      coalesce(d.contribution_count, 0)::int,
      coalesce(d.fec_total_contributed, 0)::numeric,
      coalesce(d.fec_contribution_count, 0)::int,
      (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0))::numeric,
      (coalesce(d.contribution_count, 0) + coalesce(d.fec_contribution_count, 0))::int,
      EXTRACT(YEAR FROM d.first_contribution_date)::int,
      EXTRACT(YEAR FROM d.last_contribution_date)::int,
      d.committees_donated_to,
      CASE
        WHEN coalesce(d.contribution_count, 0) > 0 AND coalesce(d.fec_contribution_count, 0) > 0 THEN 'MEC+FEC'
        WHEN coalesce(d.fec_contribution_count, 0) > 0 THEN 'FEC'
        ELSE 'MEC'
      END,
      e.gender, e.age_estimate, e.generation, e.party_lean, e.party_lean_confidence,
      e.phone_mobile, e.phone_home, e.email_personal, e.social_profile_count,
      e.giving_capacity_estimate, e.wealth_score, e.engagement_score,
      e.is_homeowner, e.current_employer, e.current_job_title,
      e.estimated_income_range, e.ethnicity
    FROM filtered_donors fd
    JOIN public.mec_donors d ON d.id = fd.id
    LEFT JOIN public.donor_enrichment e ON e.donor_id = d.id
    ORDER BY (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0)) DESC NULLS LAST;

  ELSE
    -- Path B: no enrichment filters → CTE top donors first, then LEFT JOIN enrichment
    RETURN QUERY
    WITH top_donors AS (
      SELECT d2.id
      FROM public.mec_donors d2
      WHERE
        (p_name_query IS NULL OR (
          d2.last_name ILIKE '%' || p_name_query || '%'
          OR d2.first_name ILIKE '%' || p_name_query || '%'
          OR d2.company_name ILIKE '%' || p_name_query || '%'
          OR d2.committee_name ILIKE '%' || p_name_query || '%'
        ))
        AND (p_state IS NULL OR d2.state = p_state)
        AND (p_city IS NULL OR d2.city ILIKE '%' || p_city || '%')
        AND (p_zip IS NULL OR d2.zip LIKE p_zip || '%')
        AND (_date_from IS NULL OR d2.last_contribution_date >= _date_from)
        AND (_date_to IS NULL OR d2.first_contribution_date <= _date_to)
        AND (p_employer IS NULL OR d2.employer ILIKE '%' || p_employer || '%')
        AND (p_occupation IS NULL OR d2.occupation ILIKE '%' || p_occupation || '%')
        AND (NOT p_individuals_only OR d2.donor_type = 'individual')
        AND (p_source = 'both'
             OR (p_source = 'mec' AND d2.contribution_count > 0)
             OR (p_source = 'fec' AND coalesce(d2.fec_contribution_count, 0) > 0))
        AND (p_min_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) >= p_min_total)
        AND (p_max_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) <= p_max_total)
      ORDER BY (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) DESC NULLS LAST
      LIMIT p_limit OFFSET p_offset
    )
    SELECT
      d.id,
      CASE
        WHEN d.donor_type = 'individual' THEN coalesce(d.first_name || ' ' || d.last_name, d.last_name)
        WHEN d.company_name IS NOT NULL THEN d.company_name
        ELSE d.committee_name
      END,
      d.last_name, d.first_name, d.company_name, d.committee_name,
      d.city, d.state, d.zip, d.employer, d.occupation,
      coalesce(d.total_contributed, 0)::numeric,
      coalesce(d.contribution_count, 0)::int,
      coalesce(d.fec_total_contributed, 0)::numeric,
      coalesce(d.fec_contribution_count, 0)::int,
      (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0))::numeric,
      (coalesce(d.contribution_count, 0) + coalesce(d.fec_contribution_count, 0))::int,
      EXTRACT(YEAR FROM d.first_contribution_date)::int,
      EXTRACT(YEAR FROM d.last_contribution_date)::int,
      d.committees_donated_to,
      CASE
        WHEN coalesce(d.contribution_count, 0) > 0 AND coalesce(d.fec_contribution_count, 0) > 0 THEN 'MEC+FEC'
        WHEN coalesce(d.fec_contribution_count, 0) > 0 THEN 'FEC'
        ELSE 'MEC'
      END,
      e.gender, e.age_estimate, e.generation, e.party_lean, e.party_lean_confidence,
      e.phone_mobile, e.phone_home, e.email_personal, e.social_profile_count,
      e.giving_capacity_estimate, e.wealth_score, e.engagement_score,
      e.is_homeowner, e.current_employer, e.current_job_title,
      e.estimated_income_range, e.ethnicity
    FROM top_donors td
    JOIN public.mec_donors d ON d.id = td.id
    LEFT JOIN public.donor_enrichment e ON e.donor_id = d.id
    ORDER BY (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0)) DESC NULLS LAST;
  END IF;
END;
$$;
```

**Step 2: Verify the function works**

```sql
SELECT donor_name, mec_total, fec_total, total_amount, data_sources
FROM public.search_donors_v3(p_state := 'MO', p_limit := 10);
```

**Step 3: Reload PostgREST**

```sql
NOTIFY pgrst, 'reload schema';
```

---

### Task 5: Create `get_donor_unified_profile` RPC

**Context:** When a user clicks a donor in the research tab, we need their full profile with both MEC and FEC contributions. Currently `getContributorProfile()` in Flutter fetches ALL contributions client-side and aggregates — this is slow and only does MEC. The new RPC does server-side aggregation.

**Step 1: Create the function**

```sql
CREATE OR REPLACE FUNCTION public.get_donor_unified_profile(p_donor_id INT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'donor', (
      SELECT row_to_json(d)
      FROM (
        SELECT d.*, e.gender, e.age_estimate, e.generation, e.party_lean,
               e.party_lean_confidence, e.phone_mobile, e.phone_home,
               e.email_personal, e.current_employer, e.current_job_title,
               e.wealth_score, e.engagement_score, e.is_homeowner,
               e.estimated_income_range, e.ethnicity, e.giving_capacity_estimate
        FROM public.mec_donors d
        LEFT JOIN public.donor_enrichment e ON e.donor_id = d.id
        WHERE d.id = p_donor_id
      ) d
    ),
    'mec_contributions', (
      SELECT coalesce(json_agg(row_to_json(c) ORDER BY c.contribution_date DESC), '[]'::json)
      FROM (
        SELECT id, mec_id, committee_name, contributor_last_name, contributor_first_name,
               city, state, employer, occupation, contribution_date, contribution_amount,
               filing_year, monetary_or_inkind
        FROM public.mec_contributions
        WHERE donor_id = p_donor_id
      ) c
    ),
    'fec_contributions', (
      SELECT coalesce(json_agg(row_to_json(f) ORDER BY f.contribution_receipt_date DESC), '[]'::json)
      FROM (
        SELECT id, cmte_id, committee_name, contributor_name,
               city, state, employer,
               occupation, transaction_date,
               transaction_amount, cycle AS report_year, entity_tp AS receipt_type
        FROM public.fec_contributions
        WHERE donor_id = p_donor_id
      ) f
    ),
    'mec_committee_breakdown', (
      SELECT coalesce(json_agg(row_to_json(cb) ORDER BY cb.total DESC), '[]'::json)
      FROM (
        SELECT mec_id, committee_name,
               sum(contribution_amount) AS total,
               count(*) AS cnt,
               min(contribution_date) AS first_date,
               max(contribution_date) AS last_date
        FROM public.mec_contributions
        WHERE donor_id = p_donor_id
        GROUP BY mec_id, committee_name
      ) cb
    ),
    'fec_committee_breakdown', (
      SELECT coalesce(json_agg(row_to_json(fb) ORDER BY fb.total DESC), '[]'::json)
      FROM (
        SELECT cmte_id, committee_name,
               sum(transaction_amount) AS total,
               count(*) AS cnt,
               min(transaction_date) AS first_date,
               max(transaction_date) AS last_date
        FROM public.fec_contributions
        WHERE donor_id = p_donor_id
        GROUP BY committee_id, committee_name
      ) fb
    )
  ) INTO result;

  RETURN result;
END;
$$;
```

**Step 2: Verify**

```sql
SELECT public.get_donor_unified_profile(1);
```

---

### Task 6: Create `get_committee_donors_paginated` RPC

**Context:** The committees tab currently calls `getTopContributors()` which fetches ALL contributions for a committee and aggregates client-side, limited to top 25. Users want ALL donors with pagination.

**Step 1: Create the function**

```sql
CREATE OR REPLACE FUNCTION public.get_committee_donors_paginated(
  p_mec_id TEXT,
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0,
  p_sort_by TEXT DEFAULT 'total',  -- 'total', 'count', 'name', 'last_date'
  p_ascending BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  donor_id INT,
  donor_name TEXT,
  city TEXT,
  state TEXT,
  employer TEXT,
  occupation TEXT,
  total NUMERIC,
  cnt INT,
  first_date DATE,
  last_date DATE,
  has_fec BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    CASE
      WHEN c.contributor_company IS NOT NULL AND c.contributor_company != '' THEN c.contributor_company
      WHEN c.contributor_committee IS NOT NULL AND c.contributor_committee != '' THEN c.contributor_committee
      ELSE trim(coalesce(c.contributor_first_name, '') || ' ' || coalesce(c.contributor_last_name, ''))
    END,
    c.city,
    c.state,
    c.employer,
    c.occupation,
    sum(c.contribution_amount),
    count(*)::int,
    min(c.contribution_date)::date,
    max(c.contribution_date)::date,
    coalesce(d.fec_contribution_count, 0) > 0
  FROM public.mec_contributions c
  LEFT JOIN public.mec_donors d ON d.id = c.donor_id
  WHERE c.mec_id = p_mec_id
  GROUP BY d.id, 2, c.city, c.state, c.employer, c.occupation, d.fec_contribution_count
  ORDER BY
    CASE WHEN p_sort_by = 'total' AND NOT p_ascending THEN sum(c.contribution_amount) END DESC NULLS LAST,
    CASE WHEN p_sort_by = 'total' AND p_ascending THEN sum(c.contribution_amount) END ASC NULLS LAST,
    CASE WHEN p_sort_by = 'count' AND NOT p_ascending THEN count(*) END DESC,
    CASE WHEN p_sort_by = 'count' AND p_ascending THEN count(*) END ASC,
    CASE WHEN p_sort_by = 'name' AND p_ascending THEN trim(coalesce(c.contributor_first_name, '') || ' ' || coalesce(c.contributor_last_name, '')) END ASC,
    CASE WHEN p_sort_by = 'name' AND NOT p_ascending THEN trim(coalesce(c.contributor_first_name, '') || ' ' || coalesce(c.contributor_last_name, '')) END DESC,
    CASE WHEN p_sort_by = 'last_date' AND NOT p_ascending THEN max(c.contribution_date) END DESC NULLS LAST,
    CASE WHEN p_sort_by = 'last_date' AND p_ascending THEN max(c.contribution_date) END ASC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$$;
```

**Step 2: Verify**

```sql
SELECT * FROM public.get_committee_donors_paginated('C101141', p_limit := 5);
```

**Step 3: Reload PostgREST**

```sql
NOTIFY pgrst, 'reload schema';
```

---

### Task 7: Create FEC committee search function

**Step 1: Create `search_committees_unified` RPC**

```sql
CREATE OR REPLACE FUNCTION public.search_committees_unified(
  p_query TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_party TEXT DEFAULT NULL,
  p_source TEXT DEFAULT 'both',  -- 'mec', 'fec', 'both'
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS TABLE (
  id INT,
  source TEXT,
  committee_id TEXT,      -- mec_id or fec committee_id
  committee_name TEXT,
  committee_type TEXT,
  committee_status TEXT,
  party_affiliation TEXT,
  candidate_name TEXT,
  treasurer_name TEXT,
  state TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  (
    -- MEC committees
    SELECT
      m.id,
      'MEC'::text,
      m.mec_id,
      -- Strip leading zeros from committee names
      regexp_replace(m.committee_name, '^0+', ''),
      m.committee_type,
      m.committee_status,
      m.party_affiliation,
      m.candidate_name,
      m.treasurer_name,
      NULL::text  -- MEC doesn't have state at committee level
    FROM public.mec_committees m
    WHERE
      (p_source = 'both' OR p_source = 'mec')
      AND (p_query IS NULL OR (
        m.committee_name ILIKE '%' || p_query || '%'
        OR m.candidate_name ILIKE '%' || p_query || '%'
        OR m.treasurer_name ILIKE '%' || p_query || '%'
      ))
      AND (p_status IS NULL OR m.committee_status = p_status)
      AND (p_party IS NULL OR m.party_affiliation = p_party)

    UNION ALL

    -- FEC committees
    SELECT
      f.id::int,
      'FEC'::text,
      f.cmte_id,
      f.cmte_name,
      f.cmte_type,
      CASE WHEN f.cmte_type IS NOT NULL THEN 'Active' ELSE 'Unknown' END,
      f.party,
      fc.cand_name,
      f.treasurer_name,
      f.state
    FROM public.fec_committees f
    LEFT JOIN public.fec_candidates fc ON fc.cand_id = f.cand_id
    WHERE
      (p_source = 'both' OR p_source = 'fec')
      AND (p_query IS NULL OR (
        f.cmte_name ILIKE '%' || p_query || '%'
        OR fc.cand_name ILIKE '%' || p_query || '%'
        OR f.treasurer_name ILIKE '%' || p_query || '%'
      ))
      AND (p_party IS NULL OR f.party = p_party)
  )
  ORDER BY committee_name ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
```

**Step 2: Verify & reload**

```sql
SELECT * FROM public.search_committees_unified(p_query := 'missouri', p_limit := 5);
NOTIFY pgrst, 'reload schema';
```

---

## Phase 3: Flutter — Models & Repository Updates

### Task 8: Create FEC contribution model

**Files:**
- Create: `lib/models/crm/fec_contribution.dart`

**Step 1: Create the model**

```dart
import 'package:intl/intl.dart';

/// FecContribution model - maps to Supabase 'public.fec_contributions' table
/// Column names: cmte_id, committee_name, contributor_name, city, state, zip,
/// employer, occupation, transaction_date, transaction_amount, cycle, entity_tp, donor_id
class FecContribution {
  final int id;
  final String? cmteId;
  final String? committeeName;
  final String? contributorName;
  final String? city;
  final String? state;
  final String? zip;
  final String? employer;
  final String? occupation;
  final DateTime? transactionDate;
  final double? transactionAmount;
  final int? cycle;
  final String? entityType;
  final int? donorId;

  const FecContribution({
    required this.id,
    this.cmteId,
    this.committeeName,
    this.contributorName,
    this.city,
    this.state,
    this.zip,
    this.employer,
    this.occupation,
    this.transactionDate,
    this.transactionAmount,
    this.cycle,
    this.entityType,
    this.donorId,
  });

  factory FecContribution.fromJson(Map<String, dynamic> json) {
    return FecContribution(
      id: json['id'] as int,
      cmteId: json['cmte_id'] as String?,
      committeeName: json['committee_name'] as String?,
      contributorName: json['contributor_name'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      transactionDate: _parseDate(json['transaction_date']),
      transactionAmount: (json['transaction_amount'] as num?)?.toDouble(),
      cycle: json['cycle'] as int?,
      entityType: json['entity_tp'] as String?,
      donorId: json['donor_id'] as int?,
    );
  }

  String get formattedDate {
    if (transactionDate == null) return 'Date unknown';
    return DateFormat.yMMMd().format(transactionDate!);
  }

  String get formattedAmount {
    if (transactionAmount == null) return '\$0.00';
    return NumberFormat.simpleCurrency().format(transactionAmount);
  }

  String get displayName => contributorName ?? 'Unknown';

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
```

**Step 2: Commit**

---

### Task 9: Update `MecRepository` with unified search and profile methods

**Files:**
- Modify: `lib/services/crm/mec_repository.dart`

**Step 1: Add new imports and methods**

Add import at top:
```dart
import 'package:bluebubbles/models/crm/fec_contribution.dart';
```

Add these new methods to the `MecRepository` class:

```dart
  // ---------------------------------------------------------------------------
  // searchDonorsUnified (RPC — unified MEC+FEC search)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchDonorsUnified({
    String? state,
    int? yearFrom,
    int? yearTo,
    double? minTotal,
    double? maxTotal,
    String? party,
    String? nameQuery,
    String? city,
    String? zip,
    String? employer,
    String? occupation,
    String? gender,
    int? ageMin,
    int? ageMax,
    bool? hasPhone,
    bool? hasEmail,
    bool? isHomeowner,
    bool individualsOnly = true,
    String source = 'both',  // 'mec', 'fec', 'both'
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    final params = <String, dynamic>{
      'p_individuals_only': individualsOnly,
      'p_source': source,
      'p_limit': limit,
      'p_offset': offset,
    };
    if (state != null && state.isNotEmpty) params['p_state'] = state;
    if (yearFrom != null) params['p_year_from'] = yearFrom;
    if (yearTo != null) params['p_year_to'] = yearTo;
    if (minTotal != null) params['p_min_total'] = minTotal;
    if (maxTotal != null) params['p_max_total'] = maxTotal;
    if (party != null && party.isNotEmpty) params['p_party'] = party;
    if (nameQuery != null && nameQuery.isNotEmpty) params['p_name_query'] = nameQuery;
    if (city != null && city.isNotEmpty) params['p_city'] = city;
    if (zip != null && zip.isNotEmpty) params['p_zip'] = zip;
    if (employer != null && employer.isNotEmpty) params['p_employer'] = employer;
    if (occupation != null && occupation.isNotEmpty) params['p_occupation'] = occupation;
    if (gender != null && gender.isNotEmpty) params['p_gender'] = gender;
    if (ageMin != null) params['p_age_min'] = ageMin;
    if (ageMax != null) params['p_age_max'] = ageMax;
    if (hasPhone != null) params['p_has_phone'] = hasPhone;
    if (hasEmail != null) params['p_has_email'] = hasEmail;
    if (isHomeowner != null) params['p_is_homeowner'] = isHomeowner;

    final data = await _readClient.rpc('search_donors_v3', params: params);
    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // getDonorUnifiedProfile (RPC — full MEC+FEC profile)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getDonorUnifiedProfile(int donorId) async {
    if (!isReady) return null;

    final data = await _readClient.rpc('get_donor_unified_profile', params: {
      'p_donor_id': donorId,
    });

    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // getCommitteeDonorsPaginated (RPC — all donors for a committee)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCommitteeDonorsPaginated({
    required String mecId,
    int limit = 100,
    int offset = 0,
    String sortBy = 'total',
    bool ascending = false,
  }) async {
    if (!isReady) return [];

    final data = await _readClient.rpc('get_committee_donors_paginated', params: {
      'p_mec_id': mecId,
      'p_limit': limit,
      'p_offset': offset,
      'p_sort_by': sortBy,
      'p_ascending': ascending,
    });

    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // searchCommitteesUnified (RPC — MEC+FEC committees)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchCommitteesUnified({
    String? query,
    String? status,
    String? party,
    String source = 'both',
    int limit = 50,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    final params = <String, dynamic>{
      'p_source': source,
      'p_limit': limit,
      'p_offset': offset,
    };
    if (query != null && query.isNotEmpty) params['p_query'] = query;
    if (status != null && status.isNotEmpty) params['p_status'] = status;
    if (party != null && party.isNotEmpty) params['p_party'] = party;

    final data = await _readClient.rpc('search_committees_unified', params: params);
    return (data as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }
```

**Step 2: Commit**

---

## Phase 4: Flutter — Committees Tab Overhaul

### Task 10: Rewrite `committees_tab.dart`

**Files:**
- Modify: `lib/screens/crm/tabs/committees_tab.dart`

**Key changes:**
1. Use `searchCommitteesUnified()` RPC instead of direct table query
2. Add source filter chips (MEC / FEC / Both)
3. Strip leading zeros from displayed committee names (handled server-side now)
4. Committee detail view: use `getCommitteeDonorsPaginated()` for ALL donors with infinite scroll
5. Each donor row is clickable — navigates to unified donor profile (opens in Donor Research tab's profile mode)
6. Fix status filter to show ALL committees when no filter selected (not just "Active")

**Complete replacement file — see Task 10 implementation in the execution phase.**

The new committees tab structure:
- Search bar (same styling)
- Filter row: Source chips (MEC / FEC / Both) + Status (Active / Terminated / All) + Party
- Committee list with source badge (MEC/FEC) on each card
- Detail view: financial summary + ALL donors (paginated, sortable) + year breakdown + contact info
- Donor rows clickable → opens unified profile

---

## Phase 5: Flutter — Donor Research Tab Overhaul

### Task 11: Rewrite `mec_research_tab.dart` to unified donor research

**Files:**
- Modify: `lib/screens/crm/tabs/mec_research_tab.dart`

**Key changes:**
1. Use `searchDonorsUnified()` instead of `searchDonors()` (v3 instead of v2)
2. Add source filter chips (MEC / FEC / Both) in the filter row
3. Show source badge (MEC / FEC / MEC+FEC) on each donor card
4. Show separate MEC and FEC totals alongside combined total
5. Profile mode: use `getDonorUnifiedProfile()` RPC
6. Profile shows MEC contributions and FEC contributions in separate sections with visual differentiation
7. Committee breakdown shows both MEC and FEC committees

**Updated search call in `_performSearch()`:**
```dart
final results = await _repository.searchDonorsUnified(
  nameQuery: nameQuery.isNotEmpty ? nameQuery : null,
  state: _selectedState.isNotEmpty ? _selectedState : null,
  yearFrom: _yearFrom,
  yearTo: _yearTo,
  minTotal: minTotal,
  party: _selectedParty,
  source: _selectedSource,  // NEW
  limit: 100,
  offset: 0,
);
```

**Updated profile mode header:** Shows combined total prominently with MEC/FEC breakdown badges.

**Updated contributions timeline:** Two sections:
- "Missouri (MEC) Contributions" with blue accent
- "Federal (FEC) Contributions" with gold accent
Each with its own committee breakdown and contribution list.

---

## Phase 6: Final Polish & Deploy

### Task 12: Build verification and deploy

**Step 1: Pull latest, verify build**

```bash
cd /tmp/my-bluebubbles-web
git pull origin master
flutter build web --release
```

**Step 2: Commit all changes**

```bash
git add -A
git commit -m "feat: unify MEC+FEC donor research with source filters and overhauled committees tab"
```

**Step 3: Push and verify Netlify deploy**

```bash
git push origin master
```

Check https://moyd.app after deploy completes.

---

## Execution Order

Tasks 1-3 (database backfill) must run first and sequentially.
Tasks 4-7 (RPC functions) can run in parallel after 1-3.
Task 8 (FEC model) is independent, can run anytime.
Task 9 (repository updates) depends on Task 8.
Tasks 10-11 (UI rewrites) depend on Task 9.
Task 12 (deploy) runs last.

```
[1] → [2] → [3] → [4,5,6,7] → [8] → [9] → [10,11] → [12]
```
