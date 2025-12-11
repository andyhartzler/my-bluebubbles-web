import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';

class CommitteeMessagesTab extends StatefulWidget {
  final Committee committee;

  const CommitteeMessagesTab({super.key, required this.committee});

  @override
  State<CommitteeMessagesTab> createState() => _CommitteeMessagesTabState();
}

class _CommitteeMessagesTabState extends State<CommitteeMessagesTab>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  final CRMMessageService _messageService = CRMMessageService.instance;
  final TextEditingController _messageController = TextEditingController();

  late TabController _tabController;
  List<Member> _members = [];
  Set<String> _memberPhoneNumbers = {};
  bool _loading = true;
  bool _sending = false;
  int _currentProgress = 0;
  int _totalMessages = 0;
  Map<String, int> _transportPreview = {};
  final List<PlatformFile> _attachments = [];

  Committee get committee => widget.committee;

  List<Member> get _membersWithPhone => _members.where(
    (m) => m.canContact && m.primaryPhone != null && m.primaryPhone!.isNotEmpty,
  ).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final members = await _repository.getMembersForCommittee(committee.name);
      if (!mounted) return;

      // Extract phone numbers from members
      final phoneNumbers = <String>{};
      for (final member in members) {
        if (member.primaryPhone != null && member.primaryPhone!.isNotEmpty) {
          phoneNumbers.add(member.primaryPhone!);
        }
      }

      // Get transport breakdown
      final contactableMembers = members.where((m) => m.canContact).toList();
      Map<String, int> transports = {};
      if (contactableMembers.isNotEmpty) {
        try {
          transports = await _messageService.previewTransportBreakdown(contactableMembers);
        } catch (_) {
          transports = {};
        }
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _memberPhoneNumbers = phoneNumbers;
        _transportPreview = transports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );

    if (result == null) return;

    setState(() {
      for (final file in result.files) {
        final alreadyExists = _attachments.any((existing) {
          if (existing.identifier != null && file.identifier != null) {
            return existing.identifier == file.identifier;
          }
          if (existing.path != null && file.path != null) {
            return existing.path == file.path;
          }
          return existing.name == file.name && existing.bytes == file.bytes;
        });

        if (!alreadyExists) {
          _attachments.add(file);
        }
      }
    });
  }

  void _removeAttachment(PlatformFile file) {
    setState(() {
      _attachments.remove(file);
    });
  }

  Future<void> _sendMessages() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    final recipients = _membersWithPhone;
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members with phone numbers')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Message'),
        content: Text(
          'Send this message to ${recipients.length} ${committee.displayName} members?\n\n'
          'Messages will be sent at a rate of ${CRMMessageService.messagesPerMinute} per minute.',
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
      _totalMessages = recipients.length;
    });

    try {
      final filter = MessageFilter(committees: [committee.name]);
      final results = await _messageService.sendBulkMessages(
        filter: filter,
        messageText: message,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
        attachments: List<PlatformFile>.from(_attachments),
      );

      final successCount = results.values.where((v) => v).length;

      if (!mounted) return;
      setState(() => _sending = false);

      // Clear the message after sending
      _messageController.clear();
      _attachments.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Messages Sent'),
          content: Text('Successfully sent $successCount of ${results.length} messages'),
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
        SnackBar(content: Text('Error sending messages: $e')),
      );
    }
  }

  Future<void> _sendIntroMessages() async {
    final eligible = _membersWithPhone.where((m) => m.introSentAt == null).toList();
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All members have already received the intro message')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Intro Message'),
        content: Text(
          'Send the intro message and contact card to ${eligible.length} ${committee.displayName} members?\n\n'
          'Members who have already received the intro will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Intro'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _currentProgress = 0;
      _totalMessages = eligible.length;
    });

    try {
      final filter = MessageFilter(committees: [committee.name]);
      final results = await _messageService.sendIntroToFilteredMembers(
        filter,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
      );

      final successCount = results.values.where((v) => v).length;

      if (!mounted) return;
      setState(() => _sending = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Intro Messages Sent'),
          content: Text('Successfully sent intro to $successCount members'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Reload members to update intro status
      _loadMembers();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending intro messages: $e')),
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
              Tab(text: 'Conversations'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildComposeTab(),
              _buildConversationsTab(),
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

    final recipients = _membersWithPhone;
    final alreadyIntroduced = recipients.where((m) => m.introSentAt != null).length;
    final introEligible = recipients.length - alreadyIntroduced;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: committee.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recipients: ${recipients.length} members',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_transportPreview.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _transportPreview.entries.map((entry) {
                            return Chip(
                              avatar: Icon(
                                entry.key == 'iMessage' ? Icons.message : Icons.sms,
                                size: 16,
                              ),
                              label: Text('${entry.value} ${entry.key}'),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                      if (alreadyIntroduced > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$alreadyIntroduced already received intro ($introEligible eligible)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Message composer card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compose Message',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        maxLines: 6,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Type your message here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        enabled: !_sending && recipients.isNotEmpty,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),

                      // Attachments section
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
                          if (!_sending && recipients.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: _pickAttachments,
                              icon: const Icon(Icons.attach_file, size: 18),
                              label: Text(_attachments.isEmpty ? 'Add attachments' : 'Add more'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick actions
              if (recipients.isNotEmpty && !_sending)
                OutlinedButton.icon(
                  onPressed: introEligible > 0 ? _sendIntroMessages : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(introEligible > 0
                      ? 'Send Intro Message + Contact Card to $introEligible Members'
                      : 'All Members Have Received Intro'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
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
              value: _totalMessages > 0 ? _currentProgress / _totalMessages : 0,
              backgroundColor: committee.primaryColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(committee.primaryColor),
            ),
            const SizedBox(height: 8),
            Text('Sending $_currentProgress of $_totalMessages...'),
          ],
        ),
      );
    }

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
          onPressed: _messageController.text.trim().isEmpty || recipients.isEmpty
              ? null
              : _sendMessages,
          icon: const Icon(Icons.send),
          label: Text('Send to ${recipients.length} Members'),
          style: ElevatedButton.styleFrom(
            backgroundColor: committee.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_memberPhoneNumbers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Committee members don\'t have phone numbers configured.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use the ConversationList widget filtered by committee member phone numbers
    return ConversationList(
      key: ValueKey('committee-conversations-${committee.id}'),
      showArchivedChats: false,
      showUnknownSenders: false,
      filterPhoneNumbers: _memberPhoneNumbers,
      isEmbedded: true,
    );
  }
}
