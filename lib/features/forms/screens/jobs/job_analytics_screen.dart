import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job Analytics'),
            Text(
              widget.job.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Member Engagement', icon: Icon(Icons.people_outline)),
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
            // Key Metrics Grid
            _buildKeyMetricsSection(theme),
            const SizedBox(height: 24),

            // Daily Views Chart
            _buildDailyViewsSection(theme),
            const SizedBox(height: 24),

            // Event Breakdown
            _buildEventBreakdownSection(theme),
            const SizedBox(height: 24),

            // Device & Browser Breakdown
            _buildBreakdownCardsRow(theme),
            const SizedBox(height: 24),

            // Recent Activity
            _buildRecentActivitySection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              theme,
              icon: Icons.visibility_outlined,
              value: '${_summary!.totalViews}',
              label: 'Total Views',
              color: Colors.blue,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.people_outline,
              value: '${_summary!.uniqueViewers}',
              label: 'Unique Viewers',
              color: Colors.indigo,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.touch_app_outlined,
              value: '${_summary!.applyClicks}',
              label: 'Apply Clicks',
              color: Colors.orange,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.assignment_turned_in_outlined,
              value: '${_summary!.applications}',
              label: 'Applications',
              color: Colors.green,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.timer_outlined,
              value: _summary!.formattedAvgTime,
              label: 'Avg. Time',
              color: Colors.purple,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.trending_up,
              value: _summary!.formattedClickThroughRate,
              label: 'Click Rate',
              color: Colors.teal,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.share_outlined,
              value: '${_summary!.shares}',
              label: 'Shares',
              color: Colors.cyan,
            ),
            _buildMetricCard(
              theme,
              icon: Icons.swap_vert,
              value: '${_summary!.maxScrollDepth}%',
              label: 'Max Scroll',
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyViewsSection(ThemeData theme) {
    if (_dailyViews.isEmpty) return const SizedBox.shrink();

    final maxViews = _dailyViews.fold<int>(
      1,
      (max, item) => (item['count'] as int) > max ? item['count'] as int : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Views (Last 14 Days)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _dailyViews.map((item) {
                  final count = item['count'] as int;
                  final height = maxViews > 0 ? (count / maxViews) * 100 : 0.0;

                  return Expanded(
                    child: Tooltip(
                      message: '${item['date']}: $count views',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: height.clamp(4.0, 100.0),
                        decoration: BoxDecoration(
                          color: count > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
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
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  _dailyViews.isNotEmpty
                      ? _formatDateShort(_dailyViews.last['date'] as String)
                      : '',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildEventBreakdownSection(ThemeData theme) {
    if (_eventCounts.isEmpty) return const SizedBox.shrink();

    final sortedEvents = _eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Event Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedEvents.take(8).map((entry) {
              final total = _eventCounts.values.fold<int>(0, (a, b) => a + b);
              final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        _getEventLabel(entry.key),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${entry.value}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
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

  String _getEventLabel(String eventType) {
    switch (eventType) {
      case 'view':
        return 'Page Views';
      case 'view_end':
        return 'View Ended';
      case 'apply_click':
        return 'Apply Clicks';
      case 'apply_external':
        return 'External Apply';
      case 'apply_start':
        return 'Started Apply';
      case 'apply_submit':
        return 'Submitted';
      case 'share':
        return 'Shares';
      case 'scroll_depth':
        return 'Scroll Events';
      case 'copy_text':
        return 'Text Copied';
      case 'print':
        return 'Printed';
      default:
        return eventType;
    }
  }

  Widget _buildBreakdownCardsRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildBreakdownCard(
            theme,
            title: 'Devices',
            icon: Icons.devices,
            data: _summary?.deviceCounts ?? {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBreakdownCard(
            theme,
            title: 'Browsers',
            icon: Icons.web,
            data: _summary?.browserCounts ?? {},
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Map<String, int> data,
  }) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Text(
                'No data',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...sorted.take(5).map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildRecentActivitySection(ThemeData theme) {
    if (_recentEvents.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_recentEvents.take(10).map((event) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _getEventColor(event.eventType).withOpacity(0.1),
                  child: Icon(
                    _getEventIcon(event.eventType),
                    size: 16,
                    color: _getEventColor(event.eventType),
                  ),
                ),
                title: Text(
                  event.eventTypeLabel,
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  '${event.locationDescription} • ${event.deviceDescription}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  DateFormat.MMMd().add_jm().format(event.createdAt),
                  style: theme.textTheme.labelSmall,
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'view':
        return Icons.visibility;
      case 'apply_click':
      case 'apply_start':
        return Icons.touch_app;
      case 'apply_submit':
        return Icons.check_circle;
      case 'apply_external':
        return Icons.open_in_new;
      case 'share':
        return Icons.share;
      case 'scroll_depth':
        return Icons.swap_vert;
      case 'copy_text':
        return Icons.content_copy;
      case 'print':
        return Icons.print;
      default:
        return Icons.event;
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
          return _buildMemberCard(theme, interaction, index + 1);
        },
      ),
    );
  }

  Widget _buildMemberCard(ThemeData theme, JobMemberInteraction interaction, int rank) {
    final colorScheme = theme.colorScheme;
    final engagementColor = _getEngagementColor(interaction.engagementLevel);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Text(
                '${interaction.memberId.substring(0, 2).toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (rank <= 3)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey[400]
                            : Colors.orange[300],
                    shape: BoxShape.circle,
                  ),
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
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Member #${interaction.memberId.substring(0, 8)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: engagementColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: engagementColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, size: 14, color: engagementColor),
                  const SizedBox(width: 4),
                  Text(
                    '${interaction.engagementScore}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: engagementColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (interaction.locationDescription != 'Unknown location')
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    interaction.locationDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            // Quick stats row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildQuickStat(theme, Icons.visibility, '${interaction.viewCount}'),
                _buildQuickStat(theme, Icons.timer, interaction.formattedTotalTime),
                _buildQuickStat(theme, Icons.swap_vert, '${interaction.maxScrollDepthPercent}%'),
                if (interaction.hasApplied)
                  _buildQuickStat(theme, Icons.check_circle, 'Applied', highlight: true),
                if (interaction.hasClickedApply && !interaction.hasApplied)
                  _buildQuickStat(theme, Icons.touch_app, 'Clicked'),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildMemberDetailContent(theme, interaction),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(ThemeData theme, IconData icon, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.green.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: highlight ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? Colors.green : theme.colorScheme.onSurfaceVariant,
              fontWeight: highlight ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberDetailContent(ThemeData theme, JobMemberInteraction interaction) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Actions Timeline
        Text(
          'Actions',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildActionRow(
          theme,
          icon: Icons.visibility,
          label: 'First viewed',
          value: interaction.firstViewedAt != null
              ? DateFormat.yMMMd().add_jm().format(interaction.firstViewedAt!)
              : 'Never',
          isActive: interaction.hasViewed,
        ),
        _buildActionRow(
          theme,
          icon: Icons.visibility,
          label: 'Last viewed',
          value: interaction.lastViewedAt != null
              ? DateFormat.yMMMd().add_jm().format(interaction.lastViewedAt!)
              : 'Never',
          isActive: interaction.hasViewed,
        ),
        if (interaction.hasClickedApply)
          _buildActionRow(
            theme,
            icon: Icons.touch_app,
            label: 'Clicked apply',
            value: interaction.applyClickedAt != null
                ? DateFormat.yMMMd().add_jm().format(interaction.applyClickedAt!)
                : 'Yes',
            isActive: true,
          ),
        if (interaction.hasApplied)
          _buildActionRow(
            theme,
            icon: Icons.check_circle,
            label: 'Applied',
            value: interaction.appliedAt != null
                ? DateFormat.yMMMd().add_jm().format(interaction.appliedAt!)
                : 'Yes',
            isActive: true,
            highlight: true,
          ),
        if (interaction.hasShared)
          _buildActionRow(
            theme,
            icon: Icons.share,
            label: 'Shared',
            value: interaction.sharedAt != null
                ? DateFormat.yMMMd().add_jm().format(interaction.sharedAt!)
                : 'Yes',
            isActive: true,
          ),

        const Divider(height: 24),

        // Engagement Metrics
        Text(
          'Engagement Metrics',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDetailMetric(
                theme,
                label: 'Total Views',
                value: '${interaction.viewCount}',
                icon: Icons.visibility_outlined,
              ),
            ),
            Expanded(
              child: _buildDetailMetric(
                theme,
                label: 'Sessions',
                value: '${interaction.sessionCount}',
                icon: Icons.login,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDetailMetric(
                theme,
                label: 'Total Time',
                value: interaction.formattedTotalTime,
                icon: Icons.timer_outlined,
              ),
            ),
            Expanded(
              child: _buildDetailMetric(
                theme,
                label: 'Avg Session',
                value: interaction.formattedAvgSession,
                icon: Icons.schedule,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDetailMetric(
                theme,
                label: 'Max Scroll',
                value: '${interaction.maxScrollDepthPercent}%',
                icon: Icons.swap_vert,
              ),
            ),
            Expanded(
              child: _buildDetailMetric(
                theme,
                label: 'Active Time',
                value: _formatSeconds(interaction.totalActiveTimeSeconds),
                icon: Icons.mouse,
              ),
            ),
          ],
        ),

        if (interaction.lastBrowser != null || interaction.lastOs != null) ...[
          const Divider(height: 24),
          Text(
            'Device Info',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (interaction.lastBrowser != null)
            _buildInfoRow(theme, Icons.web, 'Browser', interaction.lastBrowser!),
          if (interaction.lastOs != null)
            _buildInfoRow(theme, Icons.computer, 'OS', interaction.lastOs!),
          if (interaction.lastDeviceType != null)
            _buildInfoRow(theme, Icons.devices, 'Device', interaction.lastDeviceType!),
          if (interaction.browsersUsed.isNotEmpty)
            _buildInfoRow(
              theme,
              Icons.list,
              'All Browsers',
              interaction.browsersUsed.join(', '),
            ),
          if (interaction.devicesUsed.isNotEmpty)
            _buildInfoRow(
              theme,
              Icons.list,
              'All Devices',
              interaction.devicesUsed.join(', '),
            ),
        ],

        if (interaction.firstReferrerDomain != null || interaction.firstUtmSource != null) ...[
          const Divider(height: 24),
          Text(
            'Attribution',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (interaction.firstReferrerDomain != null)
            _buildInfoRow(theme, Icons.link, 'Referrer', interaction.firstReferrerDomain!),
          if (interaction.firstUtmSource != null)
            _buildInfoRow(theme, Icons.campaign, 'UTM Source', interaction.firstUtmSource!),
          if (interaction.firstUtmMedium != null)
            _buildInfoRow(theme, Icons.category, 'UTM Medium', interaction.firstUtmMedium!),
          if (interaction.firstUtmCampaign != null)
            _buildInfoRow(theme, Icons.flag, 'UTM Campaign', interaction.firstUtmCampaign!),
        ],
      ],
    );
  }

  Widget _buildActionRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    bool highlight = false,
  }) {
    final color = highlight
        ? Colors.green
        : isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: highlight ? FontWeight.bold : null,
                color: highlight ? Colors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data will appear when members interact with this job',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
