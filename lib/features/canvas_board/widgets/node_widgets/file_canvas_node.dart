import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/services/canvas_file_service.dart';

/// Canvas node widget for displaying a file
class FileCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  const FileCanvasNode({
    super.key,
    required this.node,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onDownload,
      child: Container(
        width: node.width,
        height: node.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : Border.all(color: Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: _buildFileIcon(),
            ),
            _buildFileInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    final iconData = _getFileIcon();
    final iconColor = _getFileIconColor();

    return Stack(
      children: [
        Center(
          child: Icon(
            iconData,
            size: 48,
            color: iconColor,
          ),
        ),
        if (isSelected && onDelete != null)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileInfo() {
    final fileSize = node.fileSize != null
        ? CanvasFileService.formatFileSize(node.fileSize!)
        : '';
    final dateAdded = node.createdAt != null
        ? DateFormat('MMM d').format(node.createdAt!)
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            node.fileName ?? node.label ?? 'Unknown file',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            [fileSize, if (dateAdded.isNotEmpty) 'Added $dateAdded']
                .where((s) => s.isNotEmpty)
                .join(' • '),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    final mimeType = node.fileType ?? '';
    final iconType = CanvasFileService.getFileTypeIcon(mimeType);

    switch (iconType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'word':
        return Icons.description;
      case 'excel':
        return Icons.table_chart;
      case 'powerpoint':
        return Icons.slideshow;
      case 'text':
        return Icons.article;
      case 'csv':
        return Icons.grid_on;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor() {
    final mimeType = node.fileType ?? '';
    final iconType = CanvasFileService.getFileTypeIcon(mimeType);

    switch (iconType) {
      case 'pdf':
        return Colors.red[700]!;
      case 'word':
        return Colors.blue[700]!;
      case 'excel':
        return Colors.green[700]!;
      case 'powerpoint':
        return Colors.orange[700]!;
      case 'text':
        return Colors.grey[600]!;
      case 'csv':
        return Colors.green[600]!;
      case 'image':
        return Colors.purple[600]!;
      default:
        return Colors.grey[500]!;
    }
  }
}
