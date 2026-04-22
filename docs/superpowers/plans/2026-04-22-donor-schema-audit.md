# MOYD Donor Schema Audit — Comprehensive Map

_Generated 2026-04-22. Supabase project `faajpcarasilbfndzkmd`, `public` schema. Read-only audit._

Everything in this report comes from live DB introspection plus cross-reference to
`lib/` usage and sibling plan `2026-04-21-donor-ui-current-state.md`.

## TL;DR category map

| Category | Primary table(s) | PK / canonical id | RPCs to use | Row count | Purpose in UI |
|---|---|---|---|---|---|
| **MOYD's Donors** (people who gave TO MOYD) | `donors`, `donations`, `donation_thank_yous` | `donors.id` (UUID) | `get_donor_profile_full(p_profile_id uuid)` via `donor_profiles` | 49 / 118 / 58 | Fundraising tab, donor detail, thank-you workflow |
| **MOYD Extended Profile** (CRM overlay onto MOYD donors) | `donor_profiles` + `donor_tags` + `donor_activity_log` + `donor_call_outcomes` | `donor_profiles.id` (UUID) | `get_donor_profile_full`, `search_donor_profiles`, `find_donor_profile_by_mec_id` | 49 / 0 / 0 / 0 | Call-time list, 6-tab `DonorProfileScreen`, planned prospect features |
| **MEC Research Donors** (gave to MO campaigns) | `mec_donors` + `mec_contributions` + `mec_committees` | `mec_donors.id` (bigint) | `search_donors_v3`, `get_donor_unified_profile(int)`, `get_donor_profile_by_natural_key`, `get_mec_top_donors`, `get_committee_donors_paginated` | 1.02M / 3.18M / 15.4k | Donor Research tab, MECDonorScreen, Candidate Money tab |
| **FEC Research Donors** (gave to federal campaigns) | `fec_contributions` + `fec_committees` + `fec_candidates` | `fec_contributions.sub_id`; donor roll-up via `mec_donors.id` | `get_donor_unified_profile`, `get_fec_top_donors` | 1.76M / 3.2k / 1.1k | Federal cross-reference in unified profile, FEC stats in MEC research |
| **Unified research identity** | `mec_donors` (same `id` used as `donor_id` in both `mec_contributions` and `fec_contributions`) | `mec_donors.id` | `get_donor_unified_profile(int)` | 210 rows flagged `sources @> {'mec','fec'}`, 27,377 via join | True cross-source totals |
| **Enrichment** (external data attached to research donors) | `donor_enrichment`, `donor_contacts` | `donor_enrichment.donor_id` → `mec_donors.id`; `donor_contacts.donor_id` → `mec_donors.id` | Join in profile RPCs | 470k / 10.5M | Hero badges, voter-file section, phone/email lookup |
| **VAN-MEC matching pipeline** | `van_mec_queue`, `van_mec_donor_parties` | `van_mec_queue.id` / composite | None (internal worker) | 77.5k / 49.7k | Backend matching job; not directly in UI |
| **Lookups / aggregates** | `donor_zip5_lookup` | `zip5` | Read directly | 24.6k | Geographic density for maps/filters |
| **Compliance filing** | `mec_reports`, `mec_historical_filings`, `mec_expenditures`, `mec_large_contributions`, `mec_financial_summaries`, `mec_independent_expenditures` | `mec_reports.id` / `mec_historical_filings.id` | Direct | 1 / 16 / 702k / 0 / 0 / 0 | Quarterly CD1A/CD3B report generation |

## Row counts (verified live)

```
 donation_thank_yous          |       58
 donations                    |      118
 donor_activity_log           |        0
 donor_call_outcomes          |        0
 donor_contacts               | 10,496,969
 donor_enrichment             |    470,277
 donor_profiles               |       49
 donor_tags                   |        0
 donor_zip5_lookup            |     24,652
 donors                       |       49
 fec_candidates               |      1,113
 fec_committees               |      3,223
 fec_contributions            |  1,763,506
 mec_committees               |     15,404
 mec_contributions            |  3,180,931
 mec_donors                   |  1,022,008
 mec_expenditures             |    702,133
 mec_financial_summaries      |        0
 mec_historical_filings       |       16
 mec_independent_expenditures |        0
 mec_large_contributions      |        0
 mec_reports                  |        1
 van_mec_donor_parties        |     49,693
 van_mec_queue                |     77,498
```

Most-recent write timestamps:
```
 mec_committees      | 2026-04-20 11:03
 mec_contributions   | 2026-04-18 16:14
 donations           | 2026-04-11 00:00
 fec_committees      | 2026-04-04 22:25
 fec_candidates      | 2026-04-04 22:25
 donor_profiles      | 2026-03-25 13:28
 donor_contacts      | 2026-03-17 00:31
 mec_donors          | 2026-03-09 20:36
 donor_enrichment    | 2026-02-26 15:56
 fec_contributions   | 2026-02-25 17:49
 van_mec_queue       | 2026-02-25 13:12
 donors              | 2026-02-16 00:00
 donation_thank_yous | 2025-12-20 05:03
```

---

## Per-table detail

### MOYD's Donors

#### `public.donors` — 49 rows
- **Purpose:** MOYD's actual donor ledger — the 49 people who have donated to MOYD directly (usually ActBlue, some check).
- **PK:** `id UUID`. Unique constraints: `email`, `actblue_entity_id`.
- **Key columns:** `name`, `email`, `phone_e164`, `address/city/state/zip_code`, `total_donated`, `donation_count`, `first_donation_date`, `last_donation_date`, `employer`, `occupation`, `member_id` (FK to `members`), `mo_voter_file_id` (FK to `mo_voter_file`), `date_of_birth`, `birth_year`, `dob_source`.
- **FK in:** `member_id → members.id`, `mo_voter_file_id → mo_voter_file.voter_id`.
- **FK referenced by:** `donations.donor_id`, `hanaway_campaign_tracking.donor_id`, `subscribers.donor_id`, and indirectly by `donor_profiles.donor_id` (no hard FK—soft link).
- **Triggers (many):** auto-link to members on insert, auto-create subscriber, sync to knowledge base, refresh dashboard metrics, populate geography, update `updated_at`.
- **Active?** Yes — rows added as recently as 2026-02-16, donations through 2026-04-10.
- **Quality:** Of 49 rows, **0 have `actblue_entity_id` populated** (all NULL) despite the unique constraint — odd; ActBlue IDs live on `donations.actblue_contribution_id` (113/118 present). 45 of 49 are not linked to a `members.id`.

#### `public.donations` — 118 rows
- **Purpose:** Individual gift records received by MOYD.
- **PK:** `id UUID`. Unique: `actblue_contribution_id`.
- **Key columns:** `donor_id` (FK → `donors`), `amount`, `donation_date`, `status`, `payment_method`, `recurring`, `designation`, `campaign`, `actblue_contribution_id`, `actblue_order_number`, `check_number`, `event_id`, `sent_thank_you`, `actblue_raw_data`.
- **Triggers:** `trigger_update_donor_totals` (rolls up totals to `donors`), knowledge sync, dashboard metrics refresh.
- **Active?** Yes — most recent donation 2026-04-10. Sum = $4,431.
- **Quality:** Clean. 5 of 118 lack an `actblue_contribution_id` (likely check-based).

#### `public.donation_thank_yous` — 58 rows
- **Purpose:** Log of thank-you messages sent (email/text/card) per donation.
- **PK:** `id UUID`. Unique on `(donation_id, method)`.
- **FK:** `donation_id → donations.id`.
- **Trigger:** `trigger_update_thank_you_status` (flips `donations.sent_thank_you` bool).
- **Active?** Last row 2025-12-20 — slightly stale relative to donations.

---

### MOYD Extended Profile (CRM overlay)

#### `public.donor_profiles` — 49 rows
- **Purpose:** CRM-level richer profile per person MOYD tracks as a prospect/donor. 1:1 with `donors` today (49 rows, all have `donor_id` set), but _also_ carries pointers to research identities (`mec_donor_id`, `van_id`).
- **PK:** `id UUID`.
- **Key columns:** `donor_id` (→ `donors`, soft), `mec_donor_id` (→ `mec_donors`, soft), `van_id` (→ `van_voters`, soft), `member_id`, `display_name`, contact fields, `total_donated_moyd`, `total_donated_political`, `donor_tier`, `giving_capacity`, `wealth_score`, `party_lean`, `has_*` coverage flags.
- **FK in:** `mo_voter_file_id → mo_voter_file.voter_id`. **No hard FKs** to `donors` / `mec_donors` / `van_voters`.
- **FK referenced by:** `donor_activity_log.profile_id`, `donor_call_outcomes.profile_id`, `donor_tags.profile_id`.
- **Active?** Yes — last row 2026-03-25.
- **Quality:** All 49 have both `donor_id` and `mec_donor_id`. `van_id` is 0/49 — VAN link is planned but unpopulated.

#### `public.donor_tags` — 0 rows
- Empty. Schema: `profile_id + tag_name` unique. Not yet used.

#### `public.donor_activity_log` — 0 rows
- Empty. Schema: timeline entries for prospect outreach. Referenced by `get_donor_profile_full` but nothing writes to it yet.

#### `public.donor_call_outcomes` — 0 rows
- Empty. Schema: pledge/call-time call results linked to `call_time_list_items`. Referenced by `get_donor_profile_full`; back-end integration for Call Time workflow pending.

---

### MEC Research Donors

#### `public.mec_donors` — 1,022,008 rows
- **Purpose:** Aggregated donor entities reconstructed from scraped Missouri Ethics Commission + FEC filings. One row = one unique donor (individual / company / committee) across MO political giving.
- **PK:** `id BIGINT`. `match_key` unique (when not null) for dedup.
- **Key columns:** `donor_type` (`individual`/`company`/`committee`), `last_name`, `first_name`, `company_name`, `committee_name`, `address1`, `city`, `state`, `zip`, `employer`, `occupation`, `total_contributed`, `contribution_count`, `fec_contribution_count`, `fec_total_contributed`, `sources` (text[] of `mec`/`fec`), `committees_donated_to` (jsonb), `mo_voter_file_id`, `birth_year`, `date_of_birth`, `match_status`, `match_confidence`.
- **Breakdown:** 499,146 individuals; 152,594 companies; 370,268 committees.
- **FK referenced by:** `mec_contributions.donor_id`, `fec_contributions.donor_id`, `donor_enrichment.donor_id`, `call_time_list_items.donor_id`, `mo_business_entities.donor_id`.
- **Active?** Yes (last update 2026-03-09).
- **Quality:**
  - 238,109 rows have junk `last_name` values (`#N/A`, `N/A`, `NULL`, `UNKNOWN`, empty string). Worth filtering in UI.
  - **`sources` is unpopulated for 706,195 of 1.02M rows** (empty array). Only 238,749 flagged `mec`; 76,854 flagged `fec`; only 210 flagged both. Do not rely on `sources` to decide category; use `EXISTS` against the contribution tables instead.
  - 211,127 rows have `mo_voter_file_id` (≈20.7% voter-file match rate).
  - Top individual donor is Rex Sinquefield ($82.8M) — two separate rows ("Rex" and "Rex and Jeanne") point to the same voter_file_id — duplicate entity problem to flag.

#### `public.mec_contributions` — 3,180,931 rows
- **Purpose:** Raw individual MEC contribution receipts (one row per gift).
- **PK:** `id BIGINT`. Dedup uniq on `(mec_id, contribution_date, contribution_amount, contributor_last_name, contributor_first_name, contributor_company, contributor_committee, report_type)`.
- **Key columns:** `mec_id` (committee), `committee_name`, `contributor_last_name/first_name/company/committee`, `address1/city/state/zip`, `employer`, `occupation`, `contribution_date`, `contribution_amount`, `monetary_or_inkind`, `filing_year`, `donor_id` (→ `mec_donors`).
- **Quality:** 634,388 rows have `donor_id IS NULL` (≈20%). The codebase plan document flags that the FK is ~96% unreliable in practice, which matches the "use natural-key lookup" pattern in `MECDonorScreen`.

#### `public.mec_committees` — 15,404 rows
- **Purpose:** MO Ethics Commission committee registry (candidate committees, PACs, etc.).
- **PK:** `id BIGINT`. Unique: `mec_id`.
- **Key columns:** `mec_id`, `committee_name`, `committee_type`, `committee_status`, `candidate_name`, `party_affiliation`, `party_classification`, `treasurer_name`, `election_history` (jsonb).
- **Active?** Yes (most recent update 2026-04-20).

#### `public.mec_expenditures` — 702,133 rows
- **Purpose:** Committee spending (not donors).
- **PK:** `id BIGINT`. No unique beyond PK.
- **Key columns:** `mec_id`, `payee_last_name/first_name/company`, `expenditure_date`, `expenditure_amount`, `expenditure_purpose`, `filing_year`.
- **Active?** Yes.

#### `public.mec_large_contributions` — 0 rows
- **Purpose (planned):** 48-hour large-contribution reports (>$5k). Empty today.

#### `public.mec_independent_expenditures` — 0 rows
- **Purpose (planned):** Independent expenditure filings. Empty today.

#### `public.mec_financial_summaries` — 0 rows
- **Purpose (planned):** Committee aggregate summaries. Empty today.

#### `public.mec_historical_filings` — 16 rows
- **Purpose:** Pointers to scraped MEC filing PDFs (bucket + storage_path).
- **Key columns:** `committee_mec_id`, `filing_type`, `period_start`/`end`, `quarter`, `total_contributions`, `total_expenditures`, `storage_bucket`, `storage_path`, `source_url`, `raw_text`.
- **Quality:** Contribution totals not yet backfilled in existing rows.

#### `public.mec_reports` — 1 row
- **Purpose:** MOYD's **own** quarterly MEC compliance report metadata (status, CD1A/CD3B CSV URLs, totals).
- **Key columns:** `quarter`, `period_start/end`, `filing_deadline`, `status`, `total_contributions`, `cd1a_csv_url`, `cd3b_csv_url`.
- **Current:** Single row for 2026-Q1, status `ready`, generated by edge-function 2026-04-14.

---

### FEC Research Donors

#### `public.fec_candidates` — 1,113 rows
- **Purpose:** Federal candidate registry (cand_id, party, office, etc.).
- **PK:** `id BIGINT`. Unique: `(cand_id, election_year)`.
- **Key columns:** `cand_id`, `cand_name`, `party`, `election_year`, `office`, `office_state`, `office_district`, `principal_committee_id`, `mo_voter_file_id`, `first_name`, `last_name`.

#### `public.fec_committees` — 3,223 rows
- **Purpose:** Federal committee registry (PACs, campaign committees).
- **PK:** `id BIGINT`. Unique: `(cmte_id, cycle)`.
- **Key columns:** `cmte_id`, `cmte_name`, `cmte_type`, `party`, `cand_id`, `treasurer_name`, `cycle`.

#### `public.fec_contributions` — 1,763,506 rows
- **Purpose:** Individual federal contribution receipts.
- **PK:** `id BIGINT`. Unique: `sub_id` (FEC's unique transaction id).
- **Key columns:** `cmte_id`, `committee_name`, `contributor_name`, `parsed_first_name`, `parsed_last_name`, `city`, `state`, `zip`, `employer`, `occupation`, `transaction_date`, `transaction_amount`, `transaction_tp`, `entity_tp`, `is_pac_contribution`, `cycle`, `donor_id` (→ `mec_donors`).
- **FK:** `donor_id → mec_donors.id` — **this is the bridge between FEC and MEC donors**. 1,402,024 of 1,763,506 rows (≈79.5%) are linked; 361,482 unlinked.
- **Quality:** Linkage rate better than MEC contributions. Unique donor count on the FK side: 201,445 distinct `mec_donors.id`.

---

### Enrichment & contact data

#### `public.donor_enrichment` — 470,277 rows
- **Purpose:** External-source enrichment (clustrmaps, dehashed, NPI, voter-file derivations, census tract, wealth scoring, etc.) keyed to a `mec_donors.id`.
- **PK:** `id BIGINT`. Unique: `donor_id` (1:1 with `mec_donors`).
- **FK:** `donor_id → mec_donors.id`, `mo_voter_file_id → mo_voter_file.voter_id`.
- **~150 columns** spanning identity / address / phones / emails / property / wealth / voter registration / donation pattern / census-tract context. See `donor_enrichment` section of `2026-04-21-donor-ui-current-state.md` for the UI-relevant subset.
- **Coverage:** 388,008 of 1,022,008 `mec_donors` have enrichment (~38%). **82,269 enrichment rows orphaned** (their `donor_id` doesn't match any current `mec_donors.id`) — cleanup opportunity.

#### `public.donor_contacts` — 10,496,969 rows
- **Purpose:** Raw contact-info lookups per research donor (one row per phone/email/fax evidence), with source/confidence context.
- **PK:** `id INTEGER`. Unique: `(donor_id, contact_type, contact_value)`.
- **Key columns:** `donor_id` (INTEGER, **not FK-enforced** but corresponds to `mec_donors.id`), `donor_name`, `source`, `contact_type` (phone/email/fax/none), `contact_value`, `confidence`, `context`, `raw_data`.
- **Sources:** `clustrmaps` 7.5M, `addresses_com` 1.3M, `permutation` 534k, `dehashed` 429k, `phonebook` 196k, `anywho` 160k, `thatsthem` 136k, `gravatar` 101k, `mo_employee` 51k, `email_permutation` 44k, `npi` 36k, `spotify` 12k, `irs_990` 7k, `mo_bar` 5k, others.
- **Types:** phone 9.5M, email 931k, fax 13k, `none` 65k (404/no-result markers).
- **Quality:** 65k `contact_type='none'` rows are "no_results_404" sentinels from thatsthem/dehashed probes — filter these out in UI contact lists.
- **Not FK-enforced:** `donor_id` is an INTEGER (not BIGINT) with no foreign key — risk of stale rows if `mec_donors.id` exceeds INT range (not today, max is under 2.1B).

---

### VAN matching pipeline

#### `public.van_mec_queue` — 77,498 rows
- **Purpose:** Worker queue used to match MEC donor names against the VAN voter file.
- **PK:** `id INTEGER`. Unique: `(lower(last_name), lower(first_name), lower(city))`.
- **Key columns:** `last_name`, `first_name`, `city`, `state`, `total_given`, `van_id` (→ `van_voters.van_id`), `match_status` (pending/matched/no_match), `match_confidence`, `donor_party`, `processed_at`, `error_message`.
- **Not in UI.** Internal matching infra only.

#### `public.van_mec_donor_parties` — 49,693 rows
- **Purpose:** Cached party-totals-by-person (rolled-up from MEC+VAN) used to assign a donor's likely party lean.
- **PK:** composite `(last_name, first_name, city, party)`.
- **Key columns:** `total_to_party`.
- **Not in UI directly.**

---

### Lookups & aggregates

#### `public.donor_zip5_lookup` — 24,652 rows
- **Purpose:** Donor density by ZIP5 (likely pre-aggregated for map/choropleth rendering).
- **PK:** `zip5`. Fields: `state`, `donor_count`.
- **Top entries** are expected MO affluent zips (63105, 65203, 63131…).

---

## Canonical identity paths

### Path 1 — MOYD's Donors
```
donors.id (UUID)
  ← donations.donor_id
  ← donation_thank_yous (via donation_id → donations.id)
  ← donor_profiles.donor_id  (soft link; 1:1 today)
  → mo_voter_file.voter_id   (via donors.mo_voter_file_id)
  → members.id               (via donors.member_id)
```

### Path 2 — MOYD Extended Profile (CRM)
```
donor_profiles.id (UUID)
  → donors.id        (donor_id, soft)
  → mec_donors.id    (mec_donor_id, soft; all 49 linked today)
  → van_voters.van_id (van_id, soft; 0/49 populated)
  ← donor_tags.profile_id (HARD FK)
  ← donor_activity_log.profile_id (HARD FK)
  ← donor_call_outcomes.profile_id (HARD FK)
```

### Path 3 — MEC / FEC Research (unified under `mec_donors`)
```
mec_donors.id (BIGINT)  ← THE canonical research-donor id
  ← mec_contributions.donor_id      (~80% linked)
  ← fec_contributions.donor_id      (~79.5% linked)
  ← donor_enrichment.donor_id       (1:1 when enriched; ~38% coverage)
  ← call_time_list_items.donor_id
  ← mo_business_entities.donor_id
  → mo_voter_file.voter_id          (via mec_donors.mo_voter_file_id; ~20.7%)
```

**"Unified research entity" ≡ the single `mec_donors` row** that holds both MEC and FEC
contribution children. True cross-source donors today:
- 27,377 `mec_donors` have both `fec_contribution_count > 0` **and** `contribution_count > 0`
- but only 210 rows carry the `sources = {mec,fec}` tag. The `sources` field is stale/unreliable — compute from the child tables instead.

### Bridge `donors` ↔ `mec_donors`
There is **no direct FK**. Today the only bridge is `donor_profiles.donor_id`
(UUID → `donors.id`) + `donor_profiles.mec_donor_id` (int → `mec_donors.id`),
set manually/semi-automatically. All 49 `donor_profiles` rows have both sides populated.

---

## RPCs (donor-related)

| RPC | Args | Returns | Reads from | Used for |
|---|---|---|---|---|
| `search_donors_v3` | 21 params incl. `p_name_query, p_state, p_city, p_zip, p_year_from, p_year_to, p_min_total, p_max_total, p_party, p_employer, p_occupation, p_gender, p_age_min/max, p_has_phone, p_has_email, p_is_homeowner, p_individuals_only, p_source, p_limit, p_offset` | setof rows | `mec_donors` + `donor_enrichment` (joined), filtered by `mec/fec/both` via `p_source` | MEC Research tab search. **NB: two overloads exist (21-arg each, different param order).** The one used from `MecRepository.searchDonorsUnified` passes `p_name_query` first. |
| `search_donors_v2` | similar minus `p_source` | setof | `mec_donors`+`donor_enrichment` | Legacy — prefer v3. |
| `search_donors` | 10 params | setof | `mec_donors` | Legacy. |
| `search_donor_profiles` | `search_query, filter_tier/party/county/cd, filter_min/max_donated, filter_min/max_wealth, filter_has_enrichment/has_van, sort_by, sort_dir, page_num, page_size` | setof | `donor_profiles` (CRM table, 49 rows) | Planned: CRM prospect search |
| `get_donor_unified_profile` | `p_donor_id integer` (→ `mec_donors.id`) | `jsonb` | `mec_donors` + `mec_contributions` + `fec_contributions` (top 200 each by amount) + `donor_enrichment` + roll-up committee lists + linked `donor_profiles.id` | **Preferred** for viewing a research donor (used by MecResearchTab profile mode). |
| `get_donor_profile_by_natural_key` | `p_first_name, p_last_name, p_city, p_state` | `json` | `mec_contributions` aggregated + `mec_donors` identity + `donor_enrichment` joined by name match | Used by `MECDonorScreen` (reached from Candidate Money tab). Recently extended (migration `20260421_17_extend_donor_profile_rpc.sql`) to include enrichment + voter-file ids. |
| `get_donor_profile_full` | `p_profile_id uuid` (→ `donor_profiles.id`) | `jsonb` | `donor_profiles` + `donations` + `donation_thank_yous` + `mec_contributions` + `fec_contributions` + `donor_enrichment` + `sec_insider_filings` + `property_records` + `casenet_records` + `mo_business_entities` + `van_voters` + `van_voting_history` + `van_scores` + `donor_tags` + `donor_activity_log` + `donor_call_outcomes` + `census_zip_data` + `zillow_zip_data` | **Full 360° view** for a MOYD extended profile. Used by `DonorProfileScreen`. |
| `find_donor_profile_by_mec_id` | `p_mec_donor_id integer` | `text` (UUID) | `donor_profiles` | Reverse lookup: "does MEC donor N have a MOYD CRM profile?" |
| `get_donor_candidates` | `p_donor_id integer` | setof | `mec_contributions` × `candidates.mec_committee_ids` | "Which candidates has this donor supported?" |
| `get_donor_mec_contributions` | `p_donor_id integer, p_limit` | setof | `mec_contributions` | Simple pagination of MEC gifts for a donor. |
| `get_committee_donors_paginated` | `p_mec_id, p_limit, p_offset, p_sort_by, p_ascending` | setof | `mec_contributions` grouped by donor | "Top donors to committee X". |
| `get_mec_top_donors` / `get_mec_top_donors_multi` | `p_mec_id[s], p_limit` | setof | `mec_contributions` | Candidate Money tab top-donor list. |
| `get_fec_top_donors` | `p_fec_cand_id, p_limit` | setof | `fec_contributions` via committee | Federal candidate top-donor list. |
| `get_donor_profile_stats` | none | `jsonb` | `donor_profiles` | Dashboard KPIs for MOYD prospects. |
| `get_donors_filtered` / `count_donors_filtered` | `p_congressional_districts, p_counties` | setof / int | `donors` | MOYD-donor list filter. |
| `count_donors_missing_county` | none | int | `donors` | Data quality probe. |
| `get_distinct_donor_zips` | `mo_only bool` | setof | `donors` | Map filter. |
| `is_member_donor` | `member_uuid` | bool | `donors` via `member_id` | Show "donor" badge on member rows. |

Internal triggers (not RPCs): `auto_create_subscriber_from_donor`, `auto_link_donor_to_member`, `sync_donor_to_subscribers`, `update_donor_totals`, `trigger_populate_donor_geography`, `bulk_sync_donors`, `enrich_donors_from_census`.

---

## Which RPC should each UI surface call?

| UI context | Table the user is thinking about | Call this RPC |
|---|---|---|
| MOYD fundraising dashboard totals | `donations` / `donors` | `get_donor_profile_stats` + direct table reads |
| MOYD donor list (49 people) | `donors` | `get_donors_filtered` / direct `donors` select |
| MOYD donor detail (thank-you / gift history) | `donors` + `donations` | direct or `get_donor_profile_full(profile_id)` when a `donor_profiles` exists |
| MOYD prospect CRM card (the 6-tab view) | `donor_profiles` | `get_donor_profile_full(p_profile_id uuid)` |
| MEC Research tab search | `mec_donors` | `search_donors_v3` with `p_source='mec'` or `'both'` |
| MEC Research tab profile | `mec_donors` | **`get_donor_unified_profile(p_donor_id int)`** (preferred) |
| Candidate Money tab → donor row | `mec_donors` via natural key | `get_donor_profile_by_natural_key` (recently extended with enrichment) |
| Candidate Money tab → top donors list | `mec_contributions` | `get_mec_top_donors` / `get_mec_top_donors_multi` |
| Committee detail → top donors list | `mec_contributions` | `get_committee_donors_paginated` |
| Federal candidate top donors | `fec_contributions` | `get_fec_top_donors` |
| "Which candidates did this donor give to?" | `mec_contributions × candidates` | `get_donor_candidates` |
| Research → is this person a MOYD prospect? | `donor_profiles` | `find_donor_profile_by_mec_id(mec_donor_id)` |

---

## Data-integrity issues worth flagging

1. **`mec_donors.sources` is stale/unreliable.** 706k of 1.02M rows have empty `sources[]` yet 2.5M MEC contributions + 1.4M FEC contributions are linked to them. Recompute from child tables or drop the column.
2. **`mec_contributions.donor_id` is unpopulated for ~20% (634k) and unreliable for another ~76% per code comment.** Natural-key lookup is the working fallback. Plan a re-matching pass.
3. **238k `mec_donors` rows have junk last names** (`#N/A`, `N/A`, `NULL`, `UNKNOWN`, empty). Filter in UI; consider hard-deleting non-committee junk.
4. **Duplicate donor entities** exist in `mec_donors`: e.g. "Rex Sinquefield" and "Rex and Jeanne Sinquefield" are two rows with the same `mo_voter_file_id`. Needs a merge strategy before "unified profile" is trustworthy.
5. **82,269 `donor_enrichment` rows are orphaned** — their `donor_id` no longer matches any current `mec_donors.id`. Clean-up task.
6. **`donors.actblue_entity_id` is NULL for all 49 rows** despite a unique constraint + dedicated index. The ActBlue identity lives on `donations.actblue_contribution_id` (113/118). Either backfill `donors.actblue_entity_id` or drop the column.
7. **`donor_contacts.donor_id` is not FK-enforced** (plain INTEGER). Some orphan potential. The table also carries 65k "no_results_404" sentinel rows (`contact_type='none'`) — filter from UI.
8. **`donor_profiles.van_id` is 0/49 populated.** The planned VAN linkage is entirely absent today despite the column + index existing.
9. **Empty tables with schema but no data:** `donor_tags`, `donor_activity_log`, `donor_call_outcomes`, `mec_large_contributions`, `mec_independent_expenditures`, `mec_financial_summaries`. Either backfill when features ship or remove from schema.
10. **`mec_historical_filings` has 16 rows but no financial totals populated** — only the CO1 / quarterly PDFs pointers. PDF parsing pipeline not yet wired in.
11. **45 of 49 `donors` rows have `member_id` NULL.** The `trigger_auto_link_donor_to_member` is not firing matches — email/name mismatch between `donors` and `members`.
12. **No hard FK between `donor_profiles` and `donors` / `mec_donors` / `van_voters`.** All three pointers are soft integers/UUIDs. Add FKs (or at least CHECK) to prevent drift.
13. **Two `search_donors_v3` overloads** with the same 21 param count but different positional order. PostgREST will pick one based on arg names; Dart callers that pass positionally will silently bind to the "wrong" overload. Drop the older one.

---

## Clean donor categorization for UI

### "MOYD's Donors" (people who donated TO MOYD)
- Authoritative table: **`donors`** (49 rows).
- Gift history: **`donations`** (118 rows).
- Extended CRM overlay when present: **`donor_profiles`** (49 rows, 1:1 with `donors` today via `donor_profiles.donor_id`).
- Surface in UI: Fundraising tab, MOYD Donor Detail, thank-you workflow, member profile linked-donor card.

### "MEC Research Donors" (donated to any MO committee)
- Authoritative entity: **`mec_donors`** where at least one row exists in `mec_contributions` with `donor_id = mec_donors.id`.
- Raw gifts: **`mec_contributions`**.
- Enrichment: **`donor_enrichment`** joined on `donor_id`.
- Surface in UI: "Donor Research" tab, MECDonorScreen, Candidate Money tab.

### "FEC Research Donors" (donated to federal campaigns)
- Authoritative entity: same **`mec_donors`** rows — but filtered by having at least one row in `fec_contributions` with `donor_id = mec_donors.id`. `mec_donors` is the unified identity table; it was named "mec" before FEC was folded in.
- Raw gifts: **`fec_contributions`**.
- Committees: **`fec_committees`** + **`fec_candidates`**.

### "Unified research entities" (same person across MEC + FEC)
- Expected: a single `mec_donors` row carries both types of gifts → sum via `get_donor_unified_profile`.
- Current state:
  - 27,377 rows have activity in **both** `mec_contributions` (linked) **and** `fec_contributions` (linked).
  - Only 210 rows tagged `sources = {mec,fec}` — tag is unreliable.
  - ~38% of research donors have `donor_enrichment`.
  - ~20.7% have a voter-file match (`mo_voter_file_id`).
  - Duplicate identities (Sinquefield case) still leak through — real unique count is lower than `mec_donors.id` count suggests.

### Research-donor → MOYD-donor bridge
- Only via `donor_profiles.mec_donor_id` (49 curated rows today). There is no automatic bridge; `find_donor_profile_by_mec_id` is how UI checks if a research donor already has a MOYD CRM profile.

---

## References

- Code-side usage and UI screens: `docs/superpowers/plans/2026-04-21-donor-ui-current-state.md`.
- Earlier unification plan: `docs/plans/2026-02-25-mec-fec-unification-plan.md`.
- Donors-page redesign plan: `docs/plans/2026-02-25-donors-page-redesign.md`.
- Recent RPC extension: `supabase/migrations/20260421_17_extend_donor_profile_rpc.sql`.
- Repository classes:
  - `lib/services/crm/donor_repository.dart` (MOYD donors)
  - `lib/services/crm/donor_profile_repository.dart` (donor_profiles CRM)
  - `lib/services/crm/mec_repository.dart` (research donors)
