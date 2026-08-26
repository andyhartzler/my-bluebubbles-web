import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/election_results_repository.dart';

/// The November general-election field: every 2026 Missouri general-election
/// race, grouped by office type (U.S. Congress, MO Senate, MO House, then
/// Statewide), each race rendered as a "War Room" style card showing the full
/// head-to-head with the advancing Democratic nominee flagged.
///
/// Read-only reference data driven entirely by [ElectionResultsRepository];
/// it does not use the [MissouriMapController] that the Primary field view owns.
class CandidatesGeneralList extends StatefulWidget {
  const CandidatesGeneralList({super.key});

  @override
  State<CandidatesGeneralList> createState() => _CandidatesGeneralListState();
}

/// A single general-election race with its full candidate list (votes-desc).
class _Race {
  _Race({
    required this.officeType,
    required this.district,
    required this.title,
    required this.candidates,
  });

  final String officeType;
  final String? district;
  final String title;
  final List<ElectionResult> candidates;

  bool get hasDemocrat => candidates.any((c) => c.isDemocrat);
  ElectionResult? get demNominee {
    for (final c in candidates) {
      if (c.isDemocrat && c.advanced) return c;
    }
    return null;
  }
}

class _CandidatesGeneralListState extends State<CandidatesGeneralList> {
  final ElectionResultsRepository _repo = ElectionResultsRepository();

  bool _loading = true;
  List<_Race> _all = [];
  String _search = '';

  /// null = All, otherwise 'congressional' | 'senate' | 'house'.
  String? _officeFilter;

  // Group display order and headers.
  static const List<String> _order = [
    'congressional',
    'senate',
    'house',
    'statewide',
  ];
  static const Map<String, String> _groupLabels = {
    'congressional': 'U.S. Congress',
    'senate': 'MO Senate',
    'house': 'MO House',
    'statewide': 'Statewide',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _repo.byDistrict(),
      _repo.generalCandidates(),
    ]);
    final byDistrict = results[0] as Map<String, List<ElectionResult>>;
    final general = results[1] as List<ElectionResult>;

    final races = <_Race>[];

    // Districted races (congressional / senate / house): use the full
    // head-to-head from byDistrict, but only for races that actually field a
    // November nominee (someone advanced).
    byDistrict.forEach((_, list) {
      if (list.isEmpty) return;
      if (!list.any((r) => r.advanced)) return;
      final first = list.first;
      final type = first.officeType;
      if (type != 'congressional' && type != 'senate' && type != 'house') {
        return;
      }
      races.add(_Race(
        officeType: type,
        district: first.district,
        title: _districtTitle(type, first.district),
        candidates: list,
      ));
    });

    // Statewide / other: byDistrict skips null-district rows, so build these
    // from the advancing nominees grouped by their printed office name.
    final byOffice = <String, List<ElectionResult>>{};
    for (final r in general) {
      if (r.officeType == 'statewide' || r.officeType == 'other') {
        (byOffice[r.officeRaw] ??= <ElectionResult>[]).add(r);
      }
    }
    byOffice.forEach((office, list) {
      list.sort((a, b) => b.votes.compareTo(a.votes));
      races.add(_Race(
        officeType: 'statewide',
        district: null,
        title: _titleCase(office),
        candidates: list,
      ));
    });

    if (!mounted) return;
    setState(() {
      _all = races;
      _loading = false;
    });
  }

  static String _districtTitle(String type, String? district) {
    final d = district ?? '';
    switch (type) {
      case 'congressional':
        return 'U.S. House District $d';
      case 'senate':
        return 'MO Senate District $d';
      case 'house':
        return 'MO House District $d';
      default:
        return type;
    }
  }

  static String _titleCase(String s) {
    return s
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  List<_Race> get _filtered {
    Iterable<_Race> xs = _all;
    if (_officeFilter != null) {
      xs = xs.where((r) => r.officeType == _officeFilter);
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      xs = xs.where((r) =>
          (r.district?.toLowerCase().contains(q) ?? false) ||
          r.title.toLowerCase().contains(q) ||
          r.candidates.any((c) => c.candidateName.toLowerCase().contains(q)));
    }
    final list = xs.toList();
    list.sort((a, b) {
      final t = _order.indexOf(a.officeType).compareTo(_order.indexOf(b.officeType));
      if (t != 0) return t;
      final da = int.tryParse(a.district ?? '') ?? 1 << 30;
      final db = int.tryParse(b.district ?? '') ?? 1 << 30;
      if (da != db) return da.compareTo(db);
      return a.title.compareTo(b.title);
    });
    return list;
  }

  static String _formatVotes(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.sunriseGold),
      );
    }

    final filtered = _filtered;
    final demNominees =
        filtered.where((r) => r.demNominee != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(filtered.length, demNominees),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : _buildList(filtered),
        ),
      ],
    );
  }

  Widget _buildTopBar(int raceCount, int demNominees) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _buildOfficeFilter()),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search candidate or district…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 18),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: BrandColors.sunriseGold, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$raceCount races · $demNominees Democratic '
            '${demNominees == 1 ? 'nominee' : 'nominees'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeFilter() {
    const options = <MapEntry<String?, String>>[
      MapEntry(null, 'All'),
      MapEntry('congressional', 'Congress'),
      MapEntry('senate', 'Senate'),
      MapEntry('house', 'House'),
    ];
    return SegmentedButton<String?>(
      segments: options
          .map((o) => ButtonSegment<String?>(
                value: o.key,
                label: Text(o.value, style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
      selected: {_officeFilter},
      onSelectionChanged: (s) => setState(() => _officeFilter = s.first),
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
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.how_to_vote_outlined,
              color: Colors.white24, size: 44),
          const SizedBox(height: 12),
          Text(
            _search.trim().isEmpty
                ? 'No general-election races loaded'
                : 'No races match “${_search.trim()}”',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<_Race> races) {
    // Flatten into a list of section headers + race cards preserving order.
    final items = <Widget>[];
    String? lastType;
    for (final race in races) {
      if (race.officeType != lastType) {
        items.add(_buildGroupHeader(_groupLabels[race.officeType] ?? race.officeType));
        lastType = race.officeType;
      }
      items.add(_buildRaceCard(race));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }

  Widget _buildGroupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceCard(_Race race) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1B2337) : Colors.white;
    final border = dark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFF273351).withOpacity(0.10);
    final titleColor = dark ? Colors.white : const Color(0xFF273351);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            race.title,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          if (!race.hasDemocrat) _buildNoDemocratNote(),
          ...race.candidates.map((c) => _buildCandidateRow(c, dark: dark)),
        ],
      ),
    );
  }

  Widget _buildNoDemocratNote() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFD98A82),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'No Democrat filed',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white60
                  : const Color(0xFF5A6478),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateRow(ElectionResult c, {required bool dark}) {
    final isNominee = c.isDemocrat && c.advanced;
    final nameColor = dark ? Colors.white : const Color(0xFF273351);
    final trackColor =
        dark ? const Color(0xFF313D5E) : const Color(0xFFDFE4EC);
    final fillFraction = ((c.pct ?? 0) / 100).clamp(0.0, 1.0);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _partyChip(c.partyShort, c.party),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.candidateName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: nameColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isNominee) ...[
                      const SizedBox(width: 8),
                      _nomineePill(c.party),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _voteBar(fillFraction, trackColor, isDem: c.isDemocrat),
                const SizedBox(height: 5),
                Text(
                  c.pct != null
                      ? '${_formatVotes(c.votes)} · ${c.pct!.toStringAsFixed(1)}%'
                      : _formatVotes(c.votes),
                  style: const TextStyle(
                    color: Color(0xFF5A6478),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final rowWithRail = isNominee
        ? Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: BrandColors.sunriseGold, width: 3),
              ),
            ),
            padding: const EdgeInsets.only(left: 8),
            child: row,
          )
        : row;

    return InkWell(
      onTap: () => _showDetail(c),
      borderRadius: BorderRadius.circular(8),
      child: rowWithRail,
    );
  }

  Widget _partyChip(String letter, String party) {
    final color = _partyColor(party);
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Color _partyColor(String party) {
    switch (party.isEmpty ? '?' : party[0].toUpperCase()) {
      case 'D':
        return const Color(0xFF1D4ED8);
      case 'R':
        return const Color(0xFFC62828);
      case 'L':
        return const Color(0xFFB45309);
      case 'G':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF546E7A);
    }
  }

  Widget _nomineePill(String party) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _partyColor(party),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'NOMINEE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _voteBar(double fraction, Color track, {required bool isDem}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: track),
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDem
                      ? const LinearGradient(
                          colors: [Color(0xFF32A6DE), Color(0xFF273351)],
                        )
                      : null,
                  color: isDem ? null : const Color(0xFF9AA5B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(ElectionResult c) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? const Color(0xFF1B2337) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final nameColor = dark ? Colors.white : const Color(0xFF273351);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _partyChip(c.partyShort, c.party),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.candidateName,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (c.isDemocrat && c.advanced) _nomineePill(c.party),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                c.officeRaw,
                style: const TextStyle(
                  color: Color(0xFF5A6478),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.party,
                style: TextStyle(
                  color: _partyColor(c.party),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                c.pct != null
                    ? 'Primary result: ${_formatVotes(c.votes)} votes · '
                        '${c.pct!.toStringAsFixed(1)}%'
                    : 'Primary result: ${_formatVotes(c.votes)} votes',
                style: TextStyle(
                  color: nameColor.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
