import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
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
        gradient: LinearGradient(
          colors: [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.block, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ineligible Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_members.length} members still have Slack access',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadMembers,
            icon: const Icon(Icons.refresh, color: Colors.white),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BrandColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: BrandColors.success,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No ineligible members with Slack access',
            style: TextStyle(
              color: BrandColors.unityBlue,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All Slack users are eligible members',
            style: TextStyle(
              color: BrandColors.unityBlue.withOpacity(0.7),
              fontSize: 14,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BrandColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: BrandColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.unityBlue,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.unityBlue,
                foregroundColor: Colors.white,
              ),
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
  const _IneligibleMemberCard({required this.member, required this.onTap});

  final Member member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final age = member.age;
    final email = member.email ?? member.schoolEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: Colors.red.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.red, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar with red border
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: CorsAwareAvatar(
                      imageUrl: member.primaryProfilePhotoUrl,
                      radius: 26,
                      backgroundColor: Colors.red.withOpacity(0.1),
                      fallbackText: member.name,
                      fallbackTextColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 14),
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
                                style: const TextStyle(
                                  color: BrandColors.unityBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'INELIGIBLE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (email != null)
                          Text(
                            email,
                            style: TextStyle(
                              color: BrandColors.unityBlue.withOpacity(0.7),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                      Colors.red,
                    ),
                  if (member.slackUserId != null)
                    _buildInfoChip(
                      context,
                      Icons.tag,
                      'Slack: ${member.slackUserId}',
                      BrandColors.momentumBlue,
                    ),
                  if (member.county != null)
                    _buildInfoChip(
                      context,
                      Icons.location_on_outlined,
                      member.county!,
                      BrandColors.momentumBlue,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Action button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.unityBlue,
                    foregroundColor: Colors.white,
                  ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: BrandColors.unityBlue.withOpacity(0.7),
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
