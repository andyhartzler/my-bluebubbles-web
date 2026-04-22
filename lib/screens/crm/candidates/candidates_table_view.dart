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
}
