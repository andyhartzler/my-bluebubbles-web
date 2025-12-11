import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/utils/quill_html_converter.dart';

class CommitteeEmailTab extends StatefulWidget {
  final Committee committee;

  const CommitteeEmailTab({super.key, required this.committee});

  @override
  State<CommitteeEmailTab> createState() => _CommitteeEmailTabState();
}

class _CommitteeEmailTabState extends State<CommitteeEmailTab>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  final CRMEmailService _emailService = CRMEmailService.instance;

  final TextEditingController _subjectController = TextEditingController();
  late quill.QuillController _bodyController;
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _bodyScrollController = ScrollController();
  final List<PlatformFile> _attachments = [];

  late TabController _tabController;
  List<Member> _members = [];
  bool _loading = true;
  bool _sending = false;
  int _currentProgress = 0;
  int _totalEmails = 0;
  late String _selectedFromEmail;

  Committee get committee => widget.committee;

  List<Member> get _membersWithEmail => _members.where(
    (m) => m.preferredEmail != null && m.preferredEmail!.isNotEmpty,
  ).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bodyController = quill.QuillController.basic();

    // Initialize from email
    final senders = CRMConfig.allowedSenderEmails;
    if (senders.contains(CRMConfig.defaultSenderEmail)) {
      _selectedFromEmail = CRMConfig.defaultSenderEmail;
    } else if (senders.isNotEmpty) {
      _selectedFromEmail = senders.first;
    } else {
      _selectedFromEmail = CRMConfig.defaultSenderEmail;
    }

    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final members = await _repository.getMembersForCommittee(committee.name);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      withReadStream: !kIsWeb,
    );

    if (result == null || result.files.isEmpty) return;

    final additions = <PlatformFile>[];
    final failedFiles = <String>[];

    for (final file in result.files) {
      final platformFile = await materializePickedPlatformFile(file, source: result);
      if (platformFile == null) {
        failedFiles.add(file.name);
        continue;
      }

      // Check if already exists
      final alreadyExists = _attachments.any((existing) {
        if (existing.identifier != null && file.identifier != null) {
          return existing.identifier == file.identifier;
        }
        if (existing.path != null && file.path != null) {
          return existing.path == file.path;
        }
        return existing.name == platformFile.name;
      });

      if (!alreadyExists) {
        additions.add(platformFile);
      }
    }

    if (!mounted) return;

    setState(() {
      _attachments.addAll(additions);
    });

    if (failedFiles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load: ${failedFiles.join(', ')}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeAttachment(PlatformFile file) {
    setState(() {
      _attachments.remove(file);
    });
  }

  Future<void> _sendEmails() async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject')),
      );
      return;
    }

    final bodyHtml = QuillHtmlConverter.convertToHtml(_bodyController.document);
    final bodyPlainText = _bodyController.document.toPlainText().trim();

    if (bodyPlainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email body')),
      );
      return;
    }

    final recipients = _membersWithEmail;
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members with email addresses')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Email'),
        content: Text(
          'Send this email to ${recipients.length} ${committee.displayName} members?\n\n'
          'Subject: $subject',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _currentProgress = 0;
      _totalEmails = recipients.length;
    });

    try {
      final filter = MessageFilter(committees: [committee.name]);
      final results = await _emailService.sendBulkEmail(
        filter: filter,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyPlainText: bodyPlainText,
        fromEmail: _selectedFromEmail,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalEmails = total;
          });
        },
        attachments: List<PlatformFile>.from(_attachments),
      );

      final successCount = results.values.where((v) => v).length;

      if (!mounted) return;
      setState(() => _sending = false);

      // Clear the form after sending
      _subjectController.clear();
      _bodyController.clear();
      _attachments.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emails Sent'),
          content: Text('Successfully sent $successCount of ${results.length} emails'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending emails: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Tab bar
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Compose'),
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildComposeTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposeTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recipients = _membersWithEmail;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Recipients info card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: committee.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recipients: ${recipients.length} members',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'From: $_selectedFromEmail',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (CRMConfig.allowedSenderEmails.length > 1)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down),
                          onSelected: (email) {
                            setState(() => _selectedFromEmail = email);
                          },
                          itemBuilder: (context) => CRMConfig.allowedSenderEmails
                              .map((email) => PopupMenuItem(
                                    value: email,
                                    child: Text(email),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subject field
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      hintText: 'Enter email subject...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                    ),
                    enabled: !_sending && recipients.isNotEmpty,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Email body editor
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message Body',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Toolbar
                      if (!_sending && recipients.isNotEmpty)
                        quill.QuillSimpleToolbar(
                          configurations: quill.QuillSimpleToolbarConfigurations(
                            controller: _bodyController,
                            showBoldButton: true,
                            showItalicButton: true,
                            showUnderLineButton: true,
                            showStrikeThrough: false,
                            showListBullets: true,
                            showListNumbers: true,
                            showLink: true,
                            showFontFamily: false,
                            showFontSize: false,
                            showCodeBlock: false,
                            showQuote: false,
                            showIndent: false,
                            showInlineCode: false,
                            showColorButton: false,
                            showBackgroundColorButton: false,
                            showClearFormat: true,
                            showAlignmentButtons: true,
                            showHeaderStyle: false,
                            showDividers: true,
                            showSearchButton: false,
                            showSubscript: false,
                            showSuperscript: false,
                            showDirection: false,
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Editor
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        height: 200,
                        child: quill.QuillEditor(
                          focusNode: _bodyFocusNode,
                          scrollController: _bodyScrollController,
                          configurations: quill.QuillEditorConfigurations(
                            controller: _bodyController,
                            padding: const EdgeInsets.all(12),
                            placeholder: 'Compose your email message...',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attachments
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attachments',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!_sending && recipients.isNotEmpty)
                            TextButton.icon(
                              onPressed: _pickAttachments,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                      if (_attachments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No attachments added',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments.map(
                            (file) => InputChip(
                              label: Text(file.name),
                              avatar: const Icon(Icons.attachment, size: 18),
                              onDeleted: _sending ? null : () => _removeAttachment(file),
                            ),
                          ).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Send button footer
        _buildSendFooter(recipients),
      ],
    );
  }

  Widget _buildSendFooter(List<Member> recipients) {
    if (_sending) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _totalEmails > 0 ? _currentProgress / _totalEmails : 0,
              backgroundColor: committee.primaryColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(committee.primaryColor),
            ),
            const SizedBox(height: 8),
            Text('Sending $_currentProgress of $_totalEmails emails...'),
          ],
        ),
      );
    }

    final hasContent = _subjectController.text.trim().isNotEmpty &&
        _bodyController.document.toPlainText().trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: !hasContent || recipients.isEmpty ? null : _sendEmails,
          icon: const Icon(Icons.send),
          label: Text('Send Email to ${recipients.length} Members'),
          style: ElevatedButton.styleFrom(
            backgroundColor: committee.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Committee email summary card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, color: committee.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Committee Email Summary',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_membersWithEmail.length} members with email addresses',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info text
          Text(
            'Email History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To view detailed email history for individual members, navigate to their profile from the Members tab.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Member list with email addresses
          Text(
            'Members with Email',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._membersWithEmail.take(10).map((member) => ListTile(
            leading: CircleAvatar(
              backgroundColor: committee.primaryColor.withOpacity(0.2),
              child: Text(
                member.name.isNotEmpty ? member.name[0] : '?',
                style: TextStyle(color: committee.primaryColor),
              ),
            ),
            title: Text(member.name),
            subtitle: Text(member.preferredEmail ?? ''),
            dense: true,
          )),
          if (_membersWithEmail.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... and ${_membersWithEmail.length - 10} more members',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
