import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/dashboard_metrics.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:bluebubbles/services/crm/dashboard_metrics_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/screens/dashboard/widgets/quick_links_dialog.dart';

import 'models/dashboard_widget_config.dart';
import 'widgets/dashboard_widgets.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

const _prefsKey = 'dashboard_config_v2';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  final QuickLinksRepository _quickLinksRepo = QuickLinksRepository();
  final DashboardMetricsService _metricsService = DashboardMetricsService();
  final Uuid _uuid = const Uuid();

  DashboardMetrics? _metrics;
  List<Member> _recentMembers = [];
  int _chatCount = 0;
  int _totalMessages = 0;
  int _weeklyMessages = 0;
  bool _loading = true;
  String? _error;

  // Edit mode state
  bool _isEditMode = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showPalette = false;

  // Dashboard configuration
  DashboardConfig _config = _getDefaultConfig();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    _loadConfig();
    _load();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  static DashboardConfig _getDefaultConfig() {
    return DashboardConfig(
      id: 'default',
      name: 'My Dashboard',
      columns: 4,
      widgets: [
        // Hero stats row
        DashboardWidgetConfig(
          id: 'hero_members',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.medium,
          dataSourceKey: 'totalMembers',
          title: 'Total Members',
          icon: Icons.people_alt,
          gradientColors: [_unityBlue, _momentumBlue],
          gridX: 0,
          gridY: 0,
        ),
        DashboardWidgetConfig(
          id: 'hero_counties',
          type: DashboardWidgetType.progressRing,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalUniqueCounties',
          title: 'Counties',
          subtitle: '/ 114 in Missouri',
          icon: Icons.map_outlined,
          gradientColors: [_sunriseGold, _actionRed],
          gridX: 2,
          gridY: 0,
        ),
        DashboardWidgetConfig(
          id: 'hero_chapters',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalCharteredChapters',
          title: 'Chartered Chapters',
          icon: Icons.flag,
          gradientColors: [_grassrootsGreen, _momentumBlue],
          gridX: 3,
          gridY: 0,
        ),
        // Second row
        DashboardWidgetConfig(
          id: 'members_phone',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalMembersWithPhone',
          title: 'With Phone',
          icon: Icons.phone_in_talk,
          gradientColors: [_momentumBlue, _justicePurple],
          gridX: 0,
          gridY: 1,
        ),
        DashboardWidgetConfig(
          id: 'new_this_month',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'newMembersThisMonth',
          title: 'New This Month',
          icon: Icons.trending_up,
          gradientColors: [_grassrootsGreen, _sunriseGold],
          gridX: 1,
          gridY: 1,
        ),
        DashboardWidgetConfig(
          id: 'subscribers',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalSubscribers',
          title: 'Subscribers',
          icon: Icons.email,
          gradientColors: [_justicePurple, _actionRed],
          gridX: 2,
          gridY: 1,
        ),
        DashboardWidgetConfig(
          id: 'donors',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalDonors',
          title: 'Donors',
          icon: Icons.volunteer_activism,
          gradientColors: [_actionRed, _sunriseGold],
          gridX: 3,
          gridY: 1,
        ),
        // Third row - charts
        DashboardWidgetConfig(
          id: 'growth_chart',
          type: DashboardWidgetType.lineChart,
          size: DashboardWidgetSize.large,
          dataSourceKey: 'membersJoinedByMonth',
          title: 'Member Growth',
          icon: Icons.show_chart,
          gridX: 0,
          gridY: 2,
        ),
        DashboardWidgetConfig(
          id: 'county_chart',
          type: DashboardWidgetType.barChart,
          size: DashboardWidgetSize.large,
          dataSourceKey: 'membersByCounty',
          title: 'Top Counties',
          icon: Icons.bar_chart,
          gridX: 2,
          gridY: 2,
        ),
        // Fourth row
        DashboardWidgetConfig(
          id: 'community_type',
          type: DashboardWidgetType.pieChart,
          size: DashboardWidgetSize.medium,
          dataSourceKey: 'membersByCommunityType',
          title: 'Community Type',
          icon: Icons.pie_chart,
          gridX: 0,
          gridY: 4,
        ),
        DashboardWidgetConfig(
          id: 'top_donors',
          type: DashboardWidgetType.leaderboard,
          size: DashboardWidgetSize.medium,
          dataSourceKey: 'top5Donors',
          title: 'Top Donors',
          icon: Icons.emoji_events,
          gridX: 2,
          gridY: 4,
        ),
        // Fifth row
        DashboardWidgetConfig(
          id: 'slack_messages',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalSlackMessages',
          title: 'Slack Messages',
          icon: Icons.chat,
          gradientColors: [_justicePurple, _momentumBlue],
          gridX: 0,
          gridY: 5,
        ),
        DashboardWidgetConfig(
          id: 'social_impressions',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalSocialImpressions',
          title: 'Social Impressions',
          icon: Icons.visibility,
          gradientColors: [_sunriseGold, _grassrootsGreen],
          gridX: 1,
          gridY: 5,
        ),
        DashboardWidgetConfig(
          id: 'total_donations',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalDonationsAmount',
          title: 'Total Raised',
          icon: Icons.attach_money,
          gradientColors: [_grassrootsGreen, _unityBlue],
          gridX: 2,
          gridY: 5,
        ),
        DashboardWidgetConfig(
          id: 'avg_age',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'averageMemberAge',
          title: 'Avg Age',
          icon: Icons.cake,
          gradientColors: [_momentumBlue, _justicePurple],
          gridX: 3,
          gridY: 5,
        ),
      ],
    );
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_prefsKey);
      if (configJson != null) {
        setState(() {
          _config = DashboardConfig.fromJsonString(configJson);
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _config.toJsonString());
    } catch (e) {
      debugPrint('Error saving dashboard config: $e');
    }
  }

  Future<void> _load() async {
    if (!CRMConfig.crmEnabled || !_supabaseService.isInitialized) {
      setState(() {
        _loading = false;
        _metrics = DashboardMetrics.empty;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final weeklySince = DateTime.now().subtract(const Duration(days: 7));

      final results = await Future.wait<dynamic>([
        _metricsService.fetchMetrics(),
        _fetchChatCount(),
        _fetchMessageCount(),
        _fetchMessageCount(after: weeklySince),
        _memberRepo.getRecentMembers(limit: 5),
      ]);

      final metrics = results[0] as DashboardMetrics?;
      final chatCount = (results[1] as int?) ?? 0;
      final totalMessages = (results[2] as int?) ?? 0;
      final weeklyMessages = (results[3] as int?) ?? 0;
      final recentMembers = (results[4] as List<Member>?) ?? [];

      if (!mounted) return;

      setState(() {
        _metrics = metrics ?? DashboardMetrics.empty;
        _chatCount = chatCount;
        _totalMessages = totalMessages;
        _weeklyMessages = weeklyMessages;
        _recentMembers = recentMembers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<int> _fetchChatCount() async {
    try {
      final Response<dynamic> response = await http.chatCount();
      return response.data['data']['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchMessageCount({DateTime? after}) async {
    try {
      final Response<dynamic> response = await http.messageCount(after: after);
      return response.data['data']['total'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _flipController.forward();
        _showPalette = true;
      } else {
        _flipController.reverse();
        _showPalette = false;
        _saveConfig();
      }
    });
  }

  void _addWidget(DashboardDataSource source, DashboardWidgetType type) {
    final newWidget = DashboardWidgetConfig(
      id: _uuid.v4(),
      type: type,
      size: _getSizeForType(type),
      dataSourceKey: source.key,
      title: source.label,
      icon: source.icon,
      gradientColors: WidgetGradients.random,
      gridX: 0,
      gridY: _getNextAvailableY(),
    );

    setState(() {
      _config = _config.copyWith(
        widgets: [..._config.widgets, newWidget],
      );
    });
  }

  void _removeWidget(String widgetId) {
    setState(() {
      _config = _config.copyWith(
        widgets: _config.widgets.where((w) => w.id != widgetId).toList(),
      );
    });
  }

  void _updateWidget(DashboardWidgetConfig updated) {
    setState(() {
      _config = _config.copyWith(
        widgets: _config.widgets.map((w) => w.id == updated.id ? updated : w).toList(),
      );
    });
  }

  DashboardWidgetSize _getSizeForType(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.statCard:
      case DashboardWidgetType.progressRing:
      case DashboardWidgetType.sparkline:
        return DashboardWidgetSize.small;
      case DashboardWidgetType.barChart:
      case DashboardWidgetType.lineChart:
      case DashboardWidgetType.pieChart:
      case DashboardWidgetType.donutChart:
        return DashboardWidgetSize.large;
      case DashboardWidgetType.leaderboard:
      case DashboardWidgetType.trendCard:
        return DashboardWidgetSize.medium;
      case DashboardWidgetType.heatmap:
        return DashboardWidgetSize.hero;
    }
  }

  int _getNextAvailableY() {
    if (_config.widgets.isEmpty) return 0;
    int maxY = 0;
    for (final w in _config.widgets) {
      final bottom = w.gridY + w.gridHeight;
      if (bottom > maxY) maxY = bottom;
    }
    return maxY;
  }

  void _openMembersList(BuildContext context, {bool showChaptersOnly = false}) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: MembersListScreen(showChaptersOnly: showChaptersOnly),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isBack = angle > math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _buildEditMode(),
                )
              : _buildViewMode(),
        );
      },
    );
  }

  Widget _buildViewMode() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Image.asset(
            'assets/images/Blue-Gradient-Background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_unityBlue.withOpacity(0.1), _momentumBlue.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withOpacity(0.15)),
        ),
        // Content
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildDashboardContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    final metrics = _metrics ?? DashboardMetrics.empty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final horizontalPadding = isCompact ? 16.0 : 32.0;
        final columns = isCompact ? 2 : 4;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Header
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader()),
            ),
            // Widgets Grid
            SliverPadding(
              padding: EdgeInsets.all(horizontalPadding),
              sliver: SliverToBoxAdapter(
                child: _buildWidgetsGrid(metrics, columns, constraints.maxWidth),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _momentumBlue),
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _unityBlue,
                ),
              ),
              Text(
                'Real-time insights into your organizing work',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _unityBlue.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Customize Dashboard',
          icon: const Icon(Icons.edit_outlined, color: _unityBlue),
          onPressed: _toggleEditMode,
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: _unityBlue),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildWidgetsGrid(DashboardMetrics metrics, int columns, double maxWidth) {
    final widgetWidth = (maxWidth - 32 - (columns - 1) * 16) / columns;
    final widgetHeight = widgetWidth * 0.8;

    // Sort widgets by position
    final sortedWidgets = List<DashboardWidgetConfig>.from(_config.widgets)
      ..sort((a, b) {
        if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
        return a.gridX.compareTo(b.gridX);
      });

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: sortedWidgets.map((widget) {
        final width = _getWidgetWidth(widget, widgetWidth, columns);
        final height = _getWidgetHeight(widget, widgetHeight);

        return SizedBox(
          width: width,
          height: height,
          child: _buildWidget(widget, metrics),
        );
      }).toList(),
    );
  }

  double _getWidgetWidth(DashboardWidgetConfig widget, double unitWidth, int columns) {
    final spanWidth = widget.gridWidth.clamp(1, columns);
    return unitWidth * spanWidth + (spanWidth - 1) * 16;
  }

  double _getWidgetHeight(DashboardWidgetConfig widget, double unitHeight) {
    final spanHeight = widget.gridHeight;
    return unitHeight * spanHeight + (spanHeight - 1) * 16;
  }

  Widget _buildWidget(DashboardWidgetConfig config, DashboardMetrics metrics) {
    final value = _getValueForDataSource(config.dataSourceKey, metrics);

    switch (config.type) {
      case DashboardWidgetType.statCard:
      case DashboardWidgetType.trendCard:
        return StatCardWidget(
          config: config,
          value: value,
          onTap: () => _openMembersList(context),
        );

      case DashboardWidgetType.barChart:
        final data = _getDistributionData(config.dataSourceKey, metrics);
        return BarChartWidget(config: config, data: data);

      case DashboardWidgetType.lineChart:
        if (config.dataSourceKey == 'membersJoinedByMonth') {
          return LineChartWidget(config: config, data: metrics.membersJoinedByMonth);
        }
        return const SizedBox.shrink();

      case DashboardWidgetType.pieChart:
        final data = _getDistributionData(config.dataSourceKey, metrics);
        return PieChartWidget(config: config, data: data);

      case DashboardWidgetType.donutChart:
        final data = _getDistributionData(config.dataSourceKey, metrics);
        return PieChartWidget(config: config, data: data, isDonut: true);

      case DashboardWidgetType.leaderboard:
        if (config.dataSourceKey == 'top5Donors') {
          return LeaderboardWidget(
            config: config,
            data: metrics.top5Donors,
            isDonors: true,
          );
        } else if (config.dataSourceKey == 'top50SlackMembers') {
          return LeaderboardWidget(
            config: config,
            data: metrics.top50SlackMembers,
            isDonors: false,
          );
        }
        return const SizedBox.shrink();

      case DashboardWidgetType.progressRing:
        final current = _getValueForDataSource(config.dataSourceKey, metrics);
        int total = 114; // Default for counties
        if (config.dataSourceKey == 'totalUniqueCongressionalDistricts') total = 8;
        if (config.dataSourceKey == 'totalUniqueHouseDistricts') total = 163;
        if (config.dataSourceKey == 'totalUniqueSenateDistricts') total = 34;
        return ProgressRingWidget(
          config: config,
          current: (current is num) ? current.toInt() : 0,
          total: total,
        );

      case DashboardWidgetType.sparkline:
      case DashboardWidgetType.heatmap:
        return Card(
          child: Center(child: Text(config.title)),
        );
    }
  }

  dynamic _getValueForDataSource(String key, DashboardMetrics metrics) {
    switch (key) {
      case 'totalMembers':
        return metrics.totalMembers;
      case 'totalMembersWithPhone':
        return metrics.totalMembersWithPhone;
      case 'totalSubscribers':
        return metrics.totalSubscribers;
      case 'totalDonors':
        return metrics.totalDonors;
      case 'totalChapters':
        return metrics.totalChapters;
      case 'totalCharteredChapters':
        return metrics.totalCharteredChapters;
      case 'totalCollegeChapters':
        return metrics.totalCollegeChapters;
      case 'totalHighschoolChapters':
        return metrics.totalHighschoolChapters;
      case 'totalUniqueCounties':
        return metrics.totalUniqueCounties;
      case 'totalUniqueCongressionalDistricts':
        return metrics.totalUniqueCongressionalDistricts;
      case 'totalUniqueHouseDistricts':
        return metrics.totalUniqueHouseDistricts;
      case 'totalUniqueSenateDistricts':
        return metrics.totalUniqueSenateDistricts;
      case 'totalDonationsAmount':
        return metrics.totalDonationsAmount;
      case 'totalDonationCount':
        return metrics.totalDonationCount;
      case 'averageDonationAmount':
        return metrics.averageDonationAmount;
      case 'donationsThisMonth':
        return metrics.donationsThisMonth;
      case 'donationsThisYear':
        return metrics.donationsThisYear;
      case 'totalSlackMessages':
        return metrics.totalSlackMessages;
      case 'slackMessagesThisMonth':
        return metrics.slackMessagesThisMonth;
      case 'totalSocialImpressions':
        return metrics.totalSocialImpressions;
      case 'newMembersThisWeek':
        return metrics.newMembersThisWeek;
      case 'newMembersThisMonth':
        return metrics.newMembersThisMonth;
      case 'newMembersThisYear':
        return metrics.newMembersThisYear;
      case 'averageMemberAge':
        return metrics.averageMemberAge;
      case 'totalEvents':
        return metrics.totalEvents;
      case 'upcomingEvents':
        return metrics.upcomingEvents;
      case 'totalEventAttendees':
        return metrics.totalEventAttendees;
      default:
        return 0;
    }
  }

  List<NameCount> _getDistributionData(String key, DashboardMetrics metrics) {
    switch (key) {
      case 'membersByCounty':
        return metrics.membersByCounty;
      case 'membersByCongressionalDistrict':
        return metrics.membersByCongressionalDistrict;
      case 'membersByHouseDistrict':
        return metrics.membersByHouseDistrict;
      case 'membersBySenateDistrict':
        return metrics.membersBySenateDistrict;
      case 'membersByCommunityType':
        return metrics.membersByCommunityType;
      case 'membersByCollege':
        return metrics.membersByCollege;
      case 'membersByHighSchool':
        return metrics.membersByHighSchool;
      case 'membersByGraduationYear':
        return metrics.membersByGraduationYear;
      case 'membersByEducationLevel':
        return metrics.membersByEducationLevel;
      case 'membersByChapter':
        return metrics.membersByChapter;
      case 'membersByChapterStatus':
        return metrics.membersByChapterStatus;
      case 'membersByCommittee':
        return metrics.membersByCommittee;
      case 'membersByGenderIdentity':
        return metrics.membersByGenderIdentity;
      case 'membersByPronouns':
        return metrics.membersByPronouns;
      case 'membersByRace':
        return metrics.membersByRace;
      case 'membersBySexualOrientation':
        return metrics.membersBySexualOrientation;
      case 'membersByVoterRegistration':
        return metrics.membersByVoterRegistration;
      case 'membersByIndustry':
        return metrics.membersByIndustry;
      case 'membersByReferralSource':
        return metrics.membersByReferralSource;
      case 'ageDistribution':
        return [
          NameCount(name: '14-17', count: metrics.age14To17Count),
          NameCount(name: '18-21', count: metrics.age18To21Count),
          NameCount(name: '22-25', count: metrics.age22To25Count),
          NameCount(name: '26-30', count: metrics.age26To30Count),
          NameCount(name: '31-36', count: metrics.age31To36Count),
          NameCount(name: 'Unknown', count: metrics.ageUnknownCount),
        ];
      default:
        return [];
    }
  }

  Widget _buildEditMode() {
    return Container(
      color: Colors.grey[100],
      child: Row(
        children: [
          // Widget palette
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _showPalette ? 300 : 0,
            child: _buildWidgetPalette(),
          ),
          // Main edit area
          Expanded(
            child: Column(
              children: [
                _buildEditHeader(),
                Expanded(child: _buildEditableGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_showPalette ? Icons.chevron_left : Icons.chevron_right),
            onPressed: () => setState(() => _showPalette = !_showPalette),
            tooltip: _showPalette ? 'Hide palette' : 'Show palette',
          ),
          const SizedBox(width: 16),
          const Icon(Icons.edit, color: _momentumBlue),
          const SizedBox(width: 12),
          const Text(
            'Customize Dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _unityBlue,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Default'),
            onPressed: () {
              setState(() {
                _config = _getDefaultConfig();
              });
            },
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _grassrootsGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetPalette() {
    if (!_showPalette) return const SizedBox.shrink();

    final categories = DashboardDataCategory.values;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _unityBlue,
            ),
            child: const Row(
              children: [
                Icon(Icons.widgets, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Add Widgets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: categories.map((category) {
                final sources = DashboardDataSources.getByCategory(category);
                if (sources.isEmpty) return const SizedBox.shrink();

                return ExpansionTile(
                  title: Text(
                    _getCategoryLabel(category),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  initiallyExpanded: category == DashboardDataCategory.members,
                  children: sources.map((source) {
                    return _buildPaletteItem(source);
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(DashboardDataSource source) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(source.icon, color: _momentumBlue, size: 20),
        title: Text(
          source.label,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          source.description,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<DashboardWidgetType>(
          icon: const Icon(Icons.add_circle_outline, color: _grassrootsGreen),
          tooltip: 'Add as...',
          onSelected: (type) => _addWidget(source, type),
          itemBuilder: (context) {
            return source.supportedWidgets.map((type) {
              return PopupMenuItem<DashboardWidgetType>(
                value: type,
                child: Row(
                  children: [
                    Icon(_getWidgetTypeIcon(type), size: 18),
                    const SizedBox(width: 8),
                    Text(_getWidgetTypeLabel(type)),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildEditableGrid() {
    final metrics = _metrics ?? DashboardMetrics.empty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 800 ? 4 : 2;
        final widgetWidth = (constraints.maxWidth - 32 - (columns - 1) * 16) / columns;
        final widgetHeight = widgetWidth * 0.8;

        final sortedWidgets = List<DashboardWidgetConfig>.from(_config.widgets)
          ..sort((a, b) {
            if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
            return a.gridX.compareTo(b.gridX);
          });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: sortedWidgets.map((widget) {
              final width = _getWidgetWidth(widget, widgetWidth, columns);
              final height = _getWidgetHeight(widget, widgetHeight);

              return SizedBox(
                width: width,
                height: height,
                child: _buildEditableWidget(widget, metrics),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEditableWidget(DashboardWidgetConfig config, DashboardMetrics metrics) {
    return Stack(
      children: [
        _buildWidget(config, metrics),
        // Edit overlay
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showWidgetOptions(config),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _momentumBlue.withOpacity(0.5), width: 2),
                ),
              ),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _removeWidget(config.id),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 16, color: _actionRed),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showWidgetOptions(DashboardWidgetConfig config) {
    final source = DashboardDataSources.getByKey(config.dataSourceKey);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(config.icon ?? Icons.widgets, color: _momentumBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      config.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _actionRed),
                    onPressed: () {
                      Navigator.pop(context);
                      _removeWidget(config.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Display as:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (source?.supportedWidgets ?? [DashboardWidgetType.statCard]).map((type) {
                  final isSelected = config.type == type;
                  return ChoiceChip(
                    label: Text(_getWidgetTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _updateWidget(config.copyWith(
                          type: type,
                          size: _getSizeForType(type),
                        ));
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Size:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: DashboardWidgetSize.values.map((size) {
                  final isSelected = config.size == size;
                  return ChoiceChip(
                    label: Text(_getSizeLabel(size)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _updateWidget(config.copyWith(size: size));
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCategoryLabel(DashboardDataCategory category) {
    switch (category) {
      case DashboardDataCategory.members:
        return 'Members';
      case DashboardDataCategory.chapters:
        return 'Chapters';
      case DashboardDataCategory.donations:
        return 'Donations';
      case DashboardDataCategory.communications:
        return 'Communications';
      case DashboardDataCategory.events:
        return 'Events';
      case DashboardDataCategory.demographics:
        return 'Demographics';
      case DashboardDataCategory.geography:
        return 'Geography';
      case DashboardDataCategory.growth:
        return 'Growth';
      case DashboardDataCategory.engagement:
        return 'Engagement';
    }
  }

  String _getWidgetTypeLabel(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.statCard:
        return 'Stat Card';
      case DashboardWidgetType.barChart:
        return 'Bar Chart';
      case DashboardWidgetType.lineChart:
        return 'Line Chart';
      case DashboardWidgetType.pieChart:
        return 'Pie Chart';
      case DashboardWidgetType.donutChart:
        return 'Donut Chart';
      case DashboardWidgetType.leaderboard:
        return 'Leaderboard';
      case DashboardWidgetType.progressRing:
        return 'Progress Ring';
      case DashboardWidgetType.sparkline:
        return 'Sparkline';
      case DashboardWidgetType.heatmap:
        return 'Heatmap';
      case DashboardWidgetType.trendCard:
        return 'Trend Card';
    }
  }

  IconData _getWidgetTypeIcon(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.statCard:
        return Icons.credit_card;
      case DashboardWidgetType.barChart:
        return Icons.bar_chart;
      case DashboardWidgetType.lineChart:
        return Icons.show_chart;
      case DashboardWidgetType.pieChart:
        return Icons.pie_chart;
      case DashboardWidgetType.donutChart:
        return Icons.donut_large;
      case DashboardWidgetType.leaderboard:
        return Icons.leaderboard;
      case DashboardWidgetType.progressRing:
        return Icons.radio_button_checked;
      case DashboardWidgetType.sparkline:
        return Icons.trending_up;
      case DashboardWidgetType.heatmap:
        return Icons.grid_on;
      case DashboardWidgetType.trendCard:
        return Icons.insights;
    }
  }

  String _getSizeLabel(DashboardWidgetSize size) {
    switch (size) {
      case DashboardWidgetSize.small:
        return 'Small';
      case DashboardWidgetSize.medium:
        return 'Medium';
      case DashboardWidgetSize.large:
        return 'Large';
      case DashboardWidgetSize.wide:
        return 'Wide';
      case DashboardWidgetSize.tall:
        return 'Tall';
      case DashboardWidgetSize.hero:
        return 'Hero';
    }
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _actionRed),
            const SizedBox(height: 12),
            Text('Unable to load dashboard', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: _actionRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
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
}
