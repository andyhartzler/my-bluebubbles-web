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

class _LegislatorsListScreenState extends State<LegislatorsListScreen> {
  final LegislationService _service = LegislationService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedChamber = 'senate'; // 'senate' or 'house'
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
    _searchController.addListener(_onSearchChanged);
    _loadLegislators();
  }

  @override
  void dispose() {
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

  Future<void> _loadLegislators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load legislators and cached stats in parallel (search all parties)
      final results = await Future.wait([
        _service.getLegislatorsFiltered(
          chamber: 'upper',
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
        _service.getLegislatorsFiltered(
          chamber: 'lower',
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
            // Search bar styled like All Bills tab
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
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
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search legislators...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadLegislators();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Chamber selection styled like All Bills position filter
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _buildChamberSelector(),
            ),

            // Legislator list for selected chamber
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _momentumBlue))
                  : _error != null
                      ? _buildErrorState(theme)
                      : _selectedChamber == 'senate'
                          ? _buildLegislatorList(_senateLegislators, 'Senate')
                          : _buildLegislatorList(_houseLegislators, 'House'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBanner(ThemeData theme) {
    // Compact stats banner matching the filter tabs style on bills page
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            _buildCompactStatItem('${_stats!.totalLegislators}', 'Total'),
            _buildCompactStatItem('${_stats!.republicanCount}', 'Rep', color: const Color(0xFFEF4444)),
            _buildCompactStatItem('${_stats!.democratCount}', 'Dem', color: const Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatItem(String value, String label, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color?.withOpacity(0.3) ?? Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChamberSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _unityBlue,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            _buildChamberButton('Senate', 'senate', _senateLegislators.length),
            _buildChamberButton('House', 'house', _houseLegislators.length),
          ],
        ),
      ),
    );
  }

  Widget _buildChamberButton(String label, String chamber, int count) {
    final isSelected = _selectedChamber == chamber;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedChamber = chamber),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _momentumBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final hasSearch = _searchQuery.isNotEmpty;

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
                hasSearch ? Icons.search_off : Icons.people_outline,
                size: 48,
                color: _unityBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No legislators match your search' : 'No $chamber legislators found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _loadLegislators();
                },
                icon: const Icon(Icons.clear_all, color: Colors.white),
                label: const Text('Clear Search', style: TextStyle(color: Colors.white)),
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
