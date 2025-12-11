import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Canvas node widget for displaying a sticky note
class NoteCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onContentChanged;
  final TextEditingController? textController;

  // Default note colors
  static const defaultColors = [
    Color(0xFFFFF59D), // Yellow
    Color(0xFFFFAB91), // Orange
    Color(0xFFCE93D8), // Purple
    Color(0xFF90CAF9), // Blue
    Color(0xFFA5D6A7), // Green
    Color(0xFFF48FB1), // Pink
  ];

  const NoteCanvasNode({
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

  Color get noteColor {
    if (node.noteColor != null) {
      try {
        final hex = node.noteColor!.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    return defaultColors[0];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkerColor = HSLColor.fromColor(noteColor)
        .withLightness(
            (HSLColor.fromColor(noteColor).lightness - 0.1).clamp(0.0, 1.0))
        .toColor();

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        width: node.width,
        height: node.height,
        decoration: BoxDecoration(
          color: noteColor,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folded corner effect
            Container(
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [darkerColor, noteColor],
                  stops: const [0.0, 0.3],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.note,
                    size: 12,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  const Spacer(),
                  if (isSelected && onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
            // Note content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: isEditing && textController != null
                    ? TextField(
                        controller: textController,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Type your note...',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black.withOpacity(0.8),
                        ),
                        onChanged: onContentChanged,
                      )
                    : Text(
                        node.noteContent ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.black.withOpacity(0.8),
                        ),
                        overflow: TextOverflow.fade,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
