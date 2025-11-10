import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart' as file_picker;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/chapter_document.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/database/global/platform_file.dart';

import 'editors/chapter_edit_sheet.dart';
import 'bulk_message_screen.dart';
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
  final CRMMessageService _messageService = CRMMessageService.instance;

  bool _loading = true;
  List<Member> _members = [];
  List<ChapterDocument> _documents = [];
  late Chapter _chapter;
  bool _openingBulkMessage = false;
  bool _sendingIntro = false;
  bool _uploadingDocument = false;

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
        _memberRepository.getAllMembers(
          chapterName: _chapter.chapterName,
          columns: MemberRepository.listingColumns,
        ),
        _chapterRepository.getDocumentsForChapter(_chapter.chapterName),
      ]);

      if (!mounted) return;

      final membersResult = results[0] as MemberFetchResult;
      final members = membersResult.members
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
          if (_crmReady) ...[
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: 'Send Message to Chapter',
              onPressed: _openingBulkMessage ? null : _handleSendMessageToChapter,
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Send Intro to Chapter',
              onPressed: _sendingIntro ? null : _handleSendIntroToChapter,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Chapter',
              onPressed: _editChapter,
            ),
          ],
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
                      if (_crmReady) ...[
                        const SizedBox(height: 16),
                        _buildChapterActions(context),
                      ],
                      const SizedBox(height: 24),
                      ..._buildDocumentsSection(),
                      ..._buildLeadershipSection(),
                      ..._buildMembersSection(),
                    ],
                  ),
                ),
    );
  }

  Future<void> _handleSendMessageToChapter() async {
    if (!_crmReady || _openingBulkMessage) return;

    final filter = MessageFilter(chapterName: _chapter.chapterName);

    setState(() => _openingBulkMessage = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulkMessageScreen(initialFilter: filter),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingBulkMessage = false);
      } else {
        _openingBulkMessage = false;
      }
    }
  }

  Future<void> _handleSendIntroToChapter() async {
    if (!_crmReady || _sendingIntro) return;

    final eligibleMembers =
        _members.where((member) => member.canContact && member.introSentAt == null).length;

    if (eligibleMembers == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible members to receive the intro message.')),
      );
      return;
    }

    final alreadyIntroduced =
        _members.where((member) => member.canContact && member.introSentAt != null).length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final introNote = alreadyIntroduced > 0
            ? '\n\n$alreadyIntroduced member${alreadyIntroduced == 1 ? '' : 's'} have already '
                'received the intro and will be skipped.'
            : '';
        return AlertDialog(
          title: const Text('Send Intro to Chapter'),
          content: Text(
            'Send the standard introduction message to $eligibleMembers '
            'member${eligibleMembers == 1 ? '' : 's'} in the ${_chapter.chapterName} chapter?$introNote',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send Intro'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _sendingIntro = true);

    final filter = MessageFilter(chapterName: _chapter.chapterName);
    int current = 0;
    int total = eligibleMembers;
    StateSetter? updateDialog;
    bool progressDialogVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            updateDialog = setState;
            final hasTotal = total > 0;
            final progressValue = hasTotal ? current / total : null;
            final progressLabel = hasTotal
                ? 'Sending $current of $total intro messages...'
                : 'Preparing intro messages...';
            return AlertDialog(
              title: const Text('Sending Intro Messages'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progressValue),
                  const SizedBox(height: 12),
                  Text(progressLabel),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => progressDialogVisible = false);

    try {
      final results = await _messageService.sendIntroToFilteredMembers(
        filter,
        onProgress: (currentProgress, totalProgress) {
          current = currentProgress;
          total = totalProgress;
          updateDialog?.call(() {});
        },
      );

      if (progressDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogVisible = false;
      }

      if (!mounted) return;

      final attempted = results.length;
      final successCount = results.values.where((value) => value).length;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Intro Messages Sent'),
          content: Text(
            attempted == 0
                ? 'No intro messages were sent. No eligible members matched the filter.'
                : 'Successfully sent intro messages to $successCount of $attempted members.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      await _loadChapter();
    } catch (e) {
      if (progressDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogVisible = false;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending intro messages: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingIntro = false);
      } else {
        _sendingIntro = false;
      }
    }
  }

  Future<void> _handleUploadChapterDocument() async {
    if (!_crmReady || _uploadingDocument) return;

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = result.files.first;
    final platformFile = PlatformFile(
      path: picked.path,
      name: picked.name,
      size: picked.size,
      bytes: picked.bytes,
    );

    setState(() => _uploadingDocument = true);

    try {
      final uploaded = await _chapterRepository.uploadChapterDocument(
        chapterName: _chapter.chapterName,
        file: platformFile,
      );

      if (!mounted) return;

      if (uploaded != null) {
        setState(() {
          final updated = List<ChapterDocument>.from(_documents)
            ..removeWhere((doc) => doc.id == uploaded.id)
            ..add(uploaded)
            ..sort((a, b) => a.documentType.toLowerCase().compareTo(b.documentType.toLowerCase()));
          _documents = updated;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ${uploaded.displayName}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload document.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading document: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingDocument = false);
      } else {
        _uploadingDocument = false;
      }
    }
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
      detailRows.add(_buildClickableHeaderRow(
        'Contact',
        _chapter.contactEmail!,
        onTap: () => _launchUrl(Uri(scheme: 'mailto', path: _chapter.contactEmail!)),
        icon: Icons.email_outlined,
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
            icon: const Icon(Icons.open_in_new, color: Colors.white),
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (_crmReady)
                TextButton.icon(
                  onPressed: _editChapter,
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
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
          final info = _deriveSocialLinkInfo(entry.key, value);
          final link = info.uri ?? _parseUrl(value);
          detailRows.add(
            InkWell(
              onTap: link != null ? () => _launchUrl(link) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        info.label,
                        style: TextStyle(
                          color: Colors.white,
                          decoration: link != null ? TextDecoration.underline : null,
                        ),
                      ),
                    ),
                    if (link != null)
                      const Icon(Icons.open_in_new, size: 16, color: Colors.white),
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
            icon: const Icon(Icons.add_link, color: Colors.white),
            label: const Text('Add Social Media'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      color: const Color(0xFF273351), // _unityBlue for consistency
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapter.displayTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (_chapter.displaySubtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _chapter.displaySubtitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
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

  Widget _buildChapterActions(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chapter Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send Message to Chapter'),
                  onPressed: _openingBulkMessage ? null : _handleSendMessageToChapter,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Send Intro to Chapter'),
                  onPressed: _sendingIntro ? null : _handleSendIntroToChapter,
                ),
              ],
            ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No governing documents have been uploaded for this chapter yet.'),
              const SizedBox(height: 12),
              _buildDocumentUploadButton(),
            ],
          ),
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
                  const Spacer(),
                  _buildDocumentUploadButton(compact: true),
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
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      backgroundColor: Colors.white.withOpacity(0.2),
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
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

  Widget _buildClickableHeaderRow(
    String label,
    String value, {
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _openMember(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
    );
  }

  _SocialLinkInfo _deriveSocialLinkInfo(String platform, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _SocialLinkInfo(label: '', uri: null);
    }

    final lowerPlatform = platform.toLowerCase();
    Uri? uri = _tryParseSocialUrl(trimmed);
    final isLikelyUrl = uri != null;
    String? username;

    if (uri != null) {
      username = _extractUsernameFromUrl(uri, lowerPlatform);
      if (lowerPlatform == 'bluesky' && uri.host.toLowerCase().endsWith('.bsky.social')) {
        username ??= _normalizeHandle(uri.host);
      }
    }

    if (username == null && !isLikelyUrl) {
      username = _normalizeHandle(trimmed);
    }

    if (username == null || username.isEmpty) {
      return _SocialLinkInfo(label: trimmed, uri: uri);
    }

    if (uri == null || (lowerPlatform == 'bluesky' && uri.host.toLowerCase().endsWith('.bsky.social'))) {
      uri = _buildSocialUri(lowerPlatform, username);
    }

    final label = '@$username';
    return _SocialLinkInfo(label: label, uri: uri);
  }

  Uri? _tryParseSocialUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.tryParse(trimmed);
    }
    if (trimmed.contains('://')) {
      return Uri.tryParse(trimmed);
    }
    if (trimmed.contains('/') || trimmed.contains('.')) {
      return Uri.tryParse('https://$trimmed');
    }
    return null;
  }

  String? _extractUsernameFromUrl(Uri uri, String platform) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final segments = uri.pathSegments
        .map(Uri.decodeComponent)
        .where((segment) => segment.isNotEmpty)
        .toList();

    switch (platform) {
      case 'twitter/x':
        if ((host.contains('twitter.') || host == 'x.com') && segments.isNotEmpty) {
          return _normalizeHandle(segments.first);
        }
        break;
      case 'bluesky':
        if (host == 'bsky.app' && segments.length >= 2 && segments.first == 'profile') {
          return _normalizeHandle(segments[1]);
        }
        if (host.endsWith('.bsky.social')) {
          return _normalizeHandle(host);
        }
        break;
      case 'facebook':
        if (host.contains('facebook.') && segments.isNotEmpty) {
          for (final segment in segments.reversed) {
            if (segment != 'people' && segment != 'pages' && segment != 'groups') {
              return _normalizeHandle(segment);
            }
          }
          return _normalizeHandle(segments.last);
        }
        break;
      case 'instagram':
        if (host.contains('instagram.') && segments.isNotEmpty) {
          return _normalizeHandle(segments.first);
        }
        break;
      case 'threads':
        if (host.contains('threads.') && segments.isNotEmpty) {
          for (final segment in segments) {
            if (segment.startsWith('@')) {
              return _normalizeHandle(segment);
            }
          }
          return _normalizeHandle(segments.last);
        }
        break;
      case 'tiktok':
        if (host.contains('tiktok.') && segments.isNotEmpty) {
          for (final segment in segments) {
            if (segment.startsWith('@')) {
              return _normalizeHandle(segment);
            }
          }
          return _normalizeHandle(segments.last);
        }
        break;
    }

    return null;
  }

  String _normalizeHandle(String input) {
    var handle = input.trim();
    if (handle.startsWith('http://')) {
      handle = handle.substring(7);
    } else if (handle.startsWith('https://')) {
      handle = handle.substring(8);
    }
    handle = handle.replaceFirst(RegExp(r'^www\.'), '');
    if (handle.contains('/')) {
      handle = handle.split('/').last;
    }
    handle = handle.split('?').first;
    handle = handle.split('#').first;
    handle = handle.replaceAll(RegExp(r'\s+'), '');
    if (handle.startsWith('@')) {
      handle = handle.substring(1);
    }
    if (handle.endsWith('/')) {
      handle = handle.substring(0, handle.length - 1);
    }
    return handle;
  }

  Uri? _buildSocialUri(String platform, String username) {
    if (username.isEmpty) return null;
    switch (platform) {
      case 'twitter/x':
        return Uri.https('twitter.com', '/$username');
      case 'bluesky':
        return Uri.https('bsky.app', '/profile/$username');
      case 'facebook':
        return Uri.https('www.facebook.com', '/$username');
      case 'instagram':
        return Uri.https('www.instagram.com', '/$username');
      case 'threads':
        return Uri.https('www.threads.net', '/@$username');
      case 'tiktok':
        return Uri.https('www.tiktok.com', '/@$username');
    }
    return null;
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

  Widget _buildDocumentUploadButton({bool compact = false}) {
    final label = _uploadingDocument ? 'Uploading…' : 'Add Document';
    final iconWidget = _uploadingDocument
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.upload_file_outlined);
    final onPressed = _uploadingDocument ? null : _handleUploadChapterDocument;

    if (compact) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: Text(label),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: iconWidget,
      label: Text(label),
    );
  }

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

class _SocialLinkInfo {
  final String label;
  final Uri? uri;

  const _SocialLinkInfo({required this.label, this.uri});
}
