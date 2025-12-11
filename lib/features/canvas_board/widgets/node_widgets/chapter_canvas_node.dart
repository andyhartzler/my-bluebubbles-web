import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/base_canvas_node.dart';
import 'package:bluebubbles/models/crm/chapter.dart';

/// Canvas node widget for displaying a Chapter entity
class ChapterCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final Chapter? chapter;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;

  static const accentColor = Color(0xFF4CAF50); // Green

  const ChapterCanvasNode({
    super.key,
    required this.node,
    this.chapter,
    this.isSelected = false,
    this.isLoading = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCanvasNode(
      node: node,
      isSelected: isSelected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onDelete: onDelete,
      accentColor: accentColor,
      child: Container(
        width: node.width,
        height: node.height,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NodeTypeHeader(
              label: 'Chapter',
              icon: Icons.account_tree,
              color: accentColor,
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : chapter == null
                      ? _buildErrorState()
                      : _buildChapterContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'Chapter not found',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterContent() {
    final c = chapter!;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accentColor.withOpacity(0.1),
                child: const Icon(
                  Icons.school,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  c.chapterName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.school_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  c.schoolName,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              c.chapterType == 'college' ? 'College' : 'High School',
              style: const TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
