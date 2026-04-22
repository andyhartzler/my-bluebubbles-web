import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

import 'candidate_view_mode.dart';

/// Modern filter shelf for the mobile/tablet Candidates page.
///
/// Layout:
///   row 1  [search TextField                                ] [view-mode menu]
///   row 2  [All] [Dem] [Rep] [Young Dems] | [More filters 3]  [Clear all]
///   row 3  (expanded) party multi-select · office level · age · toggles
///
/// Designed to replace `_buildFiltersSection` + `_buildAdvancedFilters` on the
/// old monolithic page. Every interaction fires a callback — the parent
/// (CandidatesMobilePage) owns the filter state.
class CandidatesFilterShelf extends StatelessWidget {
  // Primary filters
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  final String? partyFilter;
  final ValueChanged<String?> onPartyFilterChanged;

  final bool ydOnly;
  final VoidCallback onToggleYdOnly;

  // Advanced-filter drawer
  final bool expanded;
  final VoidCallback onToggleExpanded;

  final int activeFilterCount;
  final VoidCallback onClearAll;

  // Advanced knobs (all optional)
  final Set<String> partyMultiSelect;
  final ValueChanged<Set<String>> onPartyMultiSelectChanged;
  final Set<String> officeLevelMultiSelect;
  final ValueChanged<Set<String>> onOfficeLevelMultiSelectChanged;
  final RangeValues ageRange;
  final ValueChanged<RangeValues> onAgeRangeChanged;
  final bool hasCampaignWebsite;
  final ValueChanged<bool> onHasCampaignWebsiteChanged;
  final bool moydContacted;
  final ValueChanged<bool> onMoydContactedChanged;
  final bool moydEndorsed;
  final ValueChanged<bool> onMoydEndorsedChanged;
  final bool hasFinanceFiled;
  final ValueChanged<bool> onHasFinanceFiledChanged;

  // View mode
  final CandidateViewMode mode;
  final ValueChanged<CandidateViewMode> onModeChanged;

  // Total/filtered counts (for display in the "Showing X of Y" strip)
  final int filteredCount;
  final int totalCount;

  const CandidatesFilterShelf({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.partyFilter,
    required this.onPartyFilterChanged,
    required this.ydOnly,
    required this.onToggleYdOnly,
    required this.expanded,
    required this.onToggleExpanded,
    required this.activeFilterCount,
    required this.onClearAll,
    required this.partyMultiSelect,
    required this.onPartyMultiSelectChanged,
    required this.officeLevelMultiSelect,
    required this.onOfficeLevelMultiSelectChanged,
    required this.ageRange,
    required this.onAgeRangeChanged,
    required this.hasCampaignWebsite,
    required this.onHasCampaignWebsiteChanged,
    required this.moydContacted,
    required this.onMoydContactedChanged,
    required this.moydEndorsed,
    required this.onMoydEndorsedChanged,
    required this.hasFinanceFiled,
    required this.onHasFinanceFiledChanged,
    required this.mode,
    required this.onModeChanged,
    required this.filteredCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchRow(context),
        const SizedBox(height: 10),
        _buildChipRail(context),
        const SizedBox(height: 8),
        _buildCountStrip(context),
        if (expanded) _buildAdvancedPanel(context),
      ],
    );
  }

  Widget _buildSearchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: searchQuery.length)),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, district, office…',
                hintStyle:
                    const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white70, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () => onSearchChanged(''),
                        icon: const Icon(Icons.clear,
                            color: Colors.white70, size: 18),
                        splashRadius: 18,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: BrandColors.sunriseGold.withOpacity(0.6), width: 1.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ViewModeMenu(mode: mode, onChanged: onModeChanged),
        ],
      ),
    );
  }

  Widget _buildChipRail(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _PrimaryChip(
            label: 'All',
            selected: partyFilter == null && !ydOnly,
            onTap: () {
              onPartyFilterChanged(null);
              if (ydOnly) onToggleYdOnly();
            },
          ),
          _PrimaryChip(
            label: 'Democrats',
            selected: partyFilter == 'Democratic',
            color: BrandColors.democratBlue,
            onTap: () => onPartyFilterChanged(
                partyFilter == 'Democratic' ? null : 'Democratic'),
          ),
          _PrimaryChip(
            label: 'Republicans',
            selected: partyFilter == 'Republican',
            color: BrandColors.republicanRed,
            onTap: () => onPartyFilterChanged(
                partyFilter == 'Republican' ? null : 'Republican'),
          ),
          _PrimaryChip(
            label: 'Young Dems',
            icon: Icons.star_rounded,
            selected: ydOnly,
            color: BrandColors.sunriseGold,
            onTap: onToggleYdOnly,
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 22, color: Colors.white24),
          const SizedBox(width: 6),
          _MoreFiltersButton(
            expanded: expanded,
            onTap: onToggleExpanded,
            activeAdvanced: activeFilterCount,
          ),
        ],
      ),
    );
  }

  Widget _buildCountStrip(BuildContext context) {
    if (activeFilterCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        child: Row(
          children: [
            Text(
              '$filteredCount candidates',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: [
          Icon(Icons.filter_list,
              size: 14, color: BrandColors.sunriseGold.withOpacity(0.85)),
          const SizedBox(width: 4),
          Text(
            '$filteredCount of $totalCount',
            style: TextStyle(
              color: BrandColors.sunriseGold.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClearAll,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 11, color: Colors.white70),
                    SizedBox(width: 3),
                    Text('Clear all',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedPanel(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.unityBlue.withOpacity(0.92),
            BrandColors.unityBlue.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: BrandColors.sunriseGold.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subsectionLabel('Party (any of)'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Democratic',
              'Republican',
              'Libertarian',
              'Green',
              'Constitution'
            ].map((p) {
              final sel = partyMultiSelect.contains(p);
              return _TogglePill(
                label: p,
                selected: sel,
                color: _partyColor(p),
                onTap: () {
                  final next = Set<String>.from(partyMultiSelect);
                  if (sel) {
                    next.remove(p);
                  } else {
                    next.add(p);
                  }
                  onPartyMultiSelectChanged(next);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _subsectionLabel('Office level'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['state', 'federal', 'statewide', 'judicial'].map((l) {
              final sel = officeLevelMultiSelect.contains(l);
              return _TogglePill(
                label: l.substring(0, 1).toUpperCase() + l.substring(1),
                selected: sel,
                color: BrandColors.momentumBlue,
                onTap: () {
                  final next = Set<String>.from(officeLevelMultiSelect);
                  if (sel) {
                    next.remove(l);
                  } else {
                    next.add(l);
                  }
                  onOfficeLevelMultiSelectChanged(next);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _subsectionLabel(
              'Age range · ${ageRange.start.round()} — ${ageRange.end.round()}'),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: BrandColors.sunriseGold,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: BrandColors.sunriseGold,
              overlayColor: BrandColors.sunriseGold.withOpacity(0.2),
              trackHeight: 3.5,
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: RangeSlider(
              values: ageRange,
              min: 18,
              max: 90,
              divisions: 72,
              onChanged: onAgeRangeChanged,
            ),
          ),
          const SizedBox(height: 8),
          _subsectionLabel('Quick toggles'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TogglePill(
                label: 'Endorsed',
                icon: Icons.verified_rounded,
                selected: moydEndorsed,
                color: BrandColors.success,
                onTap: () => onMoydEndorsedChanged(!moydEndorsed),
              ),
              _TogglePill(
                label: 'Contacted',
                icon: Icons.phone_in_talk_rounded,
                selected: moydContacted,
                color: BrandColors.momentumBlue,
                onTap: () => onMoydContactedChanged(!moydContacted),
              ),
              _TogglePill(
                label: 'Has website',
                icon: Icons.language_rounded,
                selected: hasCampaignWebsite,
                color: BrandColors.steelBlue,
                onTap: () => onHasCampaignWebsiteChanged(!hasCampaignWebsite),
              ),
              _TogglePill(
                label: 'MEC / FEC filed',
                icon: Icons.account_balance_rounded,
                selected: hasFinanceFiled,
                color: BrandColors.federalBlue,
                onTap: () => onHasFinanceFiledChanged(!hasFinanceFiled),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subsectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.55),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }

  Color _partyColor(String party) {
    switch (party.toLowerCase()) {
      case 'democratic':
        return BrandColors.democratBlue;
      case 'republican':
        return BrandColors.republicanRed;
      case 'libertarian':
        return const Color(0xFFFCD34D);
      case 'green':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }
}

/// Rounded primary chip for the top-of-rail row (All/Dem/Rep/YD).
class _PrimaryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _PrimaryChip({
    required this.label,
    this.icon,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? BrandColors.momentumBlue;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c, c.withOpacity(0.65)],
                    )
                  : null,
              color: selected ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? Colors.white.withOpacity(0.55)
                    : Colors.white.withOpacity(0.12),
                width: selected ? 1.2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: c.withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 13,
                      color: selected ? Colors.white : c),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreFiltersButton extends StatelessWidget {
  final bool expanded;
  final int activeAdvanced;
  final VoidCallback onTap;
  const _MoreFiltersButton({
    required this.expanded,
    required this.onTap,
    required this.activeAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final hot = activeAdvanced > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: hot
                ? BrandColors.sunriseGold.withOpacity(0.16)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: hot
                  ? BrandColors.sunriseGold.withOpacity(0.55)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded ? Icons.expand_less_rounded : Icons.tune_rounded,
                size: 13,
                color: hot ? BrandColors.sunriseGold : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                expanded ? 'Hide filters' : 'More filters',
                style: TextStyle(
                  color: hot ? BrandColors.sunriseGold : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hot) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: BrandColors.sunriseGold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeAdvanced',
                    style: const TextStyle(
                      color: Color(0xFF1a1a2e),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.22)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.60)
                  : Colors.white.withOpacity(0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 12,
                    color: selected ? color : Colors.white60),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact view-mode picker — trailing icon button that opens a popup menu.
class _ViewModeMenu extends StatelessWidget {
  final CandidateViewMode mode;
  final ValueChanged<CandidateViewMode> onChanged;
  const _ViewModeMenu({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CandidateViewMode>(
      tooltip: 'View mode',
      onSelected: onChanged,
      color: BrandColors.unityBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: BrandColors.sunriseGold.withOpacity(0.35)),
      ),
      itemBuilder: (ctx) => CandidateViewMode.values.map((m) {
        final active = m == mode;
        return PopupMenuItem<CandidateViewMode>(
          value: m,
          child: Row(
            children: [
              Icon(m.icon,
                  color: active ? BrandColors.sunriseGold : Colors.white70,
                  size: 15),
              const SizedBox(width: 10),
              Text(
                m.label,
                style: TextStyle(
                  color: active ? BrandColors.sunriseGold : Colors.white,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.icon, color: BrandColors.sunriseGold, size: 16),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
