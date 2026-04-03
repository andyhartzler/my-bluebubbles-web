import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATES INTELLIGENCE PAGE
//  A stunning, data-rich view into the 2026 Missouri races
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

  // Data
  List<Candidate> _allCandidates = [];
  List<Candidate> _filteredCandidates = [];
  List<Candidate> _youngDems = [];
  CandidateStats _stats = const CandidateStats();
  Map<String, List<Candidate>> _districtMap = {};

  // Filters
  String? _partyFilter;
  String? _officeLevelFilter;
  String? _districtFilter;
  bool _ydOnly = false;
  String _sortBy = 'name';
  bool _sortAscending = true;

  // State
  bool _loading = true;
  String? _selectedMapDistrict;
  List<Candidate>? _selectedDistrictCandidates;

  // Animation
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

    setState(() {
      _allCandidates = allCandidates;
      _youngDems = youngDems;
      _stats = stats;
      _districtMap = districtMap;
      _loading = false;
      _applyFilters();
    });

    _statsAnimController.forward();
  }

  void _applyFilters() {
    var candidates = List<Candidate>.from(_allCandidates);

    // Search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      candidates = candidates
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              (c.district?.toLowerCase().contains(query) ?? false) ||
              c.office.toLowerCase().contains(query))
          .toList();
    }

    // Party filter
    if (_partyFilter != null) {
      candidates = candidates.where((c) => c.party == _partyFilter).toList();
    }

    // Office level filter
    if (_officeLevelFilter != null) {
      candidates =
          candidates.where((c) => c.officeLevel == _officeLevelFilter).toList();
    }

    // District filter
    if (_districtFilter != null) {
      candidates =
          candidates.where((c) => c.district == _districtFilter).toList();
    }

    // YD only
    if (_ydOnly) {
      candidates = candidates.where((c) => c.isYoungDem).toList();
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
        default:
          cmp = a.name.compareTo(b.name);
      }
      return _sortAscending ? cmp : -cmp;
    });

    setState(() => _filteredCandidates = candidates);
  }

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

              // ── Filters + Search ──
              SliverToBoxAdapter(child: _buildFiltersSection()),

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
    // Calculate which district grid cell was tapped
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final pos = details.localPosition;

    // Map is arranged as a ~16x11 grid representing Missouri districts
    final cols = 16;
    final rows = 11;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final col = (pos.dx / cellW).floor().clamp(0, cols - 1);
    final row = (pos.dy / cellH).floor().clamp(0, rows - 1);

    // Convert grid position to approximate district number
    final districtNum = row * cols + col + 1;
    final district = districtNum.toString();

    if (_districtMap.containsKey(district)) {
      setState(() {
        _selectedMapDistrict = district;
        _selectedDistrictCandidates = _districtMap[district];
      });
    } else {
      // Find nearest district
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
            style: TextStyle(
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
    // Cycle through gradient colors for visual variety
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
              // Avatar
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
  //  FILTERS + SEARCH
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFiltersSection() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search candidates by name, district, office…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.clear, color: Colors.white54),
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
                _filterChip(
                    'Libertarian', _partyFilter == 'Libertarian', () {
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
                _filterChip(
                    'Statewide', _officeLevelFilter == 'statewide', () {
                  setState(() => _officeLevelFilter =
                      _officeLevelFilter == 'statewide'
                          ? null
                          : 'statewide');
                  _applyFilters();
                }),
                _filterChip(
                    'Judicial', _officeLevelFilter == 'judicial', () {
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

        // Sort controls
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Text(
                '${_filteredCandidates.length} candidates',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              const Text('Sort: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              _sortChip('Name', 'name'),
              _sortChip('Age', 'age'),
              _sortChip('District', 'district'),
              _sortChip('Filed', 'filing_date'),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _applyFilters();
                },
                child: Icon(
                  _sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () => _openCandidate(c),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
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
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.officeDisplay,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Age
              if (c.estimatedAge != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const Icon(Icons.chevron_right,
                  color: Colors.white24, size: 18),
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

  Widget _ydBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BrandColors.sunriseGold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: BrandColors.sunriseGold.withOpacity(0.5)),
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
    // Draw Missouri outline (simplified polygon)
    _drawMissouriOutline(canvas, size);
    // Draw district dots inside the outline
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

    // Simplified Missouri outline (normalized 0-1 coordinates)
    // Missouri is roughly wider than tall, with a boot-heel in the SE
    final outline = [
      Offset(0.05, 0.10), // NW corner
      Offset(0.40, 0.08), // N edge
      Offset(0.55, 0.05), // N edge near KC
      Offset(0.70, 0.07), // N edge
      Offset(0.88, 0.10), // NE corner near Hannibal
      Offset(0.90, 0.20), // E edge
      Offset(0.92, 0.35), // E edge (Mississippi)
      Offset(0.95, 0.45), // E edge near STL
      Offset(0.92, 0.55), // E edge south of STL
      Offset(0.88, 0.65), // SE edge
      Offset(0.90, 0.75), // Bootheel top
      Offset(0.92, 0.90), // Bootheel east
      Offset(0.80, 0.92), // Bootheel bottom
      Offset(0.75, 0.80), // Bootheel west
      Offset(0.70, 0.72), // S edge
      Offset(0.55, 0.70), // S edge
      Offset(0.40, 0.72), // S edge (Ozarks)
      Offset(0.25, 0.70), // SW edge
      Offset(0.10, 0.68), // SW corner
      Offset(0.05, 0.55), // W edge
      Offset(0.03, 0.35), // W edge near KC
      Offset(0.05, 0.20), // NW edge
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

    // Draw grid lines (subtle)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;

    for (double x = 0.1; x < 1.0; x += 0.05) {
      canvas.drawLine(
        Offset(x * size.width, 0),
        Offset(x * size.width, size.height),
        gridPaint,
      );
    }
    for (double y = 0.1; y < 1.0; y += 0.05) {
      canvas.drawLine(
        Offset(0, y * size.height),
        Offset(size.width, y * size.height),
        gridPaint,
      );
    }
  }

  void _drawDistrictDots(Canvas canvas, Size size) {
    // Arrange districts roughly in Missouri's geographic layout
    // Districts 1-163 arranged in a grid that approximates MO geography
    //
    // Key metro areas get denser placement:
    //  - KC area: left-center (~0.05-0.20, 0.25-0.45)
    //  - STL area: right (~0.80-0.95, 0.30-0.55)
    //  - Springfield: south-center (~0.30-0.45, 0.55-0.70)
    //  - Columbia: center (~0.45-0.55, 0.25-0.35)

    final rng = math.Random(42); // Deterministic layout

    // Generate positions for all 163 districts
    for (final entry in districtMap.entries) {
      final districtNum = int.tryParse(entry.key) ?? 0;
      if (districtNum < 1 || districtNum > 163) continue;

      final candidates = entry.value;

      // Determine district position based on number ranges
      // (This is an approximation; real GIS data would be more accurate)
      double x, y;
      if (districtNum <= 30) {
        // KC metro area
        x = 0.08 + (districtNum % 6) * 0.025 + rng.nextDouble() * 0.01;
        y = 0.25 + (districtNum ~/ 6) * 0.04 + rng.nextDouble() * 0.01;
      } else if (districtNum <= 40) {
        // KC suburbs
        x = 0.12 + ((districtNum - 30) % 5) * 0.03 + rng.nextDouble() * 0.015;
        y = 0.20 + ((districtNum - 30) ~/ 5) * 0.05 + rng.nextDouble() * 0.015;
      } else if (districtNum <= 80) {
        // STL metro area
        final idx = districtNum - 41;
        x = 0.78 + (idx % 7) * 0.022 + rng.nextDouble() * 0.01;
        y = 0.28 + (idx ~/ 7) * 0.038 + rng.nextDouble() * 0.01;
      } else if (districtNum <= 95) {
        // STL suburbs
        final idx = districtNum - 81;
        x = 0.72 + (idx % 5) * 0.03 + rng.nextDouble() * 0.015;
        y = 0.25 + (idx ~/ 5) * 0.06 + rng.nextDouble() * 0.015;
      } else if (districtNum <= 105) {
        // Columbia / Jeff City area
        final idx = districtNum - 96;
        x = 0.42 + (idx % 4) * 0.035 + rng.nextDouble() * 0.02;
        y = 0.28 + (idx ~/ 4) * 0.05 + rng.nextDouble() * 0.02;
      } else if (districtNum <= 120) {
        // Springfield area
        final idx = districtNum - 106;
        x = 0.28 + (idx % 5) * 0.03 + rng.nextDouble() * 0.015;
        y = 0.55 + (idx ~/ 5) * 0.045 + rng.nextDouble() * 0.015;
      } else {
        // Rural / rest of state
        final idx = districtNum - 121;
        x = 0.15 + (idx % 10) * 0.065 + rng.nextDouble() * 0.03;
        y = 0.15 + (idx ~/ 10) * 0.08 + rng.nextDouble() * 0.03;
      }

      // Clamp inside the outline area
      x = x.clamp(0.06, 0.93);
      y = y.clamp(0.08, 0.88);

      // Determine color based on candidates in this district
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

      // Glow effect for YD and selected
      if (hasYd || isSelected) {
        final glowPaint = Paint()
          ..color = dotColor.withOpacity(0.3 * pulseValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(pos, dotRadius * 1.8, glowPaint);
      }

      // Draw the dot
      final dotPaint = Paint()..color = dotColor;
      canvas.drawCircle(pos, dotRadius, dotPaint);

      // Draw district number for selected
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

    // Draw city labels
    _drawCityLabel(canvas, size, 'Kansas City', 0.10, 0.22);
    _drawCityLabel(canvas, size, 'St. Louis', 0.82, 0.24);
    _drawCityLabel(canvas, size, 'Springfield', 0.32, 0.52);
    _drawCityLabel(canvas, size, 'Columbia', 0.47, 0.24);
    _drawCityLabel(canvas, size, 'Jeff City', 0.45, 0.38);
  }

  void _drawCityLabel(
      Canvas canvas, Size size, String name, double x, double y) {
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
