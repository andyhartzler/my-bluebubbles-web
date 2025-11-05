import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_document.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'editors/chapter_edit_sheet.dart';
import 'member_detail_screen.dart';

class ChapterDetailScreen extends StatefulWidget {
  final Chapter chapter;

  const ChapterDetailScreen({super.key, required this.chapter});

  @override
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen> {
  final ChapterRepository _chapterRepository = ChapterRepository();
  final MemberRepository _memberRepository = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  bool _loading = true;
  List<Member> _members = [];
  List<ChapterDocument> _documents = [];
  late Chapter _chapter;

  bool get _crmReady => _supabaseService.isInitialized && CRMConfig.crmEnabled;

  @override
  void initState() {
    super.initState();
    _chapter = widget.chapter;
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    if (!_crmReady) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _memberRepository.getAllMembers(chapterName: _chapter.chapterName),
        _chapterRepository.getDocumentsForChapter(_chapter.chapterName),
      ]);

      if (!mounted) return;

      final members = (results[0] as List<Member>)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final documents = results[1] as List<ChapterDocument>;

      setState(() {
        _members = members;
        _documents = documents;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chapter: $e')),
      );
    }
  }

  Future<void> _editChapter() async {
    if (!_crmReady) return;

    final updated = await showModalBottomSheet<Chapter?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ChapterEditSheet(chapter: _chapter),
      ),
    );

    if (!mounted || updated == null) return;
    setState(() => _chapter = updated);
    await _loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_chapter.chapterName} Chapter';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_crmReady)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Chapter',
              onPressed: _editChapter,
            ),
        ],
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. Unable to load chapter details.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadChapter,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildChapterHeader(context),
                      const SizedBox(height: 24),
                      ..._buildDocumentsSection(),
                      ..._buildLeadershipSection(),
                      ..._buildMembersSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildChapterHeader(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    chips.add(_buildPill(Icons.category, _chapter.chapterType.toUpperCase()));

    if (_chapter.status != null && _chapter.status!.trim().isNotEmpty) {
      chips.add(_buildPill(Icons.flag, _chapter.status!.trim()));
    }

    chips.add(_buildPill(
      _chapter.isChartered ? Icons.verified : Icons.pending,
      _chapter.isChartered ? 'Chartered' : 'Not Chartered',
    ));

    if (_chapter.charterDate != null) {
      chips.add(_buildPill(
        Icons.calendar_month,
        'Chartered ${_formatDate(_chapter.charterDate!)}',
      ));
    }

    final detailRows = <Widget>[];
    if (_chapter.schoolName.isNotEmpty) {
      detailRows.add(_buildHeaderRow('School', _chapter.schoolName));
    }
    if (_chapter.contactEmail != null && _chapter.contactEmail!.isNotEmpty) {
      detailRows.add(_buildHeaderRow(
        'Contact',
        _chapter.contactEmail!,
        trailing: IconButton(
          tooltip: 'Email chapter',
          icon: const Icon(Icons.email_outlined),
          onPressed: () => _launchUrl(Uri(scheme: 'mailto', path: _chapter.contactEmail!)),
        ),
      ));
    }
    if (_chapter.website != null && _chapter.website!.isNotEmpty) {
      final uri = _parseUrl(_chapter.website!);
      if (uri != null) {
        detailRows.add(_buildHeaderRow(
          'Website',
          uri.toString(),
          trailing: IconButton(
            tooltip: 'Open website',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _launchUrl(uri),
          ),
        ));
      }
    }

    // Build social media section
    final socialPlatforms = <String, String?>{
      'Twitter/X': _chapter.twitter ?? _chapter.socialMedia?['twitter'],
      'Bluesky': _chapter.bluesky ?? _chapter.socialMedia?['bluesky'],
      'Facebook': _chapter.facebook ?? _chapter.socialMedia?['facebook'],
      'Instagram': _chapter.instagram ?? _chapter.socialMedia?['instagram'],
      'Threads': _chapter.threads ?? _chapter.socialMedia?['threads'],
      'TikTok': _chapter.tiktok ?? _chapter.socialMedia?['tiktok'],
    };

    final hasSocialMedia = socialPlatforms.values.any((v) => v != null && v.trim().isNotEmpty);

    if (hasSocialMedia) {
      // Add social media heading with edit button
      detailRows.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              const Text(
                'Social Media',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(width: 8),
              if (_crmReady)
                TextButton.icon(
                  onPressed: _editChapter,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
            ],
          ),
        ),
      );

      // Add each social platform as a clickable row
      for (final entry in socialPlatforms.entries) {
        final value = entry.value;
        if (value != null && value.trim().isNotEmpty) {
          detailRows.add(
            InkWell(
              onTap: () {
                final link = _parseUrl(value);
                if (link != null) {
                  _launchUrl(link);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            ),
          );
        }
      }
    } else if (_crmReady) {
      // No social media, show add button
      detailRows.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            onPressed: _editChapter,
            icon: const Icon(Icons.add_link),
            label: const Text('Add Social Media'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapter.displayTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_chapter.displaySubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_chapter.displaySubtitle, style: theme.textTheme.titleMedium),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (detailRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...detailRows,
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLeadershipSection() {
    final leaders = _members
        .where((member) => member.chapterPosition != null && member.chapterPosition!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.chapterPosition!.toLowerCase().compareTo(b.chapterPosition!.toLowerCase()));

    if (leaders.isEmpty) {
      return [];
    }

    return [
      _buildSection(
        icon: Icons.emoji_events_outlined,
        title: 'Chapter Leadership',
        child: Column(
          children: leaders.map((leader) => _buildMemberTile(leader, emphasizeRole: true)).toList(),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildMembersSection() {
    if (_members.isEmpty) {
      return [
        _buildSection(
          icon: Icons.people_outline,
          title: 'Members',
          child: const Text('No members found for this chapter yet.'),
        ),
        const SizedBox(height: 24),
      ];
    }

    final members = _members.toList();
    members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return [
      _buildSection(
        icon: Icons.people,
        title: 'Members (${members.length})',
        child: Column(
          children: members.map((member) => _buildMemberTile(member)).toList(),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildDocumentsSection() {
    if (_documents.isEmpty) {
      return [
        _buildSection(
          icon: Icons.description_outlined,
          title: 'Governing Documents',
          child: const Text('No governing documents have been uploaded for this chapter yet.'),
        ),
      ];
    }

    return [
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Governing Documents',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _documents.map(_buildDocumentCard).toList(),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildDocumentCard(ChapterDocument doc) {
    final theme = Theme.of(context);
    final submitted = doc.uploadedAt ?? doc.createdAt;
    final submittedLabel = submitted != null ? _formatDate(submitted) : 'Date unavailable';
    final description = _describeDocument(doc);

    return InkWell(
      onTap: () {
        final uri = _parseUrl(doc.publicUrl);
        if (uri != null) {
          _launchUrl(uri);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              doc.displayName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Submitted $submittedLabel',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Member member, {bool emphasizeRole = false}) {
    final subtitleParts = <String>[];
    if (emphasizeRole && member.chapterPosition != null) {
      subtitleParts.add(member.chapterPosition!.trim());
    }
    if (member.primaryPhone != null && member.primaryPhone!.trim().isNotEmpty) {
      subtitleParts.add(member.primaryPhone!.trim());
    }
    if (member.preferredEmail != null && member.preferredEmail!.trim().isNotEmpty) {
      subtitleParts.add(member.preferredEmail!.trim());
    }

    final subtitle = subtitleParts.join(' • ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?')),
      title: Text(member.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.open_in_new),
        tooltip: 'View profile',
        onPressed: () => _openMember(member),
      ),
      onTap: () => _openMember(member),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child}) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      backgroundColor: Colors.blueGrey.withOpacity(0.12),
    );
  }

  Widget _buildHeaderRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  void _openMember(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
    );
  }

  String _describeDocument(ChapterDocument doc) {
    final pieces = <String>[];
    pieces.add(doc.documentType);
    if (doc.fileSize != null) {
      pieces.add(_formatFileSize(doc.fileSize!));
    }
    if (doc.uploadedAt != null) {
      pieces.add('Uploaded ${_formatDate(doc.uploadedAt!)}');
    }
    return pieces.join(' • ');
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  Uri? _parseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.tryParse(trimmed);
    }

    return Uri.tryParse('https://$trimmed');
  }

  Future<void> _launchUrl(Uri uri) async {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.toString()}')),
      );
    }
  }
}
