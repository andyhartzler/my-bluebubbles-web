import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import '../../models/job.dart';
import '../../models/job_analytics.dart';
import '../../models/job_notification_log.dart';
import '../../services/jobs_service.dart';
import '../../widgets/job_analytics_map.dart';
import 'job_builder_screen.dart';
import 'job_applicants_screen.dart';

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

  // Current job (may be updated after edit)
  late Job _job;

  bool _isLoading = true;
  JobAnalyticsSummary? _summary;
  List<JobMemberInteraction> _interactions = [];
  List<JobAnalyticsEvent> _recentEvents = [];
  Map<String, int> _eventCounts = {};
  List<Map<String, dynamic>> _dailyViews = [];
  List<JobViewLocation> _viewLocations = [];

  // Job details state
  int _applicationCount = 0;

  // Notifications state
  List<JobNotificationLog> _notificationLogs = [];
  bool _loadingLogs = false;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAnalytics(),
      _loadApplicationCount(),
      _loadNotificationLogs(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshJob() async {
    try {
      final job = await _jobsService.getJob(_job.id);
      if (mounted) {
        setState(() => _job = job);
      }
    } catch (_) {}
  }

  Future<void> _loadAnalytics() async {
    try {
      final results = await Future.wait([
        _jobsService.getJobAnalyticsSummary(_job.id),
        _jobsService.getJobMemberInteractions(_job.id, limit: 100),
        _jobsService.getJobAnalyticsEvents(_job.id, limit: 50),
        _jobsService.getEventCountsByType(_job.id),
        _jobsService.getDailyViewCounts(_job.id, days: 14),
        _jobsService.getJobViewLocations(_job.id),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as JobAnalyticsSummary;
          _interactions = results[1] as List<JobMemberInteraction>;
          _recentEvents = results[2] as List<JobAnalyticsEvent>;
          _eventCounts = results[3] as Map<String, int>;
          _dailyViews = results[4] as List<Map<String, dynamic>>;
          _viewLocations = results[5] as List<JobViewLocation>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    }
  }

  Future<void> _loadApplicationCount() async {
    try {
      final count = await _jobsService.getApplicationCount(_job.id);
      if (mounted) {
        setState(() => _applicationCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadNotificationLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final logs = await _jobsService.getNotificationLogsForJob(_job.id);
      if (mounted) {
        setState(() {
          _notificationLogs = logs;
          _loadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLogs = false);
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
            Text(_job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _job.organization,
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
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInBrowser,
            tooltip: 'View on Website',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
            Tab(text: 'Job Details'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOverviewTab(theme),
                _buildMemberEngagementTab(theme),
                _buildJobDetailsTab(theme),
                _buildNotificationsTab(theme),
              ],
            ),
    );
  }

  void _openInBrowser() async {
    final url = 'https://moyd.org/jobs/${_job.slug ?? _job.id}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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

            // View Locations Map
            _buildViewLocationsMap(theme),
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

  Widget _buildViewLocationsMap(ThemeData theme) {
    return JobAnalyticsMap(
      locations: _viewLocations,
      height: 300,
      onLocationTap: (location) {
        _showLocationMembersSheet(location);
      },
    );
  }

  void _showLocationMembersSheet(JobViewLocation location) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.locationName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${location.viewCount} views from ${location.members.length} ${location.members.length == 1 ? 'member' : 'members'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Members list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: location.members.length,
                  itemBuilder: (context, index) {
                    final member = location.members[index];
                    return _buildLocationMemberTile(member, theme);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationMemberTile(dynamic member, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final photoUrl = member.profilePhotos.isNotEmpty
        ? member.profilePhotos.first.publicUrl
        : null;

    return ListTile(
      leading: photoUrl != null
          ? CircleAvatar(
              radius: 22,
              backgroundImage: CachedNetworkImageProvider(photoUrl),
              backgroundColor: colorScheme.surfaceContainerHighest,
            )
          : CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                _getInitials(member.name ?? member.email ?? ''),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
      title: Text(
        member.name ?? member.email ?? 'Unknown Member',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: member.email != null && member.name != null
          ? Text(
              member.email!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.outline,
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
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
        // View Member button at the top
        if (interaction.memberId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _navigateToMemberProfile(interaction.memberId!),
                icon: const Icon(Icons.person, size: 18),
                label: const Text('View Member Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

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

  // ============================================================================
  // JOB DETAILS TAB
  // ============================================================================

  Widget _buildJobDetailsTab(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _refreshJob,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Edit Button at top
            FilledButton.tonalIcon(
              onPressed: () => _editJob(),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Job Details'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 20),

            // Title and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _job.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(_job.status),
              ],
            ),
            const SizedBox(height: 8),

            // Organization
            Text(
              _job.organization,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(_job.jobType, Colors.blue, Icons.work_outline),
                if (_job.locationType != null)
                  _buildChip(_job.locationType!, Colors.green, Icons.laptop_mac),
                if (_job.isPaid)
                  _buildChip('Paid', Colors.purple, Icons.attach_money),
                if (_job.featured)
                  _buildChip('Featured', Colors.amber, Icons.star),
              ],
            ),
            const SizedBox(height: 24),

            // Applicants Summary
            _buildApplicantsSummaryCard(theme),
            const SizedBox(height: 16),

            // Location
            if (_job.location != null) ...[
              _buildSectionCard(theme, 'Location', _job.location!, Icons.location_on_outlined),
              const SizedBox(height: 16),
            ],

            // Description
            _buildSectionCard(theme, 'Description', _job.description, Icons.description_outlined),
            const SizedBox(height: 16),

            // Custom Questions
            if (_job.customQuestions.isNotEmpty) ...[
              _buildCustomQuestionsCard(theme),
              const SizedBox(height: 16),
            ],

            // Requirements
            if (_job.requirements != null) ...[
              _buildSectionCard(theme, 'Requirements', _job.requirements!, Icons.checklist_outlined),
              const SizedBox(height: 16),
            ],

            // Qualifications
            if (_job.qualifications != null) ...[
              _buildSectionCard(theme, 'Qualifications', _job.qualifications!, Icons.school_outlined),
              const SizedBox(height: 16),
            ],

            // Compensation
            if (_job.salaryRange != null || _job.hourlyRate != null) ...[
              _buildSectionCard(
                theme,
                'Compensation',
                _job.salaryRange ?? _job.hourlyRate ?? '',
                Icons.payments_outlined,
              ),
              const SizedBox(height: 16),
            ],

            // References
            if (_job.referencesEnabled) ...[
              _buildReferencesCard(theme),
              const SizedBox(height: 16),
            ],

            // Contact Info
            _buildContactCard(theme),
            const SizedBox(height: 16),

            // Submitter Info
            _buildSubmitterCard(theme),
            const SizedBox(height: 16),

            // Dates and metadata
            _buildMetadataCard(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantsSummaryCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _applicationCount > 0 ? () => _viewApplicants() : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.3),
          ),
          child: Row(
            children: [
              Icon(
                Icons.people_outline,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Applicants',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_applicationCount total application${_applicationCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_applicationCount > 0)
                FilledButton.tonal(
                  onPressed: _viewApplicants,
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(ThemeData theme, String title, String content, IconData icon) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomQuestionsCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.3),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Questions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_job.customQuestions.length} custom question${_job.customQuestions.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _job.customQuestions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return _buildCustomQuestionItem(theme, question, index + 1);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionItem(ThemeData theme, CustomQuestion question, int number) {
    String typeLabel;
    IconData typeIcon;
    switch (question.type) {
      case CustomQuestionType.text:
        typeLabel = 'Short text';
        typeIcon = Icons.short_text;
        break;
      case CustomQuestionType.textarea:
        typeLabel = 'Long text';
        typeIcon = Icons.notes;
        break;
      case CustomQuestionType.select:
        typeLabel = 'Dropdown';
        typeIcon = Icons.arrow_drop_down_circle_outlined;
        break;
      case CustomQuestionType.checkbox:
        typeLabel = 'Checkboxes';
        typeIcon = Icons.check_box_outlined;
        break;
      case CustomQuestionType.radio:
        typeLabel = 'Multiple choice';
        typeIcon = Icons.radio_button_checked;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: number < _job.customQuestions.length ? 12 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$number',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        question.question,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (question.required)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(typeIcon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (question.options.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: question.options.map((option) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          option,
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferencesCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_page_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'References',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailInfoRow(theme, 'Required', _job.referencesRequired ? 'Yes' : 'Optional'),
            _buildDetailInfoRow(theme, 'Count', '${_job.referencesCount} reference${_job.referencesCount == 1 ? '' : 's'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_mail_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Contact Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailInfoRow(theme, 'Email', _job.contactEmail),
            if (_job.contactName != null)
              _buildDetailInfoRow(theme, 'Contact', _job.contactName!),
            if (_job.contactPhone != null)
              _buildDetailInfoRow(theme, 'Phone', _job.contactPhone!),
            if (_job.applicationUrl != null)
              _buildDetailInfoRow(theme, 'Apply URL', _job.applicationUrl!, isLink: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitterCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Submitted By',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailInfoRow(theme, 'Name', _job.submitterName),
            _buildDetailInfoRow(theme, 'Email', _job.submitterEmail),
            if (_job.submitterOrganization != null)
              _buildDetailInfoRow(theme, 'Organization', _job.submitterOrganization!),
            if (_job.submitterPhone != null)
              _buildDetailInfoRow(theme, 'Phone', _job.submitterPhone!),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Job Metadata',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailInfoRow(theme, 'Posted', DateFormat.yMMMd().format(_job.createdAt)),
            if (_job.expiresAt != null)
              _buildDetailInfoRow(
                theme,
                'Expires',
                DateFormat.yMMMd().format(_job.expiresAt!),
                highlight: _job.expiresAt!.isBefore(DateTime.now()),
              ),
            if (_job.approvedAt != null)
              _buildDetailInfoRow(theme, 'Approved', DateFormat.yMMMd().format(_job.approvedAt!)),
            _buildDetailInfoRow(theme, 'Views', '${_job.viewCount}'),
            _buildDetailInfoRow(theme, 'Applications', '$_applicationCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInfoRow(ThemeData theme, String label, String value, {bool isLink = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: isLink
                ? InkWell(
                    onTap: () => _launchUrl(value),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  )
                : Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: highlight ? Colors.red : null,
                      fontWeight: highlight ? FontWeight.bold : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    String urlToLaunch = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      urlToLaunch = 'https://$url';
    }

    final uri = Uri.parse(urlToLaunch);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _editJob() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobBuilderScreen(jobId: _job.id),
      ),
    ).then((_) {
      _refreshJob();
      _loadApplicationCount();
    });
  }

  void _viewApplicants() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobApplicantsScreen(job: _job),
      ),
    ).then((_) {
      _loadApplicationCount();
    });
  }

  void _navigateToMemberProfile(String memberId) async {
    try {
      final member = await MemberRepository().getMemberById(memberId);
      if (member != null && mounted) {
        Navigator.of(context).push(
          ThemeSwitcher.buildPageRoute(
            builder: (_) => TitleBarWrapper(
              child: MemberDetailScreen(member: member),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member not found')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading member: $e')),
        );
      }
    }
  }

  // ============================================================================
  // NOTIFICATIONS TAB
  // ============================================================================

  Widget _buildNotificationsTab(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (_loadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notificationLogs.isEmpty) {
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
                  Icons.notifications_off_outlined,
                  size: 40,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No notifications sent yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Notifications will appear here when\ntriggered for this job listing',
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

    return RefreshIndicator(
      onRefresh: _loadNotificationLogs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notificationLogs.length,
        itemBuilder: (context, index) {
          final log = _notificationLogs[index];
          return _buildNotificationLogCard(theme, log);
        },
      ),
    );
  }

  Widget _buildNotificationLogCard(ThemeData theme, JobNotificationLog log) {
    final colorScheme = theme.colorScheme;
    final statusColor = log.isSuccess
        ? Colors.green
        : log.isFailed
            ? Colors.red
            : Colors.orange;

    final channelIcon = log.channel == 'email'
        ? Icons.email_outlined
        : Icons.sms_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    channelIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.triggerTypeLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              log.statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.createdAt != null
                            ? _formatNotificationTime(log.createdAt!)
                            : 'Unknown time',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipient
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.recipientName ?? log.recipientEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (log.recipientName != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      log.recipientEmail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                // Subject
                if (log.subjectRendered != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.subject_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.subjectRendered!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Error message
                if (log.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final central = tz.getLocation('America/Chicago');
    final centralTime = tz.TZDateTime.from(dateTime.toUtc(), central);
    return DateFormat.yMMMd().add_jm().format(centralTime);
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
