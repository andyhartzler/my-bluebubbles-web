import 'package:flutter/material.dart';

import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';

class CommitteeMessagesTab extends StatefulWidget {
  final Committee committee;

  const CommitteeMessagesTab({super.key, required this.committee});

  @override
  State<CommitteeMessagesTab> createState() => _CommitteeMessagesTabState();
}

class _CommitteeMessagesTabState extends State<CommitteeMessagesTab>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  late TabController _tabController;
  List<Member> _members = [];
  Set<String> _memberPhoneNumbers = {};
  bool _loading = true;
  bool _openingComposer = false;

  Committee get committee => widget.committee;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

      setState(() {
        _members = members;
        _memberPhoneNumbers = phoneNumbers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openMessageComposer() async {
    if (_openingComposer) return;

    setState(() => _openingComposer = true);

    try {
      final filter = MessageFilter(committees: [committee.name]);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BulkMessageScreen(initialFilter: filter),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingComposer = false);
      }
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
              Tab(text: 'Send Message'),
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

    final membersWithPhone = _members.where(
      (m) => m.primaryPhone != null && m.primaryPhone!.isNotEmpty,
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Compose card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 48,
                  color: committee.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Send Message to ${committee.displayName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send an SMS/iMessage to all ${membersWithPhone.length} committee members with phone numbers.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Recipients preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: committee.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: committee.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recipients',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: committee.primaryColor,
                              ),
                            ),
                            Text(
                              '${membersWithPhone.length} members with phone numbers',
                              style: TextStyle(
                                fontSize: 12,
                                color: committee.primaryColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Compose button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: membersWithPhone.isEmpty || _openingComposer
                        ? null
                        : _openMessageComposer,
                    icon: _openingComposer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit),
                    label: Text(_openingComposer ? 'Opening...' : 'Open Message Composer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: committee.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                if (membersWithPhone.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No members have phone numbers configured.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Member list preview
        Text(
          'Committee Members',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...membersWithPhone.take(5).map((member) => ListTile(
          leading: CircleAvatar(
            backgroundColor: committee.primaryColor.withOpacity(0.2),
            child: Text(
              member.name.isNotEmpty ? member.name[0] : '?',
              style: TextStyle(color: committee.primaryColor),
            ),
          ),
          title: Text(member.name),
          subtitle: Text(member.primaryPhone ?? ''),
          dense: true,
        )),

        if (membersWithPhone.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${membersWithPhone.length - 5} more members',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ),
      ],
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
    // This is an exact copy of the main Conversations page with filtering applied
    return ConversationList(
      key: ValueKey('committee-conversations-${committee.id}'),
      showArchivedChats: false,
      showUnknownSenders: false,
      filterPhoneNumbers: _memberPhoneNumbers,
      isEmbedded: true,
    );
  }
}
