import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/committee_member_workspace_screen.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/committees/widgets/member_calendar_widget.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _backgroundAsset = 'assets/images/Blue-Gradient-Background.png';
const _overlayOpacity = 0.12;

/// Committee Hub Dashboard for non-executive committee members
///
/// A modern dashboard showing committee assignments, upcoming meetings,
/// and personalized welcome message.
class CommitteeHubScreen extends StatefulWidget {
  const CommitteeHubScreen({super.key});

  @override
  State<CommitteeHubScreen> createState() => _CommitteeHubScreenState();
}

class _CommitteeHubScreenState extends State<CommitteeHubScreen> {
  final CommitteeRepository _repository = CommitteeRepository();
  final MeetingRepository _meetingRepository = MeetingRepository();

  bool _isLoading = true;
  String? _error;
  Map<String, int> _committeeMemberCounts = {};
  Map<String, bool> _workspaceEnabledMap = {};
  List<Meeting> _upcomingMeetings = [];
  int _totalMeetingsThisMonth = 0;

  /// Whether all the user's committees have workspace disabled
  bool _allWorkspacesDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = context.read<UserSessionProvider>();
      final counts = <String, int>{};
      final allMeetings = <Meeting>[];

      // Get committee names for workspace enabled check
      final committeeNames = session.userCommittees.map((c) => c.name).toList();

      // Load workspace enabled status for all committees
      final workspaceEnabled = await _repository.getWorkspaceEnabledForCommittees(committeeNames);

      for (final committee in session.userCommittees) {
        // Only load data for enabled committees
        if (workspaceEnabled[committee.name] == true) {
          final count = await _repository.getMemberCountForCommittee(committee.name);
          counts[committee.name] = count;

          // Load meetings for each committee
          try {
            final committeeDef = CommitteeDefinitions.findByName(committee.name);
            if (committeeDef != null) {
              final meetings = await _meetingRepository.getMeetingsByCommittee(
                committeeDef.meetingsFilterName,
                includeAttendance: false,
              );
              allMeetings.addAll(meetings);
            }
          } catch (_) {
            // Ignore meeting load errors
          }
        }
      }

      // Check if all workspaces are disabled
      final anyEnabled = workspaceEnabled.values.any((enabled) => enabled);

      // Get upcoming meetings (next 7 days)
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));
      final upcoming = allMeetings
          .where((m) => m.meetingDate.isAfter(now) && m.meetingDate.isBefore(weekFromNow))
          .toList()
        ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

      // Count meetings this month
      final thisMonthMeetings = allMeetings.where((m) =>
          m.meetingDate.year == now.year && m.meetingDate.month == now.month).length;

      if (!mounted) return;
      setState(() {
        _committeeMemberCounts = counts;
        _workspaceEnabledMap = workspaceEnabled;
        _allWorkspacesDisabled = !anyEnabled;
        _upcomingMeetings = upcoming.take(3).toList();
        _totalMeetingsThisMonth = thisMonthMeetings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.read<UserSessionProvider>().clearSession();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _navigateToCommittee(UserCommitteeInfo committeeInfo) {
    final committee = CommitteeDefinitions.findByName(committeeInfo.name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommitteeMemberWorkspaceScreen(
          committeeInfo: committeeInfo,
          committee: committee,
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_unityBlue, _momentumBlue],
                  ),
                ),
              ),
            ),
          ),
          // White overlay
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(_overlayOpacity)),
          ),
          // Content
          Positioned.fill(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final session = context.watch<UserSessionProvider>();

    if (session.isLoading || _isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    // Filter to only show committees with workspace enabled
    final committees = session.userCommittees
        .where((c) => _workspaceEnabledMap[c.name] == true)
        .toList();

    // If no committees at all (not in any committee)
    if (session.userCommittees.isEmpty) {
      return _buildNoCommitteesView();
    }

    // If all workspaces are disabled
    if (_allWorkspacesDisabled || committees.isEmpty) {
      return _buildWorkspaceDisabledView();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
        final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 32.0 : 20.0);

        return RefreshIndicator(
          onRefresh: () async {
            await session.refreshSession();
            await _loadData();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Welcome header
              SliverToBoxAdapter(
                child: _buildWelcomeHeader(session, horizontalPadding),
              ),

              // Quick stats row
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
                sliver: SliverToBoxAdapter(
                  child: _buildQuickStats(session, committees.length),
                ),
              ),

              // Main content - responsive layout
              if (isDesktop)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 32),
                  sliver: SliverToBoxAdapter(
                    child: _buildDesktopLayout(committees),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 32),
                  sliver: SliverToBoxAdapter(
                    child: _buildMobileLayout(committees),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(UserSessionProvider session, double horizontalPadding) {
    final theme = Theme.of(context);
    final greeting = _getGreeting();
    final firstName = session.displayName.split(' ').first;

    return Container(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 48, horizontalPadding, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _unityBlue.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CorsAwareAvatar(
              imageUrl: null,
              radius: 32,
              backgroundColor: _momentumBlue,
              fallbackText: session.displayName,
              fallbackIconColor: Colors.white,
              fallbackTextColor: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _unityBlue.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
          ),
          // Logout button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _unityBlue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, color: _unityBlue),
              tooltip: 'Sign out',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(UserSessionProvider session, int committeeCount) {
    final theme = Theme.of(context);
    final totalMembers = _committeeMemberCounts.values.fold(0, (a, b) => a + b);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatCard(
          icon: Icons.groups_outlined,
          label: 'Committees',
          value: '$committeeCount',
          color: _momentumBlue,
          theme: theme,
        ),
        _buildStatCard(
          icon: Icons.people_outline,
          label: 'Fellow Members',
          value: '$totalMembers',
          color: const Color(0xFF4CAF50),
          theme: theme,
        ),
        if (_upcomingMeetings.isNotEmpty)
          _buildStatCard(
            icon: Icons.event_outlined,
            label: 'This Week',
            value: '${_upcomingMeetings.length} meeting${_upcomingMeetings.length == 1 ? '' : 's'}',
            color: const Color(0xFFFF9800),
            theme: theme,
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _unityBlue.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(List<UserCommitteeInfo> committees) {
    return Column(
      children: [
        // Top row - Committees and Upcoming meetings
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Committees section
            Expanded(
              flex: 3,
              child: _buildCommitteesSection(committees),
            ),
            const SizedBox(width: 24),
            // Upcoming meetings section
            Expanded(
              flex: 2,
              child: _buildUpcomingMeetingsSection(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Calendar section - full width
        const MemberCalendarWidget(),
      ],
    );
  }

  Widget _buildMobileLayout(List<UserCommitteeInfo> committees) {
    return Column(
      children: [
        _buildCommitteesSection(committees),
        const SizedBox(height: 24),
        _buildUpcomingMeetingsSection(),
        const SizedBox(height: 24),
        const MemberCalendarWidget(),
      ],
    );
  }

  Widget _buildCommitteesSection(List<UserCommitteeInfo> committees) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _momentumBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dashboard_outlined, color: _momentumBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Your Committees',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Committee list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: committees.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 24, endIndent: 24),
            itemBuilder: (context, index) => _buildCommitteeRow(committees[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteeRow(UserCommitteeInfo committeeInfo) {
    final theme = Theme.of(context);
    final memberCount = _committeeMemberCounts[committeeInfo.name] ?? 0;
    final committee = CommitteeDefinitions.findByName(committeeInfo.name);
    final icon = committee?.icon ?? Icons.groups_outlined;
    final primaryColor = committee?.primaryColor ?? _momentumBlue;

    return InkWell(
      onTap: () => _navigateToCommittee(committeeInfo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // Committee icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    committeeInfo.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: _unityBlue.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _unityBlue.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _momentumBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18, color: _momentumBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingMeetingsSection() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFFF9800), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Upcoming This Week',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Meeting list
          if (_upcomingMeetings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 48,
                      color: _unityBlue.withOpacity(0.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No meetings this week',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _unityBlue.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingMeetings.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 24, endIndent: 24),
              itemBuilder: (context, index) => _buildMeetingRow(_upcomingMeetings[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildMeetingRow(Meeting meeting) {
    final theme = Theme.of(context);
    final isToday = _isToday(meeting.meetingDate);
    final isTomorrow = _isTomorrow(meeting.meetingDate);

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isTomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = _formatWeekday(meeting.meetingDate);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isToday ? _momentumBlue : _unityBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${meeting.meetingDate.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _formatMonthShort(meeting.meetingDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.meetingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _unityBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isToday || isTomorrow) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isToday ? _momentumBlue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dateLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isToday ? _momentumBlue : Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      meeting.formattedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _unityBlue.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }

  String _formatWeekday(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  String _formatMonthShort(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[date.month - 1];
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: _unityBlue),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _unityBlue),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _momentumBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCommitteesView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _unityBlue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _momentumBlue.withOpacity(0.1),
                ),
                padding: const EdgeInsets.all(24),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 56,
                  color: _momentumBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Committee Access',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You don't appear to be assigned to any committees yet.\nPlease contact your committee chair for assistance.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _unityBlue,
                  side: const BorderSide(color: _unityBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceDisabledView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _unityBlue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.1),
                ),
                padding: const EdgeInsets.all(24),
                child: Icon(
                  Icons.lock_clock_outlined,
                  size: 56,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Workspace Not Available',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your committee(s) do not have workspace access enabled.\n\nIf you believe this is an error, please ask your committee leaders in Slack.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _momentumBlue,
                      side: const BorderSide(color: _momentumBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _unityBlue,
                      side: const BorderSide(color: _unityBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
