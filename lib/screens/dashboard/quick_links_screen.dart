import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/quick_link.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';

// Brand colors matching dashboard
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

class QuickLinksScreen extends StatefulWidget {
  const QuickLinksScreen({super.key});

  @override
  State<QuickLinksScreen> createState() => _QuickLinksScreenState();
}

class _QuickLinksScreenState extends State<QuickLinksScreen> {
  final QuickLinksRepository _repository = QuickLinksRepository();

  bool _loading = true;
  bool _processing = false;
  String? _error;
  List<QuickLink> _links = const [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final links = await _repository.fetchQuickLinks();
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
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

  Future<void> _openLink(QuickLink link) async {
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
        _showMessage('Unable to open link: $trimmed');
        return;
      }
      await launchUrl(resolved, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<PlatformFile?> _pickFile() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        withData: true,
      );
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

  Future<PlatformFile?> _pickIcon() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final selected = result.files.single;
      return await materializePickedPlatformFile(selected, source: result);
    } catch (error) {
      _showMessage('Failed to pick icon: $error');
      return null;
    }
  }

  Future<void> _createLink() async {
    final result = await showDialog<_QuickLinkFormResult>(
      context: context,
      builder: (_) => const _QuickLinkFormDialog(),
    );

    if (!mounted || result == null) return;

    await _setProcessing(() async {
      final created = await _repository.createQuickLink(
        title: result.title,
        category: result.category,
        description: result.description,
        externalUrl: result.externalUrl,
        iconUrl: result.iconUrl,
        file: result.file,
        isActive: result.isActive,
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

  Future<void> _editLink(QuickLink link) async {
    final result = await showDialog<_QuickLinkFormResult>(
      context: context,
      builder: (_) => _QuickLinkFormDialog(existing: link),
    );

    if (!mounted || result == null) return;

    await _setProcessing(() async {
      if (result.delete) {
        await _repository.deleteQuickLink(link);
        if (!mounted) return;
        setState(() {
          _links = _links.where((item) => item.id != link.id).toList();
        });
        _showMessage('Removed "${link.title}"');
        return;
      }

      final updated = await _repository.updateQuickLink(
        link,
        title: result.title,
        category: result.category,
        description: result.description,
        externalUrl: result.externalUrl,
        iconUrl: result.iconUrl,
        file: result.file,
        removeExistingFile: result.removeFile && result.file == null,
        isActive: result.isActive,
      );
      if (!mounted) return;
      setState(() {
        _links = _links.map((item) => item.id == updated.id ? updated : item).toList();
      });
      _showMessage('Updated "${updated.title}"');
    });
  }

  List<QuickLink> get _filteredLinks {
    if (_searchQuery.isEmpty) return _links;
    final query = _searchQuery.toLowerCase();
    return _links.where((link) {
      return link.title.toLowerCase().contains(query) ||
          link.category.toLowerCase().contains(query) ||
          (link.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return TitleBarWrapper(
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Image.asset(
                'assets/images/Blue-Gradient-Background.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_unityBlue.withOpacity(0.1), _momentumBlue.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.white.withOpacity(0.15)),
            ),
            // Content
            Positioned.fill(
              child: Column(
                children: [
                  _buildHeader(isMobile),
                  if (_processing)
                    const LinearProgressIndicator(minHeight: 3),
                  Expanded(
                    child: _buildBody(isMobile),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _processing ? null : _createLink,
          backgroundColor: _momentumBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Resource'),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 32,
        isMobile ? 16 : 24,
        isMobile ? 16 : 32,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: _unityBlue),
                tooltip: 'Back to Dashboard',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Links',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 32,
                        fontWeight: FontWeight.bold,
                        color: _unityBlue,
                      ),
                    ),
                    Text(
                      'Access important links, documents, and resources',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: _unityBlue.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, color: _unityBlue),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: const Icon(Icons.search, color: _momentumBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isMobile) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _momentumBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: _actionRed.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Failed to load quick links',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _unityBlue.withOpacity(0.7)),
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

    final links = _filteredLinks;
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.link_off,
              size: 64,
              color: _momentumBlue.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No resources match your search'
                  : 'No quick links yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _unityBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Tap the + button to add your first resource',
              style: TextStyle(color: _unityBlue.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    // Group links by category
    final grouped = _groupLinksByCategory(links);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 32,
        8,
        isMobile ? 16 : 32,
        100, // Space for FAB
      ),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped[index];
        return _buildCategorySection(entry.key, entry.value, isMobile);
      },
    );
  }

  List<MapEntry<String, List<QuickLink>>> _groupLinksByCategory(List<QuickLink> links) {
    final Map<String, List<QuickLink>> grouped = {};

    // Define category order
    const categoryOrder = [
      'social_media',
      'websites',
      'governing_documents',
      'documents',
      'forms',
    ];

    for (final link in links) {
      final category = link.normalizedCategory;
      grouped.putIfAbsent(category, () => []).add(link);
    }

    // Sort within each category
    for (final list in grouped.values) {
      list.sort((a, b) {
        final orderCompare = (a.sortOrder ?? 1 << 20).compareTo(b.sortOrder ?? 1 << 20);
        if (orderCompare != 0) return orderCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    // Sort categories
    final entries = grouped.entries.toList();
    entries.sort((a, b) {
      final aIndex = categoryOrder.indexOf(a.key);
      final bIndex = categoryOrder.indexOf(b.key);
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      return a.key.compareTo(b.key);
    });

    return entries;
  }

  String _formatCategoryLabel(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildCategorySection(String category, List<QuickLink> links, bool isMobile) {
    final isSocialMedia = category == 'social_media' || category == 'social media';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: _getCategoryColor(category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatCategoryLabel(category),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _momentumBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${links.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _momentumBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Links grid/list
          if (isSocialMedia)
            _buildSocialMediaGrid(links, isMobile)
          else
            _buildLinksGrid(links, isMobile),
        ],
      ),
    );
  }

  Widget _buildSocialMediaGrid(List<QuickLink> links, bool isMobile) {
    final crossAxisCount = isMobile ? 4 : 8;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: links.length,
      itemBuilder: (context, index) => _buildSocialMediaCard(links[index]),
    );
  }

  Widget _buildSocialMediaCard(QuickLink link) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openLink(link),
        onLongPress: () => _editLink(link),
        child: Tooltip(
          message: link.title,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: link.iconUrl != null && link.iconUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      link.iconUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildIconPlaceholder(link),
                    ),
                  )
                : _buildIconPlaceholder(link),
          ),
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder(QuickLink link) {
    return Container(
      decoration: BoxDecoration(
        color: _momentumBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          link.title.isNotEmpty ? link.title[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _momentumBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildLinksGrid(List<QuickLink> links, bool isMobile) {
    final crossAxisCount = isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 4 : 3.5,
      ),
      itemCount: links.length,
      itemBuilder: (context, index) => _buildLinkCard(links[index]),
    );
  }

  Widget _buildLinkCard(QuickLink link) {
    final hasFile = link.hasStorageReference;
    final hasExternalUrl = link.hasExternalUrl;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openLink(link),
        onLongPress: () => _editLink(link),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor(link.normalizedCategory).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: link.iconUrl != null && link.iconUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          link.iconUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            _getLinkIcon(link),
                            color: _getCategoryColor(link.normalizedCategory),
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(
                        _getLinkIcon(link),
                        color: _getCategoryColor(link.normalizedCategory),
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              // Title and description
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _unityBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (link.description != null && link.description!.isNotEmpty)
                      Text(
                        link.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _unityBlue.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (hasFile) ...[
                          Icon(Icons.attach_file, size: 14, color: _grassrootsGreen),
                          const SizedBox(width: 4),
                          Text(
                            'File',
                            style: TextStyle(fontSize: 11, color: _grassrootsGreen),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hasExternalUrl) ...[
                          Icon(Icons.open_in_new, size: 14, color: _momentumBlue),
                          const SizedBox(width: 4),
                          Text(
                            'Link',
                            style: TextStyle(fontSize: 11, color: _momentumBlue),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    color: _unityBlue.withOpacity(0.5),
                    onPressed: () => _copyLink(link),
                    tooltip: 'Copy link',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: _unityBlue.withOpacity(0.5),
                    onPressed: () => _editLink(link),
                    tooltip: 'Edit',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'social_media':
      case 'social media':
        return _momentumBlue;
      case 'websites':
      case 'website':
        return _justicePurple;
      case 'governing_documents':
        return _sunriseGold;
      case 'documents':
      case 'document':
        return _grassrootsGreen;
      case 'forms':
      case 'form':
        return _actionRed;
      default:
        return _unityBlue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'social_media':
      case 'social media':
        return Icons.share;
      case 'websites':
      case 'website':
        return Icons.language;
      case 'governing_documents':
        return Icons.gavel;
      case 'documents':
      case 'document':
        return Icons.description;
      case 'forms':
      case 'form':
        return Icons.assignment;
      default:
        return Icons.link;
    }
  }

  IconData _getLinkIcon(QuickLink link) {
    if (link.hasStorageReference) {
      final contentType = link.contentType?.toLowerCase() ?? '';
      if (contentType.contains('pdf')) return Icons.picture_as_pdf;
      if (contentType.contains('image')) return Icons.image;
      if (contentType.contains('video')) return Icons.video_file;
      return Icons.insert_drive_file;
    }
    return Icons.open_in_new;
  }
}

// Form dialog for creating/editing quick links
class _QuickLinkFormResult {
  final String title;
  final String category;
  final String? description;
  final String? externalUrl;
  final String? iconUrl;
  final PlatformFile? file;
  final bool isActive;
  final bool delete;
  final bool removeFile;

  const _QuickLinkFormResult({
    required this.title,
    required this.category,
    this.description,
    this.externalUrl,
    this.iconUrl,
    this.file,
    this.isActive = true,
    this.delete = false,
    this.removeFile = false,
  });
}

class _QuickLinkFormDialog extends StatefulWidget {
  final QuickLink? existing;

  const _QuickLinkFormDialog({this.existing});

  @override
  State<_QuickLinkFormDialog> createState() => _QuickLinkFormDialogState();
}

class _QuickLinkFormDialogState extends State<_QuickLinkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _urlController;
  late TextEditingController _iconUrlController;

  PlatformFile? _selectedFile;
  bool _isActive = true;
  bool _removeFile = false;
  bool _uploading = false;

  static const _categoryOptions = [
    'social_media',
    'websites',
    'governing_documents',
    'documents',
    'forms',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _categoryController = TextEditingController(text: existing?.category ?? 'websites');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _urlController = TextEditingController(text: existing?.externalUrl ?? '');
    _iconUrlController = TextEditingController(text: existing?.iconUrl ?? '');
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final file = await materializePickedPlatformFile(selected, source: result);
      if (mounted && file != null) {
        setState(() {
          _selectedFile = file;
          _removeFile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _pickIcon() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      // For icons, we'll upload to moyd-assets bucket
      // For now, we'll just get the file and user can paste icon URL
      // TODO: Implement icon upload to moyd-assets bucket
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Icon picked. Please paste the icon URL after uploading to storage.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick icon: $e')),
        );
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(_QuickLinkFormResult(
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      externalUrl: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      iconUrl: _iconUrlController.text.trim().isEmpty
          ? null
          : _iconUrlController.text.trim(),
      file: _selectedFile,
      isActive: _isActive,
      removeFile: _removeFile,
    ));
  }

  void _delete() {
    Navigator.of(context).pop(const _QuickLinkFormResult(
      title: '',
      category: '',
      delete: true,
    ));
  }

  String _formatCategoryLabel(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final hasExistingFile = widget.existing?.hasStorageReference ?? false;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.add_link,
                      color: _momentumBlue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Resource' : 'Add Resource',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _unityBlue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form fields
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: 'Enter resource title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category dropdown
                        DropdownButtonFormField<String>(
                          value: _categoryOptions.contains(_categoryController.text)
                              ? _categoryController.text
                              : _categoryOptions.first,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          items: _categoryOptions.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(_formatCategoryLabel(category)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _categoryController.text = value;
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Optional description or notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // URL
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'External URL',
                            hintText: 'https://example.com',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),

                        // Icon URL
                        TextFormField(
                          controller: _iconUrlController,
                          decoration: InputDecoration(
                            labelText: 'Icon URL',
                            hintText: 'URL to icon image',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.image),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.upload),
                              onPressed: _pickIcon,
                              tooltip: 'Pick icon image',
                            ),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),

                        // File upload section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.attach_file, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Document Upload',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_selectedFile != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _grassrootsGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: _grassrootsGreen, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedFile!.name ?? 'Selected file',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => setState(() => _selectedFile = null),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (hasExistingFile && !_removeFile) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _momentumBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.insert_drive_file, color: _momentumBlue, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.existing!.fileName ?? 'Existing file',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: _actionRed),
                                        onPressed: () => setState(() => _removeFile = true),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        tooltip: 'Remove file',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _pickDocument,
                                icon: const Icon(Icons.upload_file),
                                label: Text(_selectedFile != null || (hasExistingFile && !_removeFile)
                                    ? 'Replace File'
                                    : 'Upload File'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Documents will be stored in Supabase storage',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Active toggle
                        SwitchListTile(
                          title: const Text('Active'),
                          subtitle: const Text('Show this resource in the list'),
                          value: _isActive,
                          onChanged: (value) => setState(() => _isActive = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    if (isEditing)
                      TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete, color: _actionRed),
                        label: const Text('Delete', style: TextStyle(color: _actionRed)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: Icon(isEditing ? Icons.save : Icons.add),
                      label: Text(isEditing ? 'Save' : 'Create'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _momentumBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
