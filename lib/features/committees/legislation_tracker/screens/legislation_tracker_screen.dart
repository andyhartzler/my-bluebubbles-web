import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/legislation_provider.dart';
import '../models/tracked_bill.dart';
import '../models/legislation_category.dart';
import '../widgets/bill_list.dart';
import '../widgets/bill_filters.dart';
import '../widgets/quick_actions_panel.dart';
import '../widgets/legislation_stats_card.dart';
import 'bill_detail_screen.dart';
import 'bill_search_screen.dart';
import 'legislation_dashboard_screen.dart';
import 'legislators_list_screen.dart';

/// Main screen for the Legislation Tracker tab
class LegislationTrackerScreen extends StatefulWidget {
  final String committeeId;

  const LegislationTrackerScreen({
    super.key,
    required this.committeeId,
  });

  @override
  State<LegislationTrackerScreen> createState() => _LegislationTrackerScreenState();
}

class _LegislationTrackerScreenState extends State<LegislationTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LegislationProvider>();
      provider.loadTrackedBills(widget.committeeId);
      provider.loadCategories(widget.committeeId);
      provider.loadStats(widget.committeeId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Consumer<LegislationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.trackedBills.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.trackedBills.isEmpty) {
          return _buildErrorState(context, theme, provider);
        }

        if (isWideScreen) {
          return _buildWideLayout(context, theme, provider);
        }

        return _buildMobileLayout(context, theme, provider);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, ThemeData theme, LegislationProvider provider) {
    return Column(
      children: [
        // Header with tabs
        Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Action bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Filter toggle
                    IconButton(
                      icon: Badge(
                        isLabelVisible: _hasActiveFilters(provider),
                        child: Icon(
                          _showFilters ? Icons.filter_list_off : Icons.filter_list,
                        ),
                      ),
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                    ),
                    const Spacer(),
                    // Quick actions
                    QuickActionsPanel(
                      compact: true,
                      isSyncing: provider.isSyncing,
                      onSearchBills: () => _navigateToSearch(context),
                      onSyncBills: () => provider.syncAllBills(widget.committeeId),
                      onViewDashboard: () => _navigateToDashboard(context),
                    ),
                  ],
                ),
              ),
              // Filter panel
              if (_showFilters)
                BillFilters(
                  positionFilter: provider.positionFilter,
                  priorityFilter: provider.priorityFilter,
                  categoryFilter: provider.categoryFilter,
                  searchQuery: provider.searchQuery,
                  showArchived: provider.showArchived,
                  categories: provider.categories,
                  onPositionChanged: (v) => provider.setPositionFilter(v),
                  onPriorityChanged: (v) => provider.setPriorityFilter(v),
                  onCategoryChanged: (v) => provider.setCategoryFilter(v),
                  onSearchChanged: (v) => provider.setSearchQuery(v),
                  onShowArchivedChanged: (v) => provider.setShowArchived(v),
                  onClearFilters: () => provider.clearFilters(),
                ),
              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('All'),
                        const SizedBox(width: 4),
                        _buildCountBadge(theme, provider.filteredBills.length),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Support'),
                        const SizedBox(width: 4),
                        _buildCountBadge(theme, provider.supportedBills.length, BillPosition.support.color),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Oppose'),
                        const SizedBox(width: 4),
                        _buildCountBadge(theme, provider.opposedBills.length, BillPosition.oppose.color),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 18),
                        SizedBox(width: 4),
                        Text('Legislators'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllBillsTab(context, theme, provider),
              _buildFilteredBillsList(context, provider, provider.supportedBills, 'No bills you support'),
              _buildFilteredBillsList(context, provider, provider.opposedBills, 'No bills you oppose'),
              LegislatorsListScreen(committeeId: widget.committeeId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, ThemeData theme, LegislationProvider provider) {
    return Row(
      children: [
        // Sidebar with stats and actions
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Stats card
                    if (provider.stats != null)
                      LegislationStatsCard(
                        stats: provider.stats!,
                        onTap: () => _navigateToDashboard(context),
                      ),
                    const SizedBox(height: 16),
                    // Quick actions
                    QuickActionsPanel(
                      isSyncing: provider.isSyncing,
                      onSearchBills: () => _navigateToSearch(context),
                      onSyncBills: () => provider.syncAllBills(widget.committeeId),
                      onViewDashboard: () => _navigateToDashboard(context),
                      onExportReport: () => _exportReport(context, provider),
                      onManageCategories: () => _manageCategories(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Filters
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildSidebarFilters(context, theme, provider),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Main content
        Expanded(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Tracked Bills',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCountBadge(theme, provider.filteredBills.length),
                    const Spacer(),
                    // View toggle could go here
                  ],
                ),
              ),
              // Bill list
              Expanded(
                child: _buildAllBillsTab(context, theme, provider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarFilters(BuildContext context, ThemeData theme, LegislationProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filters',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Search
        TextField(
          decoration: InputDecoration(
            hintText: 'Search bills...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            isDense: true,
          ),
          onChanged: provider.setSearchQuery,
        ),
        const SizedBox(height: 16),
        // Position filter
        Text('Position', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              theme,
              label: 'All',
              isSelected: provider.positionFilter == null,
              onTap: () => provider.setPositionFilter(null),
            ),
            ...BillPosition.values.map((p) => _buildFilterChip(
                  theme,
                  label: '${p.emoji} ${p.label}',
                  isSelected: provider.positionFilter == p.value,
                  color: p.color,
                  onTap: () => provider.setPositionFilter(p.value),
                )),
          ],
        ),
        const SizedBox(height: 16),
        // Priority filter
        Text('Priority', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              theme,
              label: 'All',
              isSelected: provider.priorityFilter == null,
              onTap: () => provider.setPriorityFilter(null),
            ),
            ...BillPriority.values.map((p) => _buildFilterChip(
                  theme,
                  label: p.label,
                  isSelected: provider.priorityFilter == p.value,
                  color: p.color,
                  onTap: () => provider.setPriorityFilter(p.value),
                )),
          ],
        ),
        const SizedBox(height: 16),
        // Category filter
        if (provider.categories.isNotEmpty) ...[
          Text('Category', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                theme,
                label: 'All',
                isSelected: provider.categoryFilter == null,
                onTap: () => provider.setCategoryFilter(null),
              ),
              ...provider.categories.map((c) => _buildFilterChip(
                    theme,
                    label: c.displayName,
                    isSelected: provider.categoryFilter == c.name,
                    color: c.colorValue,
                    icon: c.iconData,
                    onTap: () => provider.setCategoryFilter(c.name),
                  )),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Show archived toggle
        SwitchListTile(
          title: const Text('Show Archived'),
          value: provider.showArchived,
          onChanged: provider.setShowArchived,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        // Clear filters
        if (_hasActiveFilters(provider))
          TextButton.icon(
            onPressed: provider.clearFilters,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Filters'),
          ),
      ],
    );
  }

  Widget _buildFilterChip(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
    IconData? icon,
  }) {
    return Material(
      color: isSelected
          ? (color ?? theme.colorScheme.primary).withOpacity(0.2)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (color ?? theme.colorScheme.primary)
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? color : null),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllBillsTab(BuildContext context, ThemeData theme, LegislationProvider provider) {
    final bills = provider.filteredBills;

    if (bills.isEmpty) {
      return _buildEmptyState(context, theme, provider);
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadTrackedBills(widget.committeeId),
      child: BillList(
        bills: bills,
        onBillTap: (bill) => _navigateToBillDetail(context, bill),
        isLoading: provider.isLoading,
      ),
    );
  }

  Widget _buildFilteredBillsList(
    BuildContext context,
    LegislationProvider provider,
    List<TrackedBill> bills,
    String emptyMessage,
  ) {
    return RefreshIndicator(
      onRefresh: () => provider.loadTrackedBills(widget.committeeId),
      child: BillList(
        bills: bills,
        onBillTap: (bill) => _navigateToBillDetail(context, bill),
        isLoading: provider.isLoading,
        emptyMessage: emptyMessage,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme, LegislationProvider provider) {
    final hasFilters = _hasActiveFilters(provider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.filter_list_off : Icons.gavel_outlined,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No bills match your filters' : 'No bills being tracked',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your filters or search query'
                  : 'Search and track bills from the Missouri Legislature',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: provider.clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              )
            else
              FilledButton.icon(
                onPressed: () => _navigateToSearch(context),
                icon: const Icon(Icons.search),
                label: const Text('Search Bills'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, LegislationProvider provider) {
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
              'Error loading bills',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'An unknown error occurred',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.loadTrackedBills(widget.committeeId),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(ThemeData theme, int count, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color ?? theme.colorScheme.primary,
        ),
      ),
    );
  }

  bool _hasActiveFilters(LegislationProvider provider) {
    return provider.positionFilter != null ||
        provider.priorityFilter != null ||
        provider.categoryFilter != null ||
        provider.searchQuery.isNotEmpty ||
        provider.showArchived;
  }

  void _navigateToBillDetail(BuildContext context, TrackedBill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillDetailScreen(
          billId: bill.id,
          committeeId: widget.committeeId,
        ),
      ),
    );
  }

  void _navigateToSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillSearchScreen(
          committeeId: widget.committeeId,
        ),
      ),
    );
  }

  void _navigateToDashboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegislationDashboardScreen(
          committeeId: widget.committeeId,
        ),
      ),
    );
  }

  void _exportReport(BuildContext context, LegislationProvider provider) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  void _manageCategories(BuildContext context) {
    // TODO: Implement category management
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category management coming soon')),
    );
  }
}
