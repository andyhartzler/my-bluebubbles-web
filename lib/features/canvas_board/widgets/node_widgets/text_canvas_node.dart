import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Canvas node widget for displaying plain text
class TextCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onContentChanged;
  final TextEditingController? textController;

  const TextCanvasNode({
    super.key,
    required this.node,
    this.isSelected = false,
    this.isEditing = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
    this.onContentChanged,
    this.textController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        width: node.width,
        height: node.height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: isEditing && textController != null
            ? TextField(
                controller: textController,
                maxLines: null,
                expands: true,
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Type text...',
                ),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
                onChanged: onContentChanged,
              )
            : Text(
                node.textContent ?? '',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                overflow: TextOverflow.fade,
              ),
      ),
    );
  }
}
