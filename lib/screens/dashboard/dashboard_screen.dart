import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/dashboard_metrics.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/screens/committee_workspace_screen.dart';
import 'package:bluebubbles/features/slack/screens/slack_management_screen.dart';
import 'package:bluebubbles/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:bluebubbles/screens/crm/bulk_message_screen.dart';
import 'package:bluebubbles/screens/crm/donors_screen.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/screens/crm/members_list_screen.dart';
import 'package:bluebubbles/screens/crm/subscribers_screen.dart';
import 'package:bluebubbles/services/crm/dashboard_metrics_service.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/screens/dashboard/widgets/quick_links_dialog.dart';
import 'package:bluebubbles/screens/dashboard/quick_links_screen.dart';

import 'models/dashboard_widget_config.dart';
import 'widgets/dashboard_widgets.dart';
import 'widgets/dashboard_error_boundary.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

const _prefsKey = 'dashboard_config_v2';

/// Data class for dragging widgets from the palette
class _PaletteDragData {
  final DashboardDataSource source;
  final DashboardWidgetType type;

  const _PaletteDragData({required this.source, required this.type});
}

/// Data class for reordering existing widgets
class _WidgetReorderData {
  final int fromIndex;
  final DashboardWidgetConfig config;

  const _WidgetReorderData({required this.fromIndex, required this.config});
}

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
  int _quickLinksCount = 0;
  bool _loading = true;
  String? _error;

  // Edit mode state
  bool _isEditMode = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showPalette = false;
  int? _dragHoverIndex; // Track where a dragged widget would be inserted
  bool _isDragging = false; // Track active drag to prevent rebuilds mid-gesture

  // Dashboard configuration - separate configs for mobile and desktop
  DashboardConfig _desktopConfig = _getDefaultConfig();
  DashboardConfig _mobileConfig = _getDefaultMobileConfig();

  // Track which layout we're currently editing/viewing
  bool _isMobileLayout = false;

  // Active config getter (returns mobile or desktop based on current screen)
  DashboardConfig get _config => _isMobileLayout ? _mobileConfig : _desktopConfig;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update mobile layout flag when screen size changes
    // We update directly here since didChangeDependencies is called after
    // the widget tree is in a valid state. No addPostFrameCallback needed
    // as that was causing RenderBox layout errors from callback accumulation.
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    // Only update if the value actually changed - this won't trigger rebuild
    // during the same frame since we're just updating the field
    _isMobileLayout = isMobile;
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
          id: 'distribution_explorer',
          type: DashboardWidgetType.dynamicDistribution,
          size: DashboardWidgetSize.large,
          dataSourceKey: 'dynamicDistribution',
          title: 'Distribution Explorer',
          icon: Icons.analytics,
          gradientColors: [_momentumBlue, _justicePurple],
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
        // Sixth row - Recently joined members
        DashboardWidgetConfig(
          id: 'recent_members',
          type: DashboardWidgetType.memberList,
          size: DashboardWidgetSize.medium,
          dataSourceKey: 'recentlyJoinedMembers',
          title: 'Recently Joined',
          icon: Icons.person_add,
          gradientColors: [_grassrootsGreen, _momentumBlue],
          gridX: 0,
          gridY: 6,
        ),
      ],
    );
  }

  /// Default mobile config with swipeable stat card rows
  static DashboardConfig _getDefaultMobileConfig() {
    return DashboardConfig(
      id: 'default_mobile',
      name: 'Mobile Dashboard',
      columns: 2,
      widgets: [
        // Swipeable stat card row 1 (key stats)
        DashboardWidgetConfig(
          id: 'mobile_members',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalMembers',
          title: 'Members',
          icon: Icons.people_alt,
          gradientColors: [_unityBlue, _momentumBlue],
          gridX: 0,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        DashboardWidgetConfig(
          id: 'mobile_subscribers',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalSubscribers',
          title: 'Subscribers',
          icon: Icons.email,
          gradientColors: [_justicePurple, _actionRed],
          gridX: 1,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        DashboardWidgetConfig(
          id: 'mobile_donors',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalDonors',
          title: 'Donors',
          icon: Icons.volunteer_activism,
          gradientColors: [_actionRed, _sunriseGold],
          gridX: 2,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        DashboardWidgetConfig(
          id: 'mobile_chapters',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalCharteredChapters',
          title: 'Chapters',
          icon: Icons.flag,
          gradientColors: [_grassrootsGreen, _momentumBlue],
          gridX: 3,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        DashboardWidgetConfig(
          id: 'mobile_new_month',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'newMembersThisMonth',
          title: 'New This Month',
          icon: Icons.trending_up,
          gradientColors: [_grassrootsGreen, _sunriseGold],
          gridX: 4,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        // Distribution Explorer - mobileFull size (tall proportions, full width)
        DashboardWidgetConfig(
          id: 'mobile_distribution',
          type: DashboardWidgetType.dynamicDistribution,
          size: DashboardWidgetSize.mobileFull,
          dataSourceKey: 'dynamicDistribution',
          title: 'Distribution Explorer',
          icon: Icons.analytics,
          gradientColors: [_momentumBlue, _justicePurple],
          gridX: 0,
          gridY: 1,
        ),
        // Growth chart - mobileFull size
        DashboardWidgetConfig(
          id: 'mobile_growth',
          type: DashboardWidgetType.lineChart,
          size: DashboardWidgetSize.mobileFull,
          dataSourceKey: 'membersJoinedByMonth',
          title: 'Member Growth',
          icon: Icons.show_chart,
          gridX: 0,
          gridY: 2,
        ),
        // More stats in swipeable row 2
        DashboardWidgetConfig(
          id: 'mobile_counties',
          type: DashboardWidgetType.progressRing,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalUniqueCounties',
          title: 'Counties',
          subtitle: '/ 114',
          icon: Icons.map_outlined,
          gradientColors: [_sunriseGold, _actionRed],
          gridX: 0,
          gridY: 3,
          swipeRowId: 'stats_row_2',
        ),
        DashboardWidgetConfig(
          id: 'mobile_slack',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalSlackMessages',
          title: 'Slack Messages',
          icon: Icons.chat,
          gradientColors: [_justicePurple, _momentumBlue],
          gridX: 1,
          gridY: 3,
          swipeRowId: 'stats_row_2',
        ),
        DashboardWidgetConfig(
          id: 'mobile_donations',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'totalDonationsAmount',
          title: 'Total Raised',
          icon: Icons.attach_money,
          gradientColors: [_grassrootsGreen, _unityBlue],
          gridX: 2,
          gridY: 3,
          swipeRowId: 'stats_row_2',
        ),
        DashboardWidgetConfig(
          id: 'mobile_age',
          type: DashboardWidgetType.statCard,
          size: DashboardWidgetSize.small,
          dataSourceKey: 'averageMemberAge',
          title: 'Avg Age',
          icon: Icons.cake,
          gradientColors: [_momentumBlue, _justicePurple],
          gridX: 3,
          gridY: 3,
          swipeRowId: 'stats_row_2',
        ),
        // Community type pie chart
        DashboardWidgetConfig(
          id: 'mobile_community',
          type: DashboardWidgetType.pieChart,
          size: DashboardWidgetSize.mobileFull,
          dataSourceKey: 'membersByCommunityType',
          title: 'Community Type',
          icon: Icons.pie_chart,
          gridX: 0,
          gridY: 4,
        ),
      ],
    );
  }

  /// Update config setter to work with mobile/desktop separation
  void _setConfig(DashboardConfig config) {
    if (_isMobileLayout) {
      _mobileConfig = config;
    } else {
      _desktopConfig = config;
    }
  }

  Future<void> _loadConfig() async {
    try {
      debugPrint('[DashboardScreen] Loading configs from database...');

      // Load both desktop and mobile layouts in parallel
      final results = await Future.wait([
        _metricsService.fetchDashboardLayout(),
        _metricsService.fetchDashboardLayoutMobile(),
      ]);

      final desktopLayoutJson = results[0];
      final mobileLayoutJson = results[1];

      // Parse desktop layout
      if (desktopLayoutJson != null) {
        debugPrint('[DashboardScreen] Parsing desktop layout JSON with ${desktopLayoutJson['widgets']?.length ?? 0} widgets');
        try {
          final config = DashboardConfig.fromJson(desktopLayoutJson);
          debugPrint('[DashboardScreen] Successfully parsed desktop config: ${config.widgets.length} widgets');
          _desktopConfig = config;
        } catch (parseError, stackTrace) {
          _logDetailedParseError('DashboardConfig.fromJson (desktop)', parseError, stackTrace, desktopLayoutJson);
          _desktopConfig = _getDefaultConfig();
        }
      } else {
        // Fallback to local storage for backwards compatibility
        debugPrint('[DashboardScreen] No desktop database layout, checking SharedPreferences...');
        final prefs = await SharedPreferences.getInstance();
        final configJson = prefs.getString(_prefsKey);
        if (configJson != null) {
          try {
            final config = DashboardConfig.fromJsonString(configJson);
            debugPrint('[DashboardScreen] Loaded desktop from SharedPreferences: ${config.widgets.length} widgets');
            _desktopConfig = config;
            // Migrate to database
            _metricsService.saveDashboardLayout(_desktopConfig.toJson());
          } catch (parseError, stackTrace) {
            _logDetailedParseError('DashboardConfig.fromJsonString', parseError, stackTrace, configJson);
          }
        }
      }

      // Parse mobile layout
      if (mobileLayoutJson != null) {
        debugPrint('[DashboardScreen] Parsing mobile layout JSON with ${mobileLayoutJson['widgets']?.length ?? 0} widgets');
        try {
          final config = DashboardConfig.fromJson(mobileLayoutJson);
          debugPrint('[DashboardScreen] Successfully parsed mobile config: ${config.widgets.length} widgets');
          _mobileConfig = config;
        } catch (parseError, stackTrace) {
          _logDetailedParseError('DashboardConfig.fromJson (mobile)', parseError, stackTrace, mobileLayoutJson);
          _mobileConfig = _getDefaultMobileConfig();
        }
      } else {
        // No mobile layout saved yet, use default
        debugPrint('[DashboardScreen] No mobile layout in database, using default mobile config');
        _mobileConfig = _getDefaultMobileConfig();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      _logDetailedParseError('_loadConfig', e, stackTrace, null);
    }
  }

  void _logDetailedParseError(String context, Object error, StackTrace stackTrace, dynamic data) {
    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('╔══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('║ DASHBOARD CONFIG PARSING ERROR');
    buffer.writeln('╠══════════════════════════════════════════════════════════════════════════════');
    buffer.writeln('║ Context: $context');
    buffer.writeln('║ Error Type: ${error.runtimeType}');
    buffer.writeln('║ Error Message: $error');
    buffer.writeln('║');

    // Check for type casting errors
    final errorStr = error.toString();
    if (errorStr.contains("type 'int' is not a subtype of type 'bool")) {
      buffer.writeln('║ ⚠️  TYPE CASTING ERROR: int -> bool');
      buffer.writeln('║');
      buffer.writeln('║ This typically happens when:');
      buffer.writeln('║   1. Database stores boolean as 0/1 integer');
      buffer.writeln('║   2. JSON field expected bool but got int');
      buffer.writeln('║');

      // Try to find the specific field
      if (data is Map) {
        buffer.writeln('║ Checking data fields for int values that should be bool:');
        _checkForIntBoolFields(data, buffer, '  ');
      }
    }

    buffer.writeln('║');
    buffer.writeln('║ STACK TRACE (first 15 frames):');
    final stackLines = stackTrace.toString().split('\n').take(15);
    for (final line in stackLines) {
      if (line.contains('package:bluebubbles')) {
        buffer.writeln('║ >>> $line');
      } else {
        buffer.writeln('║     $line');
      }
    }

    buffer.writeln('║');
    buffer.writeln('╚══════════════════════════════════════════════════════════════════════════════');
    debugPrint(buffer.toString());
  }

  void _checkForIntBoolFields(Map<dynamic, dynamic> data, StringBuffer buffer, String indent) {
    data.forEach((key, value) {
      if (value is int && (value == 0 || value == 1)) {
        // Likely a boolean field stored as int
        final boolFieldNames = ['visible', 'required', 'enabled', 'active', 'is_'];
        final keyStr = key.toString().toLowerCase();
        for (final boolName in boolFieldNames) {
          if (keyStr.contains(boolName)) {
            buffer.writeln('║ $indent⚠️  "$key": $value (likely should be bool)');
            break;
          }
        }
      } else if (value is Map) {
        buffer.writeln('║ $indent"$key": {nested}');
        _checkForIntBoolFields(value as Map<dynamic, dynamic>, buffer, '$indent  ');
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        buffer.writeln('║ $indent"$key": [${value.length} items]');
        if (value.isNotEmpty) {
          _checkForIntBoolFields(value.first as Map<dynamic, dynamic>, buffer, '$indent  ');
        }
      }
    });
  }

  Future<void> _saveConfig() async {
    // Determine screen width for logging
    final screenWidth = MediaQuery.of(context).size.width;
    debugPrint('[DashboardScreen] _saveConfig called - isMobile: $_isMobileLayout, screenWidth: $screenWidth');

    try {
      // Save to appropriate database column based on mobile/desktop
      if (_isMobileLayout) {
        final configJson = _mobileConfig.toJson();
        debugPrint('[DashboardScreen] Saving mobile layout with ${_mobileConfig.widgets.length} widgets');
        final success = await _metricsService.saveDashboardLayoutMobile(configJson);
        if (success) {
          debugPrint('[DashboardScreen] ✓ Mobile dashboard layout saved to database');
        } else {
          debugPrint('[DashboardScreen] ✗ Failed to save mobile dashboard layout to database');
        }
      } else {
        final configJson = _desktopConfig.toJson();
        debugPrint('[DashboardScreen] Saving desktop layout with ${_desktopConfig.widgets.length} widgets');
        final success = await _metricsService.saveDashboardLayout(configJson);
        if (success) {
          debugPrint('[DashboardScreen] ✓ Desktop dashboard layout saved to database');
        } else {
          // Fallback to local storage if database save fails
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, _desktopConfig.toJsonString());
          debugPrint('[DashboardScreen] Desktop dashboard layout saved to local storage (fallback)');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[DashboardScreen] Error saving dashboard config: $e');
      debugPrint('[DashboardScreen] Stack trace: $stackTrace');
      // Fallback to local storage for desktop only
      if (!_isMobileLayout) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, _desktopConfig.toJsonString());
        } catch (_) {}
      }
    }
  }

  Future<void> _load() async {
    if (!CRMConfig.crmEnabled) {
      setState(() {
        _loading = false;
        _metrics = DashboardMetrics.empty;
      });
      return;
    }

    // Check if we have any valid Supabase client available
    // The CRMSupabaseService singleton or the global Supabase.instance
    bool hasSupabaseClient = _supabaseService.isInitialized;
    if (!hasSupabaseClient) {
      try {
        // Just check if client exists - accessing it throws if not initialized
        Supabase.instance.client;
        hasSupabaseClient = true;
      } catch (_) {
        // Supabase.instance not available
      }
    }

    if (!hasSupabaseClient) {
      debugPrint('[DashboardScreen] No Supabase client available');
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
        _metricsService.fetchMetricsWithAdditionalStats(),
        _fetchChatCount(),
        _fetchMessageCount(),
        _fetchMessageCount(after: weeklySince),
        _memberRepo.getRecentMembers(limit: 25),
        _quickLinksRepo.countQuickLinks(),
      ]);

      var metrics = results[0] as DashboardMetrics?;
      final chatCount = (results[1] as int?) ?? 0;
      final totalMessages = (results[2] as int?) ?? 0;
      final weeklyMessages = (results[3] as int?) ?? 0;
      final recentMembers = (results[4] as List<Member>?) ?? [];
      final quickLinksCount = (results[5] as int?) ?? 0;

      // Enrich top slack members with profile photos from member records
      if (metrics != null && metrics.top50SlackMembers.isNotEmpty) {
        debugPrint('[DashboardScreen] Enriching ${metrics.top50SlackMembers.length} slack members with photos...');

        final slackEmails = metrics.top50SlackMembers
            .where((m) => m.email != null && m.email!.isNotEmpty)
            .map((m) => m.email!)
            .toList();

        debugPrint('[DashboardScreen] Found ${slackEmails.length} slack members with emails');
        if (slackEmails.isNotEmpty) {
          debugPrint('[DashboardScreen] Sample emails: ${slackEmails.take(3).join(', ')}');
        }

        if (slackEmails.isNotEmpty) {
          final photoMap = await _memberRepo.getMemberPhotosByEmails(slackEmails);
          debugPrint('[DashboardScreen] Photo map returned ${photoMap.length} matches');

          if (photoMap.isNotEmpty) {
            debugPrint('[DashboardScreen] Sample photo matches: ${photoMap.keys.take(3).join(', ')}');
            final enrichedSlackMembers = metrics.top50SlackMembers.map((member) {
              if (member.email == null || member.email!.isEmpty) return member;
              final photoUrl = photoMap[member.email!.toLowerCase()];
              if (photoUrl != null) {
                return member.copyWith(profilePhotoUrl: photoUrl);
              }
              return member;
            }).toList();

            // Count how many got enriched
            final enrichedCount = enrichedSlackMembers.where((m) => m.profilePhotoUrl != null).length;
            debugPrint('[DashboardScreen] Enriched $enrichedCount slack members with photos');

            // Create new metrics with enriched slack members using copyWith
            metrics = metrics.copyWith(top50SlackMembers: enrichedSlackMembers);
          }
        } else {
          debugPrint('[DashboardScreen] No slack members have email addresses');
        }
      }

      if (!mounted) return;

      // Debug logging for dashboard data
      debugPrint('[DashboardScreen] _load completed:');
      debugPrint('[DashboardScreen]   metrics is null: ${metrics == null}');
      if (metrics != null) {
        debugPrint('[DashboardScreen]   totalMembers: ${metrics.totalMembers}');
        debugPrint('[DashboardScreen]   top5Donors: ${metrics.top5Donors.length}');
        debugPrint('[DashboardScreen]   top50SlackMembers: ${metrics.top50SlackMembers.length}');
        debugPrint('[DashboardScreen]   membersByCounty: ${metrics.membersByCounty.length}');
      }

      setState(() {
        _metrics = metrics ?? DashboardMetrics.empty;
        _chatCount = chatCount;
        _totalMessages = totalMessages;
        _weeklyMessages = weeklyMessages;
        _recentMembers = recentMembers;
        _quickLinksCount = quickLinksCount;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('[DashboardScreen] _load error: $e');
      debugPrint('[DashboardScreen] Stack: ${stack.toString().split('\n').take(5).join('\n')}');
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
    if (!mounted) return;
    final wasEditMode = _isEditMode;
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        // Reset to start before animating forward (fixes layout issues on re-entry)
        if (_flipController.value != 0.0) {
          _flipController.value = 0.0;
        }
        _flipController.forward();
        _showPalette = true;
      } else {
        // Reset to end before animating reverse (fixes layout issues on re-entry)
        if (_flipController.value != 1.0) {
          _flipController.value = 1.0;
        }
        _flipController.reverse();
        _showPalette = false;
      }
    });
    // Save config AFTER setState completes, and only when exiting edit mode
    if (wasEditMode && !_isEditMode) {
      _saveConfig();
    }
  }

  void _addWidget(DashboardDataSource source, DashboardWidgetType type) {
    _addWidgetAtIndex(source, type, _config.widgets.length);
  }

  void _addWidgetAtIndex(DashboardDataSource source, DashboardWidgetType type, int index) {
    if (!mounted) return;
    final newWidget = DashboardWidgetConfig(
      id: _uuid.v4(),
      type: type,
      size: _getSizeForType(type),
      dataSourceKey: source.key,
      title: source.label,
      icon: source.icon,
      gradientColors: WidgetGradients.random,
      gridX: 0,
      gridY: index,
    );

    setState(() {
      final widgetsList = List<DashboardWidgetConfig>.from(_config.widgets);
      widgetsList.insert(index.clamp(0, widgetsList.length), newWidget);
      // Update grid positions
      for (int i = 0; i < widgetsList.length; i++) {
        widgetsList[i] = widgetsList[i].copyWith(gridY: i);
      }
      _setConfig(DashboardConfig(id: _config.id, name: _config.name, widgets: widgetsList));
    });
  }

  void _removeWidget(String widgetId) {
    if (!mounted) return;
    setState(() {
      _setConfig(_config.copyWith(
        widgets: _config.widgets.where((w) => w.id != widgetId).toList(),
      ));
    });
  }

  void _updateWidget(DashboardWidgetConfig updated) {
    if (!mounted) return;
    setState(() {
      final currentWidgets = _config.widgets;
      _setConfig(_config.copyWith(
        widgets: currentWidgets.map((w) => w.id == updated.id ? updated : w).toList(),
      ));
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
      case DashboardWidgetType.memberList:
        return DashboardWidgetSize.medium;
      case DashboardWidgetType.heatmap:
      case DashboardWidgetType.dynamicDistribution:
        return DashboardWidgetSize.hero;
      case DashboardWidgetType.quickLinksButton:
        return DashboardWidgetSize.small;
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

  void _openQuickLinksPage(BuildContext context) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => const QuickLinksScreen(),
      ),
    ).then((_) {
      // Refresh quick links count when returning from the page
      _quickLinksRepo.countQuickLinks().then((count) {
        if (mounted) {
          setState(() => _quickLinksCount = count);
        }
      });
    });
  }

  void _openMemberDetail(BuildContext context, Member member) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: MemberDetailScreen(member: member),
        ),
      ),
    );
  }

  void _openDonorsScreen(BuildContext context) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: DonorsScreen(),
        ),
      ),
    );
  }

  void _openSubscribersScreen(BuildContext context) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: SubscribersScreen(),
        ),
      ),
    );
  }

  void _openSlackScreen(BuildContext context) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: SlackManagementScreen(),
        ),
      ),
    );
  }

  void _openSocialMediaStats(BuildContext context) {
    // Navigate to Communications committee with Social Media tab
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: CommitteeWorkspaceScreen(
            committee: CommitteeDefinitions.communications,
          ),
        ),
      ),
    );
  }

  void _openAIAssistant(BuildContext context) {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (_) => TitleBarWrapper(
          child: const AIAssistantScreen(),
        ),
      ),
    );
  }

  /// Returns the appropriate onTap handler for a given dataSourceKey
  VoidCallback? _getNavigationForDataSource(String dataSourceKey) {
    // Slack-related keys
    if (dataSourceKey.toLowerCase().contains('slack')) {
      return () => _openSlackScreen(context);
    }

    // Donor/donation-related keys
    if (dataSourceKey.toLowerCase().contains('donor') ||
        dataSourceKey.toLowerCase().contains('donation')) {
      return () => _openDonorsScreen(context);
    }

    // Subscriber-related keys
    if (dataSourceKey.toLowerCase().contains('subscriber')) {
      return () => _openSubscribersScreen(context);
    }

    // Chapter-related keys
    if (dataSourceKey.toLowerCase().contains('chapter')) {
      return () => _openMembersList(context, showChaptersOnly: true);
    }

    // Social media / impressions related keys
    if (dataSourceKey.toLowerCase().contains('social') ||
        dataSourceKey.toLowerCase().contains('impression')) {
      return () => _openSocialMediaStats(context);
    }

    // Member-related keys (default fallback for most stats)
    if (dataSourceKey.toLowerCase().contains('member') ||
        dataSourceKey.toLowerCase().contains('age') ||
        dataSourceKey.toLowerCase().contains('county') ||
        dataSourceKey.toLowerCase().contains('district') ||
        dataSourceKey.toLowerCase().contains('committee') ||
        dataSourceKey.toLowerCase().contains('college') ||
        dataSourceKey.toLowerCase().contains('highschool') ||
        dataSourceKey.toLowerCase().contains('graduation') ||
        dataSourceKey.toLowerCase().contains('education') ||
        dataSourceKey.toLowerCase().contains('gender') ||
        dataSourceKey.toLowerCase().contains('pronoun') ||
        dataSourceKey.toLowerCase().contains('race') ||
        dataSourceKey.toLowerCase().contains('orientation') ||
        dataSourceKey.toLowerCase().contains('voter') ||
        dataSourceKey.toLowerCase().contains('industry') ||
        dataSourceKey.toLowerCase().contains('referral') ||
        dataSourceKey.toLowerCase().contains('community')) {
      return () => _openMembersList(context);
    }

    // Event-related keys would go to events screen if we have one
    // For now, just return null (no navigation)
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in LayoutBuilder to get explicit constraints before the animation
    // This prevents "RenderBox was not laid out" errors on subsequent edit mode entries
    return LayoutBuilder(
      builder: (context, constraints) {
        // Validate constraints to prevent RenderBox errors during layout
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }

        // Cache the constraints for child widgets to use
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        return SizedBox(
          width: screenWidth,
          height: screenHeight,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final angle = _flipAnimation.value * math.pi;
                final isBack = angle > math.pi / 2;

                // Build the content widget based on animation state
                // Use a key to help Flutter reuse widgets without full rebuilds
                final Widget content;
                if (isBack) {
                  content = Transform(
                    key: const ValueKey('edit_transform'),
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildEditModeStable(screenWidth, screenHeight),
                  );
                } else {
                  content = KeyedSubtree(
                    key: const ValueKey('view_mode'),
                    child: _buildViewMode(),
                  );
                }

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: content,
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Build edit mode with stable constraints to prevent RenderBox errors
  /// This wrapper ensures the edit mode has fixed constraints regardless of animation state
  Widget _buildEditModeStable(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: _buildEditMode(),
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
        // Guard against invalid constraints during animation transitions
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final horizontalPadding = isMobile ? 12.0 : (isTablet ? 20.0 : 32.0);
        final columns = isMobile ? 2 : (isTablet ? 3 : 4);

        // Layout mode is now updated in didChangeDependencies to prevent
        // callback accumulation that was causing RenderBox layout errors

        return CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Header
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 12 : 24, horizontalPadding, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader(isMobile: isMobile)),
            ),
            // Widgets Grid - use swipeable rows on mobile
            SliverPadding(
              padding: EdgeInsets.all(horizontalPadding),
              sliver: SliverToBoxAdapter(
                child: isMobile
                    ? _buildMobileWidgetsGrid(metrics, constraints.maxWidth - horizontalPadding * 2)
                    : _buildWidgetsGrid(metrics, columns, constraints.maxWidth - horizontalPadding * 2),
              ),
            ),
            // Bottom padding for mobile
            if (isMobile)
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        );
      },
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    final theme = Theme.of(context);

    if (isMobile) {
      return Row(
        children: [
          Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _momentumBlue),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dashboard',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: _unityBlue,
              ),
            ),
          ),
          IconButton(
            tooltip: 'AI Assistant',
            icon: const Icon(Icons.psychology_outlined, color: _unityBlue, size: 22),
            onPressed: () => _openAIAssistant(context),
          ),
          IconButton(
            tooltip: 'Customize',
            icon: const Icon(Icons.edit_outlined, color: _unityBlue, size: 22),
            onPressed: _toggleEditMode,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: _unityBlue, size: 22),
            onPressed: _load,
          ),
        ],
      );
    }

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
          tooltip: 'AI Assistant',
          icon: const Icon(Icons.psychology_outlined, color: _unityBlue),
          onPressed: () => _openAIAssistant(context),
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
    // Guard against invalid dimensions
    if (maxWidth <= 0 || columns <= 0) {
      return const SizedBox.shrink();
    }

    final widgetWidth = ((maxWidth - 32 - (columns - 1) * 16) / columns).clamp(50.0, maxWidth);
    final widgetHeight = (widgetWidth * 0.8).clamp(50.0, maxWidth);

    // Guard against empty widgets list
    if (_config.widgets.isEmpty) {
      return Center(
        child: Text(
          'No widgets configured',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

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
          width: width.clamp(50.0, maxWidth),
          height: height.clamp(50.0, maxWidth * 2),
          child: _buildWidget(widget, metrics),
        );
      }).toList(),
    );
  }

  /// Build mobile-optimized grid with swipeable horizontal rows
  Widget _buildMobileWidgetsGrid(DashboardMetrics metrics, double maxWidth) {
    // Guard against invalid dimensions
    if (maxWidth <= 0) {
      return const SizedBox.shrink();
    }

    // Guard against empty widgets list
    if (_config.widgets.isEmpty) {
      return Center(
        child: Text(
          'No widgets configured',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final widgetWidth = (maxWidth * 0.42).clamp(80.0, maxWidth); // Each swipeable card is ~42% of width
    final widgetHeight = (widgetWidth * 0.9).clamp(80.0, maxWidth);
    final fullWidgetHeight = (maxWidth * 0.75).clamp(100.0, maxWidth * 2); // Height for full-width widgets (tall proportions)

    // Sort widgets by position
    final sortedWidgets = List<DashboardWidgetConfig>.from(_config.widgets)
      ..sort((a, b) {
        if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
        return a.gridX.compareTo(b.gridX);
      });

    // Group widgets: swipeable rows vs standalone
    final List<Widget> rows = [];
    final Map<String, List<DashboardWidgetConfig>> swipeRows = {};
    final List<DashboardWidgetConfig> standaloneWidgets = [];

    for (final widget in sortedWidgets) {
      if (widget.swipeRowId != null) {
        swipeRows.putIfAbsent(widget.swipeRowId!, () => []).add(widget);
      } else {
        standaloneWidgets.add(widget);
      }
    }

    // Build in order: process widgets in their gridY order
    final processedSwipeRows = <String>{};

    for (final widget in sortedWidgets) {
      final swipeId = widget.swipeRowId;
      if (swipeId != null) {
        // Check if we've already processed this swipe row
        if (!processedSwipeRows.contains(swipeId)) {
          processedSwipeRows.add(swipeId);
          final rowWidgets = swipeRows[swipeId];
          if (rowWidgets != null && rowWidgets.isNotEmpty) {
            rows.add(_buildSwipeableRow(rowWidgets, metrics, widgetWidth, widgetHeight));
          }
        }
      } else {
        // Standalone widget - use full width for mobileFull size
        final isMobileFull = widget.size == DashboardWidgetSize.mobileFull ||
            widget.size == DashboardWidgetSize.hero ||
            widget.size == DashboardWidgetSize.large;
        final height = isMobileFull ? fullWidgetHeight : widgetHeight;

        rows.add(SizedBox(
          width: maxWidth,
          height: height,
          child: _buildWidget(widget, metrics),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: row,
      )).toList(),
    );
  }

  /// Build a horizontally swipeable row of widgets
  Widget _buildSwipeableRow(List<DashboardWidgetConfig> widgets, DashboardMetrics metrics,
      double baseWidgetWidth, double baseWidgetHeight) {
    // Guard against empty widgets or invalid dimensions
    if (widgets.isEmpty || baseWidgetWidth <= 0 || baseWidgetHeight <= 0) {
      return const SizedBox.shrink();
    }

    // Determine row height based on the largest widget in the row
    double rowHeight = baseWidgetHeight;
    for (final widget in widgets) {
      final isLarge = widget.size == DashboardWidgetSize.large ||
          widget.size == DashboardWidgetSize.hero ||
          widget.size == DashboardWidgetSize.mobileFull;
      if (isLarge) {
        // Use a taller height for rows containing large widgets
        rowHeight = baseWidgetHeight * 1.8;
        break;
      } else if (widget.size == DashboardWidgetSize.medium) {
        // Medium widgets get slightly more height
        rowHeight = math.max(rowHeight, baseWidgetHeight * 1.3);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page indicator dots above the row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Swipe to see more',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.swipe, size: 14, color: Colors.grey[400]),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: widgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final widget = widgets[index];
              // Calculate width based on widget size
              double itemWidth = baseWidgetWidth;
              if (widget.size == DashboardWidgetSize.large ||
                  widget.size == DashboardWidgetSize.hero ||
                  widget.size == DashboardWidgetSize.mobileFull) {
                itemWidth = baseWidgetWidth * 1.8; // Larger width for large widgets
              } else if (widget.size == DashboardWidgetSize.medium) {
                itemWidth = baseWidgetWidth * 1.3; // Slightly larger for medium
              }
              return SizedBox(
                width: itemWidth,
                height: rowHeight,
                child: _buildWidget(widget, metrics),
              );
            },
          ),
        ),
      ],
    );
  }

  double _getWidgetWidth(DashboardWidgetConfig widget, double unitWidth, int columns) {
    // Use widthMultiplier for proper mini widget support (0.5 width)
    final spanWidth = widget.widthMultiplier.clamp(0.5, columns.toDouble());
    // For mini widgets (0.5), no gap adjustment needed
    final gapAdjustment = spanWidth >= 1 ? (spanWidth.floor() - 1) * 16.0 : 0.0;
    return unitWidth * spanWidth + gapAdjustment;
  }

  double _getWidgetHeight(DashboardWidgetConfig widget, double unitHeight) {
    // Use heightMultiplier for proper mini widget support (0.5 height)
    final spanHeight = widget.heightMultiplier;
    // For mini widgets (0.5), no gap adjustment needed
    final gapAdjustment = spanHeight >= 1 ? (spanHeight.floor() - 1) * 16.0 : 0.0;
    return unitHeight * spanHeight + gapAdjustment;
  }

  Widget _buildWidget(DashboardWidgetConfig config, DashboardMetrics metrics) {
    try {
      return _buildWidgetInternal(config, metrics);
    } catch (e, stackTrace) {
      debugPrint('[DashboardScreen] Error building widget ${config.id} (${config.type}): $e');
      debugPrint('[DashboardScreen] Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      return Card(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 32),
              const SizedBox(height: 8),
              Text(
                'Error loading widget',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${config.title}',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildWidgetInternal(DashboardWidgetConfig config, DashboardMetrics metrics) {
    final value = _getValueForDataSource(config.dataSourceKey, metrics);

    switch (config.type) {
      case DashboardWidgetType.statCard:
      case DashboardWidgetType.trendCard:
        return StatCardWidget(
          config: config,
          value: value,
          onTap: _getNavigationForDataSource(config.dataSourceKey),
        );

      case DashboardWidgetType.barChart:
        final data = _getDistributionData(config.dataSourceKey, metrics);
        return BarChartWidget(config: config, data: data);

      case DashboardWidgetType.lineChart:
        if (config.dataSourceKey == 'membersJoinedByMonth') {
          return LineChartWidget(config: config, data: metrics.membersJoinedByMonth);
        } else if (config.dataSourceKey == 'slackEngagementTrend') {
          return LineChartWidget(config: config, data: metrics.slackEngagementTrend);
        } else if (config.dataSourceKey == 'socialGrowthTrend') {
          return LineChartWidget(config: config, data: metrics.socialGrowthTrend);
        } else if (config.dataSourceKey == 'emailCampaignPerformance') {
          // Use existing monthly counts or create empty list
          return LineChartWidget(config: config, data: const []);
        }
        // Fallback: show bar chart for distribution data
        final data = _getDistributionData(config.dataSourceKey, metrics);
        if (data.isNotEmpty) {
          return BarChartWidget(config: config, data: data);
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
            onTap: _getNavigationForDataSource(config.dataSourceKey),
          );
        } else if (config.dataSourceKey == 'top50SlackMembers') {
          return LeaderboardWidget(
            config: config,
            data: metrics.top50SlackMembers,
            isDonors: false,
            onTap: _getNavigationForDataSource(config.dataSourceKey),
          );
        }
        return const SizedBox.shrink();

      case DashboardWidgetType.progressRing:
        final current = _getValueForDataSource(config.dataSourceKey, metrics);
        int total = 114; // Default for counties
        bool isPercentage = false;
        if (config.dataSourceKey == 'totalUniqueCongressionalDistricts') total = 8;
        if (config.dataSourceKey == 'totalUniqueHouseDistricts') total = 163;
        if (config.dataSourceKey == 'totalUniqueSenateDistricts') total = 34;
        // Handle percentage-based metrics
        if (config.dataSourceKey == 'socialEngagementRate' ||
            config.dataSourceKey == 'emailOpenRate' ||
            config.dataSourceKey == 'emailClickRate') {
          total = 100;
          isPercentage = true;
        }
        return ProgressRingWidget(
          config: config,
          current: isPercentage
              ? ((current is num) ? (current * 100).toInt() : 0)
              : ((current is num) ? current.toInt() : 0),
          total: total,
        );

      case DashboardWidgetType.sparkline:
      case DashboardWidgetType.heatmap:
        return Card(
          child: Center(child: Text(config.title)),
        );

      case DashboardWidgetType.memberList:
        return MemberListWidget(
          config: config,
          members: _recentMembers,
          onMemberTap: (member) => _openMemberDetail(context, member),
        );

      case DashboardWidgetType.dynamicDistribution:
        return DynamicDistributionChartWidget(
          config: config,
          metrics: metrics,
        );

      case DashboardWidgetType.quickLinksButton:
        return QuickLinksButtonWidget(
          config: config,
          linkCount: _quickLinksCount,
          onTap: () => _openQuickLinksPage(context),
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
      case 'slackMessagesThisWeek':
        return metrics.slackMessagesThisWeek;
      case 'slackActiveUsers':
        return metrics.slackActiveUsers;
      case 'totalSocialImpressions':
        return metrics.totalSocialImpressions;
      // Social Media stats
      case 'totalFollowers':
        return metrics.totalFollowers;
      case 'socialMediaReach':
        return metrics.socialMediaReach;
      case 'socialEngagementRate':
        return metrics.socialEngagementRate;
      // Legislation stats
      case 'totalBillsTracked':
        return metrics.totalBillsTracked;
      case 'billsSupported':
        return metrics.billsSupported;
      case 'billsOpposed':
        return metrics.billsOpposed;
      case 'priorityBills':
        return metrics.priorityBills;
      case 'legislativeActionsTaken':
        return metrics.legislativeActionsTaken;
      // Email Campaign stats
      case 'totalEmailsSent':
        return metrics.totalEmailsSent;
      case 'emailOpenRate':
        return metrics.averageOpenRate;
      case 'emailClickRate':
        return metrics.averageClickRate;
      case 'emailUnsubscribeRate':
        return 0; // Will be fetched from email_campaign_stats when available
      case 'emailsThisMonth':
        return metrics.totalEmailsSent; // Approximate - could be refined later
      case 'activeCampaigns':
        return metrics.totalCampaigns;
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
      // Slack Analytics distributions
      case 'slackChannelActivity':
        return metrics.slackChannelActivity;
      // Social Media distributions
      case 'followersByPlatform':
        return metrics.followersByPlatform;
      // Legislation distributions
      case 'billsByPosition':
        return metrics.billsByPosition;
      case 'billsByPriority':
        return metrics.billsByPriority;
      case 'billsByCategory':
        return metrics.billsByCategory;
      default:
        return [];
    }
  }

  Widget _buildEditMode() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Layout mode is now updated in didChangeDependencies to prevent
    // callback accumulation that was causing RenderBox layout errors

    // Simple edit mode structure like the legislation dashboard
    // No global error boundary - use local try-catch only where needed
    if (isMobile) {
      // Mobile: Use a bottom sheet for the palette
      return Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            _buildEditHeader(isMobile: true),
            Expanded(child: _buildEditableGrid()),
          ],
        ),
      );
    }

    // Desktop: Use sidebar layout
    return Container(
      color: Colors.grey[100],
      child: Row(
        children: [
          // Widget palette - only render when showing
          if (_showPalette)
            SizedBox(
              width: 300,
              child: _buildWidgetPaletteSafe(),
            ),
          // Main edit area
          Expanded(
            child: Column(
              children: [
                _buildEditHeader(isMobile: false),
                Expanded(child: _buildEditableGrid()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditModeError(String error) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Error loading edit mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                error,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Check the browser console for detailed diagnostics',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleEditMode,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Exit Edit Mode'),
            ),
          ],
        ),
      ),
    );
  }

  /// Safe version of _buildWidgetPalette with error handling and logging
  Widget _buildWidgetPaletteSafe() {
    try {
      debugPrint('[DashboardScreen] Building widget palette...');
      return _buildWidgetPalette();
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════════════════════════════════════════');
      debugPrint('║ WIDGET PALETTE ERROR');
      debugPrint('╠══════════════════════════════════════════════════════════════════════════════');
      debugPrint('║ Error: $e');
      debugPrint('║');
      debugPrint('║ Stack trace:');
      for (final line in stackTrace.toString().split('\n').take(20)) {
        if (line.contains('package:bluebubbles')) {
          debugPrint('║ >>> $line');
        } else {
          debugPrint('║     $line');
        }
      }
      debugPrint('╚══════════════════════════════════════════════════════════════════════════════');
      debugPrint('');

      return Container(
        width: 300,
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text('Error loading palette'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  e.toString(),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showMobilePalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.widgets, color: _unityBlue),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Widgets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _unityBlue,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Categories
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  children: DashboardDataCategory.values.map((category) {
                    final sources = DashboardDataSources.getByCategory(category);
                    if (sources.isEmpty) return const SizedBox.shrink();

                    return _buildMobilePaletteCategory(category, sources);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePaletteCategory(DashboardDataCategory category, List<DashboardDataSource> sources) {
    return Column(
      key: ValueKey('mobile_cat_${category.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            _getCategoryLabel(category),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _unityBlue,
            ),
          ),
        ),
        ...sources.map((source) => _buildMobilePaletteItem(source)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMobilePaletteItem(DashboardDataSource source) {
    return Card(
      key: ValueKey('mobile_item_${source.key}'),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(source.icon, color: _momentumBlue, size: 22),
        title: Text(source.label, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          source.description,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.add_circle, color: _grassrootsGreen),
        onTap: () {
          Navigator.pop(context);
          _showWidgetTypeSelector(source);
        },
      ),
    );
  }

  void _showWidgetTypeSelector(DashboardDataSource source) {
    if (source.supportedWidgets.length == 1) {
      _addWidget(source, source.supportedWidgets.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display "${source.label}" as:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: source.supportedWidgets.map((type) {
                return ActionChip(
                  avatar: Icon(_getWidgetTypeIcon(type), size: 18),
                  label: Text(_getWidgetTypeLabel(type)),
                  onPressed: () {
                    Navigator.pop(context);
                    _addWidget(source, type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEditHeader({required bool isMobile}) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_unityBlue, Color(0xFF1E2A45)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Cancel button
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                    label: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      _loadConfig();
                      _toggleEditMode();
                    },
                  ),
                  const Spacer(),
                  // Title
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.white70, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Editing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Save button - prominent
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _grassrootsGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _toggleEditMode,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Add widget button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Widget'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _showMobilePalette,
                  ),
                  const SizedBox(width: 12),
                  // Reset button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      setState(() {
                        // Reset to appropriate default based on current layout
                        _setConfig(_isMobileLayout ? _getDefaultMobileConfig() : _getDefaultConfig());
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Desktop header
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_unityBlue, Color(0xFF1E2A45)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Toggle palette button
          IconButton(
            icon: Icon(
              _showPalette ? Icons.chevron_left : Icons.menu,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showPalette = !_showPalette),
            tooltip: _showPalette ? 'Hide palette' : 'Show palette',
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  'Edit Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Customize your dashboard',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          // Reset button
          TextButton.icon(
            icon: const Icon(Icons.restore, color: Colors.white70, size: 18),
            label: const Text('Reset', style: TextStyle(color: Colors.white70)),
            onPressed: () {
              setState(() {
                // Reset to appropriate default based on current layout
                _setConfig(_isMobileLayout ? _getDefaultMobileConfig() : _getDefaultConfig());
              });
            },
          ),
          const SizedBox(width: 8),
          // Cancel button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _loadConfig();
              _toggleEditMode();
            },
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          // Save button - prominent
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Save & Exit', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _grassrootsGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetPalette() {
    try {
      final categories = DashboardDataCategory.values
          .where((c) {
            try {
              return DashboardDataSources.getByCategory(c).isNotEmpty;
            } catch (e) {
              debugPrint('Error checking category $c: $e');
              return false;
            }
          })
          .toList();

      return RepaintBoundary(
        child: Container(
        key: const ValueKey('widget_palette'),
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
              child: ListView.builder(
                key: const ValueKey('palette_list'),
                padding: const EdgeInsets.all(12),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  try {
                    final category = categories[index];
                    final sources = DashboardDataSources.getByCategory(category);

                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: ValueKey('category_${category.name}'),
                        title: Text(
                          _getCategoryLabel(category),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        initiallyExpanded: index == 0,
                        children: sources.map((source) {
                          return _buildPaletteItem(source);
                        }).toList(),
                      ),
                    );
                  } catch (e) {
                    return ListTile(
                      leading: const Icon(Icons.error_outline, color: Colors.red),
                      title: const Text('Error loading category'),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      );
    } catch (e) {
      // Return error state for the entire palette
      return Container(
        key: const ValueKey('widget_palette_error'),
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text('Error loading widget palette'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPaletteItem(DashboardDataSource source) {
    // Determine the widget type to use for dragging (use first supported or statCard as default)
    final defaultType = source.supportedWidgets.isNotEmpty
        ? source.supportedWidgets.first
        : DashboardWidgetType.statCard;

    // Store values locally to avoid closure issues
    final sourceIcon = source.icon;
    final sourceLabel = source.label;
    final sourceDescription = source.description;
    final sourceKey = source.key;
    final supportedWidgets = source.supportedWidgets;

    // Simple card without complex trailing widgets that can cause overlay issues
    final card = Card(
      key: ValueKey('palette_card_$sourceKey'),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          try {
            if (!mounted) return;
            // If multiple widget types, show a simple dialog
            if (supportedWidgets.length > 1) {
              _showWidgetTypeDialog(source);
            } else {
              // Single type or no types - just add directly
              _addWidget(source, defaultType);
            }
          } catch (e) {
            debugPrint('[DashboardScreen] Error handling palette item tap: $e');
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(sourceIcon, color: _momentumBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sourceLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      sourceDescription,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Simple add icon without tooltip to avoid overlay issues
              Icon(
                supportedWidgets.length > 1 ? Icons.add_circle_outline : Icons.add_circle,
                color: _grassrootsGreen,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );

    // Wrap in Draggable for drag-and-drop functionality
    return Draggable<_PaletteDragData>(
      key: ValueKey('draggable_palette_$sourceKey'),
      data: _PaletteDragData(source: source, type: defaultType),
      onDragStarted: () {
        try {
          if (mounted) _isDragging = true;
        } catch (e) {
          debugPrint('[DashboardScreen] Error in palette onDragStarted: $e');
        }
      },
      onDragEnd: (_) {
        try {
          if (mounted) _isDragging = false;
        } catch (e) {
          debugPrint('[DashboardScreen] Error in palette onDragEnd: $e');
        }
      },
      onDraggableCanceled: (_, __) {
        try {
          if (mounted) _isDragging = false;
        } catch (e) {
          debugPrint('[DashboardScreen] Error in palette onDraggableCanceled: $e');
        }
      },
      onDragCompleted: () {
        try {
          if (mounted) _isDragging = false;
        } catch (e) {
          debugPrint('[DashboardScreen] Error in palette onDragCompleted: $e');
        }
      },
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _momentumBlue, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sourceIcon, color: _momentumBlue, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sourceLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _unityBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: card,
      ),
      child: card,
    );
  }

  void _showWidgetTypeDialog(DashboardDataSource source) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add ${source.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: source.supportedWidgets.map((type) {
            return ListTile(
              leading: Icon(_getWidgetTypeIcon(type)),
              title: Text(_getWidgetTypeLabel(type)),
              onTap: () {
                Navigator.of(dialogContext).pop();
                _addWidget(source, type);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableGrid() {
    final metrics = _metrics ?? DashboardMetrics.empty;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against invalid constraints during animation transitions
        // This prevents "RenderBox was not laid out" errors
        if (!constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        final isMobile = constraints.maxWidth < 600;
        final columns = constraints.maxWidth > 800 ? 4 : 2;
        final widgetWidth = (constraints.maxWidth - 32 - (columns - 1) * 16) / columns;
        final widgetHeight = widgetWidth * 0.8;

        // Use the widget list order directly (no sorting by grid position)
        final widgets = _config.widgets;

        // Empty state - make it a drop target too
        if (widgets.isEmpty) {
          return DragTarget<_PaletteDragData>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              if (!mounted) return;
              _addWidgetAtIndex(details.data.source, details.data.type, 0);
              _isDragging = false;
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                decoration: isHovering
                    ? BoxDecoration(
                        border: Border.all(color: _momentumBlue, width: 3),
                        borderRadius: BorderRadius.circular(16),
                        color: _momentumBlue.withOpacity(0.1),
                      )
                    : null,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHovering ? Icons.add_box : Icons.widgets_outlined,
                          size: 64,
                          color: isHovering ? _momentumBlue : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isHovering ? 'Drop here to add' : 'No widgets added',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isHovering ? _momentumBlue : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isHovering)
                          Text(
                            isMobile
                                ? 'Tap "Add Widget" above to get started'
                                : 'Drag widgets from the palette or click to add',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Build the list of widgets with drop zones between them
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _momentumBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.drag_indicator, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMobile
                          ? 'Tap widgets to edit or reorder'
                          : 'Drag from palette to add, or tap widgets to edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Wrap layout with drop zones
              _buildWidgetsWithDropZones(widgets, metrics, widgetWidth, widgetHeight, columns),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetsWithDropZones(
    List<DashboardWidgetConfig> widgets,
    DashboardMetrics metrics,
    double widgetWidth,
    double widgetHeight,
    int columns,
  ) {
    // Build a list of widgets interleaved with drop zones
    final items = <Widget>[];

    // Add a drop zone at the beginning
    items.add(_buildReorderDropZone(0, widgetWidth));

    for (int i = 0; i < widgets.length; i++) {
      final widget = widgets[i];
      final width = _getWidgetWidth(widget, widgetWidth, columns);
      final height = _getWidgetHeight(widget, widgetHeight);

      // Make the widget draggable for reordering
      // Store widget info locally to avoid closure issues
      final widgetLabel = DashboardDataSources.getByKey(widget.dataSourceKey)?.label ?? widget.dataSourceKey;
      final widgetIcon = DashboardDataSources.getByKey(widget.dataSourceKey)?.icon ?? Icons.widgets;

      items.add(
        RepaintBoundary(
          child: LongPressDraggable<_WidgetReorderData>(
            key: ValueKey('draggable_${widget.id}'),
            data: _WidgetReorderData(fromIndex: i, config: widget),
            delay: const Duration(milliseconds: 150),
            hapticFeedbackOnStart: true,
            onDragStarted: () {
              try {
                if (mounted) _isDragging = true;
              } catch (e) {
                debugPrint('[DashboardScreen] Error in onDragStarted: $e');
              }
            },
            onDragEnd: (_) {
              try {
                if (mounted) _isDragging = false;
              } catch (e) {
                debugPrint('[DashboardScreen] Error in onDragEnd: $e');
              }
            },
            onDraggableCanceled: (_, __) {
              try {
                if (mounted) _isDragging = false;
              } catch (e) {
                debugPrint('[DashboardScreen] Error in onDraggableCanceled: $e');
              }
            },
            onDragCompleted: () {
              try {
                if (mounted) _isDragging = false;
              } catch (e) {
                debugPrint('[DashboardScreen] Error in onDragCompleted: $e');
              }
            },
            feedback: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: width * 0.8,
                height: 80,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _momentumBlue, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _momentumBlue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widgetIcon, color: _momentumBlue, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widgetLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _unityBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: SizedBox(
                width: width,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _momentumBlue.withOpacity(0.5),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
              ),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: _buildEditableWidget(widget, metrics, i),
            ),
          ),
        ),
      );

      // Add drop zone after each widget
      items.add(_buildReorderDropZone(i + 1, widgetWidth));
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: items,
    );
  }

  Widget _buildReorderDropZone(int insertIndex, double widgetWidth) {
    return DragTarget<Object>(
      key: ValueKey('drop_zone_$insertIndex'),
      onWillAcceptWithDetails: (details) {
        // Accept both palette items and widget reorders
        final data = details.data;
        return data is _PaletteDragData || data is _WidgetReorderData;
      },
      onAcceptWithDetails: (details) {
        // Ensure widget is still mounted before handling drop
        // Wrap in try-catch to prevent gesture-related null errors
        try {
          if (!mounted) return;
          final data = details.data;
          if (data is _PaletteDragData) {
            _addWidgetAtIndex(data.source, data.type, insertIndex);
          } else if (data is _WidgetReorderData) {
            _reorderWidgetToIndex(data.fromIndex, insertIndex);
          }
          // Reset drag state after drop
          _isDragging = false;
        } catch (e) {
          debugPrint('[DashboardScreen] Error in onAcceptWithDetails: $e');
          _isDragging = false;
        }
      },
      // Removed onMove/onLeave setState calls that were causing RenderBox layout errors
      // The DragTarget's candidateData already tracks hover state without needing _dragHoverIndex
      builder: (context, candidateData, rejectedData) {
        // Use candidateData.isNotEmpty directly - no need for _dragHoverIndex
        final isHovering = candidateData.isNotEmpty;
        final isPaletteItem = candidateData.any((d) => d is _PaletteDragData);
        final isReorder = candidateData.any((d) => d is _WidgetReorderData);

        // Show expanded drop zone when dragging
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: isHovering ? widgetWidth * 0.4 : 8,
          height: isHovering ? 80 : 60,
          margin: EdgeInsets.symmetric(horizontal: isHovering ? 4 : 0),
          decoration: BoxDecoration(
            color: isHovering
                ? (isReorder ? _grassrootsGreen.withOpacity(0.15) : _momentumBlue.withOpacity(0.15))
                : Colors.transparent,
            border: Border.all(
              color: isHovering
                  ? (isReorder ? _grassrootsGreen : _momentumBlue)
                  : Colors.grey.withOpacity(0.3),
              width: isHovering ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(isHovering ? 12 : 4),
          ),
          child: isHovering
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReorder ? Icons.swap_vert : Icons.add,
                        color: isReorder ? _grassrootsGreen : _momentumBlue,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isReorder ? 'Drop here' : 'Add here',
                        style: TextStyle(
                          color: isReorder ? _grassrootsGreen : _momentumBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildEditableWidget(DashboardWidgetConfig config, DashboardMetrics metrics, int index) {
    return Stack(
      children: [
        // The actual widget
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildWidget(config, metrics),
        ),
        // Tap overlay for editing options - use translucent behavior to not block parent gestures
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Guard against gesture callbacks during invalid states
              // This prevents "Null check operator used on a null value" errors
              try {
                if (_isDragging || !mounted) return;
                _showWidgetOptions(config, index);
              } catch (e) {
                debugPrint('[DashboardScreen] Error handling tap: $e');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _momentumBlue.withOpacity(0.5), width: 2),
              ),
            ),
          ),
        ),
        // Position indicator
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _momentumBlue,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Drag handle indicator
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_indicator, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Hold to drag',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Settings button
        Positioned(
          top: 4,
          right: 36,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                try {
                  if (_isDragging || !mounted) return;
                  _showWidgetOptions(config);
                } catch (e) {
                  debugPrint('[DashboardScreen] Error handling settings tap: $e');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.settings, size: 14, color: _momentumBlue),
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
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                try {
                  if (_isDragging || !mounted) return;
                  _removeWidget(config.id);
                } catch (e) {
                  debugPrint('[DashboardScreen] Error handling delete tap: $e');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, size: 14, color: _actionRed),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: _momentumBlue),
          ),
        ),
      ),
    );
  }

  void _moveWidget(int fromIndex, int toIndex) {
    if (!mounted) return;
    if (fromIndex == toIndex) return;
    final currentWidgets = _config.widgets;
    if (fromIndex < 0 || fromIndex >= currentWidgets.length) return;
    setState(() {
      final widgetsList = List<DashboardWidgetConfig>.from(currentWidgets);
      final item = widgetsList.removeAt(fromIndex);
      // Adjust toIndex if needed after removal
      final adjustedTo = fromIndex < toIndex ? toIndex - 1 : toIndex;
      widgetsList.insert(adjustedTo.clamp(0, widgetsList.length), item);
      // Update grid positions
      for (int i = 0; i < widgetsList.length; i++) {
        widgetsList[i] = widgetsList[i].copyWith(gridY: i);
      }
      _setConfig(DashboardConfig(id: _config.id, name: _config.name, widgets: widgetsList));
    });
    _saveConfig();
  }

  void _reorderWidgetToIndex(int fromIndex, int toIndex) {
    if (!mounted) return;
    if (fromIndex == toIndex || fromIndex == toIndex - 1) return;
    final currentWidgets = _config.widgets;
    if (fromIndex < 0 || fromIndex >= currentWidgets.length) return;
    setState(() {
      final widgetsList = List<DashboardWidgetConfig>.from(currentWidgets);
      final item = widgetsList.removeAt(fromIndex);
      // Adjust target index after removal
      final adjustedTo = fromIndex < toIndex ? toIndex - 1 : toIndex;
      widgetsList.insert(adjustedTo.clamp(0, widgetsList.length), item);
      // Update grid positions
      for (int i = 0; i < widgetsList.length; i++) {
        widgetsList[i] = widgetsList[i].copyWith(gridY: i);
      }
      _setConfig(DashboardConfig(id: _config.id, name: _config.name, widgets: widgetsList));
    });
    _saveConfig();
  }

  void _showWidgetOptions(DashboardWidgetConfig config, [int? index]) {
    if (!mounted) return;
    final source = DashboardDataSources.getByKey(config.dataSourceKey);
    final currentGradientIndex = WidgetGradients.indexOfColors(config.gradientColors);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  const Text('Color:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: WidgetGradients.all.length,
                    itemBuilder: (context, index) {
                      final gradient = WidgetGradients.all[index];
                      final isSelected = currentGradientIndex == index;
                      return GestureDetector(
                        onTap: () {
                          _updateWidget(config.copyWith(gradientColors: gradient));
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: gradient.last.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check, color: Colors.white, size: 24),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (currentGradientIndex != null)
                    Center(
                      child: Text(
                        WidgetGradients.names[currentGradientIndex],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  // Background color selection for widgets with white backgrounds
                  if (_widgetSupportsBackgroundColor(config.type)) ...[
                    const SizedBox(height: 20),
                    const Text('Background:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: WidgetBackgrounds.solidColors.length,
                      itemBuilder: (context, index) {
                        final color = WidgetBackgrounds.solidColors[index] ?? Colors.white;
                        final currentBgIndex = config.options['backgroundColorIndex'] as int? ?? 0;
                        final isSelected = currentBgIndex == index;
                        return GestureDetector(
                          onTap: () {
                            final newOptions = Map<String, dynamic>.from(config.options);
                            newOptions['backgroundColorIndex'] = index;
                            _updateWidget(config.copyWith(options: newOptions));
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? _momentumBlue : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Center(
                                    child: Icon(
                                      Icons.check,
                                      color: index == WidgetBackgrounds.solidColors.length - 1
                                          ? Colors.white
                                          : _momentumBlue,
                                      size: 20,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        WidgetBackgrounds.colorNames[config.options['backgroundColorIndex'] as int? ?? 0],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Swipe Row options (mobile only)
                  if (_isMobileLayout) ...[
                    const Text('Swipe Row:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _buildSwipeRowOptions(config),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Build swipe row options for mobile widget customization
  Widget _buildSwipeRowOptions(DashboardWidgetConfig config) {
    // Get all existing swipe row IDs
    final existingRows = _getExistingSwipeRows();
    final currentRowId = config.swipeRowId;
    final isInSwipeRow = currentRowId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current status
        if (isInSwipeRow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _momentumBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _momentumBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swipe, size: 18, color: _momentumBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'In swipe row: ${_getSwipeRowDisplayName(currentRowId)}',
                    style: const TextStyle(fontSize: 13, color: _momentumBlue),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: _actionRed,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    _removeWidgetFromSwipeRow(config);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Not in a swipe row',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ),

        // Existing rows to join
        if (existingRows.isNotEmpty) ...[
          const Text('Add to existing row:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: existingRows.map((rowId) {
              final isCurrentRow = rowId == currentRowId;
              final rowSize = _getSwipeRowSize(rowId);
              return ActionChip(
                avatar: Icon(
                  isCurrentRow ? Icons.check : Icons.add,
                  size: 16,
                  color: isCurrentRow ? _grassrootsGreen : _momentumBlue,
                ),
                label: Text(
                  '${_getSwipeRowDisplayName(rowId)} (${_getSizeLabel(rowSize)})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrentRow ? _grassrootsGreen : null,
                  ),
                ),
                backgroundColor: isCurrentRow ? _grassrootsGreen.withOpacity(0.1) : null,
                onPressed: isCurrentRow ? null : () {
                  _addWidgetToSwipeRow(config, rowId);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Create new row button
        OutlinedButton.icon(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Create new swipe row'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _grassrootsGreen,
            side: const BorderSide(color: _grassrootsGreen),
          ),
          onPressed: () {
            Navigator.pop(context);
            _showCreateSwipeRowDialog(config);
          },
        ),
      ],
    );
  }

  /// Get list of existing swipe row IDs
  List<String> _getExistingSwipeRows() {
    final rowIds = <String>{};
    for (final widget in _mobileConfig.widgets) {
      if (widget.swipeRowId != null) {
        rowIds.add(widget.swipeRowId!);
      }
    }
    return rowIds.toList()..sort();
  }

  /// Get display name for a swipe row
  String _getSwipeRowDisplayName(String rowId) {
    // Count widgets in this row for the display name
    final widgetCount = _mobileConfig.widgets.where((w) => w.swipeRowId == rowId).length;
    // Try to make a friendlier name
    if (rowId.startsWith('stats_row_')) {
      final num = rowId.replaceFirst('stats_row_', '');
      return 'Stats Row $num ($widgetCount items)';
    }
    if (rowId.startsWith('swipe_row_')) {
      final num = rowId.replaceFirst('swipe_row_', '');
      return 'Swipe Row $num ($widgetCount items)';
    }
    return '$rowId ($widgetCount items)';
  }

  /// Get the size of widgets in a swipe row
  DashboardWidgetSize _getSwipeRowSize(String rowId) {
    final rowWidgets = _mobileConfig.widgets.where((w) => w.swipeRowId == rowId).toList();
    if (rowWidgets.isEmpty) return DashboardWidgetSize.small;
    return rowWidgets.first.size;
  }

  /// Add a widget to an existing swipe row (preserving its size)
  void _addWidgetToSwipeRow(DashboardWidgetConfig config, String rowId) {
    if (!mounted) return;

    // Preserve the widget's original size - the swipe row will adapt to show
    // widgets of different sizes (small, medium, large all supported)
    setState(() {
      final updatedWidget = config.copyWith(
        swipeRowId: rowId,
        // Don't change size - keep widget's original size
      );
      final widgetsList = _mobileConfig.widgets.map((w) =>
        w.id == config.id ? updatedWidget : w
      ).toList();
      _mobileConfig = _mobileConfig.copyWith(widgets: widgetsList);
    });
    _saveConfig();
  }

  /// Remove a widget from its swipe row
  void _removeWidgetFromSwipeRow(DashboardWidgetConfig config) {
    if (!mounted) return;

    setState(() {
      final updatedWidget = config.copyWith(clearSwipeRowId: true);
      final widgetsList = _mobileConfig.widgets.map((w) =>
        w.id == config.id ? updatedWidget : w
      ).toList();
      _mobileConfig = _mobileConfig.copyWith(widgets: widgetsList);
    });
    _saveConfig();
  }

  /// Show dialog to create a new swipe row
  void _showCreateSwipeRowDialog(DashboardWidgetConfig config) {
    // Generate a new unique row ID
    final existingRows = _getExistingSwipeRows();
    int nextNum = 1;
    while (existingRows.contains('swipe_row_$nextNum')) {
      nextNum++;
    }
    final newRowId = 'swipe_row_$nextNum';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swipe, color: _momentumBlue),
            SizedBox(width: 12),
            Text('Create Swipe Row'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will create a new swipe row containing "${config.title}".',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _momentumBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: _momentumBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The widget\'s current size (${_getSizeLabel(config.size)}) will be the row size. Other widgets added to this row will be resized to match.',
                      style: const TextStyle(fontSize: 12, color: _momentumBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Create Row'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _grassrootsGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _createNewSwipeRow(config, newRowId);
            },
          ),
        ],
      ),
    );
  }

  /// Create a new swipe row with the given widget
  void _createNewSwipeRow(DashboardWidgetConfig config, String rowId) {
    if (!mounted) return;

    setState(() {
      // The widget keeps its current size (which becomes the row's size)
      final updatedWidget = config.copyWith(swipeRowId: rowId);
      final widgetsList = _mobileConfig.widgets.map((w) =>
        w.id == config.id ? updatedWidget : w
      ).toList();
      _mobileConfig = _mobileConfig.copyWith(widgets: widgetsList);
    });
    _saveConfig();
  }

  /// Check if widget type supports background color customization
  bool _widgetSupportsBackgroundColor(DashboardWidgetType type) {
    switch (type) {
      case DashboardWidgetType.barChart:
      case DashboardWidgetType.lineChart:
      case DashboardWidgetType.pieChart:
      case DashboardWidgetType.donutChart:
      case DashboardWidgetType.leaderboard:
      case DashboardWidgetType.progressRing:
      case DashboardWidgetType.memberList:
      case DashboardWidgetType.dynamicDistribution:
        return true;
      case DashboardWidgetType.statCard:
      case DashboardWidgetType.trendCard:
      case DashboardWidgetType.sparkline:
      case DashboardWidgetType.heatmap:
      case DashboardWidgetType.quickLinksButton:
        return false;
    }
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
      case DashboardDataCategory.resources:
        return 'Resources';
      case DashboardDataCategory.legislation:
        return 'Legislation';
      case DashboardDataCategory.socialMedia:
        return 'Social Media';
      case DashboardDataCategory.email:
        return 'Email Campaigns';
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
      case DashboardWidgetType.memberList:
        return 'Member List';
      case DashboardWidgetType.dynamicDistribution:
        return 'Distribution Explorer';
      case DashboardWidgetType.quickLinksButton:
        return 'Quick Links';
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
      case DashboardWidgetType.memberList:
        return Icons.people;
      case DashboardWidgetType.dynamicDistribution:
        return Icons.analytics;
      case DashboardWidgetType.quickLinksButton:
        return Icons.link;
    }
  }

  String _getSizeLabel(DashboardWidgetSize size) {
    switch (size) {
      case DashboardWidgetSize.mini:
        return 'Mini';
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
      case DashboardWidgetSize.mobileFull:
        return 'Mobile Full';
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
              _error ?? 'An unexpected error occurred',
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
