import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_document.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

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

  bool get _crmReady => _supabaseService.isInitialized && CRMConfig.crmEnabled;

  @override
  void initState() {
    super.initState();
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
        _memberRepository.getAllMembers(chapterName: widget.chapter.chapterName),
        _chapterRepository.getDocumentsForChapter(widget.chapter.chapterName),
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

  @override
  Widget build(BuildContext context) {
    final title = '${widget.chapter.chapterName} Chapter';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                      ..._buildLeadershipSection(),
                      ..._buildMembersSection(),
                      ..._buildDocumentsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildChapterHeader(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    chips.add(_buildPill(Icons.category, widget.chapter.chapterType.toUpperCase()));

    if (widget.chapter.status != null && widget.chapter.status!.trim().isNotEmpty) {
      chips.add(_buildPill(Icons.flag, widget.chapter.status!.trim()));
    }

    chips.add(_buildPill(
      widget.chapter.isChartered ? Icons.verified : Icons.pending,
      widget.chapter.isChartered ? 'Chartered' : 'Not Chartered',
    ));

    if (widget.chapter.charterDate != null) {
      chips.add(_buildPill(
        Icons.calendar_month,
        'Chartered ${_formatDate(widget.chapter.charterDate!)}',
      ));
    }

    final detailRows = <Widget>[];
    if (widget.chapter.schoolName.isNotEmpty) {
      detailRows.add(_buildHeaderRow('School', widget.chapter.schoolName));
    }
    if (widget.chapter.contactEmail != null && widget.chapter.contactEmail!.isNotEmpty) {
      detailRows.add(_buildHeaderRow(
        'Contact',
        widget.chapter.contactEmail!,
        trailing: IconButton(
          tooltip: 'Email chapter',
          icon: const Icon(Icons.email_outlined),
          onPressed: () => _launchUrl(Uri(scheme: 'mailto', path: widget.chapter.contactEmail!)),
        ),
      ));
    }
    if (widget.chapter.website != null && widget.chapter.website!.isNotEmpty) {
      final uri = _parseUrl(widget.chapter.website!);
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

    final socialMedia = widget.chapter.socialMedia;
    if (socialMedia != null && socialMedia.isNotEmpty) {
      final entries = socialMedia.entries
          .where((entry) => entry.value is String && (entry.value as String).trim().isNotEmpty)
          .map((entry) => MapEntry(entry.key, entry.value as String))
          .toList();
      if (entries.isNotEmpty) {
        detailRows.add(
          _buildHeaderRow(
            'Social',
            entries.map((entry) => entry.key).join(', '),
            trailing: Wrap(
              spacing: 8,
              children: entries
                  .map(
                    (entry) => ActionChip(
                      label: Text(entry.key.toUpperCase()),
                      onPressed: () {
                        final link = _parseUrl(entry.value);
                        if (link != null) {
                          _launchUrl(link);
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      }
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
              widget.chapter.displayTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.chapter.displaySubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.chapter.displaySubtitle, style: theme.textTheme.titleMedium),
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
      _buildSection(
        icon: Icons.description,
        title: 'Governing Documents',
        child: Column(
          children: _documents
              .map(
                (doc) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(doc.displayName),
                  subtitle: Text(_describeDocument(doc)),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Open document',
                    onPressed: () {
                      final uri = _parseUrl(doc.publicUrl);
                      if (uri != null) {
                        _launchUrl(uri);
                      }
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ];
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(value)),
                if (trailing != null) trailing,
              ],
            ),
          ),
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
