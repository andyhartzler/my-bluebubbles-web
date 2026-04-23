import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/primary_challenge_pair.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/candidate_new_dialog.dart';
import 'package:bluebubbles/screens/crm/candidates_map_fullscreen.dart';
import 'package:bluebubbles/widgets/crm/missouri_map_widget.dart';

import 'candidate_district_sheet.dart';
import 'candidate_view_mode.dart';
import 'candidates_filter_shelf.dart';
import 'candidates_grid_view.dart';
import 'candidates_hero_stats.dart';
import 'candidates_list_view.dart';
import 'candidates_table_view.dart';
import 'yd_primary_challenger_view.dart';

/// Mobile + tablet landing page for the Candidates section. Stacks the map,
/// hero stats, filter shelf, and chosen view-mode body vertically.
///
/// Desktop ≥1200px uses `CandidatesSplitPage` — this widget is only rendered
/// for widths < 1200.
///
/// Tapping a candidate on mobile opens `CandidateDistrictSheet` (bottom sheet
/// with district-highlighted mini-map + "View candidate" CTA). On tablet
/// (600-1199px) tapping just opens the candidate detail since the map is
/// already visible on the page.
class CandidatesMobilePage extends StatefulWidget {
  const CandidatesMobilePage({super.key});

  @override
  State<CandidatesMobilePage> createState() => _CandidatesMobilePageState();
}

class _CandidatesMobilePageState extends State<CandidatesMobilePage>
    with TickerProviderStateMixin {
  final CandidateRepository _repo = CandidateRepository();
  final MissouriMapController _mapController = MissouriMapController();
  final ScrollController _scrollController = ScrollController();

  // ── Data ──
  bool _loading = true;
  List<Candidate> _all = [];
  List<Candidate> _youngDems = [];
  List<PrimaryChallengePair> _pairs = const [];
  CandidateStats _stats = const CandidateStats();
  Map<String, List<Candidate>> _houseMap = {};
  Map<String, List<Candidate>> _senateMap = {};
  Map<String, List<Candidate>> _congressionalMap = {};

  // ── Filter state ──
  String _search = '';
  String? _party;
  bool _ydOnly = false;

  // Advanced
  bool _filtersExpanded = false;
  Set<String> _partyMulti = {};
  Set<String> _officeLevelMulti = {};
  RangeValues _ageRange = const RangeValues(18, 90);
  bool _hasWebsite = false;
  bool _endorsed = false;
  bool _contacted = false;
  bool _hasFinance = false;

  // View mode + selection
  CandidateViewMode _mode = CandidateViewMode.list;
  Candidate? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _repo.fetchCandidates(limit: 600),
      _repo.fetchYoungDemocrats(),
      _repo.fetchPrimaryChallengePairs(),
      _repo.fetchStats(),
    ]);
    final all = results[0] as List<Candidate>;
    final yds = results[1] as List<Candidate>;
    final pairsRaw = results[2] as List<Map<String, dynamic>>;
    final pairs =
        pairsRaw.map(PrimaryChallengePair.fromJson).toList(growable: false);
    final stats = results[3] as CandidateStats;

    // Merge YD flags (same logic as split page)
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
      _stats = stats;
      _houseMap = h;
      _senateMap = s;
      _congressionalMap = cg;
      _loading = false;
    });
  }

  // ── Derived ──

  List<Candidate> get _filtered {
    Iterable<Candidate> xs = _all;

    // Basic
    if (_party != null) xs = xs.where((c) => c.party == _party);
    if (_ydOnly) xs = xs.where((c) => c.isYoungDem);

    // Advanced
    if (_partyMulti.isNotEmpty) {
      xs = xs.where((c) => _partyMulti.contains(c.party));
    }
    if (_officeLevelMulti.isNotEmpty) {
      xs = xs.where((c) => _officeLevelMulti.contains(c.officeLevel));
    }
    if (_ageRange.start > 18 || _ageRange.end < 90) {
      xs = xs.where((c) {
        if (c.estimatedAge == null) return false;
        return c.estimatedAge! >= _ageRange.start &&
            c.estimatedAge! <= _ageRange.end;
      });
    }
    if (_hasWebsite) {
      xs = xs.where(
          (c) => c.campaignWebsite != null && c.campaignWebsite!.isNotEmpty);
    }
    if (_endorsed) xs = xs.where((c) => c.isEndorsed);
    if (_contacted) xs = xs.where((c) => c.isContacted);
    if (_hasFinance) xs = xs.where((c) => c.hasMecFiled || c.hasFecFiled);

    // Search
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

  int get _activeFilterCount {
    int count = 0;
    if (_party != null) count++;
    if (_ydOnly) count++;
    if (_partyMulti.isNotEmpty) count++;
    if (_officeLevelMulti.isNotEmpty) count++;
    if (_ageRange.start > 18 || _ageRange.end < 90) count++;
    if (_hasWebsite) count++;
    if (_endorsed) count++;
    if (_contacted) count++;
    if (_hasFinance) count++;
    return count;
  }

  // ── Filter mutations ──

  void _clearAllFilters() {
    setState(() {
      _party = null;
      _ydOnly = false;
      _partyMulti = {};
      _officeLevelMulti = {};
      _ageRange = const RangeValues(18, 90);
      _hasWebsite = false;
      _endorsed = false;
      _contacted = false;
      _hasFinance = false;
    });
  }

  // ── Interactions ──

  bool get _isTabletBreakpoint {
    final w = MediaQuery.of(context).size.width;
    return w >= 600;
  }

  Future<void> _onSelectCandidate(Candidate c) async {
    setState(() => _selected = c);
    if (_isTabletBreakpoint) {
      // Tablet: drive the inline map + open profile on any tap.
      if (c.district != null && c.district!.isNotEmpty) {
        await _mapController.zoomToDistrict(
          office: c.office,
          districtNum: c.district,
        );
      } else {
        _mapController.clearHighlight();
      }
      _openCandidateDetail(c);
    } else {
      // Mobile: slide up district-highlighted bottom sheet.
      await showCandidateDistrictSheet(
        context: context,
        candidate: c,
        houseDistricts: _houseMap,
        senateDistricts: _senateMap,
        congressionalDistricts: _congressionalMap,
        onViewProfile: () => _openCandidateDetail(c),
        onOpenFullMap: () => _openFullscreenMap(initialDistrict: c.district),
      );
    }
  }

  void _openCandidateDetail(Candidate c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CandidateDetailScreen(candidate: c)),
    );
  }

  void _openFullscreenMap({String? initialDistrict}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => CandidatesMapFullscreen(
          allCandidates: _all,
          houseDistricts: _houseMap,
          senateDistricts: _senateMap,
          congressionalDistricts: _congressionalMap,
          initialDistrict: initialDistrict,
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _onAdd() async {
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
        backgroundColor: BrandColors.error,
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Created ${created.name}'),
      backgroundColor: BrandColors.success,
    ));
    await _load();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.sunriseGold),
      );
    }

    final filtered = _filtered;
    final isTablet = _isTabletBreakpoint;

    return LayoutBuilder(builder: (context, constraints) {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          // HERO MAP (collapsible on mobile, wider on tablet)
          SliverToBoxAdapter(
            child: _buildHeroMap(constraints.maxWidth, isTablet: isTablet),
          ),
          // HERO STATS
          SliverToBoxAdapter(
            child: CandidatesHeroStats(
              stats: _stats,
              totalCandidates: _all.length,
              primaryChallengerCount: computePrimaryChallengerCount(_all),
              uncontestedRepublicanCount:
                  computeUncontestedRepublicanCount(_all),
              ydActive: _ydOnly,
              endorsedActive: _endorsed,
              onToggleYd: () => setState(() => _ydOnly = !_ydOnly),
              onToggleEndorsed: () => setState(() => _endorsed = !_endorsed),
              onTapPrimaryChallengers: () {
                setState(() {
                  _mode = CandidateViewMode.ydPrimary;
                });
                _scrollToBody();
              },
              onTapUncontested: () {
                setState(() {
                  _partyMulti = {'Republican'};
                  _filtersExpanded = true;
                });
                _scrollToBody();
              },
            ),
          ),
          // FILTER SHELF
          SliverToBoxAdapter(
            child: _ShelfSurface(
              child: CandidatesFilterShelf(
                searchQuery: _search,
                onSearchChanged: (v) => setState(() => _search = v),
                partyFilter: _party,
                onPartyFilterChanged: (p) => setState(() => _party = p),
                ydOnly: _ydOnly,
                onToggleYdOnly: () => setState(() => _ydOnly = !_ydOnly),
                expanded: _filtersExpanded,
                onToggleExpanded: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                activeFilterCount: _activeFilterCount,
                onClearAll: _clearAllFilters,
                partyMultiSelect: _partyMulti,
                onPartyMultiSelectChanged: (s) =>
                    setState(() => _partyMulti = s),
                officeLevelMultiSelect: _officeLevelMulti,
                onOfficeLevelMultiSelectChanged: (s) =>
                    setState(() => _officeLevelMulti = s),
                ageRange: _ageRange,
                onAgeRangeChanged: (r) => setState(() => _ageRange = r),
                hasCampaignWebsite: _hasWebsite,
                onHasCampaignWebsiteChanged: (v) =>
                    setState(() => _hasWebsite = v),
                moydContacted: _contacted,
                onMoydContactedChanged: (v) =>
                    setState(() => _contacted = v),
                moydEndorsed: _endorsed,
                onMoydEndorsedChanged: (v) =>
                    setState(() => _endorsed = v),
                hasFinanceFiled: _hasFinance,
                onHasFinanceFiledChanged: (v) =>
                    setState(() => _hasFinance = v),
                mode: _mode,
                onModeChanged: (m) => setState(() => _mode = m),
                filteredCount: filtered.length,
                totalCount: _all.length,
              ),
            ),
          ),
          // HEADER STRIP above list
          SliverToBoxAdapter(child: _buildListHeader(filtered.length)),
          // ─── BODY ──
          SliverToBoxAdapter(
            child: SizedBox(
              // Give the list a tall enough sliver to be scrollable inside
              // the CustomScrollView. 80vh works well on phones.
              height:
                  (constraints.maxHeight * 0.82).clamp(320.0, 1200.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildBody(filtered),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      );
    });
  }

  // Map with tap-to-fullscreen. On mobile narrower / shorter; on tablet wider.
  Widget _buildHeroMap(double w, {required bool isTablet}) {
    final mapHeight = isTablet ? 420.0 : 280.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BrandColors.unityBlue.withOpacity(0.96),
            BrandColors.momentumBlue.withOpacity(0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: BrandColors.sunriseGold.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.map_outlined,
                    color: BrandColors.sunriseGold, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Missouri districts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: BrandColors.sunriseGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: BrandColors.sunriseGold.withOpacity(0.40)),
                  ),
                  child: Text(
                    '${_all.length} filed',
                    style: const TextStyle(
                      color: BrandColors.sunriseGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _openFullscreenMap(),
                  icon: const Icon(Icons.fullscreen,
                      color: BrandColors.sunriseGold, size: 20),
                  tooltip: 'Open fullscreen',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        BrandColors.sunriseGold.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          SizedBox(
            height: mapHeight,
            child: MissouriMapWidget(
              controller: _mapController,
              houseDistrictMap: _houseMap,
              senateDistrictMap: _senateMap,
              congressionalDistrictMap: _congressionalMap,
              selectedDistrict: _selected?.district,
              highlightedDistrict: _selected?.district,
              height: mapHeight,
              compactMode: true,
              showLegend: false,
              showLabels: true,
              interactive: true,
              onDistrictTap: (district, type) {
                _openFullscreenMap(initialDistrict: district);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          const Icon(Icons.people_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            _mode == CandidateViewMode.ydPrimary
                ? 'Young-Dem primary challenges'
                : 'Candidates · $count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _onAdd,
            icon: const Icon(Icons.person_add_rounded, size: 14),
            label: const Text('Add'),
            style: TextButton.styleFrom(
              foregroundColor: BrandColors.sunriseGold,
              backgroundColor: BrandColors.sunriseGold.withOpacity(0.10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Candidate> filtered) {
    final selId = _selected?.id;
    switch (_mode) {
      case CandidateViewMode.list:
        return CandidatesListView(
          candidates: filtered,
          selectedCandidateId: selId,
          onSelect: _onSelectCandidate,
          onOpen: _openCandidateDetail,
        );
      case CandidateViewMode.grid:
        return CandidatesGridView(
          candidates: filtered,
          selectedCandidateId: selId,
          onSelect: _onSelectCandidate,
          onOpen: _openCandidateDetail,
        );
      case CandidateViewMode.table:
        return CandidatesTableView(
          candidates: filtered,
          selectedCandidateId: selId,
          onSelect: _onSelectCandidate,
          onOpen: _openCandidateDetail,
        );
      case CandidateViewMode.ydPrimary:
        return YdPrimaryChallengerView(
          rpcPairs: _pairs,
          allCandidates: _all,
          allYoungDems: _youngDems,
          selectedCandidateId: selId,
          onSelect: _onSelectCandidate,
          onOpen: _openCandidateDetail,
        );
    }
  }

  void _scrollToBody() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * 0.5,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}

/// Thin surface around the filter shelf so it reads as one cohesive pane.
class _ShelfSurface extends StatelessWidget {
  final Widget child;
  const _ShelfSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: child,
    );
  }
}
