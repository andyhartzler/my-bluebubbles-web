# Candidates Desktop UI Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the candidates page from a single-column mobile-first layout into a responsive desktop-first dashboard with side-by-side map+list, clickable stat cards, and a grid candidate layout.

**Architecture:** Add a single responsive breakpoint (900px) to candidates_page.dart. Below 900px: keep current mobile layout. Above 900px: split into 2-column layout with map/filters on the left and candidate list on the right. Stat cards become clickable to set filters.

**Tech Stack:** Flutter (existing), LayoutBuilder for responsive, existing MissouriMapWidget

---

## Current State

- `candidates_page.dart` (~2500 lines) is a single `CustomScrollView` with everything stacked vertically
- No responsive breakpoints except one at 380px for bulk buttons
- Map is 340px tall stacked above the list
- 11 stat cards in a horizontal scroll — not tappable
- Candidate list is a `SliverList` — single column on all screens
- Stats bar overflows horizontally on desktop (wastes space)

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/screens/crm/candidates_page.dart` | Modify | Add responsive layout, clickable stats, grid |

No new files needed — this is a layout refactor within the existing file.

---

### Task 1: Add responsive breakpoint and 2-column desktop layout

**Files:**
- Modify: `lib/screens/crm/candidates_page.dart:504-563` (build method)

- [ ] **Step 1: Add isDesktop check and split layout**

In the `build` method, wrap the existing `CustomScrollView` in a `LayoutBuilder`. When width >= 900, render a `Row` with:
- Left pane (400px fixed): Map + Stats + Filters
- Right pane (Expanded): Candidate list + analytics

```dart
@override
Widget build(BuildContext context) {
  // ... existing loading/error checks ...

  return LayoutBuilder(builder: (context, constraints) {
    final isDesktop = constraints.maxWidth >= 900;

    if (isDesktop) {
      return _buildDesktopLayout(constraints);
    }
    return _buildMobileLayout(); // existing CustomScrollView
  });
}

Widget _buildDesktopLayout(BoxConstraints constraints) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Left pane: Map + Stats + Filters
      SizedBox(
        width: 420,
        child: Column(
          children: [
            if (_bulkMode) _buildBulkToolbar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildMapSection(),
                  const SizedBox(height: 12),
                  _buildStatsGrid(), // NEW: grid layout for stats
                  const SizedBox(height: 12),
                  _buildFiltersSection(),
                  if (_showAdvancedFilters) ...[
                    const SizedBox(height: 8),
                    _buildAdvancedFilters(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      // Divider
      Container(width: 1, color: Colors.white.withOpacity(0.1)),
      // Right pane: YD spotlight + Analytics + Candidate list
      Expanded(
        child: CustomScrollView(
          slivers: [
            if (_youngDems.isNotEmpty)
              SliverToBoxAdapter(child: _buildYdSpotlight()),
            SliverToBoxAdapter(child: _buildAnalyticsToggle()),
            if (_showAnalytics)
              SliverToBoxAdapter(
                child: _analyticsLoading
                    ? CandidateUI.shimmerSkeleton(cardCount: 2)
                    : _buildAnalyticsSection(),
              ),
            // Candidate grid (2 columns on desktop)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildCandidateRow(_filteredCandidates[index]),
                  childCount: _filteredCandidates.length,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 2: Extract existing mobile layout**

Rename the existing `CustomScrollView` body to `_buildMobileLayout()` — just wrap the current code.

- [ ] **Step 3: Verify mobile layout unchanged**

Test on mobile viewport — should look identical.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: responsive 2-column desktop layout for candidates page"
```

---

### Task 2: Clickable stat cards with filter-on-tap

**Files:**
- Modify: `lib/screens/crm/candidates_page.dart` (stats bar + statCard method)

- [ ] **Step 1: Create a stats grid for desktop**

New `_buildStatsGrid()` method that uses `Wrap` instead of horizontal scroll:

```dart
Widget _buildStatsGrid() {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _tappableStatCard(Icons.people, '${_stats.totalCandidates}', 'Total', null, null),
      _tappableStatCard(Icons.groups, '${_stats.democrats}', 'Democrats', 'Democratic', null),
      _tappableStatCard(Icons.star, '${_stats.youngDemocrats}', 'Young Dems', null, true),
      // ... etc for all 11 stats
    ],
  );
}
```

- [ ] **Step 2: Create `_tappableStatCard` with filter callback**

```dart
Widget _tappableStatCard(IconData icon, String value, String label, String? partyFilter, bool? ydFilter) {
  final isActive = (_partyFilter == partyFilter && partyFilter != null) ||
                   (_ydOnly == true && ydFilter == true);

  return GestureDetector(
    onTap: () {
      setState(() {
        if (partyFilter != null) {
          _partyFilter = _partyFilter == partyFilter ? null : partyFilter;
        }
        if (ydFilter != null) {
          _ydOnly = !_ydOnly;
        }
        _applyFilters();
      });
    },
    child: Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? BrandColors.sunriseGold.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? BrandColors.sunriseGold : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: isActive ? BrandColors.sunriseGold : Colors.white60, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 3: Wire all 11 stats to appropriate filters**

Map each stat to its filter action:
- Total → clear all filters
- Democrats → `_partyFilter = 'Democratic'`
- Republicans → `_partyFilter = 'Republican'`
- Libertarians → `_partyFilter = 'Libertarian'`
- Young Dems → `_ydOnly = true`
- Endorsed → `_moydEndorsed = true`
- Contacted → `_moydContacted = true`
- Has Website → `_hasCampaignWebsite = true`
- MEC Filed → `_hasFinanceFiled = true`
- Uncontested (D) → custom filter

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: clickable stat cards — tap to filter candidate list"
```

---

### Task 3: Polish and visual consistency

**Files:**
- Modify: `lib/screens/crm/candidates_page.dart`

- [ ] **Step 1: Adjust map height on desktop**

Pass a larger height to `MissouriMapWidget` when on desktop:
```dart
MissouriMapWidget(
  height: isDesktop ? 450 : 340,
  // ...
)
```

- [ ] **Step 2: Improve candidate row for grid layout**

Current `_buildCandidateRow` may need adjustment for grid cells:
- Ensure text truncation with `maxLines: 1, overflow: TextOverflow.ellipsis`
- Compact padding for grid cells
- Photo + name + party badge + district should fit in ~350px width

- [ ] **Step 3: Add active filter indicator near stats**

When a stat card is active (filtering), show a small "clear filter" chip below the stats grid.

- [ ] **Step 4: Final commit**

```bash
git commit -m "fix: desktop polish — map height, grid row sizing, filter indicators"
```

---

## Execution Notes

- The mobile layout MUST remain unchanged — all changes are additive behind the `isDesktop` check
- The `_buildMobileLayout` method is literally the existing code moved into a method
- Stats grid uses `Wrap` which handles any width gracefully
- Candidate grid uses `SliverGrid` which is lazy-rendered (no performance concern)
- Filter state is shared between desktop/mobile layouts — toggling works the same way
