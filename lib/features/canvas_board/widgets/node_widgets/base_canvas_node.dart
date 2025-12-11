import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Base widget wrapper for all canvas nodes
/// Provides selection styling, resize handles, and common interactions
class BaseCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;
  final Color? accentColor;
  final bool showResizeHandles;

  const BaseCanvasNode({
    super.key,
    required this.node,
    required this.child,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
    this.accentColor,
    this.showResizeHandles = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: accent, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accent.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: child,
        ),
      ),
    );
  }
}

/// Type label header for entity nodes
class NodeTypeHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onMorePressed;
  final Widget? trailing;

  const NodeTypeHeader({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onMorePressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else if (onMorePressed != null)
            GestureDetector(
              onTap: onMorePressed,
              child: Icon(
                Icons.more_horiz,
                size: 16,
                color: color.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }
}
