import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';

/// Tab displaying ineligible members who still have Slack accounts
class IneligibleMembersTab extends StatefulWidget {
  const IneligibleMembersTab({super.key});

  @override
  State<IneligibleMembersTab> createState() => _IneligibleMembersTabState();
}

class _IneligibleMembersTabState extends State<IneligibleMembersTab> {
  final SlackManagementRepository _repository = SlackManagementRepository();

  List<Member> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final members = await _repository.getIneligibleSlackMembers();

      if (!mounted) return;

      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load ineligible members: $e';
        _loading = false;
      });
    }
  }

  void _openMemberDetail(Member member) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemberDetailScreen(member: member),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        _buildHeader(theme),
        // Member list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState(theme)
                  : _members.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildMemberList(),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.block, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ineligible Members with Slack Access',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_members.length} ineligible members still have Slack access',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadMembers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList() {
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          return _IneligibleMemberCard(
            member: _members[index],
            onTap: () => _openMemberDetail(_members[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No ineligible members with Slack access',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'All Slack users are eligible members',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_error ?? 'An error occurred', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMembers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying an ineligible member
class _IneligibleMemberCard extends StatelessWidget {
  const _IneligibleMemberCard({
    required this.member,
    required this.onTap,
  });

  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = member.age;
    final email = member.email ?? member.schoolEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.errorContainer.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.errorContainer,
                    backgroundImage: member.primaryProfilePhotoUrl != null
                        ? CachedNetworkImageProvider(member.primaryProfilePhotoUrl!)
                        : null,
                    child: member.primaryProfilePhotoUrl == null
                        ? Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Chip(
                              label: const Text('INELIGIBLE'),
                              backgroundColor: theme.colorScheme.error,
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        if (email != null)
                          Text(
                            email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Info row
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (age != null)
                    _buildInfoChip(
                      context,
                      Icons.cake_outlined,
                      '$age years old',
                      theme.colorScheme.error,
                    ),
                  if (member.slackUserId != null)
                    _buildInfoChip(
                      context,
                      Icons.tag,
                      'Slack: ${member.slackUserId}',
                      theme.colorScheme.onSurfaceVariant,
                    ),
                  if (member.county != null)
                    _buildInfoChip(
                      context,
                      Icons.location_on_outlined,
                      member.county!,
                      theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Action button
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
