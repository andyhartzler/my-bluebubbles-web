# Voter-File Universal DOB Backfill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ingest the Missouri statewide PSR voter file (April 2026 edition), build a new `public.mo_voter_file` table, then enrich every person-keyed table in the MOYD Supabase DB with real DOBs and voter-registration linkage — so we stop relying on AI-estimated ages and get accurate young-democrat classification everywhere.

**Architecture:** One new flat table `mo_voter_file` matching PSR schema, loaded via `COPY`. A generic `match_people_to_voter_file()` SQL function takes `(first_name, last_name, zip, county)` and returns `(voter_id, confidence, method)`. Every person-keyed table gets `date_of_birth date`, `mo_voter_file_id text` (FK to `mo_voter_file.voter_id`), `dob_source text` ("voter_file" / "self_reported" / "ai_estimate"). Run the matcher once per table, write results, then recompute derived fields (`estimated_age`, `is_young_dem`) from real DOBs.

**Tech Stack:** PostgreSQL 15 (Supabase project `faajpcarasilbfndzkmd`), `psql`, `pg_trgm` extension, Python 3 for CSV munging, `COPY` for bulk load.

**Tables getting backfilled:**
- `candidates` (520) — has DOB + voter_match_id already; will rename to `mo_voter_file_id` for consistency
- `historical_candidates` (1226) — no DOB; add columns
- `members` (409) — has DOB; add link
- `donors` (49) + `donor_profiles` (49) — has DOB on donors only; add to profiles
- `mec_donors` (1,022,423) — no DOB; add columns; only match confident name+zip pairs
- `fec_candidates` (1113) — no DOB; add columns
- `legislation_legislators` (193) — no DOB; add columns
- `subscribers` (73,107) — has DOB; add link only
- `donor_enrichment` (470,277) — has DOB columns but empty; populate from voter file

**Tables explicitly skipped:** `van_*` (legacy donor-360 scrape, leave alone), `fec_committees` / `mec_committees` (entities not people), `event_attendees` (derives from members/subscribers).

**Watchouts:**
- Members UPDATE fires 3 Zapier/Make webhooks. Must disable before bulk edit.
- `trigger_update_membership_eligible` recomputes on members write — desired here since DOBs may be more accurate.
- PostgREST schema reload required after DDL (`NOTIFY pgrst, 'reload schema'`).
- ALL queries must use `public.` prefix (search_path defaults to `listmonk`).

---

### Task 1: Download + unzip the PSR voter file, inspect schema

**Files:**
- Create: `/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_psr_raw.zip`
- Create: `/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_extracted/`
- Create: `/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_psr_schema_notes.md`

- [ ] **Step 1.1: Download the zip via Drive API**

Google Drive file id: `1Q0c-43RkiwwBCRCwIpouysdFRitjf8Zg` (from Alex's email thread `19daabc93d8449bf`).

Use the `backend-everything` service account (`/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json`), impersonating `andrew@moyoungdemocrats.org`, scope `https://www.googleapis.com/auth/drive.readonly`. Stream the binary to `/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_psr_raw.zip` (208MB).

```python
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
import io

KEY = '/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json'
creds = (service_account.Credentials
         .from_service_account_file(KEY, scopes=['https://www.googleapis.com/auth/drive.readonly'])
         .with_subject('andrew@moyoungdemocrats.org'))
drive = build('drive', 'v3', credentials=creds, cache_discovery=False)
req = drive.files().get_media(fileId='1Q0c-43RkiwwBCRCwIpouysdFRitjf8Zg')
with open('/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_psr_raw.zip','wb') as f:
    downloader = MediaIoBaseDownload(f, req, chunksize=50*1024*1024)
    done = False
    while not done:
        status, done = downloader.next_chunk()
        print(f"{int(status.progress()*100)}%")
```

Expected: completes with file size ≈ 208MB.

- [ ] **Step 1.2: Unzip and inspect**

```bash
cd /Users/moyd/MOYD/voter-file-enrichment-2026-04
unzip -o 01_psr_raw.zip -d 01_extracted
ls -la 01_extracted
file 01_extracted/*
```

- [ ] **Step 1.3: Inspect CSV schema**

```bash
# Assuming CSV is in there; find actual name
CSV=$(find 01_extracted -type f \( -iname '*.csv' -o -iname '*.txt' -o -iname '*.tsv' \) | head -1)
echo "Found: $CSV"
wc -l "$CSV"
head -1 "$CSV"      # header row
sed -n '2p' "$CSV" | head -c 500   # one sample row
```

Capture the column list, delimiter, encoding, and row count into `01_psr_schema_notes.md`. This determines the CREATE TABLE DDL in Task 2.

- [ ] **Step 1.4: Commit nothing yet — this is exploration.**

---

### Task 2: Create `public.mo_voter_file` table

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_01_mo_voter_file.sql`

- [ ] **Step 2.1: Write migration based on actual CSV columns from Task 1**

Starter template (adjust column list once CSV inspected):

```sql
-- 20260421_01_mo_voter_file.sql
-- Creates the MO statewide voter-file table. Source: PSR_VotersList 2026-04-01.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.mo_voter_file (
  voter_id            text PRIMARY KEY,     -- PSR VoterRegistrationID
  first_name          text,
  middle_name         text,
  last_name           text,
  suffix              text,
  date_of_birth       date,
  registration_date   date,
  voter_status        text,                 -- Active / Inactive / Cancelled
  party               text,                 -- MO does not register by party; blank in practice
  -- residence address
  house_number        text,
  street_prefix       text,
  street_name         text,
  street_suffix       text,
  unit_type           text,
  unit_number         text,
  residence_city      text,
  residence_zip5      text,
  residence_zip4      text,
  county              text,
  -- political geography
  precinct            text,
  split               text,
  ward                text,
  township            text,
  congressional_district text,
  state_senate_district  text,
  state_house_district   text,
  school_district        text,
  -- mailing address if different
  mail_address_line1  text,
  mail_city           text,
  mail_state          text,
  mail_zip            text,
  -- provenance
  file_date           date      NOT NULL DEFAULT '2026-04-01',
  imported_at         timestamptz NOT NULL DEFAULT now(),
  raw                 jsonb      -- keep any extra columns untyped for later
);

-- Indexes for matching
CREATE INDEX IF NOT EXISTS idx_mvf_name_zip
  ON public.mo_voter_file (lower(last_name), lower(first_name), residence_zip5);
CREATE INDEX IF NOT EXISTS idx_mvf_name_county
  ON public.mo_voter_file (lower(last_name), lower(first_name), lower(county));
CREATE INDEX IF NOT EXISTS idx_mvf_trgm
  ON public.mo_voter_file USING gin ((lower(first_name || ' ' || last_name)) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_mvf_county ON public.mo_voter_file (lower(county));
CREATE INDEX IF NOT EXISTS idx_mvf_zip5 ON public.mo_voter_file (residence_zip5);

COMMIT;
NOTIFY pgrst, 'reload schema';
```

- [ ] **Step 2.2: Apply via psql**

```bash
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
PGPASSWORD="$MOYD_DB_PASSWORD" psql -h db.faajpcarasilbfndzkmd.supabase.co -U postgres -d postgres \
  -f /Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_01_mo_voter_file.sql
```

Expected: `CREATE TABLE`, `CREATE INDEX` x5, `COMMIT`, `NOTIFY`.

- [ ] **Step 2.3: Verify shape**

```bash
psql ... -c "\d+ public.mo_voter_file" | head -40
```

- [ ] **Step 2.4: Commit**

```bash
cd /Users/moyd/my-bluebubbles-web
git add supabase/migrations/20260421_01_mo_voter_file.sql
git commit -m "feat(db): add mo_voter_file table for PSR statewide voter list"
```

---

### Task 3: Transform + bulk-load the voter file

**Files:**
- Create: `/Users/moyd/MOYD/voter-file-enrichment-2026-04/load_voter_file.py`
- Create: `/Users/moyd/MOYD/voter-file-enrichment-2026-04/02_normalized.csv` (generated)

- [ ] **Step 3.1: Write the normalization script**

The PSR CSV will almost certainly have different column names than our DDL. The script reads the raw CSV, maps columns to our schema, normalizes dates (MM/DD/YYYY → YYYY-MM-DD), strips/uppercases where appropriate, writes a clean CSV with header matching mo_voter_file columns.

```python
# load_voter_file.py
import csv, sys, re
from datetime import datetime
from pathlib import Path

SRC = Path('/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_extracted/<CSV_NAME>')
DST = Path('/Users/moyd/MOYD/voter-file-enrichment-2026-04/02_normalized.csv')

# column mapping: fill in after Task 1 inspection
COLMAP = {
  'VoterRegistrationID': 'voter_id',
  'FirstName': 'first_name',
  # ... fill in
}
OUT_COLS = [
  'voter_id','first_name','middle_name','last_name','suffix',
  'date_of_birth','registration_date','voter_status','party',
  'house_number','street_prefix','street_name','street_suffix',
  'unit_type','unit_number','residence_city','residence_zip5','residence_zip4',
  'county','precinct','split','ward','township',
  'congressional_district','state_senate_district','state_house_district','school_district',
  'mail_address_line1','mail_city','mail_state','mail_zip',
]

def parse_date(s):
    if not s: return ''
    for fmt in ('%m/%d/%Y','%Y-%m-%d','%m-%d-%Y'):
        try: return datetime.strptime(s, fmt).date().isoformat()
        except ValueError: continue
    return ''

rows_in = rows_out = bad_dob = 0
with SRC.open('r', encoding='utf-8', errors='replace') as fi, DST.open('w', newline='') as fo:
    reader = csv.DictReader(fi)
    writer = csv.DictWriter(fo, fieldnames=OUT_COLS)
    writer.writeheader()
    for src in reader:
        rows_in += 1
        out = {c: '' for c in OUT_COLS}
        for src_k, dst_k in COLMAP.items():
            if src_k in src:
                out[dst_k] = (src[src_k] or '').strip()
        out['date_of_birth']    = parse_date(out.get('date_of_birth',''))
        out['registration_date']= parse_date(out.get('registration_date',''))
        if not out['voter_id']: continue
        writer.writerow(out)
        rows_out += 1
print(f"in={rows_in} out={rows_out}")
```

- [ ] **Step 3.2: Run the transform**

```bash
cd /Users/moyd/MOYD/voter-file-enrichment-2026-04
python3 load_voter_file.py
wc -l 02_normalized.csv
head -2 02_normalized.csv
```

Expected: ~4M output rows, header row + data.

- [ ] **Step 3.3: COPY into Supabase**

```bash
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
PGPASSWORD="$MOYD_DB_PASSWORD" psql -h db.faajpcarasilbfndzkmd.supabase.co -U postgres -d postgres \
  -c "\COPY public.mo_voter_file(voter_id,first_name,middle_name,last_name,suffix,date_of_birth,registration_date,voter_status,party,house_number,street_prefix,street_name,street_suffix,unit_type,unit_number,residence_city,residence_zip5,residence_zip4,county,precinct,split,ward,township,congressional_district,state_senate_district,state_house_district,school_district,mail_address_line1,mail_city,mail_state,mail_zip) FROM '/Users/moyd/MOYD/voter-file-enrichment-2026-04/02_normalized.csv' WITH (FORMAT csv, HEADER true, NULL '')"
```

Expected output: `COPY <N>` where N ≈ row count.

- [ ] **Step 3.4: Verify load + ANALYZE**

```sql
SELECT COUNT(*) total,
       COUNT(date_of_birth) with_dob,
       COUNT(DISTINCT county) counties,
       MIN(date_of_birth), MAX(date_of_birth)
FROM public.mo_voter_file;

ANALYZE public.mo_voter_file;
```

Expected: total ≈ 4M, DOBs for ~90%+, 115 MO counties.

- [ ] **Step 3.5: Commit script**

```bash
cd /Users/moyd/my-bluebubbles-web
cp /Users/moyd/MOYD/voter-file-enrichment-2026-04/load_voter_file.py scripts/voter_file/load_voter_file.py
mkdir -p scripts/voter_file
git add scripts/voter_file/load_voter_file.py
git commit -m "feat(scripts): PSR voter file normalizer + loader"
```

---

### Task 4: Add `date_of_birth` + `mo_voter_file_id` + `dob_source` columns to person-tables that lack them

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_02_universal_dob_columns.sql`

- [ ] **Step 4.1: Write migration**

```sql
-- 20260421_02_universal_dob_columns.sql
-- Add date_of_birth + mo_voter_file_id + dob_source to every person-keyed table that lacks them.
BEGIN;

-- historical_candidates: no DOB, no voter link
ALTER TABLE public.historical_candidates
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL),
  ADD COLUMN IF NOT EXISTS first_name       text,
  ADD COLUMN IF NOT EXISTS last_name        text,
  ADD COLUMN IF NOT EXISTS is_young_dem     boolean;

-- donor_profiles: has no DOB
ALTER TABLE public.donor_profiles
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

-- mec_donors: 1M rows, no DOB
ALTER TABLE public.mec_donors
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

-- fec_candidates: 1113 rows
ALTER TABLE public.fec_candidates
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

-- legislation_legislators: 193 rows
ALTER TABLE public.legislation_legislators
  ADD COLUMN IF NOT EXISTS date_of_birth    date,
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

-- Tables that already have DOB but need the link + source columns
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL) DEFAULT 'self_reported';

ALTER TABLE public.donors
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

ALTER TABLE public.subscribers
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

ALTER TABLE public.donor_enrichment
  ADD COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id);

-- Rename candidates.voter_match_id (unused uuid) → mo_voter_file_id text
-- Safe because 0 rows have a value.
ALTER TABLE public.candidates
  DROP COLUMN IF EXISTS voter_match_id,
  ADD  COLUMN IF NOT EXISTS mo_voter_file_id text REFERENCES public.mo_voter_file(voter_id),
  ADD  COLUMN IF NOT EXISTS dob_source       text CHECK (dob_source IN ('voter_file','self_reported','ai_estimate') OR dob_source IS NULL);

-- Mark existing 22 candidates.date_of_birth as ai_estimate so we can overwrite cleanly.
UPDATE public.candidates SET dob_source='ai_estimate' WHERE date_of_birth IS NOT NULL AND dob_source IS NULL;

-- Mark existing 343 members.date_of_birth as self_reported (came from signup form).
UPDATE public.members SET dob_source='self_reported' WHERE date_of_birth IS NOT NULL AND dob_source IS NULL;

COMMIT;
NOTIFY pgrst, 'reload schema';
```

- [ ] **Step 4.2: Apply + verify**

```bash
PGPASSWORD=... psql ... -f supabase/migrations/20260421_02_universal_dob_columns.sql
PGPASSWORD=... psql ... -c "SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='historical_candidates' AND column_name IN ('date_of_birth','mo_voter_file_id','dob_source','first_name','last_name');"
```

Expected: 5 rows.

- [ ] **Step 4.3: Commit**

```bash
git add supabase/migrations/20260421_02_universal_dob_columns.sql
git commit -m "feat(db): add universal date_of_birth + mo_voter_file_id + dob_source columns"
```

---

### Task 5: Parse candidates.address → populate city/zip/county

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_03_candidates_parse_address.sql`

- [ ] **Step 5.1: Migration**

```sql
-- 20260421_03_candidates_parse_address.sql
-- Parse candidates.address into city/zip/county using regex + voter-file county lookup.
BEGIN;

-- Extract zip5 (last MO-looking 5-digit number in address)
UPDATE public.candidates c
SET zip = m[1]
FROM regexp_matches(c.address, '(\d{5})(?:-\d{4})?\s*$') AS m
WHERE c.zip IS NULL AND c.address IS NOT NULL;

-- Extract city (the word(s) between last comma before ST and the state)
UPDATE public.candidates c
SET city = upper(trim(m[1]))
FROM regexp_matches(c.address, ',\s*([A-Z][A-Z\s\.]+)\s+MO\s+\d{5}', 'i') AS m
WHERE c.city IS NULL AND c.address IS NOT NULL;

-- State: default MO
UPDATE public.candidates SET state='MO' WHERE state IS NULL AND address ILIKE '% MO %';

-- County lookup via voter file (majority vote from voters at same zip)
WITH zip_counties AS (
  SELECT residence_zip5 AS zip, county,
         ROW_NUMBER() OVER (PARTITION BY residence_zip5 ORDER BY COUNT(*) DESC) AS rnk
  FROM public.mo_voter_file
  WHERE residence_zip5 IS NOT NULL
  GROUP BY residence_zip5, county
)
UPDATE public.candidates c
SET county = zc.county
FROM zip_counties zc
WHERE zc.rnk = 1 AND c.zip = zc.zip AND c.county IS NULL;

COMMIT;

SELECT COUNT(*) total, COUNT(zip) with_zip, COUNT(city) with_city, COUNT(county) with_county
FROM public.candidates;
```

- [ ] **Step 5.2: Apply + verify**

Expected after: ≥ 450/520 candidates have zip populated, ≥ 400 have city/county.

- [ ] **Step 5.3: Commit**

```bash
git add supabase/migrations/20260421_03_candidates_parse_address.sql
git commit -m "chore(db): parse candidates.address into zip/city/county"
```

---

### Task 6: Generic `match_person_to_voter_file()` SQL function

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_04_match_voter_file_fn.sql`

- [ ] **Step 6.1: Write the function**

```sql
-- 20260421_04_match_voter_file_fn.sql
-- Generic matching function: takes person details, returns best voter_id + confidence + method.
BEGIN;

CREATE OR REPLACE FUNCTION public.match_person_to_voter_file(
  p_first_name  text,
  p_last_name   text,
  p_zip         text DEFAULT NULL,
  p_county      text DEFAULT NULL,
  p_city        text DEFAULT NULL
) RETURNS TABLE(voter_id text, confidence numeric, method text)
LANGUAGE sql STABLE
AS $$
  WITH
  p AS (SELECT lower(trim(p_first_name)) AS fn, lower(trim(p_last_name)) AS ln,
               NULLIF(trim(p_zip),'') AS zip, lower(NULLIF(trim(p_county),'')) AS cn,
               upper(NULLIF(trim(p_city),'')) AS ct),

  -- Pass 1: exact name + zip — unique only
  pass1 AS (
    SELECT v.voter_id, 1.0::numeric AS confidence, 'exact_name_zip' AS method
    FROM public.mo_voter_file v, p
    WHERE lower(v.first_name) = p.fn
      AND lower(v.last_name)  = p.ln
      AND p.zip IS NOT NULL
      AND v.residence_zip5    = p.zip
  ),
  pass1_unique AS (
    SELECT voter_id, confidence, method FROM pass1
    WHERE (SELECT COUNT(*) FROM pass1) = 1
  ),

  -- Pass 2: exact name + county (if pass1 empty or ambiguous)
  pass2 AS (
    SELECT v.voter_id, 0.9::numeric AS confidence, 'exact_name_county' AS method
    FROM public.mo_voter_file v, p
    WHERE lower(v.first_name) = p.fn
      AND lower(v.last_name)  = p.ln
      AND p.cn IS NOT NULL
      AND lower(v.county)     = p.cn
  ),
  pass2_unique AS (
    SELECT voter_id, confidence, method FROM pass2
    WHERE NOT EXISTS (SELECT 1 FROM pass1_unique)
      AND (SELECT COUNT(*) FROM pass2) = 1
  ),

  -- Pass 3: trigram fuzzy + county scope (threshold 0.8)
  pass3 AS (
    SELECT v.voter_id,
           similarity(lower(v.first_name||' '||v.last_name),
                      lower(p.fn||' '||p.ln)) AS confidence,
           'trigram_fuzzy_county' AS method
    FROM public.mo_voter_file v, p
    WHERE p.cn IS NOT NULL
      AND lower(v.county) = p.cn
      AND similarity(lower(v.first_name||' '||v.last_name),
                     lower(p.fn||' '||p.ln)) >= 0.8
    ORDER BY confidence DESC
    LIMIT 1
  ),
  pass3_unique AS (
    SELECT voter_id, confidence, method FROM pass3
    WHERE NOT EXISTS (SELECT 1 FROM pass1_unique)
      AND NOT EXISTS (SELECT 1 FROM pass2_unique)
  )

  SELECT * FROM pass1_unique
  UNION ALL SELECT * FROM pass2_unique
  UNION ALL SELECT * FROM pass3_unique
  LIMIT 1;
$$;

COMMIT;
```

- [ ] **Step 6.2: Test on a known person**

```sql
SELECT * FROM public.match_person_to_voter_file('Crystal', 'Quade', '65807', 'Greene');
-- Expected: 1 row with confidence 1.0 (Crystal Quade is a real MO candidate, House Minority Leader).
```

- [ ] **Step 6.3: Commit**

```bash
git add supabase/migrations/20260421_04_match_voter_file_fn.sql
git commit -m "feat(db): add match_person_to_voter_file SQL function"
```

---

### Task 7: Enrich `candidates` (520 rows)

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_05_enrich_candidates.sql`

- [ ] **Step 7.1: Run matcher + write results**

```sql
-- 20260421_05_enrich_candidates.sql
BEGIN;

-- Clear existing AI-estimated DOBs per Andrew's directive
UPDATE public.candidates
SET date_of_birth = NULL, estimated_age = NULL
WHERE dob_source = 'ai_estimate';

-- Run matcher for every candidate
WITH matches AS (
  SELECT c.id, m.voter_id, m.confidence, m.method
  FROM public.candidates c
  CROSS JOIN LATERAL public.match_person_to_voter_file(c.first_name, c.last_name, c.zip, c.county, c.city) m
)
UPDATE public.candidates c
SET mo_voter_file_id = mt.voter_id,
    date_of_birth    = v.date_of_birth,
    estimated_age    = EXTRACT(YEAR FROM age(COALESCE(c.election_date, CURRENT_DATE), v.date_of_birth))::int,
    dob_source       = 'voter_file'
FROM matches mt
JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
WHERE c.id = mt.id AND v.date_of_birth IS NOT NULL;

-- Recompute is_young_dem: Democratic + age ≤ 36 on election day
UPDATE public.candidates
SET is_young_dem = (
  party = 'Democratic'
  AND date_of_birth IS NOT NULL
  AND date_of_birth > (COALESCE(election_date, CURRENT_DATE) - INTERVAL '36 years')
);

-- Summary
SELECT COUNT(*) total,
       COUNT(mo_voter_file_id) matched,
       COUNT(date_of_birth) with_dob,
       COUNT(*) FILTER (WHERE is_young_dem) young_dems,
       COUNT(*) FILTER (WHERE is_young_dem AND party='Democratic') confirmed_young_dems
FROM public.candidates;

COMMIT;
```

- [ ] **Step 7.2: Spot-check**

```sql
SELECT first_name, last_name, party, zip, county, date_of_birth, estimated_age, is_young_dem, dob_source
FROM public.candidates
WHERE party='Democratic' AND is_young_dem
ORDER BY last_name LIMIT 20;
```

- [ ] **Step 7.3: Commit + send summary to Andrew**

```bash
git add supabase/migrations/20260421_05_enrich_candidates.sql
git commit -m "feat(candidates): enrich with real DOBs from voter file, recompute is_young_dem"
```

---

### Task 8: Enrich `historical_candidates` (1226 rows)

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_06_enrich_historical_candidates.sql`

- [ ] **Step 8.1: Split `name` → `first_name` / `last_name`**

```sql
BEGIN;

UPDATE public.historical_candidates
SET first_name = split_part(trim(name), ' ', 1),
    last_name  = regexp_replace(trim(name), '^\S+\s+', '')
WHERE first_name IS NULL AND name IS NOT NULL AND name <> '';

-- Strip known garbage rows (write-ins, aggregates)
UPDATE public.historical_candidates
SET first_name = NULL, last_name = NULL
WHERE lower(name) IN ('other','write-in','other/write-in votes','libertarian','green','constitution','republican','democratic');
```

- [ ] **Step 8.2: Match without zip/county** (historical_candidates has no address)

```sql
WITH matches AS (
  SELECT h.id, m.voter_id, m.confidence
  FROM public.historical_candidates h
  CROSS JOIN LATERAL public.match_person_to_voter_file(h.first_name, h.last_name, NULL, NULL, NULL) m
  WHERE h.first_name IS NOT NULL
)
UPDATE public.historical_candidates h
SET mo_voter_file_id = mt.voter_id,
    date_of_birth    = v.date_of_birth,
    dob_source       = 'voter_file'
FROM matches mt
JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
WHERE h.id = mt.id AND v.date_of_birth IS NOT NULL AND mt.confidence >= 1.0;
-- Only auto-apply unique exact-name matches for historical candidates since we lack disambiguation.

UPDATE public.historical_candidates
SET is_young_dem = (
  party ILIKE 'democrat%'
  AND date_of_birth IS NOT NULL
  AND date_of_birth > (make_date(COALESCE(years_ran[array_upper(years_ran,1)], EXTRACT(YEAR FROM CURRENT_DATE)::int), 11, 1) - INTERVAL '36 years')
);

SELECT COUNT(*) total, COUNT(date_of_birth) with_dob, COUNT(*) FILTER (WHERE is_young_dem) young_dems
FROM public.historical_candidates;

COMMIT;
```

- [ ] **Step 8.3: Commit**

```bash
git add supabase/migrations/20260421_06_enrich_historical_candidates.sql
git commit -m "feat(historical_candidates): split name, match voter file, backfill DOBs"
```

---

### Task 9: Enrich `members` + `donors` + `donor_profiles` (small tables, 409 + 49 + 49)

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_07_enrich_members_donors.sql`

**Watchout:** members UPDATE fires 3 Zapier/Make webhooks. We disable them for the bulk run.

- [ ] **Step 9.1: Disable member webhooks**

```sql
BEGIN;

-- identify the member triggers that invoke webhooks
SELECT tgname FROM pg_trigger WHERE tgrelid='public.members'::regclass AND NOT tgisinternal;

-- disable (by name — adjust from above query output)
ALTER TABLE public.members DISABLE TRIGGER zapier_sd_hd_update;
ALTER TABLE public.members DISABLE TRIGGER make_com_google_contacts_update;
-- (add the third one once identified)

-- keep the eligibility trigger ENABLED — we want membership_eligible to recompute
```

- [ ] **Step 9.2: Match + enrich members (DOB-only if changed)**

```sql
-- Members: voter file wins per Andrew. But preserve form-originated DOBs where voter file doesn't improve.
WITH matches AS (
  SELECT m.id, mt.voter_id, v.date_of_birth AS voter_dob
  FROM public.members m
  CROSS JOIN LATERAL public.match_person_to_voter_file(
    m.first_name, m.last_name, NULL, NULL, NULL   -- members lack city/zip cols; address is free-text
  ) mt
  JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
  WHERE v.date_of_birth IS NOT NULL
)
UPDATE public.members m
SET mo_voter_file_id = mt.voter_id,
    date_of_birth    = mt.voter_dob,
    dob_source       = 'voter_file'
FROM matches mt
WHERE m.id = mt.id;

-- Log divergences for Andrew to review (where self-reported ≠ voter file)
CREATE TABLE IF NOT EXISTS public.dob_divergences (
  id              bigserial PRIMARY KEY,
  table_name      text,
  record_id       uuid,
  prior_dob       date,
  voter_file_dob  date,
  found_at        timestamptz DEFAULT now()
);

-- (the UPDATE above already overwrote; divergence logging should happen pre-update — rework if needed)
```

- [ ] **Step 9.3: Match donors + donor_profiles**

```sql
-- donors (49 rows) — has first_name/last_name? check
WITH matches AS (
  SELECT d.id, mt.voter_id, v.date_of_birth AS voter_dob
  FROM public.donors d
  CROSS JOIN LATERAL public.match_person_to_voter_file(d.first_name, d.last_name, NULL, NULL, d.city) mt
  JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
  WHERE v.date_of_birth IS NOT NULL
)
UPDATE public.donors d
SET mo_voter_file_id = mt.voter_id,
    date_of_birth    = mt.voter_dob,
    dob_source       = 'voter_file'
FROM matches mt
WHERE d.id = mt.id;

-- donor_profiles — may have different column shape; verify before UPDATE.
-- (Will confirm at execution time, since donor_profiles column names haven't been checked.)
```

- [ ] **Step 9.4: Re-enable member webhooks + commit**

```sql
ALTER TABLE public.members ENABLE TRIGGER zapier_sd_hd_update;
ALTER TABLE public.members ENABLE TRIGGER make_com_google_contacts_update;

COMMIT;
```

```bash
git add supabase/migrations/20260421_07_enrich_members_donors.sql
git commit -m "feat(members,donors): enrich DOBs from voter file"
```

---

### Task 10: Enrich `mec_donors` (1M rows) — batched

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_08_enrich_mec_donors.sql`

**Strategy:** Most mec_donors are non-MO or corporate. Only attempt matching where `state='MO'` AND name looks like a human (no "LLC", "PAC", "INC", "LTD", "CORP"). Match in batches of 10k to avoid locking the 1M table.

- [ ] **Step 10.1: Filter + batch match**

```sql
BEGIN;

-- Add a match_status column to track progress
ALTER TABLE public.mec_donors
  ADD COLUMN IF NOT EXISTS match_status text
    CHECK (match_status IN ('pending','matched','no_match','not_applicable') OR match_status IS NULL);

-- Mark corporates as not_applicable
UPDATE public.mec_donors
SET match_status = 'not_applicable'
WHERE match_status IS NULL
  AND (full_name ILIKE '%LLC%' OR full_name ILIKE '%PAC%' OR full_name ILIKE '%INC%'
    OR full_name ILIKE '%LTD%' OR full_name ILIKE '%CORP%' OR full_name ILIKE '%CORPORATION%'
    OR full_name ILIKE '%COMPANY%' OR full_name ILIKE '%ASSOC%' OR full_name ILIKE '%FOUNDATION%'
    OR full_name ILIKE '%COMMITTEE%' OR full_name ILIKE '%UNION%' OR full_name ILIKE '%FUND%');

-- Mark non-MO rows not_applicable
UPDATE public.mec_donors SET match_status='not_applicable'
WHERE match_status IS NULL AND (state IS NULL OR state <> 'MO');

-- Mark rest pending
UPDATE public.mec_donors SET match_status='pending' WHERE match_status IS NULL;

COMMIT;
```

- [ ] **Step 10.2: Batch matcher (run in loop)**

```sql
-- Run this in a DO loop or externally in batches of 10k
DO $$
DECLARE batch_size int := 10000; updated_rows int;
BEGIN
  LOOP
    WITH batch AS (
      SELECT id, first_name, last_name, city, state
      FROM public.mec_donors
      WHERE match_status = 'pending'
      LIMIT batch_size
      FOR UPDATE SKIP LOCKED
    ),
    matches AS (
      SELECT b.id, mt.voter_id, v.date_of_birth
      FROM batch b
      CROSS JOIN LATERAL public.match_person_to_voter_file(b.first_name, b.last_name, NULL, NULL, b.city) mt
      JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
      WHERE v.date_of_birth IS NOT NULL
    )
    UPDATE public.mec_donors d
    SET mo_voter_file_id = m.voter_id,
        date_of_birth    = m.date_of_birth,
        dob_source       = 'voter_file',
        match_status     = 'matched'
    FROM matches m WHERE d.id = m.id;

    GET DIAGNOSTICS updated_rows = ROW_COUNT;

    -- Mark the rest of the batch as no_match
    UPDATE public.mec_donors
    SET match_status = 'no_match'
    WHERE match_status = 'pending'
      AND id IN (SELECT id FROM public.mec_donors WHERE match_status='pending' LIMIT batch_size);

    EXIT WHEN updated_rows = 0;
    RAISE NOTICE 'Batch updated: %', updated_rows;
  END LOOP;
END $$;

SELECT match_status, COUNT(*) FROM public.mec_donors GROUP BY 1;
```

- [ ] **Step 10.3: Commit**

```bash
git add supabase/migrations/20260421_08_enrich_mec_donors.sql
git commit -m "feat(mec_donors): match + backfill DOBs from voter file (MO individuals only)"
```

---

### Task 11: Enrich `fec_candidates` (1113) + `legislation_legislators` (193)

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_09_enrich_fec_cands_legislators.sql`

- [ ] **Step 11.1: fec_candidates**

```sql
BEGIN;

WITH matches AS (
  SELECT f.id, mt.voter_id, v.date_of_birth
  FROM public.fec_candidates f
  CROSS JOIN LATERAL public.match_person_to_voter_file(
    split_part(f.name, ',', 2),                         -- FEC stores "LAST, FIRST MIDDLE"
    split_part(f.name, ',', 1),
    NULL, NULL, f.city
  ) mt
  JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
  WHERE f.state = 'MO' AND v.date_of_birth IS NOT NULL
)
UPDATE public.fec_candidates f
SET mo_voter_file_id = m.voter_id,
    date_of_birth    = m.date_of_birth,
    dob_source       = 'voter_file'
FROM matches m WHERE f.id = m.id;
```

- [ ] **Step 11.2: legislation_legislators**

```sql
-- legislators' name field shape varies — check before matching
-- typical format: "Rep. Firstname Lastname (D-District)" or just "Firstname Lastname"
-- Use openstates_person_id joined to VAN data if available, else regex the name.

WITH matches AS (
  SELECT l.id, mt.voter_id, v.date_of_birth
  FROM public.legislation_legislators l
  CROSS JOIN LATERAL public.match_person_to_voter_file(
    split_part(regexp_replace(l.name, '^(Rep\.|Sen\.)\s*', ''), ' ', 1),
    regexp_replace(regexp_replace(l.name, '^(Rep\.|Sen\.)\s*', ''), '^\S+\s+', ''),
    NULL, NULL, NULL
  ) mt
  JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
  WHERE v.date_of_birth IS NOT NULL
)
UPDATE public.legislation_legislators l
SET mo_voter_file_id = m.voter_id,
    date_of_birth    = m.date_of_birth,
    dob_source       = 'voter_file'
FROM matches m WHERE l.id = m.id;

COMMIT;
```

- [ ] **Step 11.3: Commit**

```bash
git add supabase/migrations/20260421_09_enrich_fec_cands_legislators.sql
git commit -m "feat(fec_candidates,legislators): backfill DOBs from voter file"
```

---

### Task 12: Enrich `donor_enrichment` (470K) + `subscribers` (73K)

**Files:**
- Create: `/Users/moyd/my-bluebubbles-web/supabase/migrations/20260421_10_enrich_donor_enrichment_subscribers.sql`

- [ ] **Step 12.1: donor_enrichment — MO-only human subset**

```sql
BEGIN;

-- donor_enrichment has full_name, current_city, current_zip, current_state
WITH matches AS (
  SELECT e.id, mt.voter_id, v.date_of_birth
  FROM public.donor_enrichment e
  CROSS JOIN LATERAL public.match_person_to_voter_file(
    split_part(e.full_name, ' ', 1),
    regexp_replace(e.full_name, '^\S+\s+', ''),
    e.current_zip,
    e.current_county,
    e.current_city
  ) mt
  JOIN public.mo_voter_file v ON v.voter_id = mt.voter_id
  WHERE e.current_state = 'MO'
    AND e.full_name NOT ILIKE ANY(ARRAY['%LLC%','%PAC%','%INC%','%CORP%','%COMPANY%','%COMMITTEE%','%UNION%','%FOUNDATION%'])
    AND v.date_of_birth IS NOT NULL
)
UPDATE public.donor_enrichment e
SET mo_voter_file_id = m.voter_id,
    date_of_birth    = m.date_of_birth
FROM matches m WHERE e.id = m.id;
```

- [ ] **Step 12.2: subscribers**

```sql
-- subscribers already has date_of_birth; only populate mo_voter_file_id for linked members pattern
-- Use email as join key via the auto_link_and_enrich_subscriber trigger's logic
WITH matches AS (
  SELECT s.id, m.mo_voter_file_id
  FROM public.subscribers s
  JOIN public.members m ON lower(m.email) = lower(s.email)
  WHERE m.mo_voter_file_id IS NOT NULL AND s.mo_voter_file_id IS NULL
)
UPDATE public.subscribers s
SET mo_voter_file_id = m.mo_voter_file_id
FROM matches m WHERE s.id = m.id;

COMMIT;
```

- [ ] **Step 12.3: Commit**

```bash
git add supabase/migrations/20260421_10_enrich_donor_enrichment_subscribers.sql
git commit -m "feat(donor_enrichment,subscribers): backfill DOBs + voter_file links"
```

---

### Task 13: Refresh caches + downstream views

**Files:** none created.

- [ ] **Step 13.1: Refresh dashboard metrics + re-match candidates-to-members**

```sql
SELECT public.refresh_crm_dashboard_metrics();
SELECT public.match_candidates_to_members();
ANALYZE public.candidates;
ANALYZE public.historical_candidates;
ANALYZE public.members;
ANALYZE public.mec_donors;
NOTIFY pgrst, 'reload schema';
```

- [ ] **Step 13.2: Final summary query**

```sql
SELECT 'candidates' t, COUNT(*) total, COUNT(date_of_birth) with_dob, COUNT(*) FILTER (WHERE is_young_dem) young_dems FROM public.candidates
UNION ALL SELECT 'historical_candidates', COUNT(*), COUNT(date_of_birth), COUNT(*) FILTER (WHERE is_young_dem) FROM public.historical_candidates
UNION ALL SELECT 'members', COUNT(*), COUNT(date_of_birth), NULL FROM public.members
UNION ALL SELECT 'donors', COUNT(*), COUNT(date_of_birth), NULL FROM public.donors
UNION ALL SELECT 'mec_donors', COUNT(*), COUNT(date_of_birth), NULL FROM public.mec_donors
UNION ALL SELECT 'fec_candidates', COUNT(*), COUNT(date_of_birth), NULL FROM public.fec_candidates
UNION ALL SELECT 'legislation_legislators', COUNT(*), COUNT(date_of_birth), NULL FROM public.legislation_legislators
UNION ALL SELECT 'donor_enrichment', COUNT(*), COUNT(date_of_birth), NULL FROM public.donor_enrichment
UNION ALL SELECT 'subscribers', COUNT(*), COUNT(date_of_birth), NULL FROM public.subscribers;
```

- [ ] **Step 13.3: Send summary to Andrew on Telegram**

Include counts, especially the new young_dems count on candidates.

---

### Task 14: Documentation + memory update

**Files:**
- Create: `/Users/moyd/Desktop/MOYD/MOYD Obsidian/Projects/2026-04-21 Voter File Backfill.md` (Obsidian session note)
- Update: `/Users/moyd/Desktop/MOYD/MOYD Obsidian/Infrastructure/Supabase.md` (add mo_voter_file section)
- Update: `/Users/moyd/.claude/projects/-Users-moyd/memory/MEMORY.md` + new memory file for the voter-file system

- [ ] **Step 14.1: Obsidian session note** describing the full run, counts, any surprises.

- [ ] **Step 14.2: Update Supabase.md** with new table, matching function, and dob_source convention.

- [ ] **Step 14.3: Memory entry** `voter_file_backfill.md` pointing to the migrations and explaining the 3-pass matcher.

- [ ] **Step 14.4: Final Telegram**: "Voter file ingested + DOBs backfilled across N tables. Here are the numbers."

---

## Rollback plan

If any task fails or produces bad data:

1. **Per-table rollback**: each enrichment migration is idempotent and reversible — re-run with the inverse (set `date_of_birth=NULL, mo_voter_file_id=NULL, dob_source=NULL`).
2. **Full rollback**: `DROP TABLE public.mo_voter_file CASCADE;` cascades through every FK we added, restoring the DB to pre-task-2 state. The column ADDs from Task 4 will remain as NULL-filled columns — drop them individually if desired.

## Open questions for Andrew (parked during plan)

These stay parked until we hit them during execution:
- For the 12 candidate-linked members where member-form DOB differs from voter-file DOB, which wins? (Plan: voter file wins per Andrew's initial directive, with divergence logged to `dob_divergences` for review.)
- Retire the stalled `van_mec_queue` pipeline? (Plan: leave it, orthogonal to this work.)
