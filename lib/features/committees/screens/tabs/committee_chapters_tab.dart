import 'package:flutter/material.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/screens/crm/chapter_detail_screen.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';

/// Chapters tab for College Democrats and High School Democrats committees
class CommitteeChaptersTab extends StatefulWidget {
  final String? chapterTypeFilter;

  const CommitteeChaptersTab({super.key, this.chapterTypeFilter});

  @override
  State<CommitteeChaptersTab> createState() => _CommitteeChaptersTabState();
}

class _CommitteeChaptersTabState extends State<CommitteeChaptersTab> {
  final ChapterRepository _repository = ChapterRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Chapter> _chapters = [];
  List<Chapter> _filteredChapters = [];
  bool _loading = true;
  String? _error;

  String get _typeLabel => widget.chapterTypeFilter == 'college'
      ? 'College'
      : (widget.chapterTypeFilter == 'highschool' ? 'High School' : '');

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _searchController.addListener(_filterChapters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final chapters = await _repository.getAllChapters(
        chapterType: widget.chapterTypeFilter,
      );
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _filteredChapters = chapters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chapters: $e';
        _loading = false;
      });
    }
  }

  void _filterChapters() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredChapters = _chapters);
      return;
    }

    setState(() {
      _filteredChapters = _chapters.where((chapter) {
        return chapter.chapterName.toLowerCase().contains(query) ||
            chapter.schoolName.toLowerCase().contains(query) ||
            (chapter.contactEmail?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _openChapterDetail(Chapter chapter) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) => TitleBarWrapper(
          child: ChapterDetailScreen(chapter: chapter),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadChapters,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChapters,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search $_typeLabel chapters...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatChip(
                  '${_filteredChapters.length}',
                  'Total',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  '${_filteredChapters.where((c) => c.isChartered).length}',
                  'Chartered',
                  Colors.green,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadChapters,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Chapter list
          Expanded(
            child: _filteredChapters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No chapters match your search'
                              : 'No $_typeLabel chapters found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = _filteredChapters[index];
                      return _buildChapterCard(chapter);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(Chapter chapter) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openChapterDetail(chapter),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Chapter icon
              CircleAvatar(
                radius: 24,
                backgroundColor: chapter.isChartered
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                child: Icon(
                  chapter.isChartered ? Icons.verified : Icons.school,
                  color: chapter.isChartered ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),

              // Chapter info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.displayTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (chapter.schoolName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        chapter.schoolName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildChip(
                          chapter.isChartered ? 'Chartered' : 'Not Chartered',
                          chapter.isChartered ? Colors.green : Colors.orange,
                        ),
                        if (chapter.status != null && chapter.status!.isNotEmpty)
                          _buildChip(chapter.status!, Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: theme.disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
