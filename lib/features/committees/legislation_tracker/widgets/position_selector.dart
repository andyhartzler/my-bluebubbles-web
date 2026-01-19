import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

/// Widget for selecting a bill position (Support/Oppose/Watching/Neutral) as a dropdown
class PositionSelector extends StatelessWidget {
  final BillPosition? currentPosition;
  final ValueChanged<BillPosition?> onChanged;
  final bool showLabels;
  final bool compact;

  const PositionSelector({
    super.key,
    required this.currentPosition,
    required this.onChanged,
    this.showLabels = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompactSelector(context, theme);
    }

    return _buildDropdownSelector(context, theme);
  }

  Widget _buildDropdownSelector(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels) ...[
          Text(
            'Position',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: currentPosition != null
                ? currentPosition!.color.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentPosition != null
                  ? currentPosition!.color.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BillPosition?>(
              value: currentPosition,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(Icons.help_outline, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Not Set',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: currentPosition?.color ?? Colors.grey,
              ),
              onChanged: onChanged,
              items: [
                // "Not Set" option
                DropdownMenuItem<BillPosition?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Not Set',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // All position options
                ...BillPosition.values.map((position) {
                  return DropdownMenuItem<BillPosition?>(
                    value: position,
                    child: Row(
                      children: [
                        Text(position.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          position.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: position.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSelector(BuildContext context, ThemeData theme) {
    return PopupMenuButton<BillPosition?>(
      initialValue: currentPosition,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentPosition != null
              ? currentPosition!.color.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: currentPosition != null
                ? currentPosition!.color.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentPosition != null) ...[
              Text(currentPosition!.emoji),
              const SizedBox(width: 6),
              Text(
                currentPosition!.label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: currentPosition!.color,
                ),
              ),
            ] else ...[
              Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Not Set',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: currentPosition?.color ?? Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return [
          // "Not Set" option
          PopupMenuItem<BillPosition?>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Not Set',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (currentPosition == null)
                  Icon(Icons.check, color: Colors.grey.shade600, size: 18),
              ],
            ),
          ),
          const PopupMenuDivider(),
          // All position options
          ...BillPosition.values.map((position) {
            final isSelected = position == currentPosition;
            return PopupMenuItem<BillPosition?>(
              value: position,
              child: Row(
                children: [
                  Text(position.emoji),
                  const SizedBox(width: 8),
                  Text(
                    position.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: position.color,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check, color: position.color, size: 18),
                ],
              ),
            );
          }),
        ];
      },
    );
  }
}

/// Widget for selecting bill priority as a dropdown
class PrioritySelector extends StatelessWidget {
  final BillPriority? currentPriority;
  final ValueChanged<BillPriority?> onChanged;
  final bool showLabels;
  final bool compact;

  const PrioritySelector({
    super.key,
    required this.currentPriority,
    required this.onChanged,
    this.showLabels = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompactSelector(context, theme);
    }

    return _buildDropdownSelector(context, theme);
  }

  Widget _buildDropdownSelector(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabels) ...[
          Text(
            'Priority',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: currentPriority != null
                ? currentPriority!.color.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentPriority != null
                  ? currentPriority!.color.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BillPriority?>(
              value: currentPriority,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(Icons.help_outline, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Not Set',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: currentPriority?.color ?? Colors.grey,
              ),
              onChanged: onChanged,
              items: [
                // "Not Set" option
                DropdownMenuItem<BillPriority?>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Not Set',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // All priority options
                ...BillPriority.values.map((priority) {
                  return DropdownMenuItem<BillPriority?>(
                    value: priority,
                    child: Row(
                      children: [
                        Text(priority.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          priority.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: priority.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSelector(BuildContext context, ThemeData theme) {
    return PopupMenuButton<BillPriority?>(
      initialValue: currentPriority,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentPriority != null
              ? currentPriority!.color.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: currentPriority != null
                ? currentPriority!.color.withOpacity(0.5)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentPriority != null) ...[
              Text(currentPriority!.emoji),
              const SizedBox(width: 6),
              Text(
                currentPriority!.label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: currentPriority!.color,
                ),
              ),
            ] else ...[
              Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Not Set',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: currentPriority?.color ?? Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return [
          // "Not Set" option
          PopupMenuItem<BillPriority?>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Not Set',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (currentPriority == null)
                  Icon(Icons.check, color: Colors.grey.shade600, size: 18),
              ],
            ),
          ),
          const PopupMenuDivider(),
          // All priority options
          ...BillPriority.values.map((priority) {
            final isSelected = priority == currentPriority;
            return PopupMenuItem<BillPriority?>(
              value: priority,
              child: Row(
                children: [
                  Text(priority.emoji),
                  const SizedBox(width: 8),
                  Text(
                    priority.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: priority.color,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Icon(Icons.check, color: priority.color, size: 18),
                ],
              ),
            );
          }),
        ];
      },
    );
  }
}

/// Button for quickly setting a specific position
class PositionQuickButton extends StatelessWidget {
  final BillPosition position;
  final bool isSelected;
  final VoidCallback onTap;

  const PositionQuickButton({
    super.key,
    required this.position,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? position.color.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? position.color : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                position.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                position.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? position.color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
