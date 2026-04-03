import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATES INTELLIGENCE PAGE
//  A stunning, data-rich view into the 2026 Missouri races
//
//  Features:
//  • Interactive Missouri map with district dots
//  • Young Democrat spotlight carousel
//  • Bulk selection mode with toolbar
//  • Advanced filter panel (expandable)
//  • Analytics section (collapsible)
//  • Full candidate list with sort/filter
//  • CSV export, bulk assign, bulk email
// ═══════════════════════════════════════════════════════════════

class CandidatesPage extends StatefulWidget {
  const CandidatesPage({super.key});

  @override
  State<CandidatesPage> createState() => _CandidatesPageState();
}

class _CandidatesPageState extends State<CandidatesPage>
    with TickerProviderStateMixin {
  final CandidateRepository _repo = CandidateRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Data ──
  List<Candidate> _allCandidates = [];
  List<Candidate> _filteredCandidates = [];
  List<Candidate> _youngDems = [];
  CandidateStats _stats = const CandidateStats();
  Map<String, List<Candidate>> _districtMap = {};

  // ── Basic Filters ──
  String? _partyFilter;
  String? _officeLevelFilter;
  String? _districtFilter;
  bool _ydOnly = false;
  String _sortBy = 'name';
  bool _sortAscending = true;

  // ── Advanced Filters ──
  bool _showAdvancedFilters = false;
  Set<String> _partyMultiSelect = {};
  Set<String> _officeLevelMultiSelect = {};
  RangeValues _districtRange = const RangeValues(1, 163);
  RangeValues _ageRange = const RangeValues(18, 90);
  bool _hasCampaignWebsite = false;
  bool _hasSocialMedia = false;
  bool _moydContacted = false;
  bool _moydEndorsed = false;
  RangeValues _fundraisingRange = const RangeValues(0, 500000);

  // ── Bulk Selection ──
  bool _bulkMode = false;
  Set<String> _selectedIds = {};

  // ── Analytics ──
  bool _showAnalytics = false;
  Map<String, Map<String, int>> _partyBreakdown = {};
  Map<String, int> _contestationBreakdown = {};

  // ── State ──
  bool _loading = true;
  String? _selectedMapDistrict;
  List<Candidate>? _selectedDistrictCandidates;

  // ── Animation ──
  late AnimationController _statsAnimController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _statsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _statsAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _repo.fetchCandidates(limit: 600),
      _repo.fetchYoungDemocrats(),
      _repo.fetchStats(),
    ]);

    final allCandidates = results[0] as List<Candidate>;
    final youngDems = results[1] as List<Candidate>;
    final stats = results[2] as CandidateStats;

    // Build district map for state-level candidates
    final districtMap = <String, List<Candidate>>{};
    for (final c in allCandidates) {
      if (c.officeLevel == 'state' && c.district != null && c.district!.isNotEmpty) {
        districtMap.putIfAbsent(c.district!, () => []).add(c);
      }
    }

    if (!mounted) return;

    setState(() {
      _allCandidates = allCandidates;
      _youngDems = youngDems;
      _stats = stats;
      _districtMap = districtMap;
      _loading = false;
      _applyFilters();
    });

    _statsAnimController.forward();

    // Load analytics data in background
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final results = await Future.wait([
        _repo.fetchPartyBreakdown(),
        _repo.fetchContestationBreakdown(),
      ]);
      if (mounted) {
        setState(() {
          _partyBreakdown = results[0] as Map<String, Map<String, int>>;
          _contestationBreakdown = results[1] as Map<String, int>;
        });
      }
    } catch (e) {
      debugPrint('❌ Analytics load error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  FILTER LOGIC
  // ═══════════════════════════════════════════════════════════════

  void _applyFilters() {
    var candidates = List<Candidate>.from(_allCandidates);

    // Search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      candidates = candidates
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              (c.district?.toLowerCase().contains(query) ?? false) ||
              c.office.toLowerCase().contains(query) ||
              (c.occupation?.toLowerCase().contains(query) ?? false) ||
              (c.assignedTo?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Basic party filter (single select from chips)
    if (_partyFilter != null) {
      candidates = candidates.where((c) => c.party == _partyFilter).toList();
    }

    // Advanced: party multi-select
    if (_partyMultiSelect.isNotEmpty) {
      candidates = candidates.where((c) => _partyMultiSelect.contains(c.party)).toList();
    }

    // Basic office level
    if (_officeLevelFilter != null) {
      candidates = candidates.where((c) => c.officeLevel == _officeLevelFilter).toList();
    }

    // Advanced: office level multi-select
    if (_officeLevelMultiSelect.isNotEmpty) {
      candidates = candidates.where((c) => _officeLevelMultiSelect.contains(c.officeLevel)).toList();
    }

    // District filter
    if (_districtFilter != null) {
      candidates = candidates.where((c) => c.district == _districtFilter).toList();
    }

    // Advanced: district range
    if (_showAdvancedFilters && (_districtRange.start > 1 || _districtRange.end < 163)) {
      candidates = candidates.where((c) {
        final d = int.tryParse(c.district ?? '');
        if (d == null) return true; // Keep non-district candidates
        return d >= _districtRange.start && d <= _districtRange.end;
      }).toList();
    }

    // Advanced: age range
    if (_showAdvancedFilters && (_ageRange.start > 18 || _ageRange.end < 90)) {
      candidates = candidates.where((c) {
        if (c.estimatedAge == null) return false;
        return c.estimatedAge! >= _ageRange.start && c.estimatedAge! <= _ageRange.end;
      }).toList();
    }

    // YD only
    if (_ydOnly) {
      candidates = candidates.where((c) => c.isYoungDem).toList();
    }

    // Advanced toggles
    if (_hasCampaignWebsite) {
      candidates = candidates.where((c) => c.campaignWebsite != null && c.campaignWebsite!.isNotEmpty).toList();
    }
    if (_hasSocialMedia) {
      candidates = candidates.where((c) => c.hasSocialLinks).toList();
    }
    if (_moydContacted) {
      candidates = candidates.where((c) => c.isContacted).toList();
    }
    if (_moydEndorsed) {
      candidates = candidates.where((c) => c.isEndorsed).toList();
    }

    // Sort
    candidates.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'age':
          cmp = (a.estimatedAge ?? 999).compareTo(b.estimatedAge ?? 999);
          break;
        case 'district':
          final ai = int.tryParse(a.district ?? '') ?? 999;
          final bi = int.tryParse(b.district ?? '') ?? 999;
          cmp = ai.compareTo(bi);
          break;
        case 'filing_date':
          cmp = (a.filingDate ?? '').compareTo(b.filingDate ?? '');
          break;
        case 'score':
          cmp = b.youngDemScore.compareTo(a.youngDemScore);
          break;
        case 'party':
          cmp = a.party.compareTo(b.party);
          break;
        default:
          cmp = a.name.compareTo(b.name);
      }
      return _sortAscending ? cmp : -cmp;
    });

    setState(() => _filteredCandidates = candidates);
  }

  void _resetAdvancedFilters() {
    setState(() {
      _partyMultiSelect = {};
      _officeLevelMultiSelect = {};
      _districtRange = const RangeValues(1, 163);
      _ageRange = const RangeValues(18, 90);
      _hasCampaignWebsite = false;
      _hasSocialMedia = false;
      _moydContacted = false;
      _moydEndorsed = false;
      _fundraisingRange = const RangeValues(0, 500000);
    });
    _applyFilters();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_partyMultiSelect.isNotEmpty) count++;
    if (_officeLevelMultiSelect.isNotEmpty) count++;
    if (_districtRange.start > 1 || _districtRange.end < 163) count++;
    if (_ageRange.start > 18 || _ageRange.end < 90) count++;
    if (_hasCampaignWebsite) count++;
    if (_hasSocialMedia) count++;
    if (_moydContacted) count++;
    if (_moydEndorsed) count++;
    return count;
  }

  // ═══════════════════════════════════════════════════════════════
  //  BULK ACTIONS
  // ═══════════════════════════════════════════════════════════════

  void _toggleBulkMode() {
    setState(() {
      _bulkMode = !_bulkMode;
      if (!_bulkMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredCandidates.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _filteredCandidates.map((c) => c.id).toSet();
      }
    });
  }

  Future<void> _bulkExportCSV() async {
    final ids = _selectedIds.isNotEmpty ? _selectedIds.toList() : null;
    final csv = await _repo.exportCandidatesCsv(candidateIds: ids);
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ids?.length ?? _filteredCandidates.length} candidates exported to clipboard'),
          backgroundColor: BrandColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _bulkAssignTo() async {
    if (_selectedIds.isEmpty) return;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _BulkAssignDialog(),
    );

    if (result != null && result.isNotEmpty) {
      await _repo.bulkAssign(_selectedIds.toList(), result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedIds.length} candidates assigned to $result'),
            backgroundColor: BrandColors.success,
          ),
        );
        setState(() {
          _bulkMode = false;
          _selectedIds.clear();
        });
        _loadData();
      }
    }
  }

  Future<void> _bulkEmail() async {
    if (_selectedIds.isEmpty) return;

    final selectedCandidates = _allCandidates.where((c) => _selectedIds.contains(c.id)).toList();
    final emails = selectedCandidates
        .where((c) => c.email != null && c.email!.isNotEmpty)
        .map((c) => c.email!)
        .toList();

    if (emails.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email addresses found for selected candidates'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final emailStr = emails.join(',');
    await Clipboard.setData(ClipboardData(text: emailStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${emails.length} email addresses copied to clipboard'),
          backgroundColor: BrandColors.success,
        ),
      );
    }
  }

  Future<void> _bulkMarkContacted() async {
    if (_selectedIds.isEmpty) return;

    await _repo.bulkMarkContacted(_selectedIds.toList(), 'bulk');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedIds.length} candidates marked as contacted'),
          backgroundColor: BrandColors.success,
        ),
      );
      setState(() {
        _bulkMode = false;
        _selectedIds.clear();
      });
      _loadData();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  void _openCandidate(Candidate candidate) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CandidateDetailScreen(candidate: candidate),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.sunriseGold),
      );
    }

    return Column(
      children: [
        // ── Bulk Actions Toolbar (when in bulk mode) ──
        if (_bulkMode) _buildBulkToolbar(),

        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Missouri Map Hero ──
              SliverToBoxAdapter(child: _buildMapSection()),

              // ── Stats Bar ──
              SliverToBoxAdapter(child: _buildStatsBar()),

              // ── Young Democrat Spotlight ──
              if (_youngDems.isNotEmpty)
                SliverToBoxAdapter(child: _buildYdSpotlight()),

              // ── Analytics Section (collapsible) ──
              SliverToBoxAdapter(child: _buildAnalyticsToggle()),
              if (_showAnalytics)
                SliverToBoxAdapter(child: _buildAnalyticsSection()),

              // ── Filters + Search ──
              SliverToBoxAdapter(child: _buildFiltersSection()),

              // ── Advanced Filters (expandable) ──
              if (_showAdvancedFilters)
                SliverToBoxAdapter(child: _buildAdvancedFilters()),

              // ── Candidate List ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildCandidateRow(_filteredCandidates[index]),
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

  // ═══════════════════════════════════════════════════════════════
  //  BULK ACTIONS TOOLBAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBulkToolbar() {
    final allSelected = _selectedIds.length == _filteredCandidates.length && _filteredCandidates.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.momentumBlue.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.momentumBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Select all checkbox
            GestureDetector(
              onTap: _selectAll,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: allSelected ? BrandColors.sunriseGold : Colors.white54,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedIds.length} selected',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            // Action buttons
            _bulkActionBtn(Icons.email, 'Email', _bulkEmail),
            _bulkActionBtn(Icons.download, 'CSV', _bulkExportCSV),
            _bulkActionBtn(Icons.person_add, 'Assign', _bulkAssignTo),
            _bulkActionBtn(Icons.check_circle_outline, 'Contacted', _bulkMarkContacted),
            const SizedBox(width: 4),
            // Close bulk mode
            GestureDetector(
              onTap: _toggleBulkMode,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulkActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: _selectedIds.isEmpty ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _selectedIds.isEmpty
                ? Colors.white.withOpacity(0.05)
                : BrandColors.sunriseGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _selectedIds.isEmpty
                  ? Colors.white12
                  : BrandColors.sunriseGold.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _selectedIds.isEmpty ? Colors.white30 : BrandColors.sunriseGold),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: _selectedIds.isEmpty ? Colors.white30 : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MISSOURI MAP — Interactive district visualization
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMapSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue.withOpacity(0.9),
            BrandColors.unityBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BrandColors.momentumBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: BrandColors.sunriseGold, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Missouri 2026 — State House Districts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildMapLegend(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: MissouriMapPainter(
                      districtMap: _districtMap,
                      selectedDistrict: _selectedMapDistrict,
                      pulseValue: _pulseAnimation.value,
                    ),
                    size: Size.infinite,
                    child: GestureDetector(
                      onTapDown: (details) =>
                          _handleMapTap(details, context),
                    ),
                  );
                },
              ),
            ),
          ),
          // Selected district info
          if (_selectedMapDistrict != null &&
              _selectedDistrictCandidates != null)
            _buildDistrictPopup(),
        ],
      ),
    );
  }

  Widget _buildMapLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(BrandColors.momentumBlue, 'YD'),
        const SizedBox(width: 8),
        _legendDot(Colors.blueGrey, 'Dem'),
        const SizedBox(width: 8),
        _legendDot(BrandColors.republicanRed, 'GOP'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  void _handleMapTap(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final pos = details.localPosition;

    final cols = 16;
    final rows = 11;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final col = (pos.dx / cellW).floor().clamp(0, cols - 1);
    final row = (pos.dy / cellH).floor().clamp(0, rows - 1);

    final districtNum = row * cols + col + 1;
    final district = districtNum.toString();

    if (_districtMap.containsKey(district)) {
      setState(() {
        _selectedMapDistrict = district;
        _selectedDistrictCandidates = _districtMap[district];
      });
    } else {
      final closest = _findClosestDistrict(districtNum);
      if (closest != null) {
        setState(() {
          _selectedMapDistrict = closest;
          _selectedDistrictCandidates = _districtMap[closest];
        });
      }
    }
  }

  String? _findClosestDistrict(int target) {
    String? best;
    int bestDist = 999;
    for (final d in _districtMap.keys) {
      final n = int.tryParse(d) ?? 999;
      final dist = (n - target).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = d;
      }
    }
    return bestDist <= 5 ? best : null;
  }

  Widget _buildDistrictPopup() {
    final candidates = _selectedDistrictCandidates!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'District $_selectedMapDistrict',
                style: const TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedMapDistrict = null;
                  _selectedDistrictCandidates = null;
                }),
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...candidates.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _openCandidate(c),
                  child: Row(
                    children: [
                      _partyBadge(c),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      if (c.isYoungDem) _ydBadge(),
                      if (c.estimatedAge != null)
                        Text(
                          'Age ${c.estimatedAge}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 18),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STATS BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedBuilder(
        animation: _statsAnimController,
        builder: (context, _) {
          final progress = CurvedAnimation(
            parent: _statsAnimController,
            curve: Curves.easeOut,
          ).value;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statCard(
                  Icons.people,
                  '${(_stats.totalCandidates * progress).round()}',
                  'Total Filed',
                  BrandColors.momentumBlue,
                ),
                _statCard(
                  Icons.how_to_vote,
                  '${(_stats.democrats * progress).round()}',
                  'Democrats',
                  BrandColors.democratBlue,
                ),
                _statCard(
                  Icons.star,
                  '${(_stats.youngDemocrats * progress).round()}',
                  'Young Dems',
                  BrandColors.sunriseGold,
                ),
                _statCard(
                  Icons.check_circle,
                  '${(_stats.uncontestedDemSeats * progress).round()}',
                  'Uncontested (D)',
                  BrandColors.success,
                ),
                _statCard(
                  Icons.cake,
                  _stats.averageYdAge > 0
                      ? '${(_stats.averageYdAge * progress).toStringAsFixed(1)}'
                      : '—',
                  'Avg YD Age',
                  Colors.purpleAccent,
                ),
                _statCard(
                  Icons.thumb_up,
                  '${(_stats.endorsed * progress).round()}',
                  'Endorsed',
                  BrandColors.sunriseGold,
                ),
                _statCard(
                  Icons.phone_in_talk,
                  '${(_stats.contacted * progress).round()}',
                  'Contacted',
                  BrandColors.success,
                ),
                _statCard(
                  Icons.language,
                  '${(_stats.withWebsite * progress).round()}',
                  'Has Website',
                  BrandColors.steelBlue,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color accent) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue,
            BrandColors.unityBlue.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  YOUNG DEMOCRAT SPOTLIGHT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildYdSpotlight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.star, color: BrandColors.sunriseGold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Young Democrat Spotlight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_youngDems.length} candidates',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _youngDems.length,
            itemBuilder: (context, index) =>
                _buildYdCard(_youngDems[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildYdCard(Candidate c, int index) {
    final gradients = [
      [const Color(0xFF1E3A5F), BrandColors.momentumBlue],
      [const Color(0xFF2B4B8C), const Color(0xFF4682B4)],
      [const Color(0xFF273351), const Color(0xFF3B82F6)],
      [const Color(0xFF1E3A5F), const Color(0xFF6366F1)],
    ];
    final colors = gradients[index % gradients.length];

    return GestureDetector(
      onTap: () => _openCandidate(c),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[1].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    backgroundImage:
                        c.photoUrl != null && c.photoUrl!.isNotEmpty
                            ? NetworkImage(c.photoUrl!)
                            : null,
                    child: c.photoUrl == null || c.photoUrl!.isEmpty
                        ? Text(
                            c.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BrandColors.sunriseGold.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'YD ${c.youngDemScore}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (c.estimatedAge != null)
                Text(
                  'Age ${c.estimatedAge}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              const Spacer(),
              Text(
                c.district != null ? 'District ${c.district}' : c.office,
                style: TextStyle(
                  color: BrandColors.sunriseGold.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ANALYTICS SECTION (collapsible)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAnalyticsToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: GestureDetector(
        onTap: () => setState(() => _showAnalytics = !_showAnalytics),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                BrandColors.unityBlue,
                _showAnalytics ? BrandColors.momentumBlue.withOpacity(0.4) : BrandColors.unityBlue.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showAnalytics ? BrandColors.sunriseGold.withOpacity(0.4) : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.analytics,
                color: _showAnalytics ? BrandColors.sunriseGold : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Analytics Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(
                _showAnalytics ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          // ── Row 1: Party Breakdown + Age Distribution ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPartyPieChart()),
              const SizedBox(width: 8),
              Expanded(child: _buildAgeHistogram()),
            ],
          ),
          const SizedBox(height: 8),

          // ── Row 2: Contestation + Uncontested ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildContestationCard()),
              const SizedBox(width: 8),
              Expanded(child: _buildUncontestedCard()),
            ],
          ),
          const SizedBox(height: 8),

          // ── Fundraising Leaderboard ──
          _buildFundraisingLeaderboard(),
          const SizedBox(height: 8),

          // ── Districts with No Democrat ──
          _buildNoDemocratDistricts(),
        ],
      ),
    );
  }

  Widget _buildPartyPieChart() {
    final dem = _stats.democrats;
    final rep = _stats.republicans;
    final other = _stats.totalCandidates - dem - rep;
    final total = _stats.totalCandidates;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart, color: BrandColors.momentumBlue, size: 16),
              const SizedBox(width: 6),
              const Text('Party Split', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          // Simple visual pie representation
          SizedBox(
            height: 100,
            width: 100,
            child: CustomPaint(
              painter: _PieChartPainter(
                segments: [
                  _PieSegment(dem.toDouble(), BrandColors.democratBlue),
                  _PieSegment(rep.toDouble(), BrandColors.republicanRed),
                  _PieSegment(other.toDouble(), Colors.amber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _pieLegendRow('Democrat', dem, total, BrandColors.democratBlue),
          _pieLegendRow('Republican', rep, total, BrandColors.republicanRed),
          if (other > 0) _pieLegendRow('Other', other, total, Colors.amber),
        ],
      ),
    );
  }

  Widget _pieLegendRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))),
          Text('$count ($pct%)', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAgeHistogram() {
    final ageDist = _stats.ageDistribution;
    final categories = ['under25', '25-35', '36-50', '51-65', 'over65'];
    final labels = ['<25', '25-35', '36-50', '51-65', '65+'];
    final maxVal = categories.fold<int>(0, (max, key) => math.max(max, ageDist[key] ?? 0));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.purpleAccent, size: 16),
              const SizedBox(width: 6),
              const Text('Age Distribution', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(categories.length, (i) {
                final val = ageDist[categories[i]] ?? 0;
                final h = maxVal > 0 ? (val / maxVal) * 80 : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$val', style: const TextStyle(color: Colors.white54, fontSize: 8)),
                        const SizedBox(height: 2),
                        Container(
                          height: h.clamp(4.0, 80.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purpleAccent.withOpacity(0.7), BrandColors.momentumBlue],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(labels[i], style: const TextStyle(color: Colors.white38, fontSize: 8)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContestationCard() {
    final contested = _contestationBreakdown['contested'] ?? 0;
    final uncontestedDem = _contestationBreakdown['uncontested_dem'] ?? 0;
    final uncontestedRep = _contestationBreakdown['uncontested_rep'] ?? 0;
    final total = _contestationBreakdown['total_districts'] ?? 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              const Text('Race Status', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _contestRow('Contested', contested, total, Colors.amber),
          _contestRow('Uncontested (D)', uncontestedDem, total, BrandColors.democratBlue),
          _contestRow('Uncontested (R)', uncontestedRep, total, BrandColors.republicanRed),
          const SizedBox(height: 6),
          Text('$total total districts', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _contestRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUncontestedCard() {
    final uncontestedDem = _contestationBreakdown['uncontested_dem'] ?? 0;
    final uncontestedRep = _contestationBreakdown['uncontested_rep'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Uncontested', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Big number
          Center(
            child: Column(
              children: [
                Text(
                  '$uncontestedRep',
                  style: const TextStyle(color: BrandColors.republicanRed, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'GOP seats with\nno Dem filed',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BrandColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check, color: BrandColors.success, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$uncontestedDem Dem seats uncontested',
                  style: const TextStyle(color: BrandColors.success, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundraisingLeaderboard() {
    // Sort by YD score as proxy for fundraising since we don't have per-candidate finance totals in the list
    final topScored = List<Candidate>.from(_allCandidates)
      ..sort((a, b) => b.youngDemScore.compareTo(a.youngDemScore));
    final top10 = topScored.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: BrandColors.sunriseGold, size: 16),
              const SizedBox(width: 6),
              const Text('Top Scored Candidates', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(top10.length, (i) {
            final c = top10[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(i.isEven ? 0.03 : 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '#${i + 1}',
                      style: TextStyle(
                        color: i < 3 ? BrandColors.sunriseGold : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _partyBadgeSmall(c),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: BrandColors.sunriseGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${c.youngDemScore}',
                      style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNoDemocratDistricts() {
    // Find districts that only have Republicans
    final noDemDistricts = <String>[];
    for (final entry in _districtMap.entries) {
      final hasDem = entry.value.any((c) => c.isDemocrat);
      if (!hasDem) {
        noDemDistricts.add(entry.key);
      }
    }
    noDemDistricts.sort((a, b) {
      final ai = int.tryParse(a) ?? 999;
      final bi = int.tryParse(b) ?? 999;
      return ai.compareTo(bi);
    });

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(
                'Districts with No Democrat Filed (${noDemDistricts.length})',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (noDemDistricts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('🎉 Every district with a candidate has a Democrat!', style: TextStyle(color: BrandColors.success, fontSize: 12)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: noDemDistricts.map((dist) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    'D-$dist',
                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FILTERS + SEARCH
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFiltersSection() {
    return Column(
      children: [
        // Search bar with bulk mode toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search candidates by name, district, office…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: BrandColors.unityBlue.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              // Bulk select toggle
              GestureDetector(
                onTap: _toggleBulkMode,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bulkMode
                        ? BrandColors.sunriseGold.withOpacity(0.2)
                        : BrandColors.unityBlue.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _bulkMode ? BrandColors.sunriseGold.withOpacity(0.5) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.checklist,
                    color: _bulkMode ? BrandColors.sunriseGold : Colors.white54,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Party filters
                _filterChip('All', _partyFilter == null, () {
                  setState(() => _partyFilter = null);
                  _applyFilters();
                }),
                _filterChip('Democrat', _partyFilter == 'Democratic', () {
                  setState(() => _partyFilter =
                      _partyFilter == 'Democratic' ? null : 'Democratic');
                  _applyFilters();
                }, color: BrandColors.democratBlue),
                _filterChip('Republican', _partyFilter == 'Republican', () {
                  setState(() => _partyFilter =
                      _partyFilter == 'Republican' ? null : 'Republican');
                  _applyFilters();
                }, color: BrandColors.republicanRed),
                _filterChip('Libertarian', _partyFilter == 'Libertarian', () {
                  setState(() => _partyFilter =
                      _partyFilter == 'Libertarian' ? null : 'Libertarian');
                  _applyFilters();
                }, color: Colors.amber),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: Colors.white24),
                const SizedBox(width: 8),
                // Office level filters
                _filterChip('State', _officeLevelFilter == 'state', () {
                  setState(() => _officeLevelFilter =
                      _officeLevelFilter == 'state' ? null : 'state');
                  _applyFilters();
                }),
                _filterChip('Federal', _officeLevelFilter == 'federal', () {
                  setState(() => _officeLevelFilter =
                      _officeLevelFilter == 'federal' ? null : 'federal');
                  _applyFilters();
                }),
                _filterChip('Statewide', _officeLevelFilter == 'statewide', () {
                  setState(() => _officeLevelFilter =
                      _officeLevelFilter == 'statewide' ? null : 'statewide');
                  _applyFilters();
                }),
                _filterChip('Judicial', _officeLevelFilter == 'judicial', () {
                  setState(() => _officeLevelFilter =
                      _officeLevelFilter == 'judicial' ? null : 'judicial');
                  _applyFilters();
                }),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: Colors.white24),
                const SizedBox(width: 8),
                // YD toggle
                _filterChip('Young Dems ⭐', _ydOnly, () {
                  setState(() => _ydOnly = !_ydOnly);
                  _applyFilters();
                }, color: BrandColors.sunriseGold),
              ],
            ),
          ),
        ),

        // Sort controls + Advanced filter toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Text(
                '${_filteredCandidates.length} candidates',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              // Advanced filter button
              GestureDetector(
                onTap: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _showAdvancedFilters || _activeFilterCount > 0
                        ? BrandColors.sunriseGold.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _activeFilterCount > 0
                          ? BrandColors.sunriseGold.withOpacity(0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 14,
                        color: _activeFilterCount > 0 ? BrandColors.sunriseGold : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _activeFilterCount > 0 ? 'Filters ($_activeFilterCount)' : 'Filters',
                        style: TextStyle(
                          color: _activeFilterCount > 0 ? BrandColors.sunriseGold : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Sort: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              _sortChip('Name', 'name'),
              _sortChip('Age', 'age'),
              _sortChip('Dist', 'district'),
              _sortChip('Score', 'score'),
              _sortChip('Party', 'party'),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _applyFilters();
                },
                child: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: BrandColors.sunriseGold,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ADVANCED FILTER PANEL
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAdvancedFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.unityBlue.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: BrandColors.sunriseGold, size: 18),
              const SizedBox(width: 8),
              const Text('Advanced Filters', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_activeFilterCount > 0)
                GestureDetector(
                  onTap: _resetAdvancedFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Reset All', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Party (multi-select) ──
          _filterLabel('Party (multi-select)'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Democratic', 'Republican', 'Libertarian', 'Green', 'Constitution'].map((party) {
              final selected = _partyMultiSelect.contains(party);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _partyMultiSelect.remove(party);
                    } else {
                      _partyMultiSelect.add(party);
                    }
                  });
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? _partyColor(party).withOpacity(0.25) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? _partyColor(party).withOpacity(0.5) : Colors.white12),
                  ),
                  child: Text(
                    party,
                    style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 11),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── Office Level (multi-select) ──
          _filterLabel('Office Level'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['state', 'federal', 'statewide', 'judicial'].map((level) {
              final selected = _officeLevelMultiSelect.contains(level);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _officeLevelMultiSelect.remove(level);
                    } else {
                      _officeLevelMultiSelect.add(level);
                    }
                  });
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? BrandColors.momentumBlue.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? BrandColors.momentumBlue.withOpacity(0.5) : Colors.white12),
                  ),
                  child: Text(
                    level.substring(0, 1).toUpperCase() + level.substring(1),
                    style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 11),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── District Range (slider) ──
          _filterLabel('District Range: ${_districtRange.start.round()} — ${_districtRange.end.round()}'),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: BrandColors.momentumBlue,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: BrandColors.sunriseGold,
              overlayColor: BrandColors.sunriseGold.withOpacity(0.2),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: _districtRange,
              min: 1,
              max: 163,
              divisions: 162,
              labels: RangeLabels(
                _districtRange.start.round().toString(),
                _districtRange.end.round().toString(),
              ),
              onChanged: (values) {
                setState(() => _districtRange = values);
                _applyFilters();
              },
            ),
          ),
          const SizedBox(height: 10),

          // ── Age Range (slider) ──
          _filterLabel('Age Range: ${_ageRange.start.round()} — ${_ageRange.end.round()}'),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.purpleAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.08),
              thumbColor: BrandColors.sunriseGold,
              overlayColor: BrandColors.sunriseGold.withOpacity(0.2),
              rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: _ageRange,
              min: 18,
              max: 90,
              divisions: 72,
              labels: RangeLabels(
                _ageRange.start.round().toString(),
                _ageRange.end.round().toString(),
              ),
              onChanged: (values) {
                setState(() => _ageRange = values);
                _applyFilters();
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── Toggle Filters ──
          _filterLabel('Quick Filters'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _toggleFilterChip('Has Website', Icons.language, _hasCampaignWebsite, (val) {
                setState(() => _hasCampaignWebsite = val);
                _applyFilters();
              }),
              _toggleFilterChip('Has Social Media', Icons.share, _hasSocialMedia, (val) {
                setState(() => _hasSocialMedia = val);
                _applyFilters();
              }),
              _toggleFilterChip('MOYD Contacted', Icons.phone_in_talk, _moydContacted, (val) {
                setState(() => _moydContacted = val);
                _applyFilters();
              }),
              _toggleFilterChip('MOYD Endorsed', Icons.star, _moydEndorsed, (val) {
                setState(() => _moydEndorsed = val);
                _applyFilters();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _toggleFilterChip(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? BrandColors.success.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? BrandColors.success.withOpacity(0.5) : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : icon,
              size: 14,
              color: value ? BrandColors.success : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _partyColor(String party) {
    switch (party.toLowerCase()) {
      case 'democratic': return BrandColors.democratBlue;
      case 'republican': return BrandColors.republicanRed;
      case 'libertarian': return Colors.amber;
      case 'green': return Colors.green;
      default: return Colors.grey;
    }
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (color ?? BrandColors.sunriseGold)
                : BrandColors.unityBlue.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.white24 : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String label, String sortValue) {
    final isSelected = _sortBy == sortValue;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: () {
          setState(() => _sortBy = sortValue);
          _applyFilters();
        },
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? BrandColors.sunriseGold : Colors.white54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            decoration:
                isSelected ? TextDecoration.underline : TextDecoration.none,
            decorationColor: BrandColors.sunriseGold,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CANDIDATE LIST ROW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCandidateRow(Candidate c) {
    final isSelected = _selectedIds.contains(c.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? BrandColors.sunriseGold.withOpacity(0.1)
            : BrandColors.unityBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: BrandColors.sunriseGold.withOpacity(0.4))
            : null,
      ),
      child: InkWell(
        onTap: _bulkMode
            ? () => _toggleSelection(c.id)
            : () => _openCandidate(c),
        onLongPress: !_bulkMode
            ? () {
                _toggleBulkMode();
                _toggleSelection(c.id);
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              // Checkbox (bulk mode)
              if (_bulkMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? BrandColors.sunriseGold : Colors.white38,
                    size: 20,
                  ),
                ),
              // Party badge
              _partyBadge(c),
              const SizedBox(width: 10),
              // Name + office
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.isYoungDem) ...[
                          const SizedBox(width: 6),
                          _ydBadge(),
                        ],
                        if (c.isEndorsed) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: BrandColors.sunriseGold, size: 12),
                        ],
                        if (c.isContacted) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle, color: BrandColors.success, size: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.officeDisplay,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.assignedTo != null && c.assignedTo!.isNotEmpty)
                          Text(
                            '→ ${c.assignedTo!.split(' ').first}',
                            style: const TextStyle(color: BrandColors.momentumBlue, fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Score badge
              if (c.youngDemScore > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: BrandColors.sunriseGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${c.youngDemScore}',
                    style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              // Age
              if (c.estimatedAge != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${c.estimatedAge}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _partyBadge(Candidate c) {
    Color bgColor;
    if (c.isDemocrat) {
      bgColor = BrandColors.democratBlue;
    } else if (c.isRepublican) {
      bgColor = BrandColors.republicanRed;
    } else {
      bgColor = Colors.amber;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          c.partyShort,
          style: TextStyle(
            color: bgColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _partyBadgeSmall(Candidate c) {
    Color bgColor;
    if (c.isDemocrat) {
      bgColor = BrandColors.democratBlue;
    } else if (c.isRepublican) {
      bgColor = BrandColors.republicanRed;
    } else {
      bgColor = Colors.amber;
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(
          c.partyShort,
          style: TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _ydBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BrandColors.sunriseGold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.5)),
      ),
      child: const Text(
        'YD',
        style: TextStyle(
          color: BrandColors.sunriseGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BULK ASSIGN DIALOG
// ═══════════════════════════════════════════════════════════════

class _BulkAssignDialog extends StatefulWidget {
  @override
  State<_BulkAssignDialog> createState() => _BulkAssignDialogState();
}

class _BulkAssignDialogState extends State<_BulkAssignDialog> {
  String? _selected;
  final _customController = TextEditingController();

  final _teamMembers = [
    ...CRMConfig.teamMembers,
    'Custom…',
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandColors.unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Assign To Team Member',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._teamMembers.map((member) {
            final isCustom = member == 'Custom…';
            final isSelected = _selected == member;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => setState(() => _selected = member),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? BrandColors.sunriseGold.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? BrandColors.sunriseGold.withOpacity(0.5) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCustom ? Icons.edit : Icons.person,
                        color: isSelected ? BrandColors.sunriseGold : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        member,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: BrandColors.sunriseGold, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_selected == 'Custom…') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter team member name',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _selected == 'Custom…'
                ? _customController.text.trim()
                : _selected;
            Navigator.of(context).pop(value);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.sunriseGold,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PIE CHART PAINTER
// ═══════════════════════════════════════════════════════════════

class _PieSegment {
  final double value;
  final Color color;
  _PieSegment(this.value, this.color);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSegment> segments;

  _PieChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border between segments
      final borderPaint = Paint()
        ..color = BrandColors.unityBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════
//  MISSOURI MAP PAINTER
//  Renders a stylized grid-based map of Missouri state house
//  districts with color-coded dots for candidate status
// ═══════════════════════════════════════════════════════════════

class MissouriMapPainter extends CustomPainter {
  final Map<String, List<Candidate>> districtMap;
  final String? selectedDistrict;
  final double pulseValue;

  MissouriMapPainter({
    required this.districtMap,
    this.selectedDistrict,
    this.pulseValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawMissouriOutline(canvas, size);
    _drawDistrictDots(canvas, size);
  }

  void _drawMissouriOutline(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = BrandColors.momentumBlue.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final outline = [
      Offset(0.05, 0.10),
      Offset(0.40, 0.08),
      Offset(0.55, 0.05),
      Offset(0.70, 0.07),
      Offset(0.88, 0.10),
      Offset(0.90, 0.20),
      Offset(0.92, 0.35),
      Offset(0.95, 0.45),
      Offset(0.92, 0.55),
      Offset(0.88, 0.65),
      Offset(0.90, 0.75),
      Offset(0.92, 0.90),
      Offset(0.80, 0.92),
      Offset(0.75, 0.80),
      Offset(0.70, 0.72),
      Offset(0.55, 0.70),
      Offset(0.40, 0.72),
      Offset(0.25, 0.70),
      Offset(0.10, 0.68),
      Offset(0.05, 0.55),
      Offset(0.03, 0.35),
      Offset(0.05, 0.20),
    ];

    final path = Path();
    final first = Offset(outline[0].dx * size.width, outline[0].dy * size.height);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < outline.length; i++) {
      final p = Offset(outline[i].dx * size.width, outline[i].dy * size.height);
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    for (double x = 0.1; x < 1.0; x += 0.05) {
      canvas.drawLine(Offset(x * size.width, 0), Offset(x * size.width, size.height), gridPaint);
    }
    for (double y = 0.1; y < 1.0; y += 0.05) {
      canvas.drawLine(Offset(0, y * size.height), Offset(size.width, y * size.height), gridPaint);
    }
  }

  void _drawDistrictDots(Canvas canvas, Size size) {
    final rng = math.Random(42);

    for (final entry in districtMap.entries) {
      final districtNum = int.tryParse(entry.key) ?? 0;
      if (districtNum < 1 || districtNum > 163) continue;

      final candidates = entry.value;

      double x, y;
      if (districtNum <= 30) {
        x = 0.08 + (districtNum % 6) * 0.025 + rng.nextDouble() * 0.01;
        y = 0.25 + (districtNum ~/ 6) * 0.04 + rng.nextDouble() * 0.01;
      } else if (districtNum <= 40) {
        x = 0.12 + ((districtNum - 30) % 5) * 0.03 + rng.nextDouble() * 0.015;
        y = 0.20 + ((districtNum - 30) ~/ 5) * 0.05 + rng.nextDouble() * 0.015;
      } else if (districtNum <= 80) {
        final idx = districtNum - 41;
        x = 0.78 + (idx % 7) * 0.022 + rng.nextDouble() * 0.01;
        y = 0.28 + (idx ~/ 7) * 0.038 + rng.nextDouble() * 0.01;
      } else if (districtNum <= 95) {
        final idx = districtNum - 81;
        x = 0.72 + (idx % 5) * 0.03 + rng.nextDouble() * 0.015;
        y = 0.25 + (idx ~/ 5) * 0.06 + rng.nextDouble() * 0.015;
      } else if (districtNum <= 105) {
        final idx = districtNum - 96;
        x = 0.42 + (idx % 4) * 0.035 + rng.nextDouble() * 0.02;
        y = 0.28 + (idx ~/ 4) * 0.05 + rng.nextDouble() * 0.02;
      } else if (districtNum <= 120) {
        final idx = districtNum - 106;
        x = 0.28 + (idx % 5) * 0.03 + rng.nextDouble() * 0.015;
        y = 0.55 + (idx ~/ 5) * 0.045 + rng.nextDouble() * 0.015;
      } else {
        final idx = districtNum - 121;
        x = 0.15 + (idx % 10) * 0.065 + rng.nextDouble() * 0.03;
        y = 0.15 + (idx ~/ 10) * 0.08 + rng.nextDouble() * 0.03;
      }

      x = x.clamp(0.06, 0.93);
      y = y.clamp(0.08, 0.88);

      final hasYd = candidates.any((c) => c.isYoungDem);
      final hasDem = candidates.any((c) => c.isDemocrat);
      final hasRep = candidates.any((c) => c.isRepublican);

      Color dotColor;
      double dotRadius = 4.0;
      if (hasYd) {
        dotColor = BrandColors.momentumBlue;
        dotRadius = 5.5;
      } else if (hasDem && !hasRep) {
        dotColor = Colors.blueGrey;
        dotRadius = 4.0;
      } else if (hasDem && hasRep) {
        dotColor = Colors.amber.withOpacity(0.7);
        dotRadius = 4.5;
      } else {
        dotColor = BrandColors.republicanRed.withOpacity(0.6);
        dotRadius = 3.5;
      }

      final isSelected = selectedDistrict == entry.key;
      if (isSelected) {
        dotRadius *= 1.5 * pulseValue;
      }

      final pos = Offset(x * size.width, y * size.height);

      if (hasYd || isSelected) {
        final glowPaint = Paint()
          ..color = dotColor.withOpacity(0.3 * pulseValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(pos, dotRadius * 1.8, glowPaint);
      }

      final dotPaint = Paint()..color = dotColor;
      canvas.drawCircle(pos, dotRadius, dotPaint);

      if (isSelected) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(pos.dx - textPainter.width / 2, pos.dy - dotRadius - 14),
        );
      }
    }

    _drawCityLabel(canvas, size, 'Kansas City', 0.10, 0.22);
    _drawCityLabel(canvas, size, 'St. Louis', 0.82, 0.24);
    _drawCityLabel(canvas, size, 'Springfield', 0.32, 0.52);
    _drawCityLabel(canvas, size, 'Columbia', 0.47, 0.24);
    _drawCityLabel(canvas, size, 'Jeff City', 0.45, 0.38);
  }

  void _drawCityLabel(Canvas canvas, Size size, String name, double x, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(x * size.width - textPainter.width / 2, y * size.height),
    );
  }

  @override
  bool shouldRepaint(covariant MissouriMapPainter oldDelegate) {
    return selectedDistrict != oldDelegate.selectedDistrict ||
        pulseValue != oldDelegate.pulseValue;
  }
}
