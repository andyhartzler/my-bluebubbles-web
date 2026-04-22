import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/primary_challenge_pair.dart';

import 'candidate_view_mode.dart';
import 'candidates_grid_view.dart';
import 'candidates_list_view.dart';
import 'candidates_table_view.dart';
import 'yd_primary_challenger_view.dart';

typedef CandidateTap = void Function(Candidate c);

/// Left pane of the split page. Header + search + view-mode toggle + party
/// chips on top, delegated body below depending on active [mode].
class CandidatesListPanel extends StatelessWidget {
  final List<Candidate> filtered;
  final List<Candidate> allCandidates;
  final List<Candidate> allYoungDems;
  final List<PrimaryChallengePair> primaryPairs;
  final int totalCount;

  final CandidateViewMode mode;
  final ValueChanged<CandidateViewMode> onModeChanged;

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  final String? partyFilter;
  final ValueChanged<String?> onPartyFilterChanged;

  final bool ydOnly;
  final VoidCallback onToggleYdOnly;

  final String? selectedCandidateId;
  final CandidateTap onSelect;
  final CandidateTap onOpen;

  final VoidCallback onAddCandidate;

  const CandidatesListPanel({
    super.key,
    required this.filtered,
    required this.allCandidates,
    required this.allYoungDems,
    required this.primaryPairs,
    required this.totalCount,
    required this.mode,
    required this.onModeChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.partyFilter,
    required this.onPartyFilterChanged,
    required this.ydOnly,
    required this.onToggleYdOnly,
    required this.selectedCandidateId,
    required this.onSelect,
    required this.onOpen,
    required this.onAddCandidate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BrandColors.unityBlue.withOpacity(0.55),
            BrandColors.unityBlue.withOpacity(0.25),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          _buildSearchBar(context),
          _buildPartyChips(context),
          const SizedBox(height: 6),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.people, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text('Candidates',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${filtered.length} / $totalCount',
                style: const TextStyle(
                    color: BrandColors.sunriseGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onAddCandidate,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Add'),
            style: TextButton.styleFrom(
              foregroundColor: BrandColors.sunriseGold,
              backgroundColor: BrandColors.sunriseGold.withOpacity(0.1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name, district, occupation…',
              hintStyle:
                  const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.search,
                  color: Colors.white70, size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: BrandColors.sunriseGold.withOpacity(0.6)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<CandidateViewMode>(
            segments: CandidateViewMode.values.map((m) {
              return ButtonSegment<CandidateViewMode>(
                value: m,
                label: Text(m.label, style: const TextStyle(fontSize: 12)),
                icon: Icon(m.icon, size: 14),
              );
            }).toList(),
            selected: {mode},
            onSelectionChanged: (s) => onModeChanged(s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? BrandColors.sunriseGold.withOpacity(0.18)
                    : Colors.white.withOpacity(0.04);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? BrandColors.sunriseGold
                    : Colors.white70;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyChips(BuildContext context) {
    Widget chip(String label, String? partyValue, Color color) {
      final active = partyFilter == partyValue;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label,
              style: TextStyle(
                  color: active ? Colors.black87 : Colors.white,
                  fontSize: 11)),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onPartyFilterChanged(active ? null : partyValue),
          backgroundColor: Colors.white.withOpacity(0.06),
          selectedColor: color,
          side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          chip('All', null, BrandColors.momentumBlue),
          chip('Dem', 'Democratic', BrandColors.democratBlue),
          chip('Rep', 'Republican', BrandColors.republicanRed),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text('YD only',
                  style: TextStyle(
                      color:
                          ydOnly ? Colors.black87 : BrandColors.sunriseGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              selected: ydOnly,
              showCheckmark: false,
              onSelected: (_) => onToggleYdOnly(),
              backgroundColor: Colors.white.withOpacity(0.04),
              selectedColor: BrandColors.sunriseGold,
              side: BorderSide(
                  color: BrandColors.sunriseGold.withOpacity(0.55)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (mode) {
      case CandidateViewMode.list:
        return CandidatesListView(
          candidates: filtered,
          selectedCandidateId: selectedCandidateId,
          onSelect: onSelect,
          onOpen: onOpen,
        );
      case CandidateViewMode.grid:
        return CandidatesGridView(
          candidates: filtered,
          selectedCandidateId: selectedCandidateId,
          onSelect: onSelect,
          onOpen: onOpen,
        );
      case CandidateViewMode.table:
        return CandidatesTableView(
          candidates: filtered,
          selectedCandidateId: selectedCandidateId,
          onSelect: onSelect,
          onOpen: onOpen,
        );
      case CandidateViewMode.ydPrimary:
        return YdPrimaryChallengerView(
          rpcPairs: primaryPairs,
          allCandidates: allCandidates,
          allYoungDems: allYoungDems,
          selectedCandidateId: selectedCandidateId,
          onSelect: onSelect,
          onOpen: onOpen,
        );
    }
  }
}
