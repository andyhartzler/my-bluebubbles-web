import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/services/crm/meeting_repository.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);

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
  State<CommitteeMemberOverviewTab> createState() => _CommitteeMemberOverviewTabState();
}

class _CommitteeMemberOverviewTabState extends State<CommitteeMemberOverviewTab> {
  final MeetingRepository _meetingRepository = MeetingRepository();
  final CommitteeRepository _committeeRepository = CommitteeRepository();

  bool _isLoading = true;
  List<Meeting> _meetings = [];
  Map<DateTime, List<Meeting>> _meetingsByDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CommitteeStats? _stats;

  Committee get committee => widget.committee;
  List<CommitteeLeader> get leaders => widget.leaders;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
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

      // Group meetings by date (normalized to midnight)
      final byDate = <DateTime, List<Meeting>>{};
      for (final meeting in meetings) {
        final date = DateTime(
          meeting.meetingDate.year,
          meeting.meetingDate.month,
          meeting.meetingDate.day,
        );
        byDate.putIfAbsent(date, () => []).add(meeting);
      }

      setState(() {
        _meetings = meetings;
        _meetingsByDate = byDate;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Meeting> _getMeetingsForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return _meetingsByDate[normalized] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
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
        // Left column - Calendar
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildCalendarCard(theme),
              const SizedBox(height: 16),
              _buildSelectedDayMeetings(theme),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right column - Stats and Leadership
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildWelcomeCard(theme),
              const SizedBox(height: 16),
              if (_stats != null) _buildStatsCard(theme),
              if (leaders.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildLeadershipCard(theme),
              ],
              const SizedBox(height: 16),
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
        _buildCalendarCard(theme),
        const SizedBox(height: 16),
        _buildSelectedDayMeetings(theme),
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
    return Card(
      elevation: 4,
      color: _unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: committee.primaryColor.withOpacity(0.3),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(committee.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to ${committee.displayName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (committee.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      committee.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: _momentumBlue),
                const SizedBox(width: 8),
                Text(
                  'Meeting Calendar',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TableCalendar<Meeting>(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              eventLoader: _getMeetingsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _unityBlue,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left, color: _unityBlue),
                rightChevronIcon: const Icon(Icons.chevron_right, color: _unityBlue),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: _unityBlue.withOpacity(0.6)),
                todayDecoration: BoxDecoration(
                  color: _momentumBlue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: _unityBlue,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: const BoxDecoration(
                  color: _momentumBlue,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                markerDecoration: const BoxDecoration(
                  color: _unityBlue,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 6,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayMeetings(ThemeData theme) {
    final meetings = _selectedDay != null ? _getMeetingsForDay(_selectedDay!) : [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_outlined, color: _momentumBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDay != null
                        ? _formatSelectedDate(_selectedDay!)
                        : 'Select a day',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _unityBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (meetings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No meetings scheduled',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _unityBlue.withOpacity(0.6),
                    ),
                  ),
                ),
              )
            else
              ...meetings.map((meeting) => _buildMeetingItem(meeting, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingItem(Meeting meeting, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _unityBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _momentumBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _momentumBlue,
              borderRadius: BorderRadius.circular(2),
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
                    color: _unityBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${meeting.formattedTime} CST',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _unityBlue.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (meeting.durationMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _momentumBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${meeting.durationMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _momentumBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final stats = _stats!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: _momentumBlue),
                const SizedBox(width: 8),
                Text(
                  'Committee Stats',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
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
        color: _momentumBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: _momentumBlue),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _unityBlue,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.supervisor_account_outlined, color: _momentumBlue),
                const SizedBox(width: 8),
                Text(
                  'Committee Leadership',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _unityBlue,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CorsAwareAvatar(
            imageUrl: leader.photoUrl,
            radius: 20,
            backgroundColor: _momentumBlue.withOpacity(0.2),
            fallbackText: leader.name,
            fallbackIconColor: _unityBlue,
            fallbackTextColor: _unityBlue,
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
                    color: _unityBlue,
                  ),
                ),
                if (leader.title != null)
                  Text(
                    leader.title!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _momentumBlue,
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
    final upcoming = _meetings
        .where((m) => m.meetingDate.isAfter(now))
        .toList()
      ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

    final displayMeetings = upcoming.take(3).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upcoming_outlined, color: _momentumBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upcoming Meetings',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _unityBlue,
                    ),
                  ),
                ),
                if (widget.onNavigateToMeetings != null && upcoming.isNotEmpty)
                  TextButton(
                    onPressed: widget.onNavigateToMeetings,
                    child: const Text('See all'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayMeetings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 32,
                        color: _unityBlue.withOpacity(0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No upcoming meetings',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _unityBlue.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...displayMeetings.map((meeting) => _buildUpcomingMeetingItem(meeting, theme)),
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
        color: _unityBlue,
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

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Today';
    } else if (selected == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatMonth(DateTime date) {
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[date.month - 1];
  }
}
