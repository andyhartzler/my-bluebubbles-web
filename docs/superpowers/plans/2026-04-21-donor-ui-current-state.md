# Donor UI Current State — Investigation Findings

_Generated 2026-04-21 by code-explorer agent. Read-only, no code modified._

## Route maps

### Entry Point A: CRM Donors page → Donor Research tab → click donor row

`DonorsListScreen` (`lib/screens/crm/donors_list_screen.dart:9`) hosts a 4-tab TabBar:
- Tab 0: Fundraising (`FundraisingTab`)
- Tab 1: **Donor Research** (`MecResearchTab`) — entry point
- Tab 2: Call Time
- Tab 3: Committees

In `MecResearchTab` (`lib/screens/crm/tabs/mec_research_tab.dart`):
- Search → `MecRepository.searchDonorsUnified()` → RPC `search_donors_v3` → aggregated rows from `mec_donors` + FEC data + enrichment fields.
- Tap donor card → `_openProfileFromDonor()` (line 180) → switches the tab into **profile mode** via `_buildProfileMode()` (line 1000). NOT a new screen push; state swap within same widget.
- Profile mode calls either `MecRepository.getDonorUnifiedProfile(donorId)` (RPC `get_donor_unified_profile`) or falls back to `getContributorProfile() + getDonorEnrichment()`.
- Renders: header card with enrichment badges, enrichment sections (address/contact/employment/political), MEC contributions, FEC contributions.

### Entry Point B: CRM Candidates → candidate → Money tab → click donor row

`CandidateDetailScreen` (`lib/screens/crm/candidate_detail_screen.dart`) Tab 2 is `_buildMoneyTab()`.

- `_loadFinanceData()` uses `CandidateRepository` to fetch `_topDonors`, `_mecContributions`, `_contributionTimeline`, `_financeSummary`.
- Tap top-donor row (line 2192) or contribution row (line 2304) → `_openDonorProfileByKey()` (line 402) → pushes `MECDonorScreen`.
- `MECDonorScreen` calls RPC `get_donor_profile_by_natural_key` directly via `_supabase.privilegedClient.rpc()` (line 56) — NOT through `MecRepository`.
- Renders: hero stat chips (total given, gift count, committees, candidates, avg, span), candidates-donated-to list, committees-given-to list, recent contributions.

## Data sources per screen

| Screen | Method | Source | Notes |
|---|---|---|---|
| `MecResearchTab` search | `MecRepository.searchDonorsUnified` | RPC `search_donors_v3` | Joins mec_donors + enrichment |
| `MecResearchTab` profile (unified) | `MecRepository.getDonorUnifiedProfile` | RPC `get_donor_unified_profile` | Preferred when donorId present |
| `MecResearchTab` profile (fallback) | `getContributorProfile + getDonorEnrichment` | `mec_contributions` + `donor_enrichment` | Used when unified RPC fails |
| `MECDonorScreen` | Direct `.rpc()` | RPC `get_donor_profile_by_natural_key` | **No enrichment data joined in** |
| `DonorDetailScreen` (MOYD) | `DonorRepository.fetchDonorDetails` | `donors` + `donations` | MOYD internal only |
| `DonorProfileScreen` (MOYD) | `DonorProfileRepository.getFullProfile` | RPC `get_donor_profile_full` | `donor_profiles` table |

## `donor_enrichment` wiring state

**Where it IS used:**
- `MecRepository.getDonorEnrichment(int donorId)` at `lib/services/crm/mec_repository.dart:82`
- `MecResearchTab._openProfileFromDonor()` line 241 (fallback path)
- `_buildEnrichmentSections()` at line 1467 renders address/contact/employment/political from the enrichment
- `_buildProfileHeader()` shows badges: party_lean, age_estimate, gender, generation, is_homeowner, wealth_score, phone bool, email bool

**Where it is NOT used (CRITICAL GAP):**
- **`MECDonorScreen`** — the primary screen reached from BOTH entry points — **does not fetch or display any `donor_enrichment` fields**. Only MEC contribution history.
- `DonorDetailScreen` — no enrichment.
- `DonorProfileScreen` — separate path, doesn't touch `donor_enrichment`.

## Shared donor profile widget

**There is none.** Four parallel implementations:

1. **`MECDonorScreen`** — MEC research donors (reached from both entry points A and B)
2. **`MecResearchTab` profile mode** — in-place panel, richest enrichment display
3. **`DonorDetailScreen`** — MOYD's 49 donors (`donors` table)
4. **`DonorProfileScreen`** — MOYD `donor_profiles` table, 6-tab layout

`candidate_detail_screen.dart:17` imports `DonorProfileScreen` but **never instantiates it** — dead import.

The enrichment code (`_buildEnrichmentSections`, `_buildProfileHeader`, `_buildEnrichmentChip`) lives only in `mec_research_tab.dart` and is not reused.

## Supabase data model gotchas

- **`donors` (49, UUID) vs `donor_profiles` (49, UUID)**: Different tables. `donors` = MOYD's actual donors (people who donated to MOYD); `donor_profiles` = richer CRM profile for major donors (may overlap in population but separate schema).
- **`mec_donors` (1M, bigint)**: Research only. `mec_contributions.donor_id` FK is ~96% unreliable per comment in `mec_donor_screen.dart:13`. Codebase uses natural-key (first/last/city/state) lookups instead.
- **Navigation from contribution → donor detail**: `CandidateDetailScreen._openDonorProfileByKey()` (line 402) extracts first_name/last_name/city/state from the `_topDonors` list and passes as natural key. Bypasses the broken FK.

## Gaps: enrichment fields not displayed in MECDonorScreen

These are populated at high rates but NOT shown when viewing a donor from the candidate Money tab:

| Field | Coverage | Current display in MECDonorScreen |
|---|---|---|
| gender | ~92% | Not shown |
| party_lean | ~84% | Not shown |
| total_political_donations | 100% | Not shown |
| current_city/zip/county | high | Not shown |
| age_estimate | high | Not shown |
| is_homeowner | high | Not shown |
| wealth_score | moderate | Not shown |
| phone_mobile / phone_home | moderate | Not shown |

**Biggest UX win location:** `MECDonorScreen._content()` method at line 164 — the hero card — is where the badges should appear.

## Top 5 concrete changes

### Change 1: Extend `get_donor_profile_by_natural_key` RPC to JOIN `donor_enrichment`
Single SQL migration on Supabase side. Returns enrichment object alongside the aggregate data.
**Impact:** Unlocks changes 2-5.

### Change 2: Add enrichment badges + section to `MECDonorScreen._content()`
Display gender/party_lean/age_estimate/is_homeowner/wealth_score as badges in the hero card. Add "Voter File Data" section below. Extract `_buildEnrichmentSections` from `mec_research_tab.dart` into a shared `DonorEnrichmentCard` widget.
**Files:** `mec_donor_screen.dart`, new `lib/widgets/crm/donor_enrichment_card.dart`.

### Change 3: Surface `total_political_donations` prominently
100% populated, answers "how big a political donor is this?" — currently shown nowhere. Add as a "Lifetime Political" chip in `MECDonorScreen` hero, and in `MecResearchTab._buildProfileHeader()`.
**Files:** `mec_donor_screen.dart`, `mec_research_tab.dart`.

### Change 4: Remove dead import OR route MOYD donors to `DonorProfileScreen`
`candidate_detail_screen.dart:17` imports `DonorProfileScreen` but never uses it. Either remove or — better — detect when tapped donor matches a `donor_profiles` row (MOYD's 49 donors) and push `DonorProfileScreen` instead of `MECDonorScreen`. Richer experience for MOYD's actual donors when viewed from candidate context.
**Files:** `candidate_detail_screen.dart`.

### Change 5: Add current address to MECDonorScreen
`donor_enrichment.current_city/zip/county` is the voter-file current address — often different from the contribution-time address. Show as "Current address" alongside contribution addresses.
**Files:** `mec_donor_screen.dart`.

## Essential file paths

- `lib/screens/crm/donors_list_screen.dart` — tab container, entry A
- `lib/screens/crm/tabs/mec_research_tab.dart` — Donor Research + richest enrichment (1700+ lines)
- `lib/screens/crm/mec_donor_screen.dart` — terminal donor detail from both entry points, **enrichment gap lives here**
- `lib/screens/crm/candidate_detail_screen.dart` — Money tab, `_openDonorProfileByKey()`, dead import of `DonorProfileScreen`
- `lib/services/crm/mec_repository.dart` — `getDonorEnrichment`, `getDonorUnifiedProfile`, `searchDonorsUnified`
- `lib/screens/crm/donor_detail_screen.dart` — MOYD-own-donor detail
- `lib/screens/crm/donor_profile_screen.dart` — 6-tab MOYD donor profiles, dead-imported from candidate screen
- `lib/services/crm/donor_profile_repository.dart` — donor_profiles repo, RPC get_donor_profile_full
- `lib/services/crm/donor_repository.dart` — donors table repo
