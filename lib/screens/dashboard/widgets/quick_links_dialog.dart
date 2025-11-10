import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchUrlString(String url, {String? errorLabel}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _showMessage(errorLabel ?? 'Unable to open link: $url');
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      _showMessage(errorLabel ?? 'Unable to open link: $trimmed');
      return;
    }

    if (!uri.hasScheme && !uri.isScheme('file')) {
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

  Future<void> _openLink(QuickLink link) async {
    final url = link.resolvedUrl;
    if (url == null || url.isEmpty) {
      _showMessage('No URL available for this quick link.');
      return;
    }

    await _launchUrlString(url);
  }

  Future<void> _openExternalLink(QuickLink link) async {
    final url = link.externalUrl;
    if (url == null || url.trim().isEmpty) {
      _showMessage('No external URL available for this quick link.');
      return;
    }

    await _launchUrlString(url, errorLabel: 'Unable to open external link');
  }

  Future<void> _openStoredFile(QuickLink link) async {
    final storageUrl = _resolveStorageUrl(link);
    if (storageUrl == null) {
      _showMessage('No stored file is available for this quick link.');
      return;
    }

    await _launchUrlString(storageUrl, errorLabel: 'Unable to open stored file');
  }

  Future<void> _copyLink(QuickLink link) async {
    final url = link.resolvedUrl ?? _resolveStorageUrl(link);
    if (url == null || url.isEmpty) {
      _showMessage('No link available to copy for "${link.title}".');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: url));
      _showMessage('Copied link for "${link.title}"');
    } catch (error) {
      _showMessage('Failed to copy link: $error');
    }
  }

  String? _resolveStorageUrl(QuickLink link) {
    final signed = link.signedUrl?.trim();
    if (signed != null && signed.isNotEmpty) {
      return signed;
    }
    if (!link.hasStorageReference || (link.storagePath ?? '').isEmpty) {
      return null;
    }

    final path = link.storagePath!.trim();
    final bucket = link.storageBucket ?? QuickLinksRepository.storageBucket;
    try {
      final client = Supabase.instance.client;
      final base = Uri.parse(client.supabaseUrl);
      final segments = [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        'storage',
        'v1',
        'object',
        'public',
        bucket,
        ...path.split('/').where((segment) => segment.isNotEmpty),
      ];
      final uri = base.replace(pathSegments: segments);
      return uri.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadToLink(QuickLink link) async {
    final file = await _pickFile();
    if (file == null) return;

    await _setProcessing(() async {
      final updated = await widget.repository.updateQuickLink(
        link,
        file: file,
      );
      if (!mounted) return;
      setState(() {
        _links = _links.map((item) => item.id == updated.id ? updated : item).toList();
      });
      _showMessage('File uploaded for "${updated.title}"');
    });
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

  void _handleMenuAction(_QuickLinkMenuAction action, QuickLink link) {
    switch (action) {
      case _QuickLinkMenuAction.upload:
        _uploadToLink(link);
        break;
      case _QuickLinkMenuAction.edit:
        _manageLink(link);
        break;
      case _QuickLinkMenuAction.removeFile:
        _removeFile(link);
        break;
      case _QuickLinkMenuAction.delete:
        _manageLink(link, startInDeleteMode: true);
        break;
    }
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

    final grouped = groupBy<QuickLink, String>(
      _links,
      (link) => link.displayCategory,
    );

    final categories = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final entry = categories[index];
          return _QuickLinkCategorySection(
            category: entry.key,
            links: entry.value,
            onOpen: _openLink,
            onMenuAction: _handleMenuAction,
            onCopy: _copyLink,
            onOpenExternal: _openExternalLink,
            onOpenStorage: _openStoredFile,
          );
        },
      ),
    );
  }
}

class _QuickLinkCategorySection extends StatelessWidget {
  const _QuickLinkCategorySection({
    required this.category,
    required this.links,
    required this.onOpen,
    required this.onMenuAction,
    this.onCopy,
    this.onOpenExternal,
    this.onOpenStorage,
  });

  final String category;
  final List<QuickLink> links;
  final ValueChanged<QuickLink> onOpen;
  final void Function(_QuickLinkMenuAction, QuickLink) onMenuAction;
  final ValueChanged<QuickLink>? onCopy;
  final ValueChanged<QuickLink>? onOpenExternal;
  final ValueChanged<QuickLink>? onOpenStorage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized =
        category.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    final displayTitle = normalized == 'documents' ? 'Governing Documents' : category;

    final List<Widget> content;
    switch (normalized) {
      case 'social_media':
        content = [
          _SocialMediaLinksRow(
            links: links,
            onOpen: onOpen,
            onMenuAction: onMenuAction,
          ),
        ];
        break;
      case 'websites':
        content = links
            .map(
              (link) => _WebsiteLinkTile(
                link: link,
                onOpen: onOpen,
                onCopy: onCopy,
                onMenuAction: onMenuAction,
              ),
            )
            .toList();
        break;
      case 'documents':
        content = links
            .map(
              (link) => _DocumentLinkTile(
                link: link,
                onOpenExternal: onOpenExternal,
                onOpenStorage: onOpenStorage,
                onMenuAction: onMenuAction,
              ),
            )
            .toList();
        break;
      default:
        content = links
            .map(
              (link) => _QuickLinkTile(
                link: link,
                onOpen: onOpen,
                onMenuAction: onMenuAction,
              ),
            )
            .toList();
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...content,
        ],
      ),
    );
  }
}

class _SocialMediaLinksRow extends StatelessWidget {
  const _SocialMediaLinksRow({
    required this.links,
    required this.onOpen,
    required this.onMenuAction,
  });

  final List<QuickLink> links;
  final ValueChanged<QuickLink> onOpen;
  final void Function(_QuickLinkMenuAction, QuickLink) onMenuAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < links.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == links.length - 1 ? 0 : 12),
              child: _SocialMediaLinkButton(
                link: links[i],
                onOpen: onOpen,
                onMenuAction: onMenuAction,
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialMediaLinkButton extends StatelessWidget {
  const _SocialMediaLinkButton({
    required this.link,
    required this.onOpen,
    required this.onMenuAction,
  });

  final QuickLink link;
  final ValueChanged<QuickLink> onOpen;
  final void Function(_QuickLinkMenuAction, QuickLink) onMenuAction;

  bool get _hasUrl => (link.resolvedUrl ?? '').isNotEmpty;

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final size = MediaQuery.of(context).size;
    final rect = RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      size.width - position.dx,
      size.height - position.dy,
    );

    final action = await showMenu<_QuickLinkMenuAction>(
      context: context,
      position: rect,
      items: _buildQuickLinkMenuItems(link),
    );
    if (action != null) {
      onMenuAction(action, link);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Tooltip(
        message: link.title,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _hasUrl ? () => onOpen(link) : null,
            child: Ink(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: _QuickLinkIconAvatar(link: link, size: 56),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebsiteLinkTile extends StatelessWidget {
  const _WebsiteLinkTile({
    required this.link,
    required this.onOpen,
    required this.onMenuAction,
    this.onCopy,
  });

  final QuickLink link;
  final ValueChanged<QuickLink> onOpen;
  final void Function(_QuickLinkMenuAction, QuickLink) onMenuAction;
  final ValueChanged<QuickLink>? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = (link.resolvedUrl ?? '').isNotEmpty;
    final titleStyle = hasUrl
        ? theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary,
          )
        : theme.textTheme.titleMedium;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: hasUrl ? () => onOpen(link) : null,
        leading: SizedBox(
          width: 40,
          height: 40,
          child: _QuickLinkIconAvatar(link: link, size: 40),
        ),
        title: Text(link.title, style: titleStyle),
        subtitle: (link.description ?? '').isNotEmpty
            ? Text(link.description!)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Copy link',
              icon: const Icon(Icons.copy),
              onPressed: hasUrl && onCopy != null ? () => onCopy!(link) : null,
            ),
            const SizedBox(width: 4),
            _QuickLinkOverflowMenu(
              link: link,
              onSelected: onMenuAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentLinkTile extends StatelessWidget {
  const _DocumentLinkTile({
    required this.link,
    required this.onMenuAction,
    this.onOpenExternal,
    this.onOpenStorage,
  });

  final QuickLink link;
  final void Function(_QuickLinkMenuAction, QuickLink) onMenuAction;
  final ValueChanged<QuickLink>? onOpenExternal;
  final ValueChanged<QuickLink>? onOpenStorage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExternal = link.hasExternalUrl;
    final hasStored = link.hasStorageReference || (link.signedUrl ?? '').isNotEmpty;
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: hasExternal && onOpenExternal != null
            ? () => onOpenExternal!(link)
            : null,
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open Drive'),
      ),
      FilledButton.icon(
        onPressed:
            hasStored && onOpenStorage != null ? () => onOpenStorage!(link) : null,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Open PDF'),
      ),
    ];

    final description = link.description;
    final fileLabel = link.fileName ?? link.storagePath;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      if ((fileLabel ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            fileLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _QuickLinkOverflowMenu(
                  link: link,
                  onSelected: onMenuAction,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.link,
    required this.onOpen,
    required this.onMenuAction,
  });

  final QuickLink link;
  final ValueChanged<QuickLink> onOpen;
  final void Function(_QuickLinkMenuAction, QuickLink) onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUrl = (link.resolvedUrl ?? '').isNotEmpty;

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
                if ((link.iconUrl ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: _QuickLinkIconAvatar(link: link, size: 44),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((link.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            link.description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      if (link.hasStorageReference)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            link.fileName ?? link.storagePath!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _QuickLinkOverflowMenu(
                  link: link,
                  onSelected: onMenuAction,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: hasUrl ? () => onOpen(link) : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkOverflowMenu extends StatelessWidget {
  const _QuickLinkOverflowMenu({
    required this.link,
    required this.onSelected,
  });

  final QuickLink link;
  final void Function(_QuickLinkMenuAction, QuickLink) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_QuickLinkMenuAction>(
      tooltip: 'More actions',
      onSelected: (action) => onSelected(action, link),
      itemBuilder: (context) => _buildQuickLinkMenuItems(link),
    );
  }
}

class _QuickLinkIconAvatar extends StatelessWidget {
  const _QuickLinkIconAvatar({
    required this.link,
    this.size = 32,
  });

  final QuickLink link;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconUrl = link.iconUrl?.trim();
    final fallback = Container(
      width: size,
      height: size,
      color: theme.colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        Icons.link,
        size: size * 0.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    return ClipOval(child: fallback);
  }
}

List<PopupMenuEntry<_QuickLinkMenuAction>> _buildQuickLinkMenuItems(QuickLink link) {
  return [
    PopupMenuItem(
      value: _QuickLinkMenuAction.upload,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.upload_file),
        title: const Text('Upload file'),
      ),
    ),
    PopupMenuItem(
      value: _QuickLinkMenuAction.edit,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.edit),
        title: const Text('Edit details'),
      ),
    ),
    PopupMenuItem(
      enabled: link.hasStorageReference,
      value: _QuickLinkMenuAction.removeFile,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.delete_outline),
        title: const Text('Remove stored file'),
      ),
    ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: _QuickLinkMenuAction.delete,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.delete_forever),
        title: const Text('Delete quick link'),
      ),
    ),
  ];
}

enum _QuickLinkMenuAction { upload, edit, removeFile, delete }

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
    _delete = widget.startInDeleteMode;
    _removeFile = widget.startInDeleteMode;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
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
    this.file,
    this.removeFile = false,
    this.delete = false,
  });

  final String title;
  final String category;
  final String? description;
  final String? externalUrl;
  final PlatformFile? file;
  final bool removeFile;
  final bool delete;
}
