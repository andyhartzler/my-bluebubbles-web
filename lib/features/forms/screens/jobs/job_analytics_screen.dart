import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/job.dart';
import '../../models/job_analytics.dart';
import '../../services/jobs_service.dart';

class JobAnalyticsScreen extends StatefulWidget {
  final Job job;
  final int initialTab;

  const JobAnalyticsScreen({
    super.key,
    required this.job,
    this.initialTab = 0,
  });

  @override
  State<JobAnalyticsScreen> createState() => _JobAnalyticsScreenState();
}

class _JobAnalyticsScreenState extends State<JobAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final _jobsService = JobsService();
  late TabController _tabController;

  bool _isLoading = true;
  JobAnalyticsSummary? _summary;
  List<JobMemberInteraction> _interactions = [];
  List<JobAnalyticsEvent> _recentEvents = [];
  Map<String, int> _eventCounts = {};
  List<Map<String, dynamic>> _dailyViews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _jobsService.getJobAnalyticsSummary(widget.job.id),
        _jobsService.getJobMemberInteractions(widget.job.id, limit: 100),
        _jobsService.getJobAnalyticsEvents(widget.job.id, limit: 50),
        _jobsService.getEventCountsByType(widget.job.id),
        _jobsService.getDailyViewCounts(widget.job.id, days: 14),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as JobAnalyticsSummary;
          _interactions = results[1] as List<JobMemberInteraction>;
          _recentEvents = results[2] as List<JobAnalyticsEvent>;
          _eventCounts = results[3] as Map<String, int>;
          _dailyViews = results[4] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analytics'),
            Text(
              widget.job.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme),
                _buildMemberEngagementTab(theme),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    if (_summary == null) {
      return _buildEmptyState(theme, 'No analytics data yet');
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Hero Stats Row
            _buildHeroStatsRow(theme),
            const SizedBox(height: 20),

            // Engagement Funnel
            _buildEngagementFunnel(theme),
            const SizedBox(height: 20),

            // Activity Sparkline
            _buildActivitySparkline(theme),
            const SizedBox(height: 20),

            // Quick Breakdown Row
            _buildQuickBreakdownRow(theme),
            const SizedBox(height: 20),

            // Recent Activity Timeline
            _buildRecentActivityTimeline(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatsRow(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  theme,
                  value: '${_summary!.totalViews}',
                  label: 'Views',
                  icon: Icons.visibility_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _buildHeroStat(
                  theme,
                  value: '${_summary!.uniqueViewers}',
                  label: 'Unique',
                  icon: Icons.people_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _buildHeroStat(
                  theme,
                  value: '${_summary!.applyClicks}',
                  label: 'Clicks',
                  icon: Icons.touch_app_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _buildHeroStat(
                  theme,
                  value: '${_summary!.applications}',
                  label: 'Applied',
                  icon: Icons.check_circle_rounded,
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecondaryMetric(
                theme,
                label: 'Avg Time',
                value: _summary!.formattedAvgTime,
                icon: Icons.timer_outlined,
              ),
              _buildSecondaryMetric(
                theme,
                label: 'CTR',
                value: _summary!.formattedClickThroughRate,
                icon: Icons.trending_up_rounded,
              ),
              _buildSecondaryMetric(
                theme,
                label: 'Shares',
                value: '${_summary!.shares}',
                icon: Icons.share_rounded,
              ),
              _buildSecondaryMetric(
                theme,
                label: 'Max Scroll',
                value: '${_summary!.maxScrollDepth}%',
                icon: Icons.expand_more_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(
    ThemeData theme, {
    required String value,
    required String label,
    required IconData icon,
    bool highlight = false,
  }) {
    final colorScheme = theme.colorScheme;
    final color = highlight ? Colors.green : colorScheme.onPrimaryContainer;

    return Column(
      children: [
        Icon(icon, size: 20, color: color.withOpacity(0.7)),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryMetric(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: colorScheme.onPrimaryContainer.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimaryContainer.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementFunnel(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final views = _summary!.totalViews;
    final clicks = _summary!.applyClicks;
    final apps = _summary!.applications;

    // Calculate percentages
    final clickPct = views > 0 ? (clicks / views * 100) : 0.0;
    final appPct = clicks > 0 ? (apps / clicks * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Conversion Funnel',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFunnelStep(
            theme,
            label: 'Views',
            count: views,
            percentage: 100,
            color: Colors.blue,
            isFirst: true,
          ),
          _buildFunnelConnector(theme, percentage: clickPct),
          _buildFunnelStep(
            theme,
            label: 'Apply Clicks',
            count: clicks,
            percentage: clickPct,
            color: Colors.orange,
          ),
          _buildFunnelConnector(theme, percentage: appPct),
          _buildFunnelStep(
            theme,
            label: 'Applications',
            count: apps,
            percentage: appPct,
            color: Colors.green,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep(
    ThemeData theme, {
    required String label,
    required int count,
    required double percentage,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final width = (percentage / 100).clamp(0.3, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 32,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            isFirst ? '100%' : '${percentage.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildFunnelConnector(ThemeData theme, {required double percentage}) {
    return Padding(
      padding: const EdgeInsets.only(left: 100),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 16,
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 14,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySparkline(ThemeData theme) {
    if (_dailyViews.isEmpty) return const SizedBox.shrink();

    final colorScheme = theme.colorScheme;
    final maxViews = _dailyViews.fold<int>(
      1,
      (max, item) => (item['count'] as int) > max ? item['count'] as int : max,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Activity (14 Days)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${_dailyViews.fold<int>(0, (sum, item) => sum + (item['count'] as int))} total views',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _dailyViews.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final count = item['count'] as int;
                final height = maxViews > 0 ? (count / maxViews) * 52 : 0.0;
                final isToday = index == _dailyViews.length - 1;

                return Expanded(
                  child: Tooltip(
                    message: '${item['date']}: $count views',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: height.clamp(4.0, 52.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isToday
                              ? [colorScheme.primary, colorScheme.primary.withOpacity(0.7)]
                              : count > 0
                                  ? [colorScheme.primaryContainer, colorScheme.primaryContainer.withOpacity(0.7)]
                                  : [colorScheme.surfaceContainerHighest, colorScheme.surfaceContainerHighest],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
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
                _dailyViews.isNotEmpty
                    ? _formatDateShort(_dailyViews.first['date'] as String)
                    : '',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Today',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateShort(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat.MMMd().format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildQuickBreakdownRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactBreakdownCard(
            theme,
            title: 'Devices',
            icon: Icons.devices_rounded,
            data: _summary?.deviceCounts ?? {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCompactBreakdownCard(
            theme,
            title: 'Browsers',
            icon: Icons.web_rounded,
            data: _summary?.browserCounts ?? {},
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBreakdownCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Map<String, int> data,
  }) {
    final colorScheme = theme.colorScheme;
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text(
              'No data',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...sorted.take(3).map((entry) {
              final pct = total > 0 ? (entry.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
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

  Widget _buildRecentActivityTimeline(ThemeData theme) {
    if (_recentEvents.isEmpty) return const SizedBox.shrink();

    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Activity',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(_recentEvents.take(5).map((event) {
            return _buildTimelineEvent(theme, event);
          })),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(ThemeData theme, JobAnalyticsEvent event) {
    final colorScheme = theme.colorScheme;
    final color = _getEventColor(event.eventType);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getEventIcon(event.eventType),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventTypeLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${event.city ?? 'Unknown'}, ${event.region ?? ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(event.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dateTime);
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'view':
        return Icons.visibility_rounded;
      case 'apply_click':
      case 'apply_start':
        return Icons.touch_app_rounded;
      case 'apply_submit':
        return Icons.check_circle_rounded;
      case 'apply_external':
        return Icons.open_in_new_rounded;
      case 'share':
        return Icons.share_rounded;
      case 'scroll_depth':
        return Icons.expand_more_rounded;
      case 'copy_text':
        return Icons.content_copy_rounded;
      case 'print':
        return Icons.print_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'view':
        return Colors.blue;
      case 'apply_click':
      case 'apply_start':
        return Colors.orange;
      case 'apply_submit':
        return Colors.green;
      case 'apply_external':
        return Colors.purple;
      case 'share':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  // ============================================================================
  // MEMBER ENGAGEMENT TAB
  // ============================================================================

  Widget _buildMemberEngagementTab(ThemeData theme) {
    if (_interactions.isEmpty) {
      return _buildEmptyState(theme, 'No member engagement data yet');
    }

    // Sort by engagement score
    final sorted = List<JobMemberInteraction>.from(_interactions)
      ..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final interaction = sorted[index];
          return _buildMemberEngagementCard(theme, interaction, index + 1);
        },
      ),
    );
  }

  Widget _buildMemberEngagementCard(
    ThemeData theme,
    JobMemberInteraction interaction,
    int rank,
  ) {
    final colorScheme = theme.colorScheme;
    final engagementColor = _getEngagementColor(interaction.engagementLevel);
    final isTopThree = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isTopThree
              ? engagementColor.withOpacity(0.3)
              : colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        leading: _buildMemberAvatar(theme, interaction, rank),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interaction.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (interaction.memberHomeLocation != null ||
                      interaction.locationDescription != 'Unknown location')
                    Text(
                      interaction.memberHomeLocation ??
                          interaction.locationDescription,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _buildEngagementBadge(theme, interaction),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildQuickActions(theme, interaction),
        ),
        children: [
          _buildMemberDetailContent(theme, interaction),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(
    ThemeData theme,
    JobMemberInteraction interaction,
    int rank,
  ) {
    final colorScheme = theme.colorScheme;
    final isTopThree = rank <= 3;

    Widget avatar;
    if (interaction.hasProfilePhoto) {
      avatar = CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(
          interaction.memberProfilePhotoUrl!,
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
      );
    } else {
      avatar = CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          interaction.initials,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    if (!isTopThree) return avatar;

    // Add rank badge for top 3
    final badgeColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey[400]!
            : Colors.orange[300]!;

    return Stack(
      children: [
        avatar,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementBadge(ThemeData theme, JobMemberInteraction interaction) {
    final color = _getEngagementColor(interaction.engagementLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            interaction.engagementLevel == 'High'
                ? Icons.local_fire_department_rounded
                : interaction.engagementLevel == 'Medium'
                    ? Icons.trending_up_rounded
                    : Icons.remove_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${interaction.engagementScore}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, JobMemberInteraction interaction) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionChip(
            theme,
            icon: Icons.visibility_rounded,
            label: '${interaction.viewCount}',
            tooltip: 'Views',
          ),
          const SizedBox(width: 6),
          _buildActionChip(
            theme,
            icon: Icons.timer_rounded,
            label: interaction.formattedTotalTime,
            tooltip: 'Time spent',
          ),
          const SizedBox(width: 6),
          _buildActionChip(
            theme,
            icon: Icons.expand_more_rounded,
            label: '${interaction.maxScrollDepthPercent}%',
            tooltip: 'Scroll depth',
          ),
          if (interaction.hasApplied) ...[
            const SizedBox(width: 6),
            _buildActionChip(
              theme,
              icon: Icons.check_circle_rounded,
              label: 'Applied',
              color: Colors.green,
            ),
          ],
          if (interaction.hasClickedApply && !interaction.hasApplied) ...[
            const SizedBox(width: 6),
            _buildActionChip(
              theme,
              icon: Icons.touch_app_rounded,
              label: 'Clicked',
              color: Colors.orange,
            ),
          ],
          if (interaction.hasShared) ...[
            const SizedBox(width: 6),
            _buildActionChip(
              theme,
              icon: Icons.share_rounded,
              label: 'Shared',
              color: Colors.cyan,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    String? tooltip,
    Color? color,
  }) {
    final colorScheme = theme.colorScheme;
    final chipColor = color ?? colorScheme.onSurfaceVariant;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null
            ? color.withOpacity(0.1)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: color != null
            ? Border.all(color: color.withOpacity(0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
              color: chipColor,
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }

  Widget _buildMemberDetailContent(ThemeData theme, JobMemberInteraction interaction) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),

        // Journey Timeline
        Text(
          'Activity Timeline',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildJourneyTimeline(theme, interaction),

        const SizedBox(height: 20),

        // Engagement Metrics
        Text(
          'Engagement Details',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        _buildEngagementMetricsGrid(theme, interaction),

        if (interaction.lastBrowser != null || interaction.lastOs != null) ...[
          const SizedBox(height: 20),
          Text(
            'Device & Tech',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDeviceInfo(theme, interaction),
        ],

        if (interaction.firstReferrerDomain != null ||
            interaction.firstUtmSource != null) ...[
          const SizedBox(height: 20),
          Text(
            'Attribution',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildAttributionInfo(theme, interaction),
        ],
      ],
    );
  }

  Widget _buildJourneyTimeline(ThemeData theme, JobMemberInteraction interaction) {
    final colorScheme = theme.colorScheme;
    final steps = <_JourneyStep>[];

    if (interaction.firstViewedAt != null) {
      steps.add(_JourneyStep(
        icon: Icons.visibility_rounded,
        label: 'First View',
        time: interaction.firstViewedAt!,
        color: Colors.blue,
      ));
    }

    if (interaction.lastViewedAt != null &&
        interaction.lastViewedAt != interaction.firstViewedAt) {
      steps.add(_JourneyStep(
        icon: Icons.visibility_rounded,
        label: 'Last View',
        time: interaction.lastViewedAt!,
        color: Colors.blue.shade300,
      ));
    }

    if (interaction.applyClickedAt != null) {
      steps.add(_JourneyStep(
        icon: Icons.touch_app_rounded,
        label: 'Clicked Apply',
        time: interaction.applyClickedAt!,
        color: Colors.orange,
      ));
    }

    if (interaction.appliedAt != null) {
      steps.add(_JourneyStep(
        icon: Icons.check_circle_rounded,
        label: 'Submitted Application',
        time: interaction.appliedAt!,
        color: Colors.green,
      ));
    }

    if (interaction.sharedAt != null) {
      steps.add(_JourneyStep(
        icon: Icons.share_rounded,
        label: 'Shared',
        time: interaction.sharedAt!,
        color: Colors.cyan,
      ));
    }

    steps.sort((a, b) => a.time.compareTo(b.time));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          return _buildTimelineStep(theme, step, isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineStep(ThemeData theme, _JourneyStep step, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(step.icon, size: 14, color: step.color),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 16,
                  color: theme.colorScheme.outlineVariant,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(step.time),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetricsGrid(ThemeData theme, JobMemberInteraction interaction) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildMetricTile(theme, 'Views', '${interaction.viewCount}', Icons.visibility_outlined),
        _buildMetricTile(theme, 'Sessions', '${interaction.sessionCount}', Icons.login_rounded),
        _buildMetricTile(theme, 'Total Time', interaction.formattedTotalTime, Icons.timer_outlined),
        _buildMetricTile(theme, 'Avg Session', interaction.formattedAvgSession, Icons.schedule_rounded),
        _buildMetricTile(theme, 'Max Scroll', '${interaction.maxScrollDepthPercent}%', Icons.expand_more_rounded),
        _buildMetricTile(theme, 'Active Time', _formatSeconds(interaction.totalActiveTimeSeconds), Icons.mouse_rounded),
        if (interaction.externalApplyClicks > 0)
          _buildMetricTile(theme, 'External Clicks', '${interaction.externalApplyClicks}', Icons.open_in_new_rounded),
      ],
    );
  }

  Widget _buildMetricTile(ThemeData theme, String label, String value, IconData icon) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo(ThemeData theme, JobMemberInteraction interaction) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (interaction.lastBrowser != null)
            _buildInfoRow(theme, Icons.web_rounded, 'Browser', interaction.lastBrowser!),
          if (interaction.lastOs != null)
            _buildInfoRow(theme, Icons.computer_rounded, 'OS', interaction.lastOs!),
          if (interaction.lastDeviceType != null)
            _buildInfoRow(theme, Icons.devices_rounded, 'Device', interaction.lastDeviceType!),
          if (interaction.browsersUsed.isNotEmpty && interaction.browsersUsed.length > 1)
            _buildInfoRow(theme, Icons.list_rounded, 'All Browsers', interaction.browsersUsed.join(', ')),
        ],
      ),
    );
  }

  Widget _buildAttributionInfo(ThemeData theme, JobMemberInteraction interaction) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (interaction.firstReferrerDomain != null)
            _buildInfoRow(theme, Icons.link_rounded, 'Referrer', interaction.firstReferrerDomain!),
          if (interaction.firstUtmSource != null)
            _buildInfoRow(theme, Icons.campaign_rounded, 'UTM Source', interaction.firstUtmSource!),
          if (interaction.firstUtmMedium != null)
            _buildInfoRow(theme, Icons.category_rounded, 'UTM Medium', interaction.firstUtmMedium!),
          if (interaction.firstUtmCampaign != null)
            _buildInfoRow(theme, Icons.flag_rounded, 'UTM Campaign', interaction.firstUtmCampaign!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  Color _getEngagementColor(String level) {
    switch (level) {
      case 'High':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 40,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics will appear when members\ninteract with this job listing',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyStep {
  final IconData icon;
  final String label;
  final DateTime time;
  final Color color;

  _JourneyStep({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });
}
