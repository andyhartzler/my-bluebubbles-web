import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/legislator.dart';
import '../providers/legislation_provider.dart';
import '../services/legislation_service.dart';
import '../widgets/legislator_card.dart';
import 'legislator_detail_screen.dart';

/// Screen displaying list of all Missouri legislators
class LegislatorsListScreen extends StatefulWidget {
  final String committeeId;

  const LegislatorsListScreen({
    super.key,
    required this.committeeId,
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

  List<Legislator> _senateLegislators = [];
  List<Legislator> _houseLegislators = [];
  LegislatorStats? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLegislators();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLegislators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
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
        _service.getLegislatorStats(),
      ]);

      setState(() {
        _senateLegislators = results[0] as List<Legislator>;
        _houseLegislators = results[1] as List<Legislator>;
        _stats = results[2] as LegislatorStats;

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

    return Column(
      children: [
        // Stats banner
        if (_stats != null) _buildStatsBanner(theme),

        // Search and filters
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search legislators...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadLegislators();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (value) {
                    setState(() => _searchQuery = value);
                    _loadLegislators();
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Party filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _partyFilter,
                    hint: const Text('Party'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'Republican', child: Text('Republican')),
                      DropdownMenuItem(value: 'Democratic', child: Text('Democratic')),
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
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Senate'),
                  const SizedBox(width: 8),
                  _buildCountBadge(theme, _senateLegislators.length),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('House'),
                  const SizedBox(width: 8),
                  _buildCountBadge(theme, _houseLegislators.length),
                ],
              ),
            ),
          ],
        ),

        // Legislator lists
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
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
    );
  }

  Widget _buildStatsBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              theme,
              '${_stats!.totalLegislators}',
              'Total',
              Icons.people,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
          ),
          Expanded(
            child: _buildStatItem(
              theme,
              '${_stats!.republicanCount}',
              'Republican',
              Icons.circle,
              color: const Color(0xFFEF4444),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
          ),
          Expanded(
            child: _buildStatItem(
              theme,
              '${_stats!.democratCount}',
              'Democrat',
              Icons.circle,
              color: const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String value, String label, IconData icon, {Color? color}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color ?? theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(ThemeData theme, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    final hasFilters = _partyFilter != null || _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.filter_list_off : Icons.people_outline,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No legislators match your filters' : 'No $chamber legislators found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _partyFilter = null;
                  });
                  _loadLegislators();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading legislators',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unknown error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadLegislators,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
