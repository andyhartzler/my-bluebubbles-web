import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/features/slack/models/slack_analytics.dart';
import 'package:bluebubbles/features/slack/services/slack_management_repository.dart';
import 'package:bluebubbles/features/slack/widgets/message_bubble.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/utils/slack_message_formatter.dart';
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
        _repository.getRecentMembershipChanges(limit: 100),
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
      final success = await _repository.refreshAnalytics(
        daysBack: _selectedDays,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Analytics refresh started. Reloading in a moment...',
            ),
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
      return const Center(
        child: CircularProgressIndicator(color: BrandColors.momentumBlue),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: BrandColors.momentumBlue,
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
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      _buildTopChannelsCard(),
                      const SizedBox(height: 16),
                      _buildTopUsersCard(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopChannelsCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTopUsersCard()),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      _buildDayOfWeekCard(),
                      const SizedBox(height: 16),
                      _buildHourlyActivityCard(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDayOfWeekCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildHourlyActivityCard()),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _buildMembershipChangesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return BrandedCard(
      gradientColors: BrandColors.tileGradient,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Slack Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_summary?.computedAt != null)
                  Text(
                    'Last updated: ${dateFormat.format(_summary!.computedAt!.toLocal())}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
          // Time period selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedDays,
                dropdownColor: BrandColors.unityBlue,
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
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
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _refreshing ? null : _refreshAnalytics,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: BrandColors.unityBlue,
            ),
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrandColors.unityBlue,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_refreshing ? 'Refreshing...' : 'Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    // Gradient colors for each card
    const List<List<Color>> cardGradients = [
      [BrandColors.unityBlue, BrandColors.momentumBlue], // Messages
      [Color(0xFF10B981), Color(0xFF059669)], // Channels - Green
      [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Users - Purple
      [Color(0xFFF59E0B), Color(0xFFD97706)], // Unmatched - Amber
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardCount = isWide ? 4 : 2;
        final cardWidth =
            (constraints.maxWidth - (cardCount - 1) * 16) / cardCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _BrandedSummaryCard(
                title: 'Total Messages',
                value: _formatNumber(_summary?.totalMessagesAllTime ?? 0),
                subtitle:
                    '+${_formatNumber(_summary?.totalMessagesRecent ?? 0)} this period',
                icon: Icons.message,
                gradientColors: cardGradients[0],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _BrandedSummaryCard(
                title: 'Active Channels',
                value: '${_summary?.activeChannels ?? 0}',
                icon: Icons.tag,
                gradientColors: cardGradients[1],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _BrandedSummaryCard(
                title: 'Linked Users',
                value: '${_summary?.linkedUsers ?? 0}',
                icon: Icons.people,
                gradientColors: cardGradients[2],
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _BrandedSummaryCard(
                title: 'Unmatched Users',
                value: '${_summary?.unmatchedUsers ?? 0}',
                subtitle:
                    _summary?.unmatchedUsers != null &&
                        _summary!.unmatchedUsers > 0
                    ? 'Needs attention'
                    : null,
                icon: Icons.person_search,
                gradientColors:
                    _summary?.unmatchedUsers != null &&
                        _summary!.unmatchedUsers > 0
                    ? cardGradients[3]
                    : [Colors.grey.shade600, Colors.grey.shade500],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessagesOverTimeChart() {
    if (_messagesByDay.isEmpty) {
      return _buildEmptyCard(
        title: 'Messages Over Time',
        message: 'No message data available',
        icon: Icons.show_chart,
      );
    }

    // Find max for scaling
    final maxCount = _messagesByDay
        .map((e) => e.count)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    // Build spots for line chart
    final spots = _messagesByDay.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
    }).toList();

    return BrandedCard(
      gradientColors: BrandColors.tileGradient,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Messages Over Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxCount > 0 ? maxCount / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        _formatNumber(value.toInt()),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (_messagesByDay.length / 6).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _messagesByDay.length) {
                          final date = _messagesByDay[index].date;
                          // Show only month/day
                          final parts = date.split('-');
                          if (parts.length >= 2) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${parts[1]}/${parts.length > 2 ? parts[2] : ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_messagesByDay.length - 1).toDouble(),
                minY: 0,
                maxY: maxCount * 1.1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: BrandColors.sunriseGold,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          BrandColors.sunriseGold.withOpacity(0.3),
                          BrandColors.sunriseGold.withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => BrandColors.unityBlue,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.x.toInt();
                        final date = index < _messagesByDay.length
                            ? _messagesByDay[index].date
                            : '';
                        return LineTooltipItem(
                          '$date\n${spot.y.toInt()} messages',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopChannelsCard() {
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

    return BrandedCard(
      gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tag, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Most Active Channels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...topChannels.asMap().entries.map((entry) {
            final index = entry.key;
            final channel = entry.value;
            final barWidth = maxCount > 0
                ? (channel.messageCount / maxCount)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '#${channel.channelName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatNumber(channel.messageCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopUsersCard() {
    if (_userActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Most Active Users',
        message: 'No user data available',
        icon: Icons.people,
      );
    }

    final topUsers = _userActivity.take(5).toList();
    final maxCount = topUsers.isNotEmpty ? topUsers.first.messageCount : 1;

    return BrandedCard(
      gradientColors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Most Active Users',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...topUsers.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final barWidth = maxCount > 0
                ? (user.messageCount / maxCount)
                : 0.0;
            return InkWell(
              onTap: () => _handleUserTap(user),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: user.isLinked
                                ? Colors.white.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!user.isLinked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          _formatNumber(user.messageCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: barWidth,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          user.isLinked ? Colors.white : Colors.orange[300]!,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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
            builder: (context) =>
                TitleBarWrapper(child: MemberDetailScreen(member: member)),
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
    if (_dayOfWeekActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Activity by Day',
        message: 'No data available',
        icon: Icons.calendar_today,
      );
    }

    final maxCount = _dayOfWeekActivity
        .map((e) => e.messageCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return BrandedCard(
      gradientColors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Activity by Day',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount * 1.2,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => BrandColors.unityBlue,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = _dayOfWeekActivity[group.x.toInt()];
                      return BarTooltipItem(
                        '${day.dayName}\n${day.messageCount} messages',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _dayOfWeekActivity.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _dayOfWeekActivity[index].dayName.substring(0, 3),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _dayOfWeekActivity.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.messageCount.toDouble(),
                        color: Colors.white,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxCount * 1.2,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyActivityCard() {
    if (_hourlyActivity.isEmpty) {
      return _buildEmptyCard(
        title: 'Activity by Hour',
        message: 'No data available',
        icon: Icons.access_time,
      );
    }

    final maxCount = _hourlyActivity
        .map((e) => e.messageCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return BrandedCard(
      gradientColors: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Activity by Hour',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: BrandColors.sunriseGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Work hours',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount * 1.2,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => BrandColors.unityBlue,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final hour = _hourlyActivity[group.x.toInt()];
                      return BarTooltipItem(
                        '${hour.hourLabel}\n${hour.messageCount} messages',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 &&
                            index < _hourlyActivity.length &&
                            index % 4 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _hourlyActivity[index].hourLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _hourlyActivity.asMap().entries.map((entry) {
                  final isWorkHour =
                      entry.value.hour >= 9 && entry.value.hour <= 17;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.messageCount.toDouble(),
                        color: isWorkHour
                            ? BrandColors.sunriseGold
                            : Colors.white.withOpacity(0.7),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipChangesCard() {
    final dateFormat = DateFormat('MMM d • h:mm a');

    if (_membershipChanges.isEmpty) {
      return _buildEmptyCard(
        title: 'Recent Membership Changes',
        message: 'No recent changes',
        icon: Icons.people_alt,
      );
    }

    return BrandedCard(
      gradientColors: BrandColors.tileGradient,
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Membership Changes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Show all membership changes
          ...(_membershipChanges.map((change) {
            final isJoin =
                change.action == 'joined' || change.action == 'invited';
            return _buildMembershipChangeItem(change, isJoin, dateFormat);
          })),
        ],
      ),
    );
  }

  Widget _buildMembershipChangeItem(
    MembershipChange change,
    bool isJoin,
    DateFormat dateFormat,
  ) {
    return InkWell(
      onTap: () => _handleMembershipChangeTap(change),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
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
                      border: Border.all(color: Colors.white, width: 2),
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
                          style: const TextStyle(
                            color: Colors.white,
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
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.tag, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          change.channelDisplayName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isJoin
                        ? Colors.green.withOpacity(0.8)
                        : Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    change.action.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (change.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(change.createdAt!.toLocal()),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ],
            ),
            // Navigation indicator
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(MembershipChange change) {
    return CorsAwareAvatar(
      imageUrl: change.avatarUrl,
      radius: 20,
      backgroundColor: change.isLinkedMember
          ? Colors.white.withOpacity(0.3)
          : Colors.orange.withOpacity(0.5),
      fallbackText: change.displayName,
      fallbackIconColor: Colors.white,
      fallbackTextColor: Colors.white,
    );
  }

  Future<void> _handleMembershipChangeTap(MembershipChange change) async {
    if (change.isLinkedMember) {
      // Navigate to member profile
      final member = await _repository.getMemberById(change.memberId!);
      if (member != null && mounted) {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (context) =>
                TitleBarWrapper(child: MemberDetailScreen(member: member)),
          ),
        );
      }
    } else if (change.slackUserId != null) {
      // Show activity dialog for unmatched user
      final unmatchedUser = await _repository.getUnmatchedUserBySlackId(
        change.slackUserId!,
      );
      if (unmatchedUser != null && mounted) {
        await showDialog(
          context: context,
          builder: (context) => _UnmatchedUserQuickView(
            user: unmatchedUser,
            repository: _repository,
            onSwitchToUnmatchedTab: widget.onSwitchToUnmatchedTab,
          ),
        );
      } else if (widget.onSwitchToUnmatchedTab != null) {
        // Fallback to switching tabs if user not found
        widget.onSwitchToUnmatchedTab!();
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
    return BrandedCard(
      gradientColors: [Colors.grey.shade600, Colors.grey.shade500],
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 48, color: Colors.white54),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
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
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
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

/// Branded summary card widget for displaying a key metric with gradient
class _BrandedSummaryCard extends StatelessWidget {
  const _BrandedSummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return BrandedCard(
      gradientColors: gradientColors,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog to show messages from a specific Slack user and allow linking
/// Uses brand colors with light blue gradient background and navy gradient tiles
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
  State<_SlackUserMessagesDialog> createState() =>
      _SlackUserMessagesDialogState();
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
        widget.repository.getMessagesBySlackUserId(
          widget.slackUserId,
          limit: _pageSize,
        ),
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
          SnackBar(
            content: Text('Matched ${widget.userName} to ${result.name}'),
          ),
        );
        widget.onLinked?.call();
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 700,
          maxHeight: screenSize.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with navy gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.tileGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CorsAwareAvatar(
                    imageUrl: _unmatchedUser?.avatarUrl,
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    fallbackText: widget.userName,
                    fallbackTextColor: Colors.white,
                    fallbackIconColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Unmatched User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_unmatchedUser != null)
                    ElevatedButton.icon(
                      onPressed: _showMatchDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.sunriseGold,
                        foregroundColor: BrandColors.unityBlue,
                      ),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Link to Member'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Messages with light blue background
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: BrandColors.momentumBlue,
                      ),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 48,
                            color: BrandColors.unityBlue.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages found',
                            style: TextStyle(
                              color: BrandColors.unityBlue.withOpacity(0.7),
                              fontSize: 15,
                            ),
                          ),
                        ],
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
                                  ? const CircularProgressIndicator(
                                      color: BrandColors.momentumBlue,
                                    )
                                  : ElevatedButton(
                                      onPressed: _loadMore,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BrandColors.unityBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Load More'),
                                    ),
                            ),
                          );
                        }

                        return SlackMessageBubble(
                          message: _messages[index],
                          userMappings: _userMappings,
                          memberCache: _memberCache,
                          primaryColor: BrandColors.momentumBlue,
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
              Text('Link to Member', style: theme.textTheme.headlineSmall),
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

  Widget _buildMemberAvatar(Member member) {
    final photoUrl = member.primaryProfilePhotoUrl;
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';

    if (photoUrl == null) {
      return CircleAvatar(child: Text(initial));
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(backgroundImage: imageProvider),
      placeholder: (context, url) => CircleAvatar(
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(child: Text(initial)),
    );
  }
}

/// Quick view dialog for unmatched user from membership changes
/// Uses brand colors with light blue gradient background and navy gradient tiles
class _UnmatchedUserQuickView extends StatefulWidget {
  const _UnmatchedUserQuickView({
    required this.user,
    required this.repository,
    this.onSwitchToUnmatchedTab,
  });

  final SlackUnmatchedUser user;
  final SlackManagementRepository repository;
  final VoidCallback? onSwitchToUnmatchedTab;

  @override
  State<_UnmatchedUserQuickView> createState() =>
      _UnmatchedUserQuickViewState();
}

class _UnmatchedUserQuickViewState extends State<_UnmatchedUserQuickView> {
  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, String>> _userMappings = {};
  bool _loading = true;
  static const int _previewLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final results = await Future.wait([
        widget.repository.getMessagesBySlackUserId(
          widget.user.slackUserId,
          limit: _previewLimit,
        ),
        widget.repository.getSlackUserMappings(),
      ]);

      if (!mounted) return;

      setState(() {
        _messages = results[0] as List<Map<String, dynamic>>;
        _userMappings = results[1] as Map<String, Map<String, String>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 450,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: BrandColors.backgroundGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with navy gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.tileGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CorsAwareAvatar(
                    imageUrl: widget.user.avatarUrl,
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    fallbackText: widget.user.primaryLabel,
                    fallbackIconColor: Colors.white,
                    fallbackTextColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.primaryLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: BrandColors.sunriseGold.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Unmatched User',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info in navy tiles
                  if (widget.user.email != null && widget.user.email!.isNotEmpty)
                    _buildInfoTile(Icons.email, 'Email', widget.user.email!),
                  if (widget.user.usernameDisplay != null)
                    _buildInfoTile(
                      Icons.alternate_email,
                      'Username',
                      widget.user.usernameDisplay!,
                    ),
                  const SizedBox(height: 16),
                  // Recent messages header
                  const Text(
                    'Recent Messages',
                    style: TextStyle(
                      color: BrandColors.unityBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Messages in navy tiles with parsed formatting
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: BrandColors.momentumBlue,
                        ),
                      ),
                    )
                  else if (_messages.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: BrandColors.tileGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'No messages found',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  else
                    ...(_messages.take(3).map((msg) => _buildMessageTile(msg))),
                ],
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.unityBlue,
                    ),
                    child: const Text('Close'),
                  ),
                  if (widget.onSwitchToUnmatchedTab != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSwitchToUnmatchedTab!();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.unityBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Match User'),
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

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> msg) {
    final text = msg['message_text']?.toString() ?? '';
    final postedAtStr = msg['posted_at']?.toString();
    final postedAt = postedAtStr != null ? DateTime.tryParse(postedAtStr) : null;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (postedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                dateFormat.format(postedAt.toLocal()),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ),
          // Parse Slack formatting for the message text
          if (text.isNotEmpty)
            _buildFormattedMessage(text)
          else
            const Text(
              '[No text content]',
              style: TextStyle(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(String text) {
    // Use SlackMessageFormatter to parse the message
    final spans = SlackMessageFormatter.parse(
      text,
      baseStyle: const TextStyle(color: Colors.white, fontSize: 13),
      linkColor: BrandColors.sunriseGold,
      mentionColor: Colors.white,
      userMappings: _userMappings,
    );

    if (spans.isEmpty) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
