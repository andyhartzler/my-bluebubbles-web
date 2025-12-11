import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/screens/crm/bulk_email_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_tab.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_provider.dart';
import 'package:provider/provider.dart';

class CommitteeEmailTab extends StatefulWidget {
  final Committee committee;

  const CommitteeEmailTab({super.key, required this.committee});

  @override
  State<CommitteeEmailTab> createState() => _CommitteeEmailTabState();
}

class _CommitteeEmailTabState extends State<CommitteeEmailTab>
    with SingleTickerProviderStateMixin {
  final CommitteeRepository _repository = CommitteeRepository();
  late TabController _tabController;
  List<Member> _members = [];
  bool _loading = true;

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
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openEmailComposer() {
    final filter = MessageFilter(committees: [committee.name]);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BulkEmailScreen(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Tab bar for history vs compose
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Email History'),
              Tab(text: 'Send Email'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildHistoryTab(),
              _buildComposeTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.email_outlined,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No members in this committee',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Add members to see their email history.',
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

    // Use the first member with an email to display history
    // In a real implementation, you might want to aggregate or show a list
    final membersWithEmail = _members.where(
      (m) => m.preferredEmail != null && m.preferredEmail!.isNotEmpty,
    ).toList();

    if (membersWithEmail.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.email_outlined,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No email addresses',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Committee members don\'t have email addresses configured.',
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
                    '${membersWithEmail.length} members with email addresses',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openEmailComposer,
                    icon: const Icon(Icons.send),
                    label: const Text('Email All Committee Members'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: committee.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent emails section
          Text(
            'Recent Emails',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View email history for individual members in their profile.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),

          // Show email history for a sample member if provider is available
          _buildEmailHistorySection(),
        ],
      ),
    );
  }

  Widget _buildEmailHistorySection() {
    final provider = _maybeReadProvider(context);
    if (provider == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Email history provider not available.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // Show aggregated view of emails to committee members
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To view email history, select a member from the Members tab.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  EmailHistoryProvider? _maybeReadProvider(BuildContext context) {
    try {
      return Provider.of<EmailHistoryProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  Widget _buildComposeTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final membersWithEmail = _members.where(
      (m) => m.preferredEmail != null && m.preferredEmail!.isNotEmpty,
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
                  Icons.email_outlined,
                  size: 48,
                  color: committee.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Send Email to ${committee.displayName}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compose and send an email to all ${membersWithEmail.length} committee members with email addresses.',
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
                              '${membersWithEmail.length} committee members',
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
                    onPressed: membersWithEmail.isEmpty ? null : _openEmailComposer,
                    icon: const Icon(Icons.edit),
                    label: const Text('Open Email Composer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: committee.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                if (membersWithEmail.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No members have email addresses configured.',
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

        ...membersWithEmail.take(5).map((member) => ListTile(
          leading: CircleAvatar(
            child: Text(member.name.isNotEmpty ? member.name[0] : '?'),
          ),
          title: Text(member.name),
          subtitle: Text(member.preferredEmail ?? ''),
          dense: true,
        )),

        if (membersWithEmail.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${membersWithEmail.length - 5} more members',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ),
      ],
    );
  }
}
