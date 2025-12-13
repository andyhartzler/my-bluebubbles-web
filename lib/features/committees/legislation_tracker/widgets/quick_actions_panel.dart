import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';

/// Panel providing quick actions for legislation tracking
class QuickActionsPanel extends StatelessWidget {
  final VoidCallback? onSearchBills;
  final VoidCallback? onViewDashboard;
  final VoidCallback? onSyncBills;
  final VoidCallback? onExportReport;
  final VoidCallback? onManageCategories;
  final bool isSyncing;
  final bool compact;

  const QuickActionsPanel({
    super.key,
    this.onSearchBills,
    this.onViewDashboard,
    this.onSyncBills,
    this.onExportReport,
    this.onManageCategories,
    this.isSyncing = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompactActions(context, theme);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  context,
                  theme,
                  icon: Icons.search,
                  label: 'Search Bills',
                  onPressed: onSearchBills,
                  isPrimary: true,
                ),
                _buildActionButton(
                  context,
                  theme,
                  icon: Icons.sync,
                  label: isSyncing ? 'Syncing...' : 'Sync Data',
                  onPressed: isSyncing ? null : onSyncBills,
                  isLoading: isSyncing,
                ),
                _buildActionButton(
                  context,
                  theme,
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  onPressed: onViewDashboard,
                ),
                _buildActionButton(
                  context,
                  theme,
                  icon: Icons.download,
                  label: 'Export Report',
                  onPressed: onExportReport,
                ),
                _buildActionButton(
                  context,
                  theme,
                  icon: Icons.category,
                  label: 'Categories',
                  onPressed: onManageCategories,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActions(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCompactButton(
            context,
            theme,
            icon: Icons.search,
            label: 'Search',
            onPressed: onSearchBills,
            isPrimary: true,
          ),
          const SizedBox(width: 8),
          _buildCompactButton(
            context,
            theme,
            icon: Icons.sync,
            label: isSyncing ? 'Syncing...' : 'Sync',
            onPressed: isSyncing ? null : onSyncBills,
            isLoading: isSyncing,
          ),
          const SizedBox(width: 8),
          _buildCompactButton(
            context,
            theme,
            icon: Icons.dashboard,
            label: 'Dashboard',
            onPressed: onViewDashboard,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool isPrimary = false,
    bool isLoading = false,
  }) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    bool isPrimary = false,
    bool isLoading = false,
  }) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Floating action button menu for bill actions
class BillActionsFAB extends StatefulWidget {
  final VoidCallback? onAddBill;
  final VoidCallback? onSearchBills;
  final VoidCallback? onSyncData;

  const BillActionsFAB({
    super.key,
    this.onAddBill,
    this.onSearchBills,
    this.onSyncData,
  });

  @override
  State<BillActionsFAB> createState() => _BillActionsFABState();
}

class _BillActionsFABState extends State<BillActionsFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FABs
        if (_isExpanded) ...[
          _buildMiniFab(
            context,
            icon: Icons.sync,
            label: 'Sync',
            onPressed: () {
              setState(() => _isExpanded = false);
              widget.onSyncData?.call();
            },
          ),
          const SizedBox(height: 8),
          _buildMiniFab(
            context,
            icon: Icons.search,
            label: 'Search',
            onPressed: () {
              setState(() => _isExpanded = false);
              widget.onSearchBills?.call();
            },
          ),
          const SizedBox(height: 8),
          _buildMiniFab(
            context,
            icon: Icons.add,
            label: 'Track Bill',
            onPressed: () {
              setState(() => _isExpanded = false);
              widget.onAddBill?.call();
            },
            isPrimary: true,
          ),
          const SizedBox(height: 8),
        ],
        // Main FAB
        FloatingActionButton(
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFab(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: 'mini_fab_$label',
          onPressed: onPressed,
          backgroundColor: isPrimary
              ? theme.colorScheme.primary
              : theme.colorScheme.secondaryContainer,
          child: Icon(
            icon,
            color: isPrimary
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ],
    );
  }
}

/// Quick position change buttons for a bill
class QuickPositionButtons extends StatelessWidget {
  final String currentPosition;
  final Function(String) onPositionChanged;
  final bool compact;

  const QuickPositionButtons({
    super.key,
    required this.currentPosition,
    required this.onPositionChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: compact ? 4 : 8,
      runSpacing: compact ? 4 : 8,
      children: BillPosition.values.map((position) {
        final isSelected = currentPosition == position.value;
        return _buildPositionButton(theme, position, isSelected);
      }).toList(),
    );
  }

  Widget _buildPositionButton(ThemeData theme, BillPosition position, bool isSelected) {
    return Material(
      color: isSelected ? position.color.withOpacity(0.2) : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(compact ? 16 : 20),
      child: InkWell(
        onTap: () => onPositionChanged(position.value),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 16 : 20),
            border: Border.all(
              color: isSelected ? position.color : theme.colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                position.emoji,
                style: TextStyle(fontSize: compact ? 12 : 14),
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  position.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? position.color : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
