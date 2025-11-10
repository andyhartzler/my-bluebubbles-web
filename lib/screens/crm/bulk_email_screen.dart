import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

enum _RecipientMode {
  manual,
  county,
  district,
  highSchool,
  college,
  committee,
  chapter,
  chapterStatus,
}

class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({
    Key? key,
    this.initialFilter,
    this.initialManualMembers,
    this.initialManualEmails,
  }) : super(key: key);

  final MessageFilter? initialFilter;
  final List<Member>? initialManualMembers;
  final List<String>? initialManualEmails;

  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMEmailService _emailService = CRMEmailService.instance;
  final CRMSupabaseService _supabaseService = CRMSupabaseService();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualEmailController = TextEditingController();

  final List<Member> _selectedMembers = [];
  final List<Member> _searchResults = [];
  final List<PlatformFile> _attachments = [];
  final List<String> _manualEmails = [];

  MessageFilter _filter = MessageFilter();
  _RecipientMode _mode = _RecipientMode.manual;
  bool _crmReady = false;
  bool _loadingPreview = false;
  bool _sending = false;
  bool _searching = false;
  String? _errorMessage;

  List<Member> _previewMembers = [];
  List<String> _previewManualEmails = [];
  int _totalRecipients = 0;
  int _missingEmailCount = 0;

  Timer? _searchDebounce;

  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];
  List<String> _highSchools = [];
  List<String> _colleges = [];
  List<String> _chapters = [];
  List<String> _chapterStatuses = [];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? MessageFilter();
    _crmReady = _supabaseService.isInitialized && CRMConfig.crmEnabled;
    if (_filter.chapterName != null && _filter.chapterName!.isNotEmpty) {
      _mode = _RecipientMode.chapter;
    }
    if (widget.initialManualMembers != null && widget.initialManualMembers!.isNotEmpty) {
      _selectedMembers.addAll(widget.initialManualMembers!);
    }
    if (widget.initialManualEmails != null && widget.initialManualEmails!.isNotEmpty) {
      for (final email in widget.initialManualEmails!) {
        final trimmed = email.trim();
        if (trimmed.isNotEmpty) {
          _manualEmails.add(trimmed);
        }
      }
    }
    _searchController.addListener(_onSearchChanged);
    if (_crmReady) {
      _loadFilterOptions();
      _updatePreview();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _htmlController.dispose();
    _textController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _manualEmailController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool get _hasRecipients => _totalRecipients > 0;

  bool get _canSendEmail =>
      _crmReady &&
      !_sending &&
      _hasRecipients &&
      _subjectController.text.trim().isNotEmpty &&
      _htmlController.text.trim().isNotEmpty;

  Future<void> _loadFilterOptions() async {
    final results = await Future.wait([
      _memberRepo.getUniqueCounties(),
      _memberRepo.getUniqueCongressionalDistricts(),
      _memberRepo.getUniqueCommittees(),
      _memberRepo.getUniqueHighSchools(),
      _memberRepo.getUniqueColleges(),
      _memberRepo.getUniqueChapterNames(),
      _memberRepo.getChapterStatusCounts(),
    ]);

    if (!mounted) return;

    setState(() {
      _counties = List<String>.from(results[0] as List);
      _districts = List<String>.from(results[1] as List);
      _committees = List<String>.from(results[2] as List);
      _highSchools = List<String>.from(results[3] as List);
      _colleges = List<String>.from(results[4] as List);
      _chapters = List<String>.from(results[5] as List);
      _chapterStatuses = (results[6] as Map<String, int>).keys.toList()..sort();
    });
  }

  Future<void> _updatePreview() async {
    if (!_crmReady) return;

    final hasFilters = _filter.hasActiveFilters;
    final hasManualRecipients = _selectedMembers.isNotEmpty || _manualEmails.isNotEmpty;

    if (!hasFilters && !hasManualRecipients) {
      setState(() {
        _previewMembers = [];
        _previewManualEmails = [];
        _totalRecipients = 0;
        _missingEmailCount = 0;
        _loadingPreview = false;
      });
      return;
    }

    setState(() {
      _loadingPreview = true;
      _errorMessage = null;
    });

    try {
      final LinkedHashMap<String, Member> combined = LinkedHashMap();
      int missingEmails = 0;

      void addMember(Member member) {
        final email = _normalizeEmail(member.preferredEmail);
        if (email == null) {
          missingEmails++;
          return;
        }
        if (_filter.excludeOptedOut && member.optOut) {
          return;
        }
        combined[member.id] = member;
      }

      if (hasFilters) {
        final response = await _memberRepo.getAllMembers(
          county: _filter.county,
          congressionalDistrict: _filter.congressionalDistrict,
          committees: _filter.committees,
          highSchool: _filter.highSchool,
          college: _filter.college,
          chapterName: _filter.chapterName,
          chapterStatus: _filter.chapterStatus,
          optedOut: _filter.excludeOptedOut ? false : null,
        );

        var members = response.members;
        if (_filter.excludeRecentlyContacted) {
          final threshold = DateTime.now().subtract(
            _filter.recentContactThreshold ?? const Duration(days: 7),
          );
          members = members
              .where((member) => member.lastContacted == null || member.lastContacted!.isBefore(threshold))
              .toList();
        }

        for (final member in members) {
          addMember(member);
        }
      }

      for (final member in _selectedMembers) {
        addMember(member);
      }

      final memberEmailSet = combined.values
          .map((member) => _normalizeEmail(member.preferredEmail)?.toLowerCase())
          .whereType<String>()
          .toSet();
      final manualEmails = <String>[];
      for (final email in _manualEmails) {
        final normalized = _normalizeEmail(email);
        if (normalized == null) continue;
        final lower = normalized.toLowerCase();
        if (memberEmailSet.contains(lower)) continue;
        if (manualEmails.any((existing) => existing.toLowerCase() == lower)) continue;
        manualEmails.add(normalized);
      }

      if (!mounted) return;

      setState(() {
        final membersList = combined.values.toList(growable: false);
        final topMembers = membersList.take(5).toList(growable: false);
        final remaining = 5 - topMembers.length;
        final manualPreviewCount = remaining > 0
            ? (remaining > manualEmails.length ? manualEmails.length : remaining)
            : 0;
        final manualPreview = manualPreviewCount > 0
            ? manualEmails.sublist(0, manualPreviewCount)
            : const <String>[];
        _previewMembers = topMembers;
        _previewManualEmails = manualPreview;
        _totalRecipients = combined.length + manualEmails.length;
        _missingEmailCount = missingEmails;
        _loadingPreview = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPreview = false;
        _errorMessage = 'Failed to build preview: $error';
      });
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final results = await _memberRepo.searchMembers(query);
        if (!mounted) return;
        setState(() {
          _searchResults
            ..clear()
            ..addAll(results.where((member) => _normalizeEmail(member.preferredEmail) != null));
          _searching = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _searchResults.clear();
          _searching = false;
        });
      }
    });
  }

  String? _normalizeEmail(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('@')) return null;
    return trimmed;
  }

  void _toggleMemberSelection(Member member) {
    final existingIndex = _selectedMembers.indexWhere((m) => m.id == member.id);
    if (existingIndex >= 0) {
      setState(() {
        _selectedMembers.removeAt(existingIndex);
      });
    } else {
      if (_normalizeEmail(member.preferredEmail) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} does not have an email address.')),
        );
        return;
      }
      setState(() {
        _selectedMembers.add(member);
      });
    }
    _updatePreview();
  }

  void _removeSelectedMember(Member member) {
    setState(() {
      _selectedMembers.removeWhere((m) => m.id == member.id);
    });
    _updatePreview();
  }

  Future<void> _pickAttachments() async {
    if (!_crmReady || _sending) return;

    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final additions = <PlatformFile>[];
    final failedFiles = <String>[];

    for (final file in result.files) {
      final platformFile = await materializePickedPlatformFile(file, source: result);
      if (platformFile == null) {
        failedFiles.add(file.name);
        continue;
      }
      additions.add(platformFile);
    }

    if (!mounted) return;

    setState(() {
      for (final file in additions) {
        final exists = _attachments.any((existing) => existing.name.toLowerCase() == file.name.toLowerCase());
        if (!exists) {
          _attachments.add(file);
        }
      }
    });

    if (failedFiles.isNotEmpty && mounted) {
      final message = failedFiles.length == 1
          ? 'Could not read "${failedFiles.first}". Please try again.'
          : 'Could not read ${failedFiles.length} files: ${failedFiles.join(', ')}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _removeAttachment(PlatformFile file) {
    if (_sending) return;
    setState(() {
      _attachments.remove(file);
    });
  }

  void _addManualEmail() {
    if (_sending) return;
    final email = _normalizeEmail(_manualEmailController.text);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address before adding.')),
      );
      return;
    }

    final normalized = email.toLowerCase();
    final existingManual = _manualEmails.any((value) => value.toLowerCase() == normalized);
    final existingMember = _selectedMembers.any((member) =>
        member.preferredEmail != null && member.preferredEmail!.trim().toLowerCase() == normalized);

    if (existingManual || existingMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That email is already in the recipient list.')),
      );
      return;
    }

    setState(() {
      _manualEmails.add(email);
      _manualEmailController.clear();
    });
    _updatePreview();
  }

  void _removeManualEmail(String email) {
    setState(() {
      _manualEmails.remove(email);
    });
    _updatePreview();
  }

  Future<void> _sendEmail() async {
    if (!_canSendEmail) return;

    final subject = _subjectController.text.trim();
    final htmlBody = _htmlController.text.trim();
    final textBody = _textController.text.trim();

    setState(() {
      _sending = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final recipients = await _resolveRecipients();
      if (recipients.emails.isEmpty) {
        throw CRMEmailException('No valid email addresses were found.');
      }

      final attachments = <CRMEmailAttachment>[];
      for (final file in _attachments) {
        final attachment = await _emailService.buildAttachmentFromPlatformFile(file);
        if (attachment != null) {
          attachments.add(attachment);
        }
      }

      await _emailService.sendEmail(
        to: recipients.emails,
        subject: subject,
        htmlBody: htmlBody,
        textBody: textBody.isEmpty ? null : textBody,
        attachments: attachments,
      );

      for (final member in recipients.members) {
        await _memberRepo.updateLastContacted(member.id);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sent to ${recipients.emails.length} recipient${recipients.emails.length == 1 ? '' : 's'}')),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {
        _sending = false;
      });

      final message = error is CRMEmailException ? error.message : 'Failed to send email: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<({List<Member> members, List<String> emails})> _resolveRecipients() async {
    final LinkedHashMap<String, Member> members = LinkedHashMap();
    final LinkedHashMap<String, String> emailMap = LinkedHashMap();

    void addEmail(String email) {
      final lower = email.toLowerCase();
      emailMap[lower] = email;
    }

    for (final manual in _manualEmails) {
      final normalized = _normalizeEmail(manual);
      if (normalized != null) {
        addEmail(normalized);
      }
    }

    void addMember(Member member) {
      final email = _normalizeEmail(member.preferredEmail);
      if (email == null) {
        return;
      }
      if (_filter.excludeOptedOut && member.optOut) {
        return;
      }
      members[member.id] = member;
      addEmail(email);
    }

    if (_filter.hasActiveFilters) {
      final response = await _memberRepo.getAllMembers(
        county: _filter.county,
        congressionalDistrict: _filter.congressionalDistrict,
        committees: _filter.committees,
        highSchool: _filter.highSchool,
        college: _filter.college,
        chapterName: _filter.chapterName,
        chapterStatus: _filter.chapterStatus,
        optedOut: _filter.excludeOptedOut ? false : null,
      );

      var membersList = response.members;
      if (_filter.excludeRecentlyContacted) {
        final threshold = DateTime.now().subtract(
          _filter.recentContactThreshold ?? const Duration(days: 7),
        );
        membersList = membersList
            .where((member) => member.lastContacted == null || member.lastContacted!.isBefore(threshold))
            .toList();
      }

      for (final member in membersList) {
        addMember(member);
      }
    }

    for (final member in _selectedMembers) {
      addMember(member);
    }

    final allEmails = emailMap.values.toList(growable: false);

    return (members: members.values.toList(growable: false), emails: allEmails);
  }

  void _setMode(_RecipientMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _updatePreview();
  }

  void _updateFilter(void Function() updater) {
    setState(updater);
    _updatePreview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Email'),
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. Email sending is disabled.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final content = [
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildComposeCard(),
                        const SizedBox(height: 16),
                        _buildPreviewCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16, height: 16),
                  Expanded(
                    flex: isWide ? 4 : 0,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildRecipientsCard(),
                      ],
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(children: content);
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildComposeCard(),
                          const SizedBox(height: 16),
                          _buildPreviewCard(),
                          const SizedBox(height: 16),
                          _buildRecipientsCard(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _crmReady
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(_sending ? 'Sending…' : 'Send Email'),
                      onPressed: _canSendEmail ? _sendEmail : null,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildComposeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compose Email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!_hasRecipients)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Select recipients to enable the compose form. Subject and HTML body are required.',
                ),
              ),
            if (!_hasRecipients) const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              enabled: _hasRecipients && !_sending,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _htmlController,
              enabled: _hasRecipients && !_sending,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'HTML Body',
                hintText: '<p>Hello {{firstName}},</p>',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              enabled: _hasRecipients && !_sending,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Plain-text fallback (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._attachments.map(
                  (file) => InputChip(
                    label: Text(file.name),
                    avatar: const Icon(Icons.attachment, size: 18),
                    onDeleted: _sending ? null : () => _removeAttachment(file),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _hasRecipients && !_sending ? _pickAttachments : null,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_attachments.isEmpty ? 'Add attachments' : 'Add more attachments'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_loadingPreview)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_totalRecipients > 0) ...[
              const SizedBox(height: 12),
              Text('Total recipients: $_totalRecipients'),
              if (_missingEmailCount > 0)
                Text('Skipped $_missingEmailCount member(s) missing email addresses'),
              const SizedBox(height: 12),
              ..._previewMembers.map(
                (member) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(member.name),
                  subtitle: Text(member.preferredEmail ?? ''),
                ),
              ),
              ..._previewManualEmails.map(
                (email) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alternate_email),
                  title: Text(email),
                  subtitle: const Text('Manual recipient'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text('Add filters or manual recipients to populate the preview.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsCard() {
    final modeChips = [
      _buildModeChip(_RecipientMode.manual, 'Manual', Icons.person_add_alt_1),
      _buildModeChip(_RecipientMode.county, 'County', Icons.map_outlined),
      _buildModeChip(_RecipientMode.district, 'District', Icons.apartment_outlined),
      _buildModeChip(_RecipientMode.highSchool, 'High School', Icons.school_outlined),
      _buildModeChip(_RecipientMode.college, 'College', Icons.school),
      _buildModeChip(_RecipientMode.committee, 'Committee', Icons.groups_outlined),
      _buildModeChip(_RecipientMode.chapter, 'Chapter', Icons.flag_outlined),
      _buildModeChip(_RecipientMode.chapterStatus, 'Chapter Status', Icons.badge_outlined),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipients',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: modeChips,
            ),
            const SizedBox(height: 16),
            _buildModeSelector(),
            const SizedBox(height: 20),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude opted-out members'),
              value: _filter.excludeOptedOut,
              onChanged: _sending
                  ? null
                  : (value) {
                      setState(() {
                        _filter = _filter.copyWithOverrides(
                          excludeOptedOut: value ?? true,
                        );
                      });
                      _updatePreview();
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclude recently contacted (7 days)'),
              value: _filter.excludeRecentlyContacted,
              onChanged: _sending
                  ? null
                  : (value) {
                      setState(() {
                        _filter = _filter.copyWithOverrides(
                          excludeRecentlyContacted: value ?? false,
                        );
                      });
                      _updatePreview();
                    },
            ),
            const SizedBox(height: 12),
            if (_selectedMembers.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedMembers
                    .map((member) => InputChip(
                          label: Text(member.name),
                          avatar: const Icon(Icons.person, size: 18),
                          onDeleted: () => _removeSelectedMember(member),
                        ))
                    .toList(),
              ),
            if (_manualEmails.isNotEmpty) ...[
              if (_selectedMembers.isNotEmpty) const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _manualEmails
                    .map((email) => InputChip(
                          label: Text(email),
                          avatar: const Icon(Icons.alternate_email, size: 18),
                          onDeleted: () => _removeManualEmail(email),
                        ))
                    .toList(),
              ),
            ],
            if (_mode == _RecipientMode.manual) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search members',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              if (_searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final member = _searchResults[index];
                      final selected = _selectedMembers.any((m) => m.id == member.id);
                      final email = _normalizeEmail(member.preferredEmail);
                      return ListTile(
                        title: Text(member.name),
                        subtitle: Text(email ?? 'No email on record'),
                        trailing: Icon(
                          selected ? Icons.check_circle : Icons.add_circle_outline,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).iconTheme.color,
                        ),
                        onTap: () => _toggleMemberSelection(member),
                      );
                    },
                  ),
                ),
              if (_searchResults.isEmpty && _searchController.text.trim().length >= 2 && !_searching)
                const Text('No members found matching your search.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualEmailController,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        labelText: 'Add manual email',
                        hintText: 'name@example.com',
                      ),
                      onSubmitted: (_) => _addManualEmail(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _sending ? null : _addManualEmail,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(_RecipientMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => _setMode(mode),
    );
  }

  Widget _buildModeSelector() {
    switch (_mode) {
      case _RecipientMode.manual:
        return const SizedBox.shrink();
      case _RecipientMode.county:
        return _buildDropdown(
          label: 'Select County',
          value: _filter.county,
          items: _counties,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(county: value);
          }),
        );
      case _RecipientMode.district:
        return _buildDropdown(
          label: 'Select Congressional District',
          value: _filter.congressionalDistrict,
          items: _districts,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(congressionalDistrict: value);
          }),
        );
      case _RecipientMode.highSchool:
        return _buildDropdown(
          label: 'Select High School',
          value: _filter.highSchool,
          items: _highSchools,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(highSchool: value);
          }),
        );
      case _RecipientMode.college:
        return _buildDropdown(
          label: 'Select College',
          value: _filter.college,
          items: _colleges,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(college: value);
          }),
        );
      case _RecipientMode.committee:
        return _buildDropdown(
          label: 'Select Committee',
          value: _filter.committees?.firstOrNull,
          items: _committees,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(committees: value == null ? null : [value]);
          }),
        );
      case _RecipientMode.chapter:
        return _buildDropdown(
          label: 'Select Chapter',
          value: _filter.chapterName,
          items: _chapters,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(chapterName: value);
          }),
        );
      case _RecipientMode.chapterStatus:
        return _buildDropdown(
          label: 'Select Chapter Status',
          value: _filter.chapterStatus,
          items: _chapterStatuses,
          onChanged: (value) => _updateFilter(() {
            _filter = _filter.copyWith(chapterStatus: value);
          }),
        );
    }
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value != null && items.contains(value) ? value : null,
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: _sending ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
