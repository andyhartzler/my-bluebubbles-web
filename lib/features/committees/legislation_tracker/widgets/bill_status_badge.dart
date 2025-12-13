import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';
import '../utils/bill_helpers.dart';

/// Widget showing bill passage status (House → Senate → Governor)
class BillStatusBadge extends StatelessWidget {
  final TrackedBill bill;
  final bool expanded;

  const BillStatusBadge({
    super.key,
    required this.bill,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (expanded) {
      return _buildExpandedStatus(context, theme);
    }

    return _buildCompactStatus(context, theme);
  }

  Widget _buildCompactStatus(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // House
        _buildStatusDot(
          passed: bill.passedLower,
          label: 'H',
          theme: theme,
        ),
        _buildConnector(theme),
        // Senate
        _buildStatusDot(
          passed: bill.passedUpper,
          label: 'S',
          theme: theme,
        ),
        _buildConnector(theme),
        // Governor
        _buildStatusDot(
          passed: bill.signedByGovernor,
          vetoed: bill.vetoed,
          label: 'G',
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildExpandedStatus(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildExpandedStage(
                  context: context,
                  theme: theme,
                  label: 'House',
                  passed: bill.passedLower,
                  date: bill.passedLowerDate,
                  icon: Icons.house,
                ),
              ),
              _buildExpandedConnector(theme, bill.passedLower),
              Expanded(
                child: _buildExpandedStage(
                  context: context,
                  theme: theme,
                  label: 'Senate',
                  passed: bill.passedUpper,
                  date: bill.passedUpperDate,
                  icon: Icons.account_balance,
                ),
              ),
              _buildExpandedConnector(theme, bill.passedUpper),
              Expanded(
                child: _buildExpandedStage(
                  context: context,
                  theme: theme,
                  label: 'Governor',
                  passed: bill.signedByGovernor,
                  vetoed: bill.vetoed,
                  date: bill.signedDate ?? bill.vetoDate,
                  icon: Icons.edit_document,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot({
    required bool passed,
    bool vetoed = false,
    required String label,
    required ThemeData theme,
  }) {
    Color color;
    IconData? icon;

    if (vetoed) {
      color = Colors.red;
      icon = Icons.close;
    } else if (passed) {
      color = Colors.green;
      icon = Icons.check;
    } else {
      color = theme.colorScheme.outline.withOpacity(0.5);
      icon = null;
    }

    return Tooltip(
      message: _getTooltipMessage(label, passed, vetoed),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 12, color: color)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildConnector(ThemeData theme) {
    return Container(
      width: 16,
      height: 2,
      color: theme.colorScheme.outline.withOpacity(0.3),
    );
  }

  Widget _buildExpandedStage({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required bool passed,
    bool vetoed = false,
    DateTime? date,
    required IconData icon,
  }) {
    Color color;
    Color bgColor;

    if (vetoed) {
      color = Colors.red;
      bgColor = Colors.red.withOpacity(0.1);
    } else if (passed) {
      color = Colors.green;
      bgColor = Colors.green.withOpacity(0.1);
    } else {
      color = theme.colorScheme.outline;
      bgColor = theme.colorScheme.surfaceContainerHighest;
    }

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Icon(
              vetoed ? Icons.cancel : (passed ? Icons.check_circle : icon),
              color: color,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: passed || vetoed ? FontWeight.bold : FontWeight.normal,
            color: passed || vetoed ? color : theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (date != null) ...[
          const SizedBox(height: 2),
          Text(
            BillHelpers.formatDate(date),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (vetoed) ...[
          const SizedBox(height: 2),
          Text(
            'VETOED',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedConnector(ThemeData theme, bool completed) {
    return Container(
      height: 2,
      width: 24,
      margin: const EdgeInsets.only(bottom: 40),
      color: completed
          ? Colors.green.withOpacity(0.5)
          : theme.colorScheme.outline.withOpacity(0.3),
    );
  }

  String _getTooltipMessage(String label, bool passed, bool vetoed) {
    final fullLabel = label == 'H'
        ? 'House'
        : label == 'S'
            ? 'Senate'
            : 'Governor';

    if (vetoed) return 'Vetoed by $fullLabel';
    if (passed) return 'Passed $fullLabel';
    return 'Pending $fullLabel';
  }
}
