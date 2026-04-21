# CRM Voter File UI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the MOYD voter-file data (DOB, voting history, district info) and `donor_enrichment` fields on candidate, donor, and member detail screens in the Flutter CRM. Fix a model/schema drift bug along the way.

**Architecture:** New `VoterFileRecord` + `DonorEnrichmentRecord` models. Shared `VoterFileService` that does a single PK lookup against `public.mo_voter_file`. Three reusable card widgets. Lazy-load on detail screen open (no list-view impact).

**Tech Stack:** Flutter Material, Supabase Flutter client, existing `_card()`/`_infoRow()` pattern from `candidate_detail_screen.dart`.

**Critical bug to fix first:** `candidate.dart:17` declares `voterMatchId` reading JSON key `voter_match_id`, but the DB column was renamed to `mo_voter_file_id` in migration `20260421_02_universal_dob_columns.sql`. This breaks candidate → voter file linkage in the Flutter layer until fixed.

---

## Patterns to follow

- **Card widget pattern** (`candidate_detail_screen.dart:1309`): `_card(title, icon, accentColor, child: ...)` — dark Container with gradient border and BoxShadow.
- **Info row pattern** (`candidate_detail_screen.dart:1302`): `_infoRow(icon, label, value)` — Icon + label + value in white70/white text.
- **Tab lazy-load** (`candidate_detail_screen.dart:148-163`): Data loads on first tab visit via `_onTabChanged()`, guarded by a boolean flag.
- **Repository pattern**: Instantiate `CRMSupabaseService()`, use `_supabase.privilegedClient`, return typed models, catch errors with `debugPrint('❌ ...')` returning null/empty.
- **Shared widgets go in `lib/screens/crm/voter_file/`** (subdirectory pattern used elsewhere as `lib/screens/crm/member_detail/`). There is no `lib/widgets/crm/` — don't create one.
- **Accent color**: `BrandColors.steelBlue` (neutral government data, not party-aligned).

## Architectural decisions (with rationale)

1. **Separate lazy-fetch, not JOIN.** `mo_voter_file` is 4.34M rows; PostgREST embedded selects would risk pulling too much. Lazy fetch on detail screen open matches the existing pattern.
2. **`VoterFileRecord` as standalone model**, not embedded in `Candidate`/`Donor`/`Member` — referenced as a nullable field on the detail screen, not the model class.
3. **`DonorEnrichmentRecord` separate from `EnrichmentData`** — the old class maps a JSONB blob shape, the new table needs a flat model.
4. **Don't render empty enrichment cards.** The `DonorEnrichmentRecord.populatedFields` getter filters nulls; if zero fields populated, don't render the card at all.

## DOB display rule (important)

In `VoterFileCard`, always display `"born {birthYear}"` — not a full date. The backend stores `make_date(birth_year, 7, 1)` to satisfy `date` column type, but that July-1 date is an artifact, not a fact. Show only the year to users.

## Member DOB override protection

`VoterCrossRefCard` must never write to `members.date_of_birth`. The widget is fully read-only. Per Andrew's 2026-04-21 22:49 Telegram: "be careful when working in the members table to preserve or prefer data we have in the members table and consult me before you add data to that table."

---

### Task 1: Fix the Candidate model drift (BLOCKING)

**Files:**
- Modify: `lib/models/crm/candidate.dart` — lines 17, 152, 220, 394, 455
- Modify: `lib/screens/crm/candidate_detail_screen.dart` — line 1393

- [ ] **Step 1.1** Rename `voterMatchId` → `moVoterFileId` in `Candidate` class field declaration (line ~17).
- [ ] **Step 1.2** Fix `fromJson` at line ~152: `json['voter_match_id']` → `json['mo_voter_file_id']`, key the new field.
- [ ] **Step 1.3** Fix `toJson` at line ~220.
- [ ] **Step 1.4** Fix `copyWith` at line ~394/455.
- [ ] **Step 1.5** Add new fields: `int? birthYear`, `String? dobSource`, `num? matchConfidence`, `String? matchMethod` — all nullable, parsed from JSON keys `birth_year`, `dob_source`, `match_confidence`, `match_method`.
- [ ] **Step 1.6** Fix `candidate_detail_screen.dart` line 1393: `c.voterMatchId` → `c.moVoterFileId`.
- [ ] **Step 1.7** Run the app, confirm candidate detail screen renders without compile errors.

---

### Task 2: New model — VoterFileRecord

**Files:**
- Create: `lib/models/crm/voter_file_record.dart`

- [ ] **Step 2.1** Class definition:

```dart
class VoterFileRecord {
  final String voterId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? suffix;
  final String? county;
  final String? residentialCity;
  final String? residentialZip5;
  final String? voterStatus;         // Active / Inactive / Cancelled
  final DateTime? registrationDate;
  final int? birthYear;
  final String? congressionalDistrict;
  final String? legislativeDistrict;
  final String? senateDistrict;
  final String? precinct;
  final String? ward;
  final String? township;
  final List<VoterHistoryEntry> voterHistory;

  int? get estimatedAge =>
      birthYear != null ? DateTime.now().year - birthYear! : null;
  bool get isActive => voterStatus == 'Active';
  int get electionCount => voterHistory.length;

  factory VoterFileRecord.fromJson(Map<String, dynamic> json) { /* ... */ }
}

class VoterHistoryEntry {
  final DateTime date;
  final String electionType;  // "General", "Primary", "Municipal", etc.
  VoterHistoryEntry({required this.date, required this.electionType});
  factory VoterHistoryEntry.parse(String s) {
    // input format: "11/05/2024 General"
    final parts = s.split(' ');
    return VoterHistoryEntry(
      date: DateFormat('MM/dd/yyyy').parse(parts[0]),
      electionType: parts.sublist(1).join(' '),
    );
  }
}
```

---

### Task 3: New model — DonorEnrichmentRecord

**Files:**
- Create: `lib/models/crm/donor_enrichment_record.dart`

Only map populated columns. Skip the 100+ NULL-only columns.

```dart
class DonorEnrichmentRecord {
  final String? id;
  final String? fullName;
  final String? gender;             // ~92%
  final String? partyLean;          // ~84%
  final num? partyLeanConfidence;
  final String? currentCity;
  final String? currentZip;
  final String? currentCounty;
  final String? congressionalDistrict;
  final double? totalPoliticalDonations;  // 100%
  final int? donationCount;
  final double? avgDonation;
  final String? donationFrequency;
  final bool? isHomeowner;
  final num? wealthScore;
  final int? ageEstimate;
  final String? moVoterFileId;

  // Only non-null rows for the UI
  List<({String label, String value})> get populatedFields { /* ... */ }
}
```

---

### Task 4: Shared service — VoterFileService

**Files:**
- Create: `lib/services/crm/voter_file_service.dart`

Single class with one static fetch method used by all three repositories.

```dart
class VoterFileService {
  static Future<VoterFileRecord?> fetchRecord(String voterId) async {
    if (voterId.isEmpty) return null;
    try {
      final response = await CRMSupabaseService().privilegedClient
          .from('mo_voter_file')
          .select('voter_id,first_name,middle_name,last_name,suffix,'
                  'county,residential_city,residential_zip5,voter_status,'
                  'registration_date,birth_year,congressional_district,'
                  'legislative_district,senate_district,precinct,ward,'
                  'township,voter_history')
          .eq('voter_id', voterId)
          .maybeSingle();
      if (response == null) return null;
      return VoterFileRecord.fromJson(response);
    } catch (e) {
      debugPrint('❌ VoterFileService.fetchRecord: $e');
      return null;
    }
  }
}
```

Explicit column list: `mo_voter_file` has 30+ columns; we only need the display-relevant subset.

---

### Task 5: Build widgets (parallelizable after Tasks 1-4)

**Files:**
- Create: `lib/screens/crm/voter_file/voter_registration_badge.dart`
- Create: `lib/screens/crm/voter_file/voter_history_strip.dart`
- Create: `lib/screens/crm/voter_file/voter_district_strip.dart`
- Create: `lib/screens/crm/voter_file/voter_file_card.dart`
- Create: `lib/screens/crm/voter_file/donor_enrichment_card.dart`
- Create: `lib/screens/crm/voter_file/voter_crossref_card.dart`

- [ ] **Step 5.1** `VoterRegistrationBadge` — Chip-like widget showing voter status with color coding (Active=green, Inactive=orange, Cancelled=red) + icon + registration date below in small text.
- [ ] **Step 5.2** `VoterHistoryStrip` — horizontal Row of up to 20 dots. Each 10px, spaced 6px. Filled (steelBlue) = voted, empty (white24 border) = missed. Sort newest-left. Tooltip on tap: `"11/05/2024 General"`. Type abbreviation below (G/P/M). Summary text below: `"N of M elections voted (X%)"`.
- [ ] **Step 5.3** `VoterDistrictStrip` — 2×2 grid of info chips: [CD-N] [MO House M] [MO Senate K] [Precinct P]. Uses `Wrap` for narrow screens. Only renders non-null values.
- [ ] **Step 5.4** `VoterFileCard` — composes the three widgets above inside `_card()`. Includes age row ("Age N (born YYYY)" with source badge), plus a staff-debug `ExpansionTile` showing match_confidence + match_method when `showDebug` param is true.
- [ ] **Step 5.5** `DonorEnrichmentCard` — 4 sections (Identity, Geography, Politics, Giving) using `_infoRow` pattern. "Show more" collapse when >8 populated fields. Don't render card if `populatedFields` is empty.
- [ ] **Step 5.6** `VoterCrossRefCard` — read-only. Shows voter file data next to member's self-reported `dateOfBirth`. Warning chip "Discrepancy — please verify with member" when years differ.

---

### Task 6: Repository wiring

**Files:**
- Modify: `lib/services/crm/candidate_repository.dart` — add fetchVoterRecord method
- Modify: `lib/services/crm/donor_profile_repository.dart` — add fetchVoterRecordForProfile + fetchEnrichmentRecord
- Modify: `lib/services/crm/mec_repository.dart` — confirm existing `getDonorEnrichment` or add pass-through

- [ ] **Step 6.1** Add `fetchVoterRecord(String voterId)` to `CandidateRepository` that delegates to `VoterFileService.fetchRecord(voterId)`.
- [ ] **Step 6.2** Add `fetchVoterRecordForProfile(String profileId)` — joins `donor_profiles.mo_voter_file_id` → `VoterFileService.fetchRecord()`.
- [ ] **Step 6.3** Add `fetchEnrichmentRecord(String profileId)` — query `.from('donor_enrichment').select(<populated cols>).eq('profile_id', profileId).maybeSingle()`. Verify `profile_id` FK exists (if not, use `donor_id` or whichever column links).

---

### Task 7: Integrate into CandidateDetailScreen

**Files:**
- Modify: `lib/screens/crm/candidate_detail_screen.dart`

- [ ] **Step 7.1** Add state: `VoterFileRecord? _voterRecord; bool _voterLoading = false;`
- [ ] **Step 7.2** `_loadVoterRecord()` method that calls `_repo.fetchVoterRecord(c.moVoterFileId!)`, handles loading/error, setState.
- [ ] **Step 7.3** Trigger from `initState` or on Profile tab first-visit.
- [ ] **Step 7.4** In `_buildOverviewTab()`, after `_buildContactInfo()` card, inject:

```dart
if (_voterLoading)
  const Center(child: CircularProgressIndicator())
else if (_voterRecord != null)
  VoterFileCard(
    record: _voterRecord!,
    dobSource: c.dobSource,
    matchConfidence: c.matchConfidence,
    matchMethod: c.matchMethod,
    showDebug: CRMConfig.debugMode,
  ),
```

---

### Task 8: Integrate into DonorProfileScreen

**Files:**
- Modify: `lib/screens/crm/donor_profile_screen.dart`

- [ ] **Step 8.1** Extend `_load()` to also fetch voter record + enrichment record.
- [ ] **Step 8.2** Add `VoterFileCard` + `DonorEnrichmentCard` to the Overview tab body inside the existing `SingleChildScrollView`.

---

### Task 9: Integrate into MECDonorScreen

**Files:**
- Modify: `lib/screens/crm/mec_donor_screen.dart`

- [ ] **Step 9.1** After `_load()` returns with `_profile`, read `_profile['mo_voter_file_id']` and fetch `VoterFileRecord` via `VoterFileService.fetchRecord()`.
- [ ] **Step 9.2** Fetch `DonorEnrichmentRecord` via `fetchEnrichmentRecord()` if `_profile['id']` is populated.
- [ ] **Step 9.3** Render both cards at the bottom of the main Column.

---

### Task 10: Integrate into MemberDetailScreen

**Files:**
- Check + possibly modify: `lib/models/crm/member.dart` (add `moVoterFileId` if missing)
- Modify: `lib/screens/crm/member_detail_screen.dart`

- [ ] **Step 10.1** Check Member model for `moVoterFileId` field; add if missing.
- [ ] **Step 10.2** Add `_loadVoterRecord()` in member detail, fetch from `VoterFileService`.
- [ ] **Step 10.3** Render `VoterCrossRefCard` at the bottom of the overview, wrapped in `if (member.moVoterFileId != null)`.
- [ ] **Step 10.4** **READ-ONLY** — no "Confirm" or "Override" buttons. Per Andrew's standing instruction.

---

### Task 11: Verification & hardening

- [ ] **Step 11.1** Test candidate with null `moVoterFileId` — confirm card is absent (no null-crash).
- [ ] **Step 11.2** Test donor with enrichment record that has zero populated fields — confirm card is absent.
- [ ] **Step 11.3** Test member with `moVoterFileId` → DOB year matches self-reported (no warning shown).
- [ ] **Step 11.4** Test member with discrepancy — confirm yellow warning chip renders.
- [ ] **Step 11.5** Performance check on detail screen open — detail should render instantly with a Loading spinner for the voter card, then populate.

---

## Open questions

- Should `VoterCrossRefCard` be visible to all CRM users, or only admin roles? Default: visible to all since the data is already accessible via DB.
- Future: Should we add a "confirm my DOB from voter file" button on the member self-service side? **Out of scope for this plan.**
