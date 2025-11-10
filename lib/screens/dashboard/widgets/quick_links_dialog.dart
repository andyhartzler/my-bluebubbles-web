import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/quick_link.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';

typedef QuickLinkManageCallback = void Function(
  QuickLink link, {
  bool startInDeleteMode,
});

class QuickLinksDialog extends StatelessWidget {
  const QuickLinksDialog({super.key, required this.repository});

  final QuickLinksRepository repository;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: QuickLinksPanel(repository: repository),
      ),
    );
  }
}

class QuickLinksPanel extends StatefulWidget {
  const QuickLinksPanel({super.key, required this.repository});

  final QuickLinksRepository repository;

  @override
  State<QuickLinksPanel> createState() => _QuickLinksPanelState();
}

class _QuickLinksPanelState extends State<QuickLinksPanel> {
  bool _loading = true;
  bool _processing = false;
  String? _error;
  List<QuickLink> _links = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final links = await widget.repository.fetchQuickLinks();
      if (!mounted) return;
      setState(() {
        _links = links;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setProcessing(Future<void> Function() fn) async {
    if (!mounted) return;
    setState(() => _processing = true);
    try {
      await fn();
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyLink(QuickLink link) async {
    final url = link.resolvedUrl;
    if (url == null || url.isEmpty) {
      _showMessage('No URL available to copy.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    _showMessage('Copied link to clipboard.');
  }

  Uri? _resolvePublicFileUri(QuickLink link) {
    if (!link.hasStorageReference) {
      return null;
    }

    final supabaseUrl = CRMConfig.supabaseUrl;
    if (supabaseUrl.isEmpty) {
      return null;
    }

    final baseUri = Uri.tryParse(supabaseUrl);
    final path = link.storagePath;
    if (baseUri == null || path == null || path.isEmpty) {
      return null;
    }

    final bucket = link.storageBucket ?? QuickLinksRepository.storageBucket;
    final segments = <String>[
      ...baseUri.pathSegments,
      'storage',
      'v1',
      'object',
      'public',
      bucket,
      ...path.split('/').where((segment) => segment.isNotEmpty),
    ];

    return Uri(
      scheme: baseUri.scheme,
      userInfo: baseUri.userInfo,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      pathSegments: segments,
    );
  }

  Future<void> _openUri(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openLink(QuickLink link, {String? errorLabel}) async {
    final url = link.resolvedUrl;
    if (url == null || url.isEmpty) {
      _showMessage('No URL available for this quick link.');
      return;
    }

    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _showMessage('No URL available for this quick link.');
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.hasScheme && !uri.isScheme('file'))) {
      final resolved = Uri.tryParse('https://$trimmed');
      if (resolved == null) {
        _showMessage(errorLabel ?? 'Unable to open link: $trimmed');
        return;
      }
      await launchUrl(resolved, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<PlatformFile?> _pickFile() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(withData: !kIsWeb);
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final selected = result.files.single;
      return await materializePickedPlatformFile(selected, source: result);
    } catch (error) {
      _showMessage('Failed to pick file: $error');
      return null;
    }
  }

  Future<void> _manageLink(
    QuickLink link, {
    bool startInDeleteMode = false,
  }) async {
    final result = await showDialog<_QuickLinkFormResult>(
      context: context,
      builder: (_) => _QuickLinkFormDialog(
        existing: link,
        startInDeleteMode: startInDeleteMode,
      ),
    );

    if (!mounted || result == null) return;

    await _setProcessing(() async {
      QuickLink updated;
      if (result.delete) {
        await widget.repository.deleteQuickLink(link);
        if (!mounted) return;
        setState(() {
          _links = _links.where((item) => item.id != link.id).toList();
        });
        _showMessage('Removed "${link.title}"');
        return;
      }

      updated = await widget.repository.updateQuickLink(
        link,
        title: result.title,
        category: result.category,
        description: result.description,
        externalUrl: result.externalUrl,
        iconUrl: result.iconUrl,
        file: result.file,
        removeExistingFile: result.removeFile && result.file == null,
      );
      if (!mounted) return;
      setState(() {
        _links = _links.map((item) => item.id == updated.id ? updated : item).toList();
      });
      _showMessage('Updated "${updated.title}"');
    });
  }

  Future<void> _createLink() async {
    final result = await showDialog<_QuickLinkFormResult>(
      context: context,
      builder: (_) => const _QuickLinkFormDialog(),
    );

    if (!mounted || result == null) return;

    await _setProcessing(() async {
      final created = await widget.repository.createQuickLink(
        title: result.title,
        category: result.category,
        description: result.description,
        externalUrl: result.externalUrl,
        iconUrl: result.iconUrl,
        file: result.file,
      );
      if (!mounted) return;
      setState(() {
        _links = [..._links, created]
          ..sort((a, b) {
            final categoryCompare = a.displayCategory
                .toLowerCase()
                .compareTo(b.displayCategory.toLowerCase());
            if (categoryCompare != 0) return categoryCompare;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
      });
      _showMessage('Created "${created.title}"');
    });
  }

  Future<void> _removeFile(QuickLink link) async {
    if (!link.hasStorageReference) {
      _showMessage('No stored file to remove.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove stored file?'),
        content: Text('Remove the uploaded file for "${link.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _setProcessing(() async {
      final updated = await widget.repository.updateQuickLink(
        link,
        removeExistingFile: true,
      );
      if (!mounted) return;
      setState(() {
        _links = _links.map((item) => item.id == updated.id ? updated : item).toList();
      });
      _showMessage('Removed stored file for "${link.title}"');
    });
  }

  Future<void> _uploadToLink(QuickLink link) async {
    final picked = await _pickFile();
    if (!mounted || picked == null) {
      return;
    }

    await _setProcessing(() async {
      final updated = await widget.repository.updateQuickLink(
        link,
        file: picked,
      );
      if (!mounted) return;

      setState(() {
        _links = _links.map((item) => item.id == updated.id ? updated : item).toList();
      });

      final action = link.hasStorageReference ? 'Replaced' : 'Uploaded';
      _showMessage('$action file for "${link.title}"');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaffoldMessenger(
      child: Material(
        color: theme.colorScheme.background,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Links',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Launch shared resources, upload new files, and manage access. ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _processing ? null : _createLink,
                    icon: const Icon(Icons.add),
                    label: const Text('New Quick Link'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_processing) const SizedBox(height: 8),
              if (_processing) const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 16),
              Expanded(
                child: _buildBody(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load quick links',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_links.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'No quick links yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first quick link to share files and resources with the team.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    final socialMedia = _links
        .where((link) => link.normalizedCategory == 'social_media')
        .toList();
    final websites = _links
        .where((link) => const {'website', 'websites'}.contains(link.normalizedCategory))
        .toList();
    final documents = _links
        .where((link) =>
            const {'documents', 'document', 'governing_documents'}
                .contains(link.normalizedCategory))
        .toList();

    final handledIds = <String>{
      ...socialMedia.map((link) => link.id),
      ...websites.map((link) => link.id),
      ...documents.map((link) => link.id),
    };

    final remaining = _links
        .where((link) => !handledIds.contains(link.id))
        .toList();

    final groupedOthers = <String, List<QuickLink>>{};
    for (final link in remaining) {
      groupedOthers.putIfAbsent(link.displayCategory, () => []).add(link);
    }

    final otherSections = groupedOthers.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    for (final entry in otherSections) {
      entry.value.sort((a, b) {
        final orderCompare = (a.sortOrder ?? 1 << 20).compareTo(b.sortOrder ?? 1 << 20);
        if (orderCompare != 0) return orderCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          if (socialMedia.isNotEmpty)
            _buildSocialMediaSection(socialMedia, theme),
          if (websites.isNotEmpty)
            _buildWebsitesSection(websites, theme),
          if (documents.isNotEmpty)
            _buildDocumentsSection(documents, theme),
          for (final entry in otherSections)
            _buildGenericSection(entry.key, entry.value, theme),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSocialMediaSection(List<QuickLink> links, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Social Media', theme),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final link in links)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: link.title,
                          child: InkWell(
                            onTap: () => _openLink(link),
                            borderRadius: BorderRadius.circular(32),
                            child: _buildLinkAvatar(link, size: 56),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _QuickLinkOverflowMenu(
                          link: link,
                          onManage: _manageLink,
                          onUploadFile: _uploadToLink,
                          onRemoveFile: _removeFile,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsitesSection(List<QuickLink> links, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Websites', theme),
          const SizedBox(height: 12),
          ...links.map((link) => _buildWebsiteRow(link, theme)),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(List<QuickLink> links, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Governing Documents', theme),
          const SizedBox(height: 12),
          ...links.map((link) => _buildDocumentRow(link, theme)),
        ],
      ),
    );
  }

  Widget _buildGenericSection(
    String category,
    List<QuickLink> links,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(category, theme),
          const SizedBox(height: 12),
          ...links.map((link) => _buildGenericTile(link, theme)),
        ],
      ),
    );
  }

  Widget _buildWebsiteRow(QuickLink link, ThemeData theme) {
    final url = link.resolvedUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _openLink(link),
            borderRadius: BorderRadius.circular(12),
            child: _buildLinkAvatar(link, size: 44),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextButton(
              onPressed: () => _openLink(link),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                link.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy link',
            onPressed: url == null ? null : () => _copyLink(link),
            icon: const Icon(Icons.copy),
          ),
          _QuickLinkOverflowMenu(
            link: link,
            onManage: _manageLink,
            onUploadFile: _uploadToLink,
            onRemoveFile: _removeFile,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(QuickLink link, ThemeData theme) {
    final pdfUri = _resolvePublicFileUri(link);
    final hasDriveLink = (link.externalUrl ?? '').trim().isNotEmpty;
    final description = link.description?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  link.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _QuickLinkOverflowMenu(
                link: link,
                onManage: _manageLink,
                onUploadFile: _uploadToLink,
                onRemoveFile: _removeFile,
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (hasDriveLink)
                _QuickLinkActionButton(
                  label: 'View in Google Drive',
                  icon: Icons.open_in_new,
                  onPressed: () => _openLink(link),
                ),
              if (pdfUri != null)
                _QuickLinkActionButton(
                  label: 'View PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  onPressed: () => _openUri(pdfUri),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenericTile(QuickLink link, ThemeData theme) {
    final url = link.resolvedUrl;
    final pdfUri = _resolvePublicFileUri(link);
    final description = link.description?.trim();
    final notes = link.notes?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: _QuickLinkIconAvatar(link: link, size: 44),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    link.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _QuickLinkOverflowMenu(
                  link: link,
                  onManage: _manageLink,
                  onUploadFile: _uploadToLink,
                  onRemoveFile: _removeFile,
                ),
              ],
            ),
            if (link.hasStorageReference) ...[
              const SizedBox(height: 8),
              Text(
                link.fileName ?? link.storagePath!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (url != null)
                  _QuickLinkActionButton(
                    label: 'Open link',
                    icon: Icons.open_in_new,
                    onPressed: () => _openLink(link),
                  ),
                if (url != null)
                  _QuickLinkActionButton(
                    label: 'Copy link',
                    icon: Icons.copy,
                    onPressed: () => _copyLink(link),
                  ),
                if (pdfUri != null)
                  _QuickLinkActionButton(
                    label: 'View PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    onPressed: () => _openUri(pdfUri),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkAvatar(QuickLink link, {double size = 48}) {
    return _QuickLinkIconAvatar(link: link, size: size);
  }
}

class _QuickLinkActionButton extends StatelessWidget {
  const _QuickLinkActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _QuickLinkIconAvatar extends StatelessWidget {
  const _QuickLinkIconAvatar({required this.link, this.size = 48});

  final QuickLink link;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconUrl = link.iconUrl?.trim();
    final borderRadius = BorderRadius.circular(size / 2);

    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(context),
        ),
      );
    }

    return _buildFallbackAvatar(context);
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
      child: Icon(
        Icons.link,
        size: size / 2,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _QuickLinkOverflowMenu extends StatelessWidget {
  const _QuickLinkOverflowMenu({
    required this.link,
    required this.onManage,
    required this.onUploadFile,
    required this.onRemoveFile,
  });

  final QuickLink link;
  final QuickLinkManageCallback onManage;
  final ValueChanged<QuickLink> onUploadFile;
  final ValueChanged<QuickLink> onRemoveFile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_QuickLinkMenuAction>(
      tooltip: 'More actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _QuickLinkMenuAction.edit:
            onManage(link);
            break;
          case _QuickLinkMenuAction.upload:
            onUploadFile(link);
            break;
          case _QuickLinkMenuAction.removeFile:
            onRemoveFile(link);
            break;
          case _QuickLinkMenuAction.delete:
            onManage(link, startInDeleteMode: true);
            break;
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: _QuickLinkMenuAction.edit,
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit details'),
            ),
          ),
          const PopupMenuItem(
            value: _QuickLinkMenuAction.upload,
            child: ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Upload or replace file'),
            ),
          ),
          if (link.hasStorageReference)
            const PopupMenuItem(
              value: _QuickLinkMenuAction.removeFile,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Remove stored file'),
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _QuickLinkMenuAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_forever),
              title: Text('Delete quick link'),
            ),
          ),
        ];
      },
    );
  }
}
enum _QuickLinkMenuAction { edit, upload, removeFile, delete }

class _QuickLinkFormDialog extends StatefulWidget {
  const _QuickLinkFormDialog({
    this.existing,
    this.startInDeleteMode = false,
  });

  final QuickLink? existing;
  final bool startInDeleteMode;

  @override
  State<_QuickLinkFormDialog> createState() => _QuickLinkFormDialogState();
}

class _QuickLinkFormDialogState extends State<_QuickLinkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _urlController;
  late final TextEditingController _iconController;
  PlatformFile? _selectedFile;
  bool _removeFile = false;
  bool _delete = false;

  QuickLink? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: existing?.title ?? '');
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _urlController = TextEditingController(text: existing?.externalUrl ?? '');
    _iconController = TextEditingController(text: existing?.iconUrl ?? '');
    _delete = widget.startInDeleteMode;
    _removeFile = widget.startInDeleteMode;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await file_picker.FilePicker.platform.pickFiles(withData: !kIsWeb);
    if (file == null || file.files.isEmpty) return;
    final materialized = await materializePickedPlatformFile(
      file.files.single,
      source: file,
    );
    if (materialized == null) return;
    setState(() {
      _selectedFile = materialized;
      _removeFile = false;
    });
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
      _removeFile = true;
    });
  }

  void _toggleDelete() {
    setState(() {
      _delete = !_delete;
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    Navigator.of(context).pop(
      _QuickLinkFormResult(
        title: _titleController.text.trim(),
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        externalUrl: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        iconUrl: _iconController.text.trim(),
        file: _selectedFile,
        removeFile: _removeFile,
        delete: _delete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(existing == null ? 'New Quick Link' : 'Edit Quick Link'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category *'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'External URL'),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || (!uri.hasScheme && !uri.host.contains('.'))) {
                    return 'Enter a valid URL including https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _iconController,
                decoration: const InputDecoration(labelText: 'Icon URL'),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || (!uri.hasScheme && !uri.host.contains('.'))) {
                    return 'Enter a valid URL including https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedFile != null)
                          Text('Selected: ${_selectedFile!.name}'),
                        if (_selectedFile == null && existing?.hasStorageReference == true)
                          Text(
                            'Current file: ${existing!.fileName ?? existing!.storagePath}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (_removeFile && existing?.hasStorageReference == true)
                          Text(
                            'Stored file will be removed',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Attach File'),
                  ),
                  if (_selectedFile != null || existing?.hasStorageReference == true)
                    TextButton(
                      onPressed: _clearFile,
                      child: const Text('Remove File'),
                    ),
                ],
              ),
              if (existing != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _delete,
                  onChanged: (_) => _toggleDelete(),
                  title: const Text('Delete this quick link'),
                  subtitle: const Text('This action cannot be undone'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(existing == null ? 'Create' : _delete ? 'Confirm Delete' : 'Save'),
        ),
      ],
    );
  }
}

class _QuickLinkFormResult {
  _QuickLinkFormResult({
    required this.title,
    required this.category,
    required this.description,
    required this.externalUrl,
    required this.iconUrl,
    this.file,
    this.removeFile = false,
    this.delete = false,
  });

  final String title;
  final String category;
  final String? description;
  final String? externalUrl;
  final String? iconUrl;
  final PlatformFile? file;
  final bool removeFile;
  final bool delete;
}
