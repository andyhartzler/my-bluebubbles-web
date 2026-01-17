import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Model for a Slack file attachment from files_archived
class SlackArchivedFile {
  final String id;
  final String name;
  final int size;
  final String mimetype;
  final String? supabaseUrl;
  final String? supabasePath;
  final String? urlPrivate;
  final DateTime? archivedAt;

  const SlackArchivedFile({
    required this.id,
    required this.name,
    required this.size,
    required this.mimetype,
    this.supabaseUrl,
    this.supabasePath,
    this.urlPrivate,
    this.archivedAt,
  });

  factory SlackArchivedFile.fromJson(Map<String, dynamic> json) {
    return SlackArchivedFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown File',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimetype: json['mimetype']?.toString() ?? 'application/octet-stream',
      supabaseUrl: json['supabase_url']?.toString(),
      supabasePath: json['supabase_path']?.toString(),
      urlPrivate: json['url_private']?.toString(),
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'].toString())
          : null,
    );
  }

  /// Check if this is an image file
  bool get isImage => mimetype.startsWith('image/');

  /// Check if this is a video file
  bool get isVideo => mimetype.startsWith('video/');

  /// Check if this is a PDF
  bool get isPdf => mimetype == 'application/pdf';

  /// Get the best available URL for the file
  String? get url => supabaseUrl ?? urlPrivate;

  /// Get a human-readable file size
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get the file extension
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}

/// Parse files_archived JSON data into a list of SlackArchivedFile
List<SlackArchivedFile> parseArchivedFiles(dynamic filesArchived) {
  if (filesArchived == null) return [];

  List<dynamic> filesList;
  if (filesArchived is String) {
    try {
      filesList = jsonDecode(filesArchived) as List<dynamic>;
    } catch (e) {
      return [];
    }
  } else if (filesArchived is List) {
    filesList = filesArchived;
  } else {
    return [];
  }

  return filesList
      .whereType<Map<String, dynamic>>()
      .map((f) => SlackArchivedFile.fromJson(f))
      .where((f) => f.url != null && f.url!.isNotEmpty)
      .toList();
}

/// Widget to display a list of file attachments
class SlackFileAttachments extends StatelessWidget {
  const SlackFileAttachments({
    super.key,
    required this.files,
    this.maxVisible = 3,
    this.darkBackground = false,
  });

  final List<SlackArchivedFile> files;
  final int maxVisible;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    final visibleFiles = files.take(maxVisible).toList();
    final remainingCount = files.length - maxVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleFiles.map(
          (file) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SlackFileAttachmentTile(
              file: file,
              darkBackground: darkBackground,
            ),
          ),
        ),
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => _showAllFilesDialog(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Text(
                  '+$remainingCount more file${remainingCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: darkBackground
                        ? const Color(0xFF32A6DE)
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAllFilesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${files.length} Files'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: files.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SlackFileAttachmentTile(file: files[index]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A single file attachment tile
class SlackFileAttachmentTile extends StatelessWidget {
  const SlackFileAttachmentTile({
    super.key,
    required this.file,
    this.darkBackground = false,
  });

  final SlackArchivedFile file;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showFilePreview(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: darkBackground
              ? Colors.white.withOpacity(0.15)
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: darkBackground
              ? null
              : Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            _buildFileIcon(theme),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: darkBackground
                        ? const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          )
                        : theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_getMimeTypeLabel()} • ${file.formattedSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: darkBackground
                          ? Colors.white.withOpacity(0.7)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 18,
              color: darkBackground
                  ? Colors.white.withOpacity(0.7)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(ThemeData theme) {
    IconData icon;
    Color color;

    if (file.isImage) {
      icon = Icons.image;
      color = Colors.blue;
    } else if (file.isVideo) {
      icon = Icons.video_file;
      color = Colors.purple;
    } else if (file.isPdf) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else {
      switch (file.extension) {
        case 'doc':
        case 'docx':
          icon = Icons.description;
          color = Colors.blue;
          break;
        case 'xls':
        case 'xlsx':
          icon = Icons.table_chart;
          color = Colors.green;
          break;
        case 'ppt':
        case 'pptx':
          icon = Icons.slideshow;
          color = Colors.orange;
          break;
        case 'zip':
        case 'rar':
        case '7z':
          icon = Icons.folder_zip;
          color = Colors.amber;
          break;
        case 'txt':
        case 'md':
          icon = Icons.article;
          color = Colors.grey;
          break;
        default:
          icon = Icons.insert_drive_file;
          color = Colors.grey;
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _getMimeTypeLabel() {
    if (file.isImage) return 'Image';
    if (file.isVideo) return 'Video';
    if (file.isPdf) return 'PDF';
    return file.extension.toUpperCase();
  }

  void _showFilePreview(BuildContext context) {
    if (file.url == null) return;

    if (file.isImage) {
      showDialog(
        context: context,
        builder: (context) => SlackFilePreviewDialog(file: file),
      );
    } else {
      // For non-image files, show a dialog with option to open
      showDialog(
        context: context,
        builder: (context) => SlackFilePreviewDialog(file: file),
      );
    }
  }
}

/// Dialog for previewing files
class SlackFilePreviewDialog extends StatelessWidget {
  const SlackFilePreviewDialog({super.key, required this.file});

  final SlackArchivedFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.9,
          maxHeight: screenSize.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getMimeTypeLabel()} • ${file.formattedSize}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: file.isImage
                  ? _buildImagePreview(context)
                  : _buildGenericPreview(context),
            ),

            // Footer with actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openInNewTab(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open in New Tab'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            file.url!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildGenericPreview(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGenericPreview(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLargeFileIcon(theme),
          const SizedBox(height: 16),
          Text(
            'Preview not available',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Open in New Tab" to view this file',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeFileIcon(ThemeData theme) {
    IconData icon;
    Color color;

    if (file.isImage) {
      icon = Icons.image;
      color = Colors.blue;
    } else if (file.isVideo) {
      icon = Icons.video_file;
      color = Colors.purple;
    } else if (file.isPdf) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 64),
    );
  }

  String _getMimeTypeLabel() {
    if (file.isImage) return 'Image';
    if (file.isVideo) return 'Video';
    if (file.isPdf) return 'PDF';
    return file.extension.toUpperCase();
  }

  Future<void> _openInNewTab(BuildContext context) async {
    if (file.url == null) return;

    final uri = Uri.parse(file.url!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    }
  }
}
