import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/legislator.dart';
import '../providers/legislation_provider.dart';
import '../services/legislation_service.dart';
import '../widgets/legislator_card.dart';
import 'legislator_detail_screen.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Screen displaying list of all Missouri legislators
class LegislatorsListScreen extends StatefulWidget {
  final String committeeId;
  final bool isMemberView;

  const LegislatorsListScreen({
    super.key,
    required this.committeeId,
    this.isMemberView = false,
  });

  @override
  State<LegislatorsListScreen> createState() => _LegislatorsListScreenState();
}

class _LegislatorsListScreenState extends State<LegislatorsListScreen>
    with SingleTickerProviderStateMixin {
  final LegislationService _service = LegislationService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  String? _partyFilter;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  // For debouncing search
  DateTime? _lastSearchTime;
  static const _searchDebounceMs = 300;

  List<Legislator> _senateLegislators = [];
  List<Legislator> _houseLegislators = [];
  LegislatorStats? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadLegislators();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query == _searchQuery) return;

    // Debounce search
    final now = DateTime.now();
    _lastSearchTime = now;

    Future.delayed(const Duration(milliseconds: _searchDebounceMs), () {
      if (_lastSearchTime == now && mounted) {
        setState(() => _searchQuery = query);
        _loadLegislators();
      }
    });
  }

  void _setPartyFilter(String? party) {
    setState(() => _partyFilter = party);
    _loadLegislators();
  }

  Future<void> _loadLegislators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load legislators and cached stats in parallel
      final results = await Future.wait([
        _service.getLegislatorsFiltered(
          chamber: 'upper',
          party: _partyFilter,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
        _service.getLegislatorsFiltered(
          chamber: 'lower',
          party: _partyFilter,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
        _service.getQuickStats(), // Use cached stats from legislation_statistics table
      ]);

      final quickStats = results[2] as Map<String, dynamic>;

      setState(() {
        _senateLegislators = results[0] as List<Legislator>;
        _houseLegislators = results[1] as List<Legislator>;

        // Build stats from cached table data
        _stats = LegislatorStats(
          totalLegislators: quickStats['total_legislators_count'] as int? ?? 0,
          republicanCount: quickStats['republican_legislators_count'] as int? ?? 0,
          democratCount: quickStats['democrat_legislators_count'] as int? ?? 0,
          houseCount: quickStats['house_legislators_count'] as int? ?? 0,
          senateCount: quickStats['senate_legislators_count'] as int? ?? 0,
          withLeadershipCount: quickStats['legislators_with_leadership_count'] as int? ?? 0,
          withPhotosCount: quickStats['legislators_with_photos_count'] as int? ?? 0,
        );

        // Sort legislators numerically by district
        _senateLegislators.sort((a, b) => _compareDistricts(a.district, b.district));
        _houseLegislators.sort((a, b) => _compareDistricts(a.district, b.district));

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Gradient background
        Positioned.fill(
          child: Image.asset(
            'assets/images/Blue-Gradient-Background.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.18)),
        ),
        // Content
        Column(
          children: [
            // Header with back button (only show if not member view)
            if (!widget.isMemberView)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Missouri Legislators',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadLegislators,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),

            // Stats banner
            if (_stats != null) _buildStatsBanner(theme),

            // Search and filters
            Container(
              padding: const EdgeInsets.all(12),
              color: _unityBlue,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search legislators...',
                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, color: _unityBlue.withOpacity(0.7)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _unityBlue.withOpacity(0.7)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadLegislators();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Party filter dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _partyFilter,
                        hint: Text('Party', style: TextStyle(color: _unityBlue.withOpacity(0.7))),
                        style: TextStyle(color: _unityBlue, fontWeight: FontWeight.w500),
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: _unityBlue),
                        items: [
                          DropdownMenuItem(value: null, child: Text('All', style: TextStyle(color: _unityBlue))),
                          DropdownMenuItem(value: 'Republican', child: Text('Republican', style: TextStyle(color: _unityBlue))),
                          DropdownMenuItem(value: 'Democratic', child: Text('Democratic', style: TextStyle(color: _unityBlue))),
                        ],
                        onChanged: (value) {
                          setState(() => _partyFilter = value);
                          _loadLegislators();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chamber tabs
            Container(
              color: _unityBlue,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: _momentumBlue,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Senate'),
                        const SizedBox(width: 8),
                        _buildCountBadge(_senateLegislators.length),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('House'),
                        const SizedBox(width: 8),
                        _buildCountBadge(_houseLegislators.length),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Legislator lists
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _momentumBlue))
                  : _error != null
                      ? _buildErrorState(theme)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLegislatorList(_senateLegislators, 'Senate'),
                            _buildLegislatorList(_houseLegislators, 'House'),
                          ],
                        ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildClickableStatItem(
              '${_stats!.totalLegislators}',
              'Total',
              Icons.people,
              isSelected: _partyFilter == null,
              onTap: () => _setPartyFilter(null),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.2),
          ),
          Expanded(
            child: _buildClickableStatItem(
              '${_stats!.republicanCount}',
              'Republican',
              Icons.circle,
              color: const Color(0xFFEF4444),
              isSelected: _partyFilter == 'Republican',
              onTap: () => _setPartyFilter('Republican'),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.2),
          ),
          Expanded(
            child: _buildClickableStatItem(
              '${_stats!.democratCount}',
              'Democrat',
              Icons.circle,
              color: const Color(0xFF3B82F6),
              isSelected: _partyFilter == 'Democratic',
              onTap: () => _setPartyFilter('Democratic'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStatItem(
    String value,
    String label,
    IconData icon, {
    Color? color,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color ?? _momentumBlue),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.white,
                    decoration: TextDecoration.none, // Remove any underline
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                decoration: TextDecoration.none, // Remove any underline
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, {Color? color}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color ?? _momentumBlue),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.white,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _momentumBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLegislatorList(List<Legislator> legislators, String chamber) {
    if (legislators.isEmpty) {
      return _buildEmptyState(chamber);
    }

    return RefreshIndicator(
      onRefresh: _loadLegislators,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: legislators.length,
        itemBuilder: (context, index) {
          final legislator = legislators[index];
          return LegislatorCard(
            legislator: legislator,
            onTap: () => _openLegislatorDetail(legislator),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String chamber) {
    final hasFilters = _partyFilter != null || _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _unityBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters ? Icons.filter_list_off : Icons.people_outline,
                size: 48,
                color: _unityBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No legislators match your filters' : 'No $chamber legislators found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _partyFilter = null;
                  });
                  _loadLegislators();
                },
                icon: const Icon(Icons.clear_all, color: Colors.white),
                label: const Text('Clear Filters', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _momentumBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading legislators',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: _unityBlue.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLegislators,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLegislatorDetail(Legislator legislator) {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: LegislatorDetailScreen(
            legislatorId: legislator.id,
            committeeId: widget.committeeId,
          ),
        ),
      ),
    );
  }

  /// Compare district strings numerically (e.g., "1" < "2" < "10")
  int _compareDistricts(String a, String b) {
    // Try to parse as integers for numeric comparison
    final aNum = int.tryParse(a);
    final bNum = int.tryParse(b);

    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }

    // Fall back to string comparison if not purely numeric
    return a.compareTo(b);
  }
}
