import 'package:flutter/material.dart';
import '../models/bill_action.dart';
import '../utils/bill_helpers.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Widget displaying a timeline of bill actions
class BillTimeline extends StatelessWidget {
  final List<BillAction> actions;
  final VoidCallback? onMarkSeen;
  final bool showMarkSeenButton;

  const BillTimeline({
    super.key,
    required this.actions,
    this.onMarkSeen,
    this.showMarkSeenButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNewActions = actions.any((a) => a.isNew);

    if (actions.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return Column(
      children: [
        if (hasNewActions && showMarkSeenButton)
          Container(
            padding: const EdgeInsets.all(12),
            color: _unityBlue,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _momentumBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fiber_new, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${actions.where((a) => a.isNew).length} new actions',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (onMarkSeen != null)
                  TextButton.icon(
                    onPressed: onMarkSeen,
                    icon: const Icon(Icons.done_all, size: 16, color: Colors.white70),
                    label: const Text('Mark all seen', style: TextStyle(color: Colors.white70)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              final isLast = index == actions.length - 1;
              return _buildTimelineItem(context, theme, action, isLast: isLast);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
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
              Icons.timeline,
              size: 48,
              color: _unityBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No actions yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: _unityBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Legislative actions will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _unityBlue.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    ThemeData theme,
    BillAction action, {
    required bool isLast,
  }) {
    final icon = BillHelpers.getActionIcon(action.actionClassification);
    final color = BillHelpers.getActionColor(action.actionClassification);
    final isSignificant = BillHelpers.isSignificantAction(action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: isSignificant ? 32 : 24,
                  height: isSignificant ? 32 : 24,
                  decoration: BoxDecoration(
                    color: action.isNew ? color.withOpacity(0.3) : color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: isSignificant ? 3 : 2),
                  ),
                  child: Icon(icon, size: isSignificant ? 16 : 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: _unityBlue.withOpacity(0.2)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: action.isNew ? 2 : 1,
                color: _unityBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  decoration: action.isNew
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _momentumBlue, width: 2),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            // Date - white text on dark card
                            Text(
                              BillHelpers.formatDate(action.actionDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Chamber badge
                            if (action.chamber != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  action.chamberDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            // New badge
                            if (action.isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _momentumBlue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Description - white text
                        Text(
                          action.actionDescription,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSignificant ? FontWeight.w500 : FontWeight.normal,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                        // Classification badges
                        if (action.actionClassification.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: action.actionClassification.map((c) {
                              final actionColor = BillHelpers.getActionColor([c]);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: actionColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: actionColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  c.replaceAll('-', ' ').replaceAll('_', ' '),
                                  style: TextStyle(fontSize: 10, color: actionColor, fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
