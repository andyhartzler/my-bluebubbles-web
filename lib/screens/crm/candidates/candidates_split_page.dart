import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/primary_challenge_pair.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/candidate_new_dialog.dart';
import 'package:bluebubbles/widgets/crm/missouri_map_widget.dart';

import 'candidate_view_mode.dart';
import 'candidates_general_list.dart';
import 'candidates_list_panel.dart';

/// Desktop split-screen Candidates page. Left pane is the [CandidatesListPanel]
/// (search + view-mode toggle + list), right pane is a sticky, full-height
/// [MissouriMapWidget] that the list drives via [MissouriMapController].
///
/// Selecting any candidate in the list fires [_onSelect] which calls
/// `_mapController.zoomToDistrict(...)` so the map zooms + paints a gold ring
/// on the candidate's district in real time.
class CandidatesSplitPage extends StatefulWidget {
  const CandidatesSplitPage({super.key});

  @override
  State<CandidatesSplitPage> createState() => _CandidatesSplitPageState();
}

class _CandidatesSplitPageState extends State<CandidatesSplitPage> {
  final CandidateRepository _repo = CandidateRepository();
  final MissouriMapController _mapController = MissouriMapController();

  bool _loading = true;
  List<Candidate> _all = [];
  List<Candidate> _youngDems = [];
  List<PrimaryChallengePair> _pairs = const [];

  CandidateViewMode _mode = CandidateViewMode.list;
  bool _showGeneral = false;
  String _search = '';
  String? _party;
  bool _ydOnly = false;

  Candidate? _selected;

  // District maps for the MissouriMapWidget
  Map<String, List<Candidate>> _houseMap = {};
  Map<String, List<Candidate>> _senateMap = {};
  Map<String, List<Candidate>> _congressionalMap = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _repo.fetchAllCandidates(),
      _repo.fetchYoungDemocrats(),
      _repo.fetchPrimaryChallengePairs(),
    ]);

    final all = results[0] as List<Candidate>;
    final yds = results[1] as List<Candidate>;
    final pairsRaw = results[2] as List<Map<String, dynamic>>;
    final pairs =
        pairsRaw.map(PrimaryChallengePair.fromJson).toList(growable: false);

    // Merge is_young_dem from the dedicated YD query (same logic as legacy page)
    final ydIds = yds.map((c) => c.id).toSet();
    final merged = all.map((c) {
      if (!c.isYoungDem && ydIds.contains(c.id)) {
        final age = c.estimatedAge;
        if (age == null || age <= 36) return c.copyWith(isYoungDem: true);
      }
      return c;
    }).toList();
    for (final yd in yds) {
      if (!merged.any((c) => c.id == yd.id)) merged.add(yd);
    }

    // Build per-level district maps
    final h = <String, List<Candidate>>{};
    final s = <String, List<Candidate>>{};
    final cg = <String, List<Candidate>>{};
    for (final c in merged) {
      final d = c.district;
      if (d == null || d.isEmpty) continue;
      final o = c.office.toLowerCase();
      final level = (c.officeLevel ?? '').toLowerCase();
      if (level == 'federal' ||
          o.contains('congress') ||
          o.contains('u.s. rep') ||
          o.contains('us rep')) {
        cg.putIfAbsent(d, () => []).add(c);
      } else if (o.contains('senate') || o.contains('senator')) {
        s.putIfAbsent(d, () => []).add(c);
      } else {
        h.putIfAbsent(d, () => []).add(c);
      }
    }

    if (!mounted) return;
    setState(() {
      _all = merged;
      _youngDems = yds;
      _pairs = pairs;
      _houseMap = h;
      _senateMap = s;
      _congressionalMap = cg;
      _loading = false;
    });
  }

  List<Candidate> get _filtered {
    Iterable<Candidate> xs = _all;
    if (_party != null) xs = xs.where((c) => c.party == _party);
    if (_ydOnly) xs = xs.where((c) => c.isYoungDem);
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      xs = xs.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.office.toLowerCase().contains(q) ||
          (c.district?.toLowerCase().contains(q) ?? false) ||
          (c.occupation?.toLowerCase().contains(q) ?? false));
    }
    final list = xs.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _onSelect(Candidate c) {
    setState(() => _selected = c);
    if (c.district != null && c.district!.isNotEmpty) {
      _mapController.zoomToDistrict(
          office: c.office, districtNum: c.district);
    } else {
      _mapController.clearHighlight();
    }
  }

  void _onOpen(Candidate c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CandidateDetailScreen(candidate: c)),
    );
  }

  Future<void> _onAddCandidate() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const CandidateNewDialog(),
    );
    if (data == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final created = await _repo.createCandidate(data);
    if (!mounted) return;
    if (created == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to create candidate'),
          backgroundColor: BrandColors.error));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Created ${created.name}'),
      backgroundColor: BrandColors.success,
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.sunriseGold),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldTabBar(),
        Expanded(
          child: _showGeneral
              ? const CandidatesGeneralList()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
        // LEFT: list panel (60%)
        Expanded(
          flex: 6,
          child: CandidatesListPanel(
            filtered: _filtered,
            allCandidates: _all,
            allYoungDems: _youngDems,
            primaryPairs: _pairs,
            totalCount: _all.length,
            mode: _mode,
            onModeChanged: (m) => setState(() => _mode = m),
            searchQuery: _search,
            onSearchChanged: (v) => setState(() => _search = v),
            partyFilter: _party,
            onPartyFilterChanged: (p) => setState(() => _party = p),
            ydOnly: _ydOnly,
            onToggleYdOnly: () => setState(() => _ydOnly = !_ydOnly),
            selectedCandidateId: _selected?.id,
            onSelect: _onSelect,
            onOpen: _onOpen,
            onAddCandidate: _onAddCandidate,
          ),
        ),
        Container(width: 2, color: Colors.white10),
        // RIGHT: sticky map (40%)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildStickyMap(),
          ),
        ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Compact Primary/General segmented toggle at the top of the Field body.
  /// Primary renders exactly today's split view; General renders the November
  /// general-election field. Styled like the list panel's view-mode control.
  Widget _buildFieldTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Primary', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('General', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_showGeneral},
            onSelectionChanged: (s) => setState(() => _showGeneral = s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStickyMap() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue.withOpacity(0.95),
            BrandColors.momentumBlue.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: BrandColors.sunriseGold.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined,
                    color: BrandColors.sunriseGold, size: 20),
                const SizedBox(width: 8),
                const Text('Missouri districts',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_selected != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: BrandColors.sunriseGold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: BrandColors.sunriseGold.withOpacity(0.55)),
                      ),
                      child: Text(
                        _selected!.district != null
                            ? _selected!.officeDisplay
                            : _selected!.name,
                        style: const TextStyle(
                            color: BrandColors.sunriseGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: MissouriMapWidget(
              controller: _mapController,
              houseDistrictMap: _houseMap,
              senateDistrictMap: _senateMap,
              congressionalDistrictMap: _congressionalMap,
              selectedDistrict: _selected?.district,
              highlightedDistrict: _selected?.district,
              height: double.infinity,
              showLegend: true,
              showLabels: true,
              interactive: true,
              compactMode: true,
            ),
          ),
        ],
      ),
    );
  }
}
