import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

typedef CandidateTap = void Function(Candidate c);

/// Sortable dense table of candidates for power-users who want to sort by
/// age / YD-score / district and skim quickly.
class CandidatesTableView extends StatefulWidget {
  final List<Candidate> candidates;
  final String? selectedCandidateId;
  final CandidateTap onSelect;
  final CandidateTap? onOpen;

  const CandidatesTableView({
    super.key,
    required this.candidates,
    required this.selectedCandidateId,
    required this.onSelect,
    this.onOpen,
  });

  @override
  State<CandidatesTableView> createState() => _CandidatesTableViewState();
}

class _CandidatesTableViewState extends State<CandidatesTableView> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  List<Candidate> get _sorted {
    final list = List<Candidate>.from(widget.candidates);
    int cmp(Candidate a, Candidate b) {
      switch (_sortColumnIndex) {
        case 0:
          return a.name.compareTo(b.name);
        case 1:
          return a.party.compareTo(b.party);
        case 2:
          return a.office.compareTo(b.office);
        case 3:
          final ai = int.tryParse(a.district ?? '') ?? 9999;
          final bi = int.tryParse(b.district ?? '') ?? 9999;
          return ai.compareTo(bi);
        case 4:
          return (a.estimatedAge ?? 999).compareTo(b.estimatedAge ?? 999);
        case 5:
          return b.youngDemScore.compareTo(a.youngDemScore);
        default:
          return 0;
      }
    }

    list.sort((a, b) => _sortAscending ? cmp(a, b) : -cmp(a, b));
    return list;
  }

  void _onSort(int col, bool asc) {
    setState(() {
      _sortColumnIndex = col;
      _sortAscending = asc;
    });
  }

  DataColumn _col(String label, {bool numeric = false}) => DataColumn(
        label: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        numeric: numeric,
        onSort: _onSort,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('No candidates match the current filters.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center),
      );
    }

    // Mobile (<600px): a 6-column DataTable with horizontal scroll is a
    // usability dead-end — the first-column "Name" scrolls off-screen
    // and sort headers are 48px tall but ~80px wide. Render a compact
    // sortable card list instead, with a sort dropdown replacing the
    // column headers. Desktop keeps the full DataTable.
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) return _buildMobileCardList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Theme(
          data: Theme.of(context).copyWith(
            dataTableTheme: DataTableThemeData(
              headingRowColor: WidgetStatePropertyAll(
                  BrandColors.unityBlue.withOpacity(0.90)),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return BrandColors.sunriseGold.withOpacity(0.22);
                }
                return BrandColors.unityBlue.withOpacity(0.55);
              }),
              dividerThickness: 0.5,
            ),
          ),
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            showCheckboxColumn: false,
            columns: [
              _col('Name'),
              _col('Party'),
              _col('Office'),
              _col('District', numeric: true),
              _col('Age', numeric: true),
              _col('YD Score', numeric: true),
            ],
            rows: _sorted.map((c) {
              final selected = c.id == widget.selectedCandidateId;
              return DataRow(
                selected: selected,
                onSelectChanged: (_) => widget.onSelect(c),
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.name,
                            style: const TextStyle(color: Colors.white)),
                        if (c.isYoungDem) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star,
                              color: BrandColors.sunriseGold, size: 14),
                        ],
                      ],
                    ),
                    onTap: widget.onOpen == null
                        ? null
                        : () => widget.onOpen!(c),
                  ),
                  DataCell(Text(c.party,
                      style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(c.office,
                      style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(c.district ?? '—',
                      style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(c.estimatedAge?.toString() ?? '—',
                      style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(c.youngDemScore.toString(),
                      style: const TextStyle(
                          color: BrandColors.sunriseGold,
                          fontWeight: FontWeight.w700))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Mobile alternative: sort dropdown + card list ──
  Widget _buildMobileCardList() {
    const sortOptions = [
      'Name',
      'Party',
      'Office',
      'District',
      'Age',
      'YD Score',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sort control — replaces the column header row, keeps the same
        // sort semantics as the desktop table.
        Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: BrandColors.unityBlue.withOpacity(0.90),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sort, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('Sort by',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _sortColumnIndex,
                    isExpanded: true,
                    dropdownColor: BrandColors.unityBlue,
                    iconEnabledColor: Colors.white70,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [
                      for (int i = 0; i < sortOptions.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(sortOptions[i]),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) _onSort(v, _sortAscending);
                    },
                  ),
                ),
              ),
              // 48×48 asc/desc toggle
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: BrandColors.sunriseGold,
                    size: 18,
                  ),
                  onPressed: () =>
                      _onSort(_sortColumnIndex, !_sortAscending),
                  tooltip: _sortAscending ? 'Ascending' : 'Descending',
                ),
              ),
            ],
          ),
        ),
        // Compact card list — one row per candidate, key fields only.
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
            itemCount: _sorted.length,
            itemBuilder: (_, i) {
              final c = _sorted[i];
              final selected = c.id == widget.selectedCandidateId;
              Color partyColor;
              if (c.isDemocrat) {
                partyColor = BrandColors.democratBlue;
              } else if (c.isRepublican) {
                partyColor = BrandColors.republicanRed;
              } else {
                partyColor = Colors.white38;
              }
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onSelect(c),
                  onLongPress: widget.onOpen == null
                      ? null
                      : () => widget.onOpen!(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? BrandColors.sunriseGold.withOpacity(0.18)
                          : BrandColors.unityBlue.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? BrandColors.sunriseGold.withOpacity(0.7)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Party dot — 10px circle in the candidate's
                        // party color, left-aligned so the eye can scan
                        // a whole list of parties at a glance.
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: partyColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Name + office + district (2 lines, clipped).
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      c.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (c.isYoungDem) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star,
                                        color: BrandColors.sunriseGold,
                                        size: 14),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.office +
                                    (c.district != null && c.district!.isNotEmpty
                                        ? ' • D ${c.district}'
                                        : '') +
                                    (c.estimatedAge != null
                                        ? ' • Age ${c.estimatedAge}'
                                        : ''),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // YD score bubble on the right — the most load-
                        // bearing field in this view.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: BrandColors.sunriseGold
                                    .withOpacity(0.4)),
                          ),
                          child: Text(
                            '${c.youngDemScore}',
                            style: const TextStyle(
                              color: BrandColors.sunriseGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
