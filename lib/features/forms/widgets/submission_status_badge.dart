import 'package:flutter/material.dart';

/// Submission status values for form submissions
/// These correspond to the database status column values
class SubmissionStatus {
  static const String draft = 'draft';
  static const String inProgress = 'in_progress';
  static const String submitted = 'submitted';
  static const String abandoned = 'abandoned';
  static const String reviewed = 'reviewed';
  static const String processed = 'processed';

  /// Get all valid status values
  static List<String> get all => [
    draft,
    inProgress,
    submitted,
    abandoned,
    reviewed,
    processed,
  ];

  /// Check if a status value is valid
  static bool isValid(String status) => all.contains(status);
}

/// Configuration for a status badge display
class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;

  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}

/// A widget that displays the status of a form submission with
/// appropriate color, icon, and label
class SubmissionStatusBadge extends StatelessWidget {
  final String status;
  final bool compact;
  final bool showIcon;
  final bool showLabel;

  const SubmissionStatusBadge({
    Key? key,
    required this.status,
    this.compact = false,
    this.showIcon = true,
    this.showLabel = true,
  }) : super(key: key);

  _StatusConfig _getConfig() {
    switch (status) {
      case SubmissionStatus.draft:
        return const _StatusConfig(
          color: Colors.grey,
          icon: Icons.edit_note,
          label: 'Draft',
        );
      case SubmissionStatus.inProgress:
        return const _StatusConfig(
          color: Colors.orange,
          icon: Icons.edit,
          label: 'In Progress',
        );
      case SubmissionStatus.submitted:
        return const _StatusConfig(
          color: Colors.green,
          icon: Icons.check_circle,
          label: 'Submitted',
        );
      case SubmissionStatus.abandoned:
        return const _StatusConfig(
          color: Colors.red,
          icon: Icons.cancel,
          label: 'Abandoned',
        );
      case SubmissionStatus.reviewed:
        return const _StatusConfig(
          color: Colors.blue,
          icon: Icons.visibility,
          label: 'Reviewed',
        );
      case SubmissionStatus.processed:
        return const _StatusConfig(
          color: Colors.purple,
          icon: Icons.done_all,
          label: 'Processed',
        );
      default:
        return _StatusConfig(
          color: Colors.grey,
          icon: Icons.help,
          label: status,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    final iconSize = compact ? 12.0 : 14.0;
    final fontSize = compact ? 10.0 : 12.0;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: config.color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(config.icon, size: iconSize, color: config.color),
            if (showLabel) SizedBox(width: compact ? 3 : 4),
          ],
          if (showLabel)
            Text(
              config.label,
              style: TextStyle(
                color: config.color,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

/// A chip version of the status badge for use in filter UI
class SubmissionStatusChip extends StatelessWidget {
  final String status;
  final bool selected;
  final VoidCallback? onTap;

  const SubmissionStatusChip({
    Key? key,
    required this.status,
    this.selected = false,
    this.onTap,
  }) : super(key: key);

  _StatusConfig _getConfig() {
    switch (status) {
      case SubmissionStatus.draft:
        return const _StatusConfig(
          color: Colors.grey,
          icon: Icons.edit_note,
          label: 'Draft',
        );
      case SubmissionStatus.inProgress:
        return const _StatusConfig(
          color: Colors.orange,
          icon: Icons.edit,
          label: 'In Progress',
        );
      case SubmissionStatus.submitted:
        return const _StatusConfig(
          color: Colors.green,
          icon: Icons.check_circle,
          label: 'Submitted',
        );
      case SubmissionStatus.abandoned:
        return const _StatusConfig(
          color: Colors.red,
          icon: Icons.cancel,
          label: 'Abandoned',
        );
      case SubmissionStatus.reviewed:
        return const _StatusConfig(
          color: Colors.blue,
          icon: Icons.visibility,
          label: 'Reviewed',
        );
      case SubmissionStatus.processed:
        return const _StatusConfig(
          color: Colors.purple,
          icon: Icons.done_all,
          label: 'Processed',
        );
      default:
        return _StatusConfig(
          color: Colors.grey,
          icon: Icons.help,
          label: status,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return FilterChip(
      avatar: Icon(
        config.icon,
        size: 16,
        color: selected ? Colors.white : config.color,
      ),
      label: Text(config.label),
      selected: selected,
      selectedColor: config.color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : config.color,
      ),
      onSelected: onTap != null ? (_) => onTap!() : null,
    );
  }
}

/// A filter bar that allows selecting submission statuses
class SubmissionStatusFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final bool showAllOption;
  final List<String>? availableStatuses;

  const SubmissionStatusFilterBar({
    Key? key,
    this.selectedStatus,
    required this.onStatusChanged,
    this.showAllOption = true,
    this.availableStatuses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statuses = availableStatuses ?? SubmissionStatus.all;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showAllOption)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Icon(Icons.list, size: 16),
                label: const Text('All'),
                selected: selectedStatus == null,
                onSelected: (_) => onStatusChanged(null),
              ),
            ),
          ...statuses.map((status) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SubmissionStatusChip(
              status: status,
              selected: selectedStatus == status,
              onTap: () => onStatusChanged(
                selectedStatus == status ? null : status,
              ),
            ),
          )),
        ],
      ),
    );
  }
}
