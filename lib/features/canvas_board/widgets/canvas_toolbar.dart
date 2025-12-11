import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Available tools in the canvas toolbar
enum CanvasTool {
  select,
  pan,
  draw,
  arrow,
  line,
  rectangle,
  circle,
  text,
  note,
}

/// Toolbar for the canvas board with drawing and selection tools
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
  final bool canUndo;
  final bool canRedo;
  final bool hasSelection;

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
    this.canUndo = false,
    this.canRedo = false,
    this.hasSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          // Tool selection buttons
          _buildToolGroup([
            _ToolItem(CanvasTool.select, Icons.near_me, 'Select (V)'),
            _ToolItem(CanvasTool.pan, Icons.pan_tool, 'Pan (H)'),
          ]),
          _buildDivider(),
          _buildToolGroup([
            _ToolItem(CanvasTool.draw, Icons.brush, 'Draw (D)'),
            _ToolItem(CanvasTool.arrow, Icons.north_east, 'Arrow (A)'),
            _ToolItem(CanvasTool.line, Icons.remove, 'Line (L)'),
          ]),
          _buildDivider(),
          _buildToolGroup([
            _ToolItem(CanvasTool.rectangle, Icons.crop_square, 'Rectangle (R)'),
            _ToolItem(CanvasTool.circle, Icons.circle_outlined, 'Circle (O)'),
          ]),
          _buildDivider(),
          _buildToolGroup([
            _ToolItem(CanvasTool.text, Icons.text_fields, 'Text (T)'),
            _ToolItem(CanvasTool.note, Icons.note_add, 'Note (N)'),
          ]),
          _buildDivider(),
          // Color picker
          _buildColorPicker(context),
          const SizedBox(width: 8),
          // Stroke width
          _buildStrokeWidthPicker(context),
          const Spacer(),
          // Undo/Redo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.undo,
                tooltip: 'Undo (Ctrl+Z)',
                onPressed: canUndo ? onUndo : null,
              ),
              _buildActionButton(
                icon: Icons.redo,
                tooltip: 'Redo (Ctrl+Shift+Z)',
                onPressed: canRedo ? onRedo : null,
              ),
              if (hasSelection) ...[
                _buildDivider(),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete (Del)',
                  onPressed: onDelete,
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolGroup(List<_ToolItem> tools) {
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
                color: isSelected ? Colors.blue : Colors.grey[700],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey[300],
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
                ? (color ?? Colors.grey[700])
                : Colors.grey[400],
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
