# Donor Page Slack Redesign — Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply the Slack page's visual language to all 4 donor page tabs, with clear separation between MOYD donors (49 who gave to us) and MEC/FEC research donors (1M+ external records).

**Architecture:** Thin chrome reskin with extracted shared widgets. Do NOT refactor business logic, state management, or data bindings. Surgically replace visual widget methods only.

**Tech Stack:** Flutter, `BrandedCard`, `BrandedBackground`, `BrandTextStyles` (already exist in `brand_colors.dart`), new public widgets `BrandedStatCard`, `BrandedRankedListCard`, `BrandedActivityFeedItem`.

---

## Design references

- **Slack design spec:** `/Users/moyd/my-bluebubbles-web/docs/superpowers/plans/2026-04-22-slack-page-design-spec.md`
- **Donor schema audit:** `/Users/moyd/my-bluebubbles-web/docs/superpowers/plans/2026-04-22-donor-schema-audit.md`
- **Slack reference impl:** `lib/features/slack/screens/slack_management_screen.dart` (gradient TabBar lines 64–95)
- **_BrandedSummaryCard to promote:** `lib/features/slack/widgets/analytics_tab.dart:1420–1487`

## What Andrew wants

> "There needs to be a clear separation from donors who are the donors table in supabase who have already donated to us and then the MEC donors and FEC donors who are the rest of everyone... the donors page and all its associated tabs and inner pages should look like the slack page."

So:
1. **Clear separation** between MOYD donors (Fundraising tab) and research donors (Donor Research tab) via hero banner labeling + visual cues.
2. **Match Slack visual language** — gradient TabBar with sunriseGold underline, BrandedCards throughout, icon-in-tile headers, branded stat tiles, top-N lists with rank badges, gold reserved for emphasis.

---

## Shared Widgets to Create

All appended to `lib/features/committees/theme/brand_colors.dart` after line 266 (end of `BrandTextStyles`).

### 1. `BrandedStatCard` (promoted from `_BrandedSummaryCard`)

```dart
class BrandedStatCard extends StatelessWidget {
  const BrandedStatCard({
    super.key,
    required this.title,      // Label (white70, 13, w500)
    required this.value,      // Big number (white, 32, bold)
    this.subtitle,            // Optional footnote (white60, 12)
    required this.icon,       // Icon in icon-tile
    this.gradientColors,      // Defaults to BrandColors.tileGradient
  });
  // Body: direct copy of analytics_tab.dart:1436–1486
}
```

### 2. `BrandedRankedListCard` + `BrandedRankedItem`

```dart
class BrandedRankedItem {
  const BrandedRankedItem({
    required this.label,
    required this.valueLabel,
    required this.progressFraction,
    this.sublabel,
  });
  final String label;
  final String valueLabel;
  final double progressFraction;
  final String? sublabel;
}

class BrandedRankedListCard extends StatelessWidget {
  const BrandedRankedListCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.gradientColors,
    this.onItemTap,
    this.emptyLabel,
  });
}
```
Layout: `BrandedCard` → `Column` → header (icon-tile + title) → `ListView.separated` rows with 24×24 rank badge (white-20%, radius 6), label+sublabel, right-aligned valueLabel, `LinearProgressIndicator` (minHeight 6, white fill on white-20% track, radius 4).

### 3. `BrandedActivityFeedItem`

```dart
class BrandedActivityFeedItem extends StatelessWidget {
  const BrandedActivityFeedItem({
    super.key,
    required this.primaryText,
    required this.secondaryText,
    this.tertiaryText,
    this.actionLabel,
    this.actionColor,
    this.leadingIcon,
    this.avatarInitials,
    this.onTap,
    this.showChevron = true,
    this.trailingChips,
  });
}
```
Layout mirrors `analytics_tab.dart:1168–1306`: white-10% container (radius 10, padding 12, margin-bottom 8).

---

## File-by-File Changes

### File 1: `lib/features/committees/theme/brand_colors.dart`
Append 3 new public widget classes. Pure additive.

### File 2: `lib/screens/crm/donors_list_screen.dart` (124 lines)
Already uses gradient TabBar + sunriseGold indicator. Only change:
- **Line 104**: `'Donors & Research'` → `'Donors'`

### File 3: `lib/screens/crm/tabs/fundraising_tab.dart` (1520 lines)
- Add `brand_colors.dart` import
- Remove local color constants (lines 25–29), substitute `BrandColors.*`
- Replace `_buildHeroCard` → `_buildStatCard` (delegates to `BrandedStatCard`)
- Update stat card gradients (navy/green/purple/amber)
- Replace header (lines 1355–1380) with `BrandedCard` hero banner ("MOYD Donors — 49 people who gave to MOYD directly")
- Reskin action buttons (Export → white OutlinedButton, Add → sunriseGold ElevatedButton)
- Add `_buildTopDonorsCard` using `BrandedRankedListCard`
- Reskin filters (search TextField + FilterChip style)
- Replace outer donation list `Card` with `BrandedCard` + section header
- Replace each donation item `Card` with `BrandedActivityFeedItem`

### File 4: `lib/screens/crm/tabs/mec_research_tab.dart` (2270 lines)
- Hero banner at top of search view ("Donor Research — 1M+ MEC/FEC records", with MEC/FEC/Both source toggle)
- Reskin search `TextField` to Slack style
- Add `BrandedStatCard` tiles (Results count, MEC: 1.02M, FEC: 1.76M — static from schema audit)
- Reskin filter chips
- Replace each donor result card with `BrandedCard`
- Confirm profile mode wrapped in `BrandedBackground`
- **DO NOT touch profile mode rendering internals** (just restored)

### File 5: `lib/screens/crm/tabs/call_time_tab.dart` (2107 lines)
- `_buildListsView()` (line 180): replace header with `BrandedCard` hero
- Add `BrandedStatCard` row (Active Lists, Total Contacts, Pledges)
- Reskin status filter chips
- Replace each list card with `BrandedCard`
- `_buildDetailView()`: add `BrandedCard` header

### File 6: `lib/screens/crm/tabs/committees_tab.dart` (1401 lines)
- `_buildSearchView()` (line 356): insert `BrandedCard` hero banner ("Committees — Browse 15,404 MEC + FEC committees")
- Reskin filter chips
- Replace each committee result card with `BrandedCard`
- Inside `_buildDetailView`: replace top-donors list section with `BrandedRankedListCard`

---

## Build sequence

### Phase 1 — Shared Widgets (prereq for everything)
- [ ] Append `BrandedStatCard` to `brand_colors.dart`
- [ ] Append `BrandedRankedItem` + `BrandedRankedListCard`
- [ ] Append `BrandedActivityFeedItem`
- [ ] `flutter analyze` → zero issues

### Phase 2 — Donors List Screen container (trivial)
- [ ] `donors_list_screen.dart:104`: title `'Donors & Research'` → `'Donors'`

### Phase 3 — Fundraising Tab
- [ ] Import + color consts swap
- [ ] Replace `_buildHeroCard` → `_buildStatCard`
- [ ] Stat card gradients (navy/green/purple/amber)
- [ ] Hero banner `BrandedCard`
- [ ] Action buttons reskin
- [ ] Add `_buildTopDonorsCard`
- [ ] Filters reskin
- [ ] Donation list `BrandedCard` wrapper + `BrandedActivityFeedItem` rows
- [ ] `flutter analyze`

### Phase 4 — Donor Research Tab (MecResearchTab)
- [ ] Hero banner at top of search view
- [ ] Search bar reskin
- [ ] `BrandedStatCard` tiles (MEC / FEC scale)
- [ ] Filter chips reskin
- [ ] Result cards → `BrandedCard`
- [ ] Verify profile mode untouched
- [ ] `flutter analyze`

### Phase 5 — Call Time Tab
- [ ] Hero banner, stat tiles, chip reskin, card reskin
- [ ] `flutter analyze`

### Phase 6 — Committees Tab
- [ ] Hero banner, chip reskin, card reskin, `BrandedRankedListCard` inside detail
- [ ] `flutter analyze`

### Phase 7 — Visual verification
- [ ] Gradient TabBar + gold indicator visible
- [ ] `BrandedBackground` behind all 4 tab bodies
- [ ] Per-tab hero banners + stat tiles render
- [ ] Narrow viewport (<600px): 4 stat tiles collapse to 2×2
- [ ] MecResearchTab profile mode still works (restored rich sections)
- [ ] CallTime → detail navigation
- [ ] Committees → detail w/ ranked donors

---

## Critical details

### Clear MOYD vs Research separation
- **Fundraising banner**: icon `Icons.volunteer_activism` (gold-tinted tile), `'MOYD Donors'` title, `'49 people who have given to MOYD directly'` subtitle
- **Research banner**: icon `Icons.manage_search` (default navy), `'Donor Research'` title, `'Explore every MO political donor — 1M+ records'` subtitle
- Research stat tiles explicitly labeled "MEC Research Database" / "FEC Research Database"

### DOB display rule (from prior work — still enforced)
Always display `birth_year` only for voter_file-sourced DOBs (never synthesize month/day).

### Error / Loading / Empty
Replace bare `CircularProgressIndicator()` with `CircularProgressIndicator(color: BrandColors.momentumBlue)`. Error states → `BrandedCard` with `Icons.error_outline` + centered message.

### Responsive
Stat tile grids: `Wrap(spacing: 16, runSpacing: 16)` instead of fixed Row/Column. Auto-reflow.

### Performance
- Fundraising top-donors derived from in-memory `_donors` (max 49). No new network calls.
- Research stat tile values are static strings from schema audit. No new queries.

---

## Out-of-scope (explicit)

- MecResearchTab profile mode internals
- `DonorEnrichmentCard` (used by other screens)
- `DonorCommandCenter`, `DonorDetailScreen`, `DonorProfileScreen`
- Any Supabase RPCs or repository changes
- `analytics_tab.dart` `_BrandedSummaryCard` (leave in place — `BrandedStatCard` is new public class)
- New `pubspec.yaml` dependencies
