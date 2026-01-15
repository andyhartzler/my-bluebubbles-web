import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/models/slack_analytics.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/features/slack/widgets/message_bubble.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';

/// Analytics tab displaying Slack workspace statistics
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key, this.onSwitchToUnmatchedTab});

  /// Callback to switch to the unmatched users tab
  final VoidCallback? onSwitchToUnmatchedTab;

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final SlackManagementRepository _repository = SlackManagementRepository();

  SlackAnalyticsSummary? _summary;
  List<DailyMessageCount> _messagesByDay = [];
  List<ChannelActivity> _channelActivity = [];
  List<UserActivity> _userActivity = [];
  List<DayOfWeekActivity> _dayOfWeekActivity = [];
  List<HourlyActivity> _hourlyActivity = [];
  List<MembershipChange> _membershipChanges = [];

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getAnalyticsSummary(),
        _repository.getMessagesByDay(),
        _repository.getChannelActivity(),
        _repository.getUserActivity(),
        _repository.getDayOfWeekActivity(),
        _repository.getHourlyActivity(),
        _repository.getRecentMembershipChanges(limit: 30),
      ]);

      if (!mounted) return;

      setState(() {
        _summary = results[0] as SlackAnalyticsSummary;
        _messagesByDay = results[1] as List<DailyMessageCount>;
        _channelActivity = results[2] as List<ChannelActivity>;
        _userActivity = results[3] as List<UserActivity>;
        _dayOfWeekActivity = results[4] as List<DayOfWeekActivity>;
        _hourlyActivity = results[5] as List<HourlyActivity>;
        _membershipChanges = results[6] as List<MembershipChange>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load analytics: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshAnalytics() async {
    if (_refreshing) return;

    setState(() => _refreshing = true);

    try {
      final success = await _repository.refreshAnalytics(daysBack: _selectedDays);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics refresh started. Reloading in a moment...'),
          ),
        );
        // Wait a bit for the edge function to complete
        await Future.delayed(const Duration(seconds: 3));
        await _loadAnalytics();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh analytics')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            _buildMessagesOverTimeChart(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTopChannelsCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildTopUsersCard()),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDayOfWeekCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildHourlyActivityCard()),
              ],
            ),
            const SizedBox(height: 24),
            _buildMembershipChangesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Row(
      children: [
        Icon(Icons.analytics, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Slack Analytics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_summary?.computedAt != null)
                Text(
                  'Last updated: ${dateFormat.format(_summary!.computedAt!.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        // Time period selector
        DropdownButton<int>(
          value: _selectedDays,
          items: const [
            DropdownMenuItem(value: 30, child: Text('Last 30 days')),
            DropdownMenuItem(value: 60, child: Text('Last 60 days')),
            DropdownMenuItem(value: 90, child: Text('Last 90 days')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedDays = value);
            }
          },
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _refreshing ? null : _refreshAnalytics,
          icon: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(_refreshing ? 'Refreshing...' : 'Refresh'),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardCount = isWide ? 4 : 2;
        final cardWidth = (constraints.maxWidth - (cardCount - 1) * 16) / cardCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Total Messages',
                value: _formatNumber(_summary?.totalMessagesAllTime ?? 0),
                subtitle: '+${_formatNumber(_summary?.totalMessagesRecent ?? 0)} this period',
                icon: Icons.message,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Active Channels',
                value: '${_summary?.activeChannels ?? 0}',
                icon: Icons.tag,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Linked Users',
                value: '${_summary?.linkedUsers ?? 0}',
                icon: Icons.people,
                color: Colors.purple,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Unmatched Users',
                value: '${_summary?.unmatchedUsers ?? 0}',
                subtitle: _summary?.unmatchedUsers != null && _summary!.unmatchedUsers > 0
                    ? 'Needs attention'
                    : null,
                icon: Icons.person_search,
                color: _summary?.unmatchedUsers != null && _summary!.unmatchedUsers > 0
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessagesOverTimeChart() {
    final theme = Theme.of(context);

    if (_messagesByDay.isEmpty) {
      return _buildEmptyCard(
        title: 'Messages Over Time',
        message: 'No message data available',
        icon: Icons.show_chart,
      );
    }

    // Find max for scaling
    final maxCount = _messagesByDay.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages Over Time',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _messagesByDay.map((day) {
                  final height = maxCount > 0 ? (day.count / maxCount) * 180 : 0.0;
                  return Expanded(
                    child: Tooltip(
                      message: '${day.date}: ${day.count} messages',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: height,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _messagesByDay.isNotEmpty ? _messagesByDay.first.date : '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _messagesByDay.isNotEmpty ? _messagesByDay.last.date : '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChannelsCard() {
    final theme = Theme.of(context);

    if (_channelActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Most Active Channels',
        message: 'No channel data available',
        icon: Icons.tag,
      );
    }

    final topChannels = _channelActivity.take(5).toList();
    final maxCount = topChannels.isNotEmpty
        ? topChannels.first.messageCount
        : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Active Channels',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...topChannels.map((channel) {
              final barWidth = maxCount > 0 ? (channel.messageCount / maxCount) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tag, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            channel.channelName,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatNumber(channel.messageCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: barWidth,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUsersCard() {
    final theme = Theme.of(context);

    if (_userActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Most Active Users',
        message: 'No user data available',
        icon: Icons.people,
      );
    }

    final topUsers = _userActivity.take(5).toList();
    final maxCount = topUsers.isNotEmpty ? topUsers.first.messageCount : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Active Users',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...topUsers.map((user) {
              final barWidth = maxCount > 0 ? (user.messageCount / maxCount) : 0.0;
              return InkWell(
                onTap: () => _handleUserTap(user),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            user.isLinked ? Icons.person : Icons.person_outline,
                            size: 14,
                            color: user.isLinked
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatNumber(user.messageCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: barWidth,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        color: user.isLinked
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUserTap(UserActivity user) async {
    if (user.isLinked && user.memberId != null && user.memberId!.isNotEmpty) {
      // Navigate to member profile Slack tab
      final member = await _repository.getMemberById(user.memberId!);
      if (member != null && mounted) {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => TitleBarWrapper(
              child: MemberDetailScreen(member: member),
            ),
          ),
        );
      }
    } else {
      // Show messages dialog for unmatched user
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => _SlackUserMessagesDialog(
          slackUserId: user.slackUserId,
          userName: user.name,
          repository: _repository,
          onLinked: _loadAnalytics,
        ),
      );
    }
  }

  Widget _buildDayOfWeekCard() {
    final theme = Theme.of(context);

    if (_dayOfWeekActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Activity by Day',
        message: 'No data available',
        icon: Icons.calendar_today,
      );
    }

    final maxCount = _dayOfWeekActivity.map((e) => e.messageCount).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity by Day',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _dayOfWeekActivity.map((day) {
                  final height = maxCount > 0 ? (day.messageCount / maxCount) * 100 : 0.0;
                  return Expanded(
                    child: Tooltip(
                      message: '${day.dayName}: ${day.messageCount} messages',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: height,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day.dayName.substring(0, 3),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyActivityCard() {
    final theme = Theme.of(context);

    if (_hourlyActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Activity by Hour',
        message: 'No data available',
        icon: Icons.access_time,
      );
    }

    final maxCount = _hourlyActivity.map((e) => e.messageCount).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity by Hour',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _hourlyActivity.map((hour) {
                  final height = maxCount > 0 ? (hour.messageCount / maxCount) * 100 : 0.0;
                  final isWorkHour = hour.hour >= 9 && hour.hour <= 17;
                  return Expanded(
                    child: Tooltip(
                      message: '${hour.hourLabel}: ${hour.messageCount} messages',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        height: height,
                        decoration: BoxDecoration(
                          color: isWorkHour
                              ? theme.colorScheme.primary.withOpacity(0.7)
                              : theme.colorScheme.secondary.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '12 AM',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
                Text(
                  '12 PM',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
                Text(
                  '11 PM',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipChangesCard() {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d • h:mm a');

    if (_membershipChanges.isEmpty) {
      return _buildEmptyCard(
        title: 'Recent Membership Changes',
        message: 'No recent changes',
        icon: Icons.people_alt,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Membership Changes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...(_membershipChanges.take(10).map((change) {
              final isJoin = change.action == 'joined' || change.action == 'invited';
              return _buildMembershipChangeItem(change, isJoin, dateFormat);
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipChangeItem(
    MembershipChange change,
    bool isJoin,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _handleMembershipChangeTap(change),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // Avatar with action indicator
            Stack(
              children: [
                _buildUserAvatar(change),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isJoin ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isJoin ? Icons.add : Icons.remove,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Name and channel info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          change.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!change.isLinkedMember)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'Unmatched',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.orange[700],
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          change.channelDisplayName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action and timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isJoin
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    change.action.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isJoin ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (change.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(change.createdAt!.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
            // Navigation indicator
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(MembershipChange change) {
    final theme = Theme.of(context);
    final accentColor = change.isLinkedMember
        ? theme.colorScheme.primary
        : Colors.orange[700]!;

    return CorsAwareAvatar(
      imageUrl: change.avatarUrl,
      radius: 20,
      backgroundColor: accentColor.withOpacity(0.2),
      fallbackText: change.displayName,
      fallbackIconColor: accentColor,
      fallbackTextColor: accentColor,
    );
  }

  Future<void> _handleMembershipChangeTap(MembershipChange change) async {
    if (change.isLinkedMember) {
      // Navigate to member profile
      final member = await _repository.getMemberById(change.memberId!);
      if (member != null && mounted) {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => TitleBarWrapper(
              child: MemberDetailScreen(member: member),
            ),
          ),
        );
      }
    } else if (widget.onSwitchToUnmatchedTab != null) {
      // Switch to unmatched users tab
      widget.onSwitchToUnmatchedTab!();
    }
  }

  Widget _buildEmptyCard({
    required String title,
    required String message,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Icon(icon, size: 48, color: theme.disabledColor),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

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
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Summary card widget for displaying a key metric
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog to show messages from a specific Slack user and allow linking
class _SlackUserMessagesDialog extends StatefulWidget {
  const _SlackUserMessagesDialog({
    required this.slackUserId,
    required this.userName,
    required this.repository,
    this.onLinked,
  });

  final String slackUserId;
  final String userName;
  final SlackManagementRepository repository;
  final VoidCallback? onLinked;

  @override
  State<_SlackUserMessagesDialog> createState() => _SlackUserMessagesDialogState();
}

class _SlackUserMessagesDialogState extends State<_SlackUserMessagesDialog> {
  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, String>> _userMappings = {};
  Map<String, Member> _memberCache = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;
  SlackUnmatchedUser? _unmatchedUser;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        widget.repository.getMessagesBySlackUserId(widget.slackUserId, limit: _pageSize),
        widget.repository.getSlackUserMappings(),
        widget.repository.getUnmatchedUserBySlackId(widget.slackUserId),
      ]);

      if (!mounted) return;

      setState(() {
        _messages = results[0] as List<Map<String, dynamic>>;
        _userMappings = results[1] as Map<String, Map<String, String>>;
        _unmatchedUser = results[2] as SlackUnmatchedUser?;
        _offset = _messages.length;
        _hasMore = _messages.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    try {
      final newMessages = await widget.repository.getMessagesBySlackUserId(
        widget.slackUserId,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) return;

      setState(() {
        _messages.addAll(newMessages);
        _offset = _messages.length;
        _hasMore = newMessages.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _showMatchDialog() async {
    if (_unmatchedUser == null) return;

    final result = await showDialog<Member>(
      context: context,
      builder: (context) => _MemberSearchDialog(repository: widget.repository),
    );

    if (result != null && mounted) {
      final success = await widget.repository.matchUserToMember(
        slackUserId: widget.slackUserId,
        memberId: result.id,
        slackEmail: _unmatchedUser!.email,
        slackDisplayName: _unmatchedUser!.displayName,
        slackRealName: _unmatchedUser!.realName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Matched ${widget.userName} to ${result.name}')),
        );
        widget.onLinked?.call();
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  CorsAwareAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    fallbackText: widget.userName,
                    fallbackTextColor: Colors.orange[700]!,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Unmatched Slack User',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_unmatchedUser != null)
                    ElevatedButton.icon(
                      onPressed: _showMatchDialog,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Link to Member'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages found',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: _loadingMore
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: _loadMore,
                                          child: const Text('Load More'),
                                        ),
                                ),
                              );
                            }

                            return SlackMessageBubble(
                              message: _messages[index],
                              userMappings: _userMappings,
                              memberCache: _memberCache,
                              primaryColor: Colors.blue,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for searching and selecting a member to match
class _MemberSearchDialog extends StatefulWidget {
  const _MemberSearchDialog({required this.repository});

  final SlackManagementRepository repository;

  @override
  State<_MemberSearchDialog> createState() => _MemberSearchDialogState();
}

class _MemberSearchDialogState extends State<_MemberSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Member> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await widget.repository.searchMembers(query, limit: 20);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link to Member',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.length < 2
                                  ? 'Type to search members...'
                                  : 'No members found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final member = _results[index];
                              return ListTile(
                                leading: CorsAwareAvatar(
                                  imageUrl: member.primaryProfilePhotoUrl,
                                  radius: 20,
                                  fallbackText: member.name,
                                ),
                                title: Text(member.name),
                                subtitle: Text(
                                  member.email ?? 'No email',
                                  style: theme.textTheme.bodySmall,
                                ),
                                onTap: () => Navigator.pop(context, member),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
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
