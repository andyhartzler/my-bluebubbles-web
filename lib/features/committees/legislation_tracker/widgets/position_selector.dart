import 'package:flutter/material.dart';
import '../models/tracked_bill.dart';

/// Widget for selecting a bill position (Support/Oppose/Watching/Neutral)
class PositionSelector extends StatelessWidget {
  final BillPosition currentPosition;
  final ValueChanged<BillPosition> onChanged;
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

    return _buildFullSelector(context, theme);
  }

  Widget _buildFullSelector(BuildContext context, ThemeData theme) {
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<BillPosition>(
            segments: BillPosition.values.map((position) {
              return ButtonSegment<BillPosition>(
                value: position,
                label: Text(
                  position.label,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
                icon: Text(position.emoji),
              );
            }).toList(),
            selected: {currentPosition},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) {
                onChanged(selected.first);
              }
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return currentPosition.color.withOpacity(0.2);
                }
                return null;
              }),
              minimumSize: WidgetStateProperty.all(const Size(80, 40)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSelector(BuildContext context, ThemeData theme) {
    return PopupMenuButton<BillPosition>(
      initialValue: currentPosition,
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: currentPosition.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: currentPosition.color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentPosition.emoji),
            const SizedBox(width: 6),
            Text(
              currentPosition.label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: currentPosition.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: currentPosition.color,
              size: 20,
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        return BillPosition.values.map((position) {
          final isSelected = position == currentPosition;
          return PopupMenuItem<BillPosition>(
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
                  Icon(
                    Icons.check,
                    color: position.color,
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
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
