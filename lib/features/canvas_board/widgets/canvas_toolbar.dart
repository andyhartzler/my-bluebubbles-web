import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Available tools in the canvas toolbar
/// Matches fldraw's EditorTool enum for feature parity
enum CanvasTool {
  select,    // Select/move objects
  pan,       // Pan the canvas
  draw,      // Freehand drawing (pencil)
  arrow,     // Arrow connector
  line,      // Line
  rectangle, // Rectangle shape
  circle,    // Circle/oval shape
  text,      // Text object
  note,      // Sticky note
  figure,    // Figure/group container (dashed border)
  comment,   // Comment annotation
}

/// Toolbar for the canvas board with drawing and selection tools
/// Designed to match fldraw's feature set with precision
class CanvasToolbar extends StatelessWidget {
  final CanvasTool selectedTool;
  final ValueChanged<CanvasTool> onToolSelected;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final double strokeWidth;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final bool canUndo;
  final bool canRedo;
  final bool hasSelection;
  final bool canPaste;

  // Default colors for the color picker
  static const defaultColors = [
    Colors.black,
    Color(0xFF424242),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFF44336),
    Color(0xFF9C27B0),
    Color(0xFFFFEB3B),
  ];

  const CanvasToolbar({
    super.key,
    required this.selectedTool,
    required this.onToolSelected,
    required this.selectedColor,
    required this.onColorSelected,
    required this.strokeWidth,
    required this.onStrokeWidthChanged,
    this.onUndo,
    this.onRedo,
    this.onDelete,
    this.onCopy,
    this.onCut,
    this.onPaste,
    this.canUndo = false,
    this.canRedo = false,
    this.hasSelection = false,
    this.canPaste = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Selection tools
          _buildToolGroup([
            _ToolItem(CanvasTool.select, Icons.near_me, 'Select'),
            _ToolItem(CanvasTool.pan, Icons.pan_tool, 'Pan'),
          ], isDark),
          _buildDivider(isDark),
          // Drawing tools
          _buildToolGroup([
            _ToolItem(CanvasTool.draw, Icons.brush, 'Draw'),
            _ToolItem(CanvasTool.arrow, Icons.north_east, 'Arrow'),
            _ToolItem(CanvasTool.line, Icons.remove, 'Line'),
          ], isDark),
          _buildDivider(isDark),
          // Shape tools
          _buildToolGroup([
            _ToolItem(CanvasTool.rectangle, Icons.crop_square, 'Rectangle'),
            _ToolItem(CanvasTool.circle, Icons.circle_outlined, 'Circle'),
          ], isDark),
          _buildDivider(isDark),
          // Text and annotation tools
          _buildToolGroup([
            _ToolItem(CanvasTool.text, Icons.text_fields, 'Text'),
            _ToolItem(CanvasTool.note, Icons.note_add, 'Sticky Note'),
          ], isDark),
          _buildDivider(isDark),
          // Figure and comment tools (fldraw parity)
          _buildToolGroup([
            _ToolItem(CanvasTool.figure, Icons.dashboard_outlined, 'Figure/Group'),
            _ToolItem(CanvasTool.comment, Icons.chat_bubble_outline, 'Comment'),
          ], isDark),
          _buildDivider(isDark),
          // Color picker
          _buildColorPicker(context),
          const SizedBox(width: 8),
          // Stroke width
          _buildStrokeWidthPicker(context),
          const Spacer(),
          // Clipboard operations
          if (hasSelection) ...[
            _buildActionButton(
              icon: Icons.content_copy,
              tooltip: 'Copy (Ctrl+C)',
              onPressed: onCopy,
              isDark: isDark,
            ),
            _buildActionButton(
              icon: Icons.content_cut,
              tooltip: 'Cut (Ctrl+X)',
              onPressed: onCut,
              isDark: isDark,
            ),
          ],
          _buildActionButton(
            icon: Icons.content_paste,
            tooltip: 'Paste (Ctrl+V)',
            onPressed: canPaste ? onPaste : null,
            isDark: isDark,
          ),
          _buildDivider(isDark),
          // Undo/Redo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.undo,
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: canUndo ? onUndo : null,
                isDark: isDark,
              ),
              _buildActionButton(
                icon: Icons.redo,
                tooltip: 'Redo (Ctrl+Shift+Z)',
                onPressed: canRedo ? onRedo : null,
                isDark: isDark,
              ),
              if (hasSelection) ...[
                _buildDivider(isDark),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete (Del)',
                  onPressed: onDelete,
                  color: Colors.red,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolGroup(List<_ToolItem> tools, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tools.map((tool) {
        final isSelected = selectedTool == tool.tool;
        return Tooltip(
          message: tool.tooltip,
          child: InkWell(
            onTap: () => onToolSelected(tool.tool),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 1)
                    : null,
              ),
              child: Icon(
                tool.icon,
                size: 20,
                color: isSelected
                    ? Colors.blue
                    : isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }

  Widget _buildColorPicker(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: 'Color',
      offset: const Offset(0, 40),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selectedColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[400]!, width: 1),
        ),
      ),
      itemBuilder: (context) {
        return [
          PopupMenuItem<Color>(
            enabled: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: defaultColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    onColorSelected(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: selectedColor == color
                          ? Border.all(color: Colors.blue, width: 2)
                          : Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ];
      },
    );
  }

  Widget _buildStrokeWidthPicker(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Stroke Width',
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: strokeWidth.clamp(2, 8),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(strokeWidth / 2),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
      itemBuilder: (context) {
        return [1.0, 2.0, 4.0, 6.0, 8.0].map((width) {
          return PopupMenuItem<double>(
            value: width,
            onTap: () => onStrokeWidthChanged(width),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: width.clamp(2, 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(width / 2),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${width.toInt()}px'),
                if (strokeWidth == width)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check, size: 16, color: Colors.blue),
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    Color? color,
    bool isDark = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null
                ? (color ?? (isDark ? Colors.grey[400] : Colors.grey[700]))
                : (isDark ? Colors.grey[700] : Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}

class _ToolItem {
  final CanvasTool tool;
  final IconData icon;
  final String tooltip;

  const _ToolItem(this.tool, this.icon, this.tooltip);
}
