import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';

/// Widget for selecting a bill priority (Critical/High/Medium/Low)
class PrioritySelector extends StatelessWidget {
  final BillPriority currentPriority;
  final ValueChanged<BillPriority> onChanged;
  final bool showLabel;
  final bool compact;

  const PrioritySelector({
    super.key,
    required this.currentPriority,
    required this.onChanged,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            'Priority',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (compact)
          _buildCompactSelector(context, theme)
        else
          _buildDropdownSelector(context, theme),
      ],
    );
  }

  Widget _buildDropdownSelector(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BillPriority>(
          value: currentPriority,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          borderRadius: BorderRadius.circular(8),
          items: BillPriority.values.map((priority) {
            return DropdownMenuItem<BillPriority>(
              value: priority,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: priority.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(priority.emoji),
                  const SizedBox(width: 6),
                  Text(
                    priority.label,
                    style: TextStyle(
                      color: priority.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCompactSelector(BuildContext context, ThemeData theme) {
    return PopupMenuButton<BillPriority>(
      initialValue: currentPriority,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: currentPriority.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: currentPriority.color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentPriority.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              currentPriority.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: currentPriority.color,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: currentPriority.color,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return BillPriority.values.map((priority) {
          final isSelected = priority == currentPriority;
          return PopupMenuItem<BillPriority>(
            value: priority,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: priority.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(priority.emoji),
                const SizedBox(width: 6),
                Text(
                  priority.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check, size: 18, color: priority.color),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

/// Horizontal priority selector with all options visible
class PriorityChips extends StatelessWidget {
  final BillPriority currentPriority;
  final ValueChanged<BillPriority> onChanged;

  const PriorityChips({
    super.key,
    required this.currentPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BillPriority.values.map((priority) {
        final isSelected = priority == currentPriority;
        return ChoiceChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(priority.emoji),
              const SizedBox(width: 4),
              Text(priority.label),
            ],
          ),
          selectedColor: priority.color.withOpacity(0.3),
          side: BorderSide(
            color: isSelected ? priority.color : Colors.grey.withOpacity(0.3),
          ),
          onSelected: (selected) {
            if (selected) {
              onChanged(priority);
            }
          },
        );
      }).toList(),
    );
  }
}
