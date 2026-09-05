import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

/// Overview tab for committee members
/// Includes calendar view of meetings, leadership, and quick links
class CommitteeMemberOverviewTab extends StatefulWidget {
  final Committee committee;
  final List<CommitteeLeader> leaders;
  final VoidCallback? onNavigateToMeetings;

  const CommitteeMemberOverviewTab({
    super.key,
    required this.committee,
    required this.leaders,
    this.onNavigateToMeetings,
  });

  @override
  State<CommitteeMemberOverviewTab> createState() =>
      _CommitteeMemberOverviewTabState();
}

class _CommitteeMemberOverviewTabState
    extends State<CommitteeMemberOverviewTab> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CommitteeRepository _committeeRepository = CommitteeRepository();

  bool _isLoading = true;
  List<Meeting> _meetings = [];
  CommitteeStats? _stats;

  Committee get committee => widget.committee;
  List<CommitteeLeader> get leaders => widget.leaders;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _meetingRepository.getMeetingsByCommittee(
          committee.meetingsFilterName,
          includeAttendance: false,
        ),
        _committeeRepository.getCommitteeStats(committee),
      ]);

      if (!mounted) return;

      final meetings = results[0] as List<Meeting>;
      final stats = results[1] as CommitteeStats;

      setState(() {
        _meetings = meetings;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(BrandColors.momentumBlue),
        ),
      );
    }

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: isDesktop
            ? _buildDesktopLayout(theme)
            : _buildMobileLayout(theme, isTablet),
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Welcome and Stats
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildWelcomeCard(theme),
              const SizedBox(height: 16),
              if (_stats != null) _buildStatsCard(theme),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right column - Leadership and Upcoming
        Expanded(
          flex: 2,
          child: Column(
            children: [
              if (leaders.isNotEmpty) ...[
                _buildLeadershipCard(theme),
                const SizedBox(height: 16),
              ],
              _buildUpcomingMeetingsCard(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, bool isTablet) {
    return Column(
      children: [
        _buildWelcomeCard(theme),
        const SizedBox(height: 16),
        if (_stats != null) ...[
          _buildStatsCard(theme),
          const SizedBox(height: 16),
        ],
        if (leaders.isNotEmpty) ...[
          _buildLeadershipCard(theme),
          const SizedBox(height: 16),
        ],
        _buildUpcomingMeetingsCard(theme),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    final userSession = context.watch<UserSessionProvider>();
    final currentMember = userSession.currentMember;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.waving_hand_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${currentMember?.name.split(' ').first ?? 'Member'}!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    committee.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final stats = _stats!;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Committee Stats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatItem(
                  icon: Icons.people_outline,
                  label: 'Members',
                  value: '${stats.memberCount}',
                  theme: theme,
                ),
                _buildStatItem(
                  icon: Icons.video_camera_front_outlined,
                  label: 'Meetings',
                  value: '${_meetings.length}',
                  theme: theme,
                ),
                _buildStatItem(
                  icon: Icons.chat_outlined,
                  label: 'Slack Messages',
                  value: '${stats.slackMessageCount}',
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadershipCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.supervisor_account_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Committee Leadership',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...leaders.map((leader) => _buildLeaderItem(leader, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderItem(CommitteeLeader leader, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Same tile gradient as the workspace header. White on a
          // white-20% disc measures 2.23:1 over the momentumBlue end, so
          // take the opaque unityBlue default at 12.51:1.
          CorsAwareAvatar(
            imageUrl: leader.photoUrl,
            radius: 20,
            fallbackText: leader.name,
            fallbackIconColor: Colors.white,
            fallbackTextColor: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leader.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (leader.title != null)
                  Text(
                    leader.title!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMeetingsCard(ThemeData theme) {
    final now = DateTime.now();
    final upcoming = _meetings.where((m) => m.meetingDate.isAfter(now)).toList()
      ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

    final displayMeetings = upcoming.take(3).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.tileGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.upcoming_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Upcoming Meetings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onNavigateToMeetings != null && upcoming.isNotEmpty)
                  TextButton(
                    onPressed: widget.onNavigateToMeetings,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('See all'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (displayMeetings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 32,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No upcoming meetings',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...displayMeetings.map(
                (meeting) => _buildUpcomingMeetingItem(meeting, theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingMeetingItem(Meeting meeting, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _formatMonth(meeting.meetingDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${meeting.meetingDate.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.meetingTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meeting.formattedTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonth(DateTime date) {
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[date.month - 1];
  }
}
