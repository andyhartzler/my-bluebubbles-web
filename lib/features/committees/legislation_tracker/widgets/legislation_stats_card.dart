import 'package:flutter/material.dart';
import '../services/legislation_service.dart';
import '../models/tracked_bill.dart';

/// Card displaying legislation tracking statistics
class LegislationStatsCard extends StatelessWidget {
  final LegislationStats stats;
  final VoidCallback? onTap;

  const LegislationStatsCard({
    super.key,
    required this.stats,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tracking Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      label: 'Total Bills',
                      value: stats.totalBills.toString(),
                      icon: Icons.gavel,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Active',
                      value: stats.activeBills.toString(),
                      icon: Icons.play_circle,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Critical',
                      value: stats.criticalBills.toString(),
                      icon: Icons.priority_high,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      label: 'Support',
                      value: stats.supportBills.toString(),
                      icon: Icons.thumb_up,
                      color: BillPosition.support.color,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Oppose',
                      value: stats.opposeBills.toString(),
                      icon: Icons.thumb_down,
                      color: BillPosition.oppose.color,
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Watching',
                      value: stats.watchingBills.toString(),
                      icon: Icons.visibility,
                      color: BillPosition.watching.color,
                    ),
                  ),
                ],
              ),
              if (stats.newActionsThisWeek > 0 || stats.recentVotesCount > 0) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    if (stats.newActionsThisWeek > 0)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fiber_new,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stats.newActionsThisWeek}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      'New actions',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (stats.newActionsThisWeek > 0 && stats.recentVotesCount > 0)
                      const SizedBox(width: 12),
                    if (stats.recentVotesCount > 0)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.how_to_vote,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stats.recentVotesCount}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                    Text(
                                      'Recent votes',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Compact stats row for inline display
class LegislationStatsRow extends StatelessWidget {
  final LegislationStats stats;

  const LegislationStatsRow({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(theme, '${stats.totalBills} Total', Icons.gavel, theme.colorScheme.primary),
          const SizedBox(width: 8),
          _buildChip(theme, '${stats.supportBills} Support', Icons.thumb_up, BillPosition.support.color),
          const SizedBox(width: 8),
          _buildChip(theme, '${stats.opposeBills} Oppose', Icons.thumb_down, BillPosition.oppose.color),
          const SizedBox(width: 8),
          _buildChip(theme, '${stats.criticalBills} Critical', Icons.priority_high, Colors.red),
        ],
      ),
    );
  }

  Widget _buildChip(ThemeData theme, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Position breakdown chart/bar
class PositionBreakdown extends StatelessWidget {
  final int supportCount;
  final int opposeCount;
  final int watchingCount;
  final int neutralCount;
  final bool showLabels;

  const PositionBreakdown({
    super.key,
    required this.supportCount,
    required this.opposeCount,
    required this.watchingCount,
    required this.neutralCount,
    this.showLabels = true,
  });

  int get total => supportCount + opposeCount + watchingCount + neutralCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (total == 0) {
      return Text(
        'No bills tracked',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (supportCount > 0)
                  Expanded(
                    flex: supportCount,
                    child: Container(color: BillPosition.support.color),
                  ),
                if (opposeCount > 0)
                  Expanded(
                    flex: opposeCount,
                    child: Container(color: BillPosition.oppose.color),
                  ),
                if (watchingCount > 0)
                  Expanded(
                    flex: watchingCount,
                    child: Container(color: BillPosition.watching.color),
                  ),
                if (neutralCount > 0)
                  Expanded(
                    flex: neutralCount,
                    child: Container(color: BillPosition.neutral.color),
                  ),
              ],
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _buildLegendItem(theme, 'Support', supportCount, BillPosition.support.color),
              _buildLegendItem(theme, 'Oppose', opposeCount, BillPosition.oppose.color),
              _buildLegendItem(theme, 'Watching', watchingCount, BillPosition.watching.color),
              _buildLegendItem(theme, 'Neutral', neutralCount, BillPosition.neutral.color),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, int count, Color color) {
    if (count == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
