import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/legislation_provider.dart';
import '../models/tracked_bill.dart';
import '../widgets/legislation_stats_card.dart';
import '../widgets/bill_card.dart';
import '../utils/bill_helpers.dart';
import '../utils/legislation_constants.dart';
import 'bill_detail_screen.dart';

/// Dashboard screen showing legislation overview and recent activity
class LegislationDashboardScreen extends StatefulWidget {
  final String committeeId;

  const LegislationDashboardScreen({
    super.key,
    required this.committeeId,
  });

  @override
  State<LegislationDashboardScreen> createState() => _LegislationDashboardScreenState();
}

class _LegislationDashboardScreenState extends State<LegislationDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh data when opening dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LegislationProvider>();
      provider.loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legislation Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<LegislationProvider>();
              provider.loadStats();
              provider.loadTrackedBills();
            },
          ),
        ],
      ),
      body: Consumer<LegislationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.trackedBills.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadStats();
              await provider.loadTrackedBills();
            },
            child: isWideScreen
                ? _buildWideLayout(context, theme, provider)
                : _buildMobileLayout(context, theme, provider),
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ThemeData theme, LegislationProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Session banner
        _buildSessionBanner(theme),
        const SizedBox(height: 16),

        // Stats card
        LegislationStatsCard(stats: provider.stats),
        const SizedBox(height: 16),

        // Position breakdown
        _buildPositionBreakdownCard(theme, provider),
        const SizedBox(height: 16),

        // Critical bills
        if (provider.criticalBills.isNotEmpty) ...[
          _buildSectionHeader(theme, 'Critical Bills', Icons.priority_high, Colors.red),
          const SizedBox(height: 8),
          ...provider.criticalBills.take(3).map((bill) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BillCard(
                  bill: bill,
                  onTap: () => _navigateToBillDetail(context, bill),
                  compact: true,
                ),
              )),
          if (provider.criticalBills.length > 3)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('View all ${provider.criticalBills.length} critical bills'),
            ),
          const SizedBox(height: 16),
        ],

        // Recent activity
        _buildRecentActivityCard(theme, provider),
        const SizedBox(height: 16),

        // Bills by stage
        _buildBillsByStageCard(theme, provider),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context, ThemeData theme, LegislationProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session banner
          _buildSessionBanner(theme),
          const SizedBox(height: 24),

          // Top row: Stats and position breakdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats
              Expanded(
                flex: 2,
                child: LegislationStatsCard(stats: provider.stats),
              ),
              const SizedBox(width: 16),
              // Position breakdown
              Expanded(
                flex: 1,
                child: _buildPositionBreakdownCard(theme, provider),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Middle row: Critical bills and recent activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Critical bills
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(theme, 'Critical Bills', Icons.priority_high, Colors.red),
                        const SizedBox(height: 12),
                        if (provider.criticalBills.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No critical bills',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          ...provider.criticalBills.take(5).map((bill) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: BillCard(
                                  bill: bill,
                                  onTap: () => _navigateToBillDetail(context, bill),
                                  compact: true,
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Recent activity
              Expanded(
                child: _buildRecentActivityCard(theme, provider),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bottom row: Bills by stage
          _buildBillsByStageCard(theme, provider),
        ],
      ),
    );
  }

  Widget _buildSessionBanner(ThemeData theme) {
    return Container(
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
          Icon(
            Icons.account_balance,
            size: 32,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missouri ${LegislationConstants.currentSession} Legislative Session',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Tracking legislation for Missouri Young Democrats',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPositionBreakdownCard(ThemeData theme, LegislationProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(theme, 'By Position', Icons.pie_chart, theme.colorScheme.primary),
            const SizedBox(height: 16),
            PositionBreakdown(
              supportCount: provider.supportedBills.length,
              opposeCount: provider.opposedBills.length,
              watchingCount: provider.watchingBills.length,
              neutralCount: provider.neutralBills.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(ThemeData theme, LegislationProvider provider) {
    // Get bills with recent activity using latestActionDate
    final billsWithActivity = provider.trackedBills
        .where((bill) => bill.latestActionDate != null && bill.latestActionDescription != null)
        .toList();
    billsWithActivity.sort((a, b) =>
        (b.latestActionDate ?? DateTime(1900)).compareTo(a.latestActionDate ?? DateTime(1900)));
    final recentBills = billsWithActivity.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(theme, 'Recent Activity', Icons.history, theme.colorScheme.secondary),
            const SizedBox(height: 12),
            if (recentBills.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No recent activity',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...recentBills.map((bill) => _buildActivityItem(context, theme, bill)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, ThemeData theme, TrackedBill bill) {
    return InkWell(
      onTap: () => _navigateToBillDetail(context, bill),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward, size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.billIdentifier,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    bill.latestActionDescription ?? '',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              BillHelpers.formatRelativeTime(bill.latestActionDate),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillsByStageCard(ThemeData theme, LegislationProvider provider) {
    // Count bills by stage
    final stageCounts = <BillStage, int>{};
    for (final bill in provider.trackedBills) {
      final stage = BillHelpers.getBillStage(bill);
      stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(theme, 'Bills by Stage', Icons.stairs, theme.colorScheme.tertiary),
            const SizedBox(height: 16),
            if (provider.trackedBills.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No bills tracked',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: BillStage.values.map((stage) {
                  final count = stageCounts[stage] ?? 0;
                  return _buildStageChip(theme, stage, count);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageChip(ThemeData theme, BillStage stage, int count) {
    final color = stage.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(count > 0 ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(count > 0 ? 0.3 : 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            stage.icon,
            size: 16,
            color: count > 0 ? color : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stage.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                  color: count > 0 ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$count bill${count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToBillDetail(BuildContext context, TrackedBill bill) {
    final provider = context.read<LegislationProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: BillDetailScreen(
            billId: bill.id,
            committeeId: widget.committeeId,
          ),
        ),
      ),
    );
  }
}
