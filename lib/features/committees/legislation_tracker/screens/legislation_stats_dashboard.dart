import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../services/committee_repository.dart';
import '../models/legislation_widget_config.dart';
import '../providers/legislation_provider.dart';
import '../screens/bill_detail_screen.dart';
import '../screens/legislator_detail_screen.dart';
import '../screens/legislation_tracker_screen.dart';
import '../services/legislation_service.dart';
import '../widgets/legislation_dashboard_widgets.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

// Party colors
const _democratBlue = Color(0xFF3B82F6);
const _republicanRed = Color(0xFFEF4444);

/// Data class for dragging widgets from the palette
class _PaletteDragData {
  final LegislationDataSource source;
  final LegislationWidgetType type;

  const _PaletteDragData({required this.source, required this.type});
}

/// Data class for reordering existing widgets
class _WidgetReorderData {
  final int fromIndex;
  final LegislationWidgetConfig config;

  const _WidgetReorderData({required this.fromIndex, required this.config});
}

class LegislationStatsDashboard extends StatefulWidget {
  final String committeeId;
  final bool isExecutive;

  const LegislationStatsDashboard({
    super.key,
    required this.committeeId,
    required this.isExecutive,
  });

  @override
  State<LegislationStatsDashboard> createState() =>
      _LegislationStatsDashboardState();
}

class _LegislationStatsDashboardState extends State<LegislationStatsDashboard>
    with SingleTickerProviderStateMixin {
  final LegislationService _service = LegislationService();
  final CommitteeRepository _committeeRepository = CommitteeRepository();
  final Uuid _uuid = const Uuid();

  LegislationStats? _stats;
  bool _loading = true;
  String? _error;

  // Edit mode state
  bool _isEditMode = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showPalette = false;
  int? _dragHoverIndex;
  bool _isDragging = false;

  // Dashboard configuration (separate for desktop and mobile)
  LegislationDashboardConfig _desktopConfig = _getDefaultConfig();
  LegislationDashboardConfig _mobileConfig = _getDefaultMobileConfig();
  bool _isMobileLayout = false;

  LegislationDashboardConfig get _config =>
      _isMobileLayout ? _mobileConfig : _desktopConfig;

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
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    _isMobileLayout = screenWidth < 768;
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  static LegislationDashboardConfig _getDefaultConfig() {
    return LegislationDashboardConfig(
      id: 'legislation_default',
      name: 'Legislation Dashboard',
      columns: 4,
      widgets: [
        // Row 1: Key stats (4 small cards)
        LegislationWidgetConfig(
          id: 'active_bills',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'totalActiveBills',
          title: 'Active Bills',
          icon: Icons.gavel,
          gradientColors: [_unityBlue, _momentumBlue],
          gridX: 0,
          gridY: 0,
        ),
        LegislationWidgetConfig(
          id: 'support_count',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'supportCount',
          title: 'Supporting',
          icon: Icons.thumb_up,
          gradientColors: [_grassrootsGreen, _momentumBlue],
          gridX: 1,
          gridY: 0,
        ),
        LegislationWidgetConfig(
          id: 'oppose_count',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'opposeCount',
          title: 'Opposing',
          icon: Icons.thumb_down,
          gradientColors: [_republicanRed, _sunriseGold],
          gridX: 2,
          gridY: 0,
        ),
        LegislationWidgetConfig(
          id: 'watching_count',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'watchingCount',
          title: 'Watching',
          icon: Icons.visibility,
          gradientColors: [_sunriseGold, _democratBlue],
          gridX: 3,
          gridY: 0,
        ),

        // Row 2-3: Party comparison (hero size)
        LegislationWidgetConfig(
          id: 'party_comparison',
          type: LegislationWidgetType.partyComparison,
          size: LegislationWidgetSize.hero,
          dataSourceKey: 'partySponsorship',
          title: 'Party Sponsorship',
          icon: Icons.compare_arrows,
          gridX: 0,
          gridY: 1,
        ),

        // Row 4-5: Position pie + Priority donut (large, side by side)
        LegislationWidgetConfig(
          id: 'position_pie',
          type: LegislationWidgetType.pieChart,
          size: LegislationWidgetSize.large,
          dataSourceKey: 'positionBreakdown',
          title: 'Bill Positions',
          icon: Icons.pie_chart,
          gridX: 0,
          gridY: 3,
        ),
        LegislationWidgetConfig(
          id: 'priority_pie',
          type: LegislationWidgetType.donutChart,
          size: LegislationWidgetSize.large,
          dataSourceKey: 'priorityBreakdown',
          title: 'Priority Levels',
          icon: Icons.flag,
          gridX: 2,
          gridY: 3,
        ),

        // Row 6-7: Leaderboards with photos (medium, side by side)
        LegislationWidgetConfig(
          id: 'dem_leaderboard',
          type: LegislationWidgetType.leaderboard,
          size: LegislationWidgetSize.medium,
          dataSourceKey: 'top10DemocratSponsors',
          title: 'Top Democrat Sponsors',
          icon: Icons.emoji_events,
          gradientColors: [_democratBlue, _momentumBlue],
          gridX: 0,
          gridY: 5,
        ),
        LegislationWidgetConfig(
          id: 'rep_leaderboard',
          type: LegislationWidgetType.leaderboard,
          size: LegislationWidgetSize.medium,
          dataSourceKey: 'top10RepublicanSponsors',
          title: 'Top Republican Sponsors',
          icon: Icons.emoji_events,
          gradientColors: [_republicanRed, _sunriseGold],
          gridX: 2,
          gridY: 5,
        ),

        // Row 8: AI Progress + Activity stats
        LegislationWidgetConfig(
          id: 'ai_progress',
          type: LegislationWidgetType.progressRing,
          size: LegislationWidgetSize.medium,
          dataSourceKey: 'aiAnalysisProgress',
          title: 'AI Analysis',
          subtitle: 'Bills analyzed',
          icon: Icons.psychology,
          gradientColors: [_justicePurple, _momentumBlue],
          gridX: 0,
          gridY: 6,
        ),
        LegislationWidgetConfig(
          id: 'actions_week',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'actionsThisWeek',
          title: 'Actions This Week',
          icon: Icons.bolt,
          gradientColors: [_grassrootsGreen, _sunriseGold],
          gridX: 2,
          gridY: 6,
        ),
        LegislationWidgetConfig(
          id: 'bills_week',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'billsIntroducedThisWeek',
          title: 'Bills This Week',
          icon: Icons.trending_up,
          gradientColors: [_momentumBlue, _unityBlue],
          gridX: 3,
          gridY: 6,
        ),
      ],
    );
  }

  static LegislationDashboardConfig _getDefaultMobileConfig() {
    return LegislationDashboardConfig(
      id: 'legislation_default_mobile',
      name: 'Mobile Legislation Dashboard',
      columns: 2,
      widgets: [
        // Swipeable stats row
        LegislationWidgetConfig(
          id: 'mobile_active',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'totalActiveBills',
          title: 'Active Bills',
          icon: Icons.gavel,
          gradientColors: [_unityBlue, _momentumBlue],
          gridX: 0,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        LegislationWidgetConfig(
          id: 'mobile_support',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'supportCount',
          title: 'Supporting',
          icon: Icons.thumb_up,
          gradientColors: [_grassrootsGreen, _momentumBlue],
          gridX: 1,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        LegislationWidgetConfig(
          id: 'mobile_oppose',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'opposeCount',
          title: 'Opposing',
          icon: Icons.thumb_down,
          gradientColors: [_republicanRed, _sunriseGold],
          gridX: 2,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),
        LegislationWidgetConfig(
          id: 'mobile_watching',
          type: LegislationWidgetType.statCard,
          size: LegislationWidgetSize.small,
          dataSourceKey: 'watchingCount',
          title: 'Watching',
          icon: Icons.visibility,
          gradientColors: [_sunriseGold, _democratBlue],
          gridX: 3,
          gridY: 0,
          swipeRowId: 'stats_row_1',
        ),

        // Party comparison
        LegislationWidgetConfig(
          id: 'mobile_party',
          type: LegislationWidgetType.partyComparison,
          size: LegislationWidgetSize.mobileFull,
          dataSourceKey: 'partySponsorship',
          title: 'Party Sponsorship',
          icon: Icons.compare_arrows,
          gridX: 0,
          gridY: 1,
        ),

        // Position chart
        LegislationWidgetConfig(
          id: 'mobile_position',
          type: LegislationWidgetType.pieChart,
          size: LegislationWidgetSize.mobileFull,
          dataSourceKey: 'positionBreakdown',
          title: 'Bill Positions',
          icon: Icons.pie_chart,
          gridX: 0,
          gridY: 2,
        ),

        // Leaderboards
        LegislationWidgetConfig(
          id: 'mobile_dem_leader',
          type: LegislationWidgetType.leaderboard,
          size: LegislationWidgetSize.mobileFull,
          dataSourceKey: 'top10DemocratSponsors',
          title: 'Top Democrat Sponsors',
          icon: Icons.emoji_events,
          gradientColors: [_democratBlue, _momentumBlue],
          gridX: 0,
          gridY: 3,
        ),
        LegislationWidgetConfig(
          id: 'mobile_rep_leader',
          type: LegislationWidgetType.leaderboard,
          size: LegislationWidgetSize.mobileFull,
          dataSourceKey: 'top10RepublicanSponsors',
          title: 'Top Republican Sponsors',
          icon: Icons.emoji_events,
          gradientColors: [_republicanRed, _sunriseGold],
          gridX: 0,
          gridY: 4,
        ),
      ],
    );
  }

  Future<void> _loadConfig() async {
    try {
      // Load layouts from Supabase (shared across all users for this committee)
      final layouts = await _committeeRepository.getLegislationDashboardLayouts(
        widget.committeeId,
      );

      final desktopConfig = layouts['desktop'];
      final mobileConfig = layouts['mobile'];

      if (desktopConfig != null) {
        _desktopConfig = LegislationDashboardConfig.fromJson(desktopConfig);
      }
      if (mobileConfig != null) {
        _mobileConfig = LegislationDashboardConfig.fromJson(mobileConfig);
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading legislation dashboard config: $e');
    }
  }

  Future<void> _saveConfig() async {
    // Only executives can save layout changes
    if (!widget.isExecutive) return;

    try {
      // Save desktop and mobile configs separately to Supabase
      if (_isMobileLayout) {
        await _committeeRepository.updateLegislationDashboardMobileLayout(
          widget.committeeId,
          _mobileConfig.toJson(),
        );
      } else {
        await _committeeRepository.updateLegislationDashboardDesktopLayout(
          widget.committeeId,
          _desktopConfig.toJson(),
        );
      }
    } catch (e) {
      debugPrint('Error saving legislation dashboard config: $e');
    }
  }

  void _setConfig(LegislationDashboardConfig config) {
    if (_isMobileLayout) {
      _mobileConfig = config;
    } else {
      _desktopConfig = config;
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var stats = await _service.getCachedStatistics();

      // Enrich leaderboard entries with photo URLs
      final enrichedDemSponsors = await _service.enrichLeaderboardWithPhotos(
        stats.top10DemocratPrimarySponsors,
      );
      final enrichedRepSponsors = await _service.enrichLeaderboardWithPhotos(
        stats.top10RepublicanPrimarySponsors,
      );
      final enrichedDemCosponsors = await _service.enrichLeaderboardWithPhotos(
        stats.top10DemocratCosponsors,
      );
      final enrichedRepCosponsors = await _service.enrichLeaderboardWithPhotos(
        stats.top10RepublicanCosponsors,
      );

      // Create new stats with enriched leaderboards
      stats = stats.copyWith(
        top10DemocratPrimarySponsors: enrichedDemSponsors,
        top10RepublicanPrimarySponsors: enrichedRepSponsors,
        top10DemocratCosponsors: enrichedDemCosponsors,
        top10RepublicanCosponsors: enrichedRepCosponsors,
      );

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ======== NAVIGATION ========

  void _navigateToBillDetail(String billId) {
    if (!mounted) return;
    final provider = _getOrCreateProvider();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: BillDetailScreen(
            billId: billId,
            committeeId: widget.committeeId,
          ),
        ),
      ),
    );
  }

  void _navigateToLegislatorDetail(String legislatorId) {
    if (!mounted) return;
    final provider = _getOrCreateProvider();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: LegislatorDetailScreen(
            legislatorId: legislatorId,
            committeeId: widget.committeeId,
          ),
        ),
      ),
    );
  }

  void _navigateToFilteredBillList({String? position, String? priority}) {
    if (!mounted) return;
    final provider = _getOrCreateProvider();

    // Pre-apply filters before navigation if specified
    if (position != null) {
      provider.setPositionFilter(position);
    }
    if (priority != null) {
      provider.setPriorityFilter(priority);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: LegislationTrackerScreen(committeeId: widget.committeeId),
        ),
      ),
    );
  }

  LegislationProvider? _cachedProvider;

  LegislationProvider _getOrCreateProvider() {
    _cachedProvider ??= LegislationProvider();
    return _cachedProvider!;
  }

  void _handleStatCardTap(String dataSourceKey) {
    // Navigate based on the stat card type
    switch (dataSourceKey) {
      case 'supportCount':
        _navigateToFilteredBillList(position: 'support');
        break;
      case 'opposeCount':
        _navigateToFilteredBillList(position: 'oppose');
        break;
      case 'watchingCount':
        _navigateToFilteredBillList(position: 'watching');
        break;
      case 'neutralCount':
        _navigateToFilteredBillList(position: 'neutral');
        break;
      case 'noPositionCount':
        _navigateToFilteredBillList(position: 'none');
        break;
      case 'criticalCount':
        _navigateToFilteredBillList(priority: 'critical');
        break;
      case 'highCount':
        _navigateToFilteredBillList(priority: 'high');
        break;
      case 'mediumCount':
        _navigateToFilteredBillList(priority: 'medium');
        break;
      case 'lowCount':
        _navigateToFilteredBillList(priority: 'low');
        break;
      default:
        // Navigate to the main bill list for other stats
        _navigateToFilteredBillList();
    }
  }

  void _handleChartTap(String dataSourceKey) {
    // Navigate to the main bill list for chart taps
    // Could be enhanced to show specific filtered views based on chart type
    _navigateToFilteredBillList();
  }

  void _toggleEditMode() {
    if (!mounted) return;
    final wasEditMode = _isEditMode;
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        if (_flipController.value != 0.0) {
          _flipController.value = 0.0;
        }
        _flipController.forward();
        _showPalette = true;
      } else {
        if (_flipController.value != 1.0) {
          _flipController.value = 1.0;
        }
        _flipController.reverse();
        _showPalette = false;
      }
    });
    if (wasEditMode && !_isEditMode) {
      _saveConfig();
    }
  }

  void _addWidget(LegislationDataSource source, LegislationWidgetType type) {
    _addWidgetAtIndex(source, type, _config.widgets.length);
  }

  void _addWidgetAtIndex(
    LegislationDataSource source,
    LegislationWidgetType type,
    int index,
  ) {
    if (!mounted) return;
    final newWidget = LegislationWidgetConfig(
      id: _uuid.v4(),
      type: type,
      size: _getSizeForType(type),
      dataSourceKey: source.key,
      title: source.label,
      icon: source.icon,
      gradientColors: LegislationWidgetGradients.all[0],
      gridX: 0,
      gridY: index,
    );

    setState(() {
      final widgetsList = List<LegislationWidgetConfig>.from(_config.widgets);
      widgetsList.insert(index.clamp(0, widgetsList.length), newWidget);
      for (int i = 0; i < widgetsList.length; i++) {
        widgetsList[i] = widgetsList[i].copyWith(gridY: i);
      }
      _setConfig(
        LegislationDashboardConfig(
          id: _config.id,
          name: _config.name,
          widgets: widgetsList,
        ),
      );
    });
  }

  void _removeWidget(String widgetId) {
    if (!mounted) return;
    setState(() {
      _setConfig(
        _config.copyWith(
          widgets: _config.widgets.where((w) => w.id != widgetId).toList(),
        ),
      );
    });
  }

  LegislationWidgetSize _getSizeForType(LegislationWidgetType type) {
    switch (type) {
      case LegislationWidgetType.statCard:
      case LegislationWidgetType.progressRing:
        return LegislationWidgetSize.small;
      case LegislationWidgetType.barChart:
      case LegislationWidgetType.lineChart:
      case LegislationWidgetType.pieChart:
      case LegislationWidgetType.donutChart:
        return LegislationWidgetSize.large;
      case LegislationWidgetType.leaderboard:
        return LegislationWidgetSize.medium;
      case LegislationWidgetType.partyComparison:
        return LegislationWidgetSize.hero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: RepaintBoundary(
            child: AnimatedBuilder(
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
            ),
          ),
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
                  colors: [
                    _unityBlue.withOpacity(0.1),
                    _momentumBlue.withOpacity(0.1),
                  ],
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
            onRefresh: _loadStats,
            child: _buildDashboardContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    final stats = _stats ?? LegislationStats.empty();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final horizontalPadding = isMobile ? 12.0 : (isTablet ? 20.0 : 32.0);
        final columns = isMobile ? 2 : (isTablet ? 3 : 4);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Header
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isMobile ? 12 : 24,
                horizontalPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildHeader(isMobile: isMobile),
              ),
            ),
            // Widgets Grid
            SliverPadding(
              padding: EdgeInsets.all(horizontalPadding),
              sliver: SliverToBoxAdapter(
                child: isMobile
                    ? _buildMobileWidgetsGrid(
                        stats,
                        constraints.maxWidth - horizontalPadding * 2,
                      )
                    : _buildWidgetsGrid(
                        stats,
                        columns,
                        constraints.maxWidth - horizontalPadding * 2,
                      ),
              ),
            ),
            if (isMobile)
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        );
      },
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    // Member view: no header controls at all
    if (!widget.isExecutive) {
      return const SizedBox.shrink();
    }

    // Executive view: just edit and refresh buttons aligned right
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Customize Dashboard',
          icon: Icon(
            Icons.edit_outlined,
            color: _unityBlue,
            size: isMobile ? 22 : 24,
          ),
          onPressed: _toggleEditMode,
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(
            Icons.refresh,
            color: _unityBlue,
            size: isMobile ? 22 : 24,
          ),
          onPressed: _loadStats,
        ),
      ],
    );
  }

  Widget _buildWidgetsGrid(
    LegislationStats stats,
    int columns,
    double maxWidth,
  ) {
    final widgetWidth = (maxWidth - (columns - 1) * 16) / columns;
    final widgetHeight = widgetWidth * 0.8;

    final sortedWidgets = List<LegislationWidgetConfig>.from(_config.widgets)
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
          child: _buildWidget(widget, stats),
        );
      }).toList(),
    );
  }

  Widget _buildMobileWidgetsGrid(LegislationStats stats, double maxWidth) {
    final widgetWidth = maxWidth * 0.42;
    final widgetHeight = widgetWidth * 0.9;
    final fullWidgetHeight = maxWidth * 0.75;

    final sortedWidgets = List<LegislationWidgetConfig>.from(_config.widgets)
      ..sort((a, b) {
        if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
        return a.gridX.compareTo(b.gridX);
      });

    final List<Widget> rows = [];
    final Map<String, List<LegislationWidgetConfig>> swipeRows = {};

    for (final widget in sortedWidgets) {
      if (widget.swipeRowId != null) {
        swipeRows.putIfAbsent(widget.swipeRowId!, () => []).add(widget);
      }
    }

    final processedSwipeRows = <String>{};

    for (final widget in sortedWidgets) {
      if (widget.swipeRowId != null) {
        if (!processedSwipeRows.contains(widget.swipeRowId)) {
          processedSwipeRows.add(widget.swipeRowId!);
          final rowWidgets = swipeRows[widget.swipeRowId]!;
          rows.add(
            _buildSwipeableRow(rowWidgets, stats, widgetWidth, widgetHeight),
          );
        }
      } else {
        final isMobileFull =
            widget.size == LegislationWidgetSize.mobileFull ||
            widget.size == LegislationWidgetSize.hero ||
            widget.size == LegislationWidgetSize.large;
        final height = isMobileFull ? fullWidgetHeight : widgetHeight;

        rows.add(
          SizedBox(
            width: maxWidth,
            height: height,
            child: _buildWidget(widget, stats),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map(
            (row) =>
                Padding(padding: const EdgeInsets.only(bottom: 16), child: row),
          )
          .toList(),
    );
  }

  Widget _buildSwipeableRow(
    List<LegislationWidgetConfig> widgets,
    LegislationStats stats,
    double baseWidgetWidth,
    double baseWidgetHeight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          height: baseWidgetHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: widgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return SizedBox(
                width: baseWidgetWidth,
                height: baseWidgetHeight,
                child: _buildWidget(widgets[index], stats),
              );
            },
          ),
        ),
      ],
    );
  }

  double _getWidgetWidth(
    LegislationWidgetConfig widget,
    double unitWidth,
    int columns,
  ) {
    final spanWidth = widget.widthMultiplier.clamp(0.5, columns.toDouble());
    final gapAdjustment = spanWidth >= 1 ? (spanWidth.floor() - 1) * 16.0 : 0.0;
    return unitWidth * spanWidth + gapAdjustment;
  }

  double _getWidgetHeight(LegislationWidgetConfig widget, double unitHeight) {
    final spanHeight = widget.heightMultiplier;
    final gapAdjustment = spanHeight >= 1
        ? (spanHeight.floor() - 1) * 16.0
        : 0.0;
    return unitHeight * spanHeight + gapAdjustment;
  }

  Widget _buildWidget(LegislationWidgetConfig config, LegislationStats stats) {
    try {
      return _buildWidgetInternal(config, stats);
    } catch (e) {
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
            ],
          ),
        ),
      );
    }
  }

  Widget _buildWidgetInternal(
    LegislationWidgetConfig config,
    LegislationStats stats,
  ) {
    final value = _getValueForDataSource(config.dataSourceKey, stats);

    switch (config.type) {
      case LegislationWidgetType.statCard:
        return LegislationStatCardWidget(
          config: config,
          value: value,
          onTap: () => _handleStatCardTap(config.dataSourceKey),
        );

      case LegislationWidgetType.pieChart:
        final data = _getDistributionData(config.dataSourceKey, stats);
        return LegislationPieChartWidget(
          config: config,
          data: data,
          onTap: () => _handleChartTap(config.dataSourceKey),
        );

      case LegislationWidgetType.donutChart:
        final data = _getDistributionData(config.dataSourceKey, stats);
        return LegislationPieChartWidget(
          config: config,
          data: data,
          isDonut: true,
          onTap: () => _handleChartTap(config.dataSourceKey),
        );

      case LegislationWidgetType.barChart:
        final data = _getDistributionData(config.dataSourceKey, stats);
        return LegislationBarChartWidget(
          config: config,
          data: data,
          onTap: () => _handleChartTap(config.dataSourceKey),
        );

      case LegislationWidgetType.progressRing:
        final current = stats.billsAiAnalyzedCount;
        final total = stats.totalBills > 0 ? stats.totalBills : 1;
        return LegislationProgressRingWidget(
          config: config,
          current: current,
          total: total,
          onTap: () => _handleStatCardTap('billsAnalyzed'),
        );

      case LegislationWidgetType.partyComparison:
        return PartyComparisonWidget(
          config: config,
          stats: stats,
          onTap: () => _navigateToFilteredBillList(),
        );

      case LegislationWidgetType.leaderboard:
        if (config.dataSourceKey.contains('Democrat')) {
          return LegislatorLeaderboardWidget(
            config: config,
            entries: config.dataSourceKey.contains('Cosponsor')
                ? stats.top10DemocratCosponsors
                : stats.top10DemocratPrimarySponsors,
            headerColor: _democratBlue,
            onEntryTap: (entry) {
              if (entry.legislatorId != null) {
                _navigateToLegislatorDetail(entry.legislatorId!);
              }
            },
          );
        } else if (config.dataSourceKey.contains('Republican')) {
          return LegislatorLeaderboardWidget(
            config: config,
            entries: config.dataSourceKey.contains('Cosponsor')
                ? stats.top10RepublicanCosponsors
                : stats.top10RepublicanPrimarySponsors,
            headerColor: _republicanRed,
            onEntryTap: (entry) {
              if (entry.legislatorId != null) {
                _navigateToLegislatorDetail(entry.legislatorId!);
              }
            },
          );
        } else if (config.dataSourceKey.contains('MostSponsored')) {
          return BillLeaderboardWidget(
            config: config,
            entries: stats.top10MostSponsoredBills,
            onEntryTap: (entry) => _navigateToBillDetail(entry.id),
          );
        } else if (config.dataSourceKey.contains('MostActive')) {
          return BillLeaderboardWidget(
            config: config,
            entries: stats.top10MostActiveBills,
            onEntryTap: (entry) => _navigateToBillDetail(entry.id),
          );
        }
        return const SizedBox.shrink();

      case LegislationWidgetType.lineChart:
        return const SizedBox.shrink();
    }
  }

  dynamic _getValueForDataSource(String key, LegislationStats stats) {
    switch (key) {
      // === Bill Counts ===
      case 'totalBills':
        return stats.totalBills;
      case 'totalActiveBills':
        return stats.totalActiveBills;
      case 'totalArchivedBills':
        return stats.totalArchivedBillsCount;
      case 'billsCurrentSession':
        return stats.billsCurrentSessionCount;

      // === Position Counts ===
      case 'supportCount':
        return stats.supportCount;
      case 'opposeCount':
        return stats.opposeCount;
      case 'watchingCount':
        return stats.watchingCount;
      case 'neutralCount':
        return stats.neutralCount;
      case 'noPositionCount':
        return stats.noPositionCount;

      // === Priority Counts ===
      case 'criticalCount':
        return stats.criticalCount;
      case 'highCount':
        return stats.highCount;
      case 'mediumCount':
        return stats.mediumCount;
      case 'lowCount':
        return stats.lowCount;
      case 'noPriorityCount':
        return stats.noPriorityCount;

      // === Legislative Status ===
      case 'passedLowerCount':
        return stats.passedLowerCount;
      case 'passedUpperCount':
        return stats.passedUpperCount;
      case 'passedBothChambersCount':
        return stats.passedBothChambersCount;
      case 'signedCount':
        return stats.signedCount;
      case 'vetoedCount':
        return stats.vetoedCount;

      // === Chamber Origin ===
      case 'houseBillsCount':
        return stats.houseBillsCount;
      case 'senateBillsCount':
        return stats.senateBillsCount;

      // === Party Sponsorship ===
      case 'democratPrimarySponsors':
        return stats.democratPrimarySponsorCount;
      case 'republicanPrimarySponsors':
        return stats.republicanPrimarySponsorCount;
      case 'democratCosponsors':
        return stats.democratCosponsorCount;
      case 'republicanCosponsors':
        return stats.republicanCosponsorCount;
      case 'totalDemocratSponsorships':
        return stats.totalDemocratSponsorships;
      case 'totalRepublicanSponsorships':
        return stats.totalRepublicanSponsorships;
      case 'avgBillsPerDemocrat':
        return stats.avgBillsPerDemocratLegislator;
      case 'avgBillsPerRepublican':
        return stats.avgBillsPerRepublicanLegislator;

      // === Bipartisan ===
      case 'bipartisanBillsCount':
        return stats.bipartisanBillsCount;
      case 'democratOnlyBillsCount':
        return stats.democratOnlyBillsCount;
      case 'republicanOnlyBillsCount':
        return stats.republicanOnlyBillsCount;

      // === Legislator Counts ===
      case 'totalLegislators':
        return stats.totalLegislatorsCount;
      case 'houseLegislators':
        return stats.houseLegislatorsCount;
      case 'senateLegislators':
        return stats.senateLegislatorsCount;
      case 'democratLegislators':
        return stats.democratLegislatorsCount;
      case 'republicanLegislators':
        return stats.republicanLegislatorsCount;

      // === Text & PDF Stats ===
      case 'billsWithTextCount':
        return stats.billsWithTextCount;
      case 'billsWithoutTextCount':
        return stats.billsWithoutTextCount;
      case 'billsWithPdfCount':
        return stats.billsWithPdfCount;
      case 'billsTextDeferredCount':
        return stats.billsTextDeferredCount;
      case 'totalBillTextWordCount':
        return stats.totalBillTextWordCount;
      case 'avgBillTextWordCount':
        return stats.avgBillTextWordCount;

      // === AI Analysis ===
      case 'billsAnalyzed':
      case 'billsAiAnalyzedCount':
        return stats.billsAiAnalyzedCount;
      case 'billsAiPendingCount':
        return stats.billsAiPendingCount;
      case 'billsAiErrorCount':
        return stats.billsAiErrorCount;
      case 'billsAwaitingAnalysis':
      case 'billsAwaitingAiAnalysisCount':
        return stats.billsAwaitingAiAnalysisCount;

      // === AI Recommendations ===
      case 'aiRecommendsSupportCount':
        return stats.aiRecommendsSupportCount;
      case 'aiRecommendsOpposeCount':
        return stats.aiRecommendsOpposeCount;
      case 'aiRecommendsWatchingCount':
        return stats.aiRecommendsWatchingCount;
      case 'aiRecommendsNeutralCount':
        return stats.aiRecommendsNeutralCount;
      case 'aiRecommendsCriticalCount':
        return stats.aiRecommendsCriticalCount;
      case 'aiRecommendsHighCount':
        return stats.aiRecommendsHighCount;
      case 'aiRecommendsMediumCount':
        return stats.aiRecommendsMediumCount;
      case 'aiRecommendsLowCount':
        return stats.aiRecommendsLowCount;

      // === Session Stats ===
      case 'currentSession':
        return stats.currentSession ?? '';
      case 'billsCurrentSessionCount':
        return stats.billsCurrentSessionCount;

      // === Activity / Timeline ===
      case 'billsIntroducedThisWeek':
        return stats.billsIntroducedThisWeek;
      case 'billsIntroducedThisMonth':
        return stats.billsIntroducedThisMonth;
      case 'billsIntroducedThisYear':
        return stats.billsIntroducedThisYear;
      case 'actionsThisWeek':
        return stats.actionsThisWeek;
      case 'actionsThisMonth':
        return stats.actionsThisMonth;
      case 'totalActionsCount':
        return stats.totalActionsCount;
      case 'billsWithRecentAction7dCount':
        return stats.billsWithRecentAction7dCount;
      case 'billsWithRecentAction30dCount':
        return stats.billsWithRecentAction30dCount;
      case 'avgActionsPerBill':
        return stats.avgActionsPerBill;

      // === Vote Stats ===
      case 'totalVotesCount':
        return stats.totalVotesCount;
      case 'votesPassedCount':
        return stats.votesPassedCount;
      case 'votesFailedCount':
        return stats.votesFailedCount;
      case 'avgVotesPerBill':
        return stats.avgVotesPerBill;
      case 'votesThisWeek':
        return stats.votesThisWeek;
      case 'votesThisMonth':
        return stats.votesThisMonth;

      // === Document Stats ===
      case 'totalDocumentsCount':
        return stats.totalDocumentsCount;
      case 'totalVersionsCount':
        return stats.totalVersionsCount;

      // === Sponsor Stats ===
      case 'totalSponsorsCount':
        return stats.totalSponsorsCount;
      case 'totalPrimarySponsorsCount':
        return stats.totalPrimarySponsorsCount;
      case 'totalCosponsorsCount':
        return stats.totalCosponsorsCount;
      case 'avgSponsorsPerBill':
        return stats.avgSponsorsPerBill;
      case 'uniqueSponsorsCount':
        return stats.uniqueSponsorsCount;

      // === Category & Tag Stats ===
      case 'billsWithCategoriesCount':
        return stats.billsWithCategoriesCount;
      case 'billsWithTagsCount':
        return stats.billsWithTagsCount;

      // === Alert Stats ===
      case 'totalAlertsCount':
        return stats.totalAlertsCount;
      case 'activeAlertsCount':
        return stats.activeAlertsCount;
      case 'alertsSentTodayCount':
        return stats.alertsSentTodayCount;
      case 'alertsSentThisWeekCount':
        return stats.alertsSentThisWeekCount;

      // === Note Stats ===
      case 'totalNotesCount':
        return stats.totalNotesCount;
      case 'billsWithNotesCount':
        return stats.billsWithNotesCount;

      // === Sync Stats ===
      case 'billsNeedingDetailSyncCount':
        return stats.billsNeedingDetailSyncCount;
      case 'billsNeedingTextExtractCount':
        return stats.billsNeedingTextExtractCount;
      case 'billsNeedingSponsorLinkCount':
        return stats.billsNeedingSponsorLinkCount;
      case 'billsWithSyncErrorsCount':
        return stats.billsWithSyncErrorsCount;

      default:
        return 0;
    }
  }

  List<PieChartItem> _getDistributionData(String key, LegislationStats stats) {
    switch (key) {
      case 'positionBreakdown':
        return [
          PieChartItem(
            label: 'Support',
            count: stats.supportCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'Oppose',
            count: stats.opposeCount,
            color: _republicanRed,
          ),
          PieChartItem(
            label: 'Watching',
            count: stats.watchingCount,
            color: _sunriseGold,
          ),
          PieChartItem(
            label: 'Neutral',
            count: stats.neutralCount,
            color: Colors.grey,
          ),
          PieChartItem(
            label: 'No Position',
            count: stats.noPositionCount,
            color: Colors.grey.shade400,
          ),
        ].where((item) => item.count > 0).toList();

      case 'priorityBreakdown':
        return [
          PieChartItem(
            label: 'Critical',
            count: stats.criticalCount,
            color: _actionRed,
          ),
          PieChartItem(
            label: 'High',
            count: stats.highCount,
            color: _sunriseGold,
          ),
          PieChartItem(
            label: 'Medium',
            count: stats.mediumCount,
            color: _momentumBlue,
          ),
          PieChartItem(
            label: 'Low',
            count: stats.lowCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'None',
            count: stats.noPriorityCount,
            color: Colors.grey.shade400,
          ),
        ].where((item) => item.count > 0).toList();

      case 'statusBreakdown':
        return [
          PieChartItem(
            label: 'Passed House',
            count: stats.passedLowerCount,
            color: _momentumBlue,
          ),
          PieChartItem(
            label: 'Passed Senate',
            count: stats.passedUpperCount,
            color: _justicePurple,
          ),
          PieChartItem(
            label: 'Passed Both',
            count: stats.passedBothChambersCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'Signed',
            count: stats.signedCount,
            color: _sunriseGold,
          ),
          PieChartItem(
            label: 'Vetoed',
            count: stats.vetoedCount,
            color: _actionRed,
          ),
        ].where((item) => item.count > 0).toList();

      case 'chamberOriginBreakdown':
        return [
          PieChartItem(
            label: 'House Bills',
            count: stats.houseBillsCount,
            color: _momentumBlue,
          ),
          PieChartItem(
            label: 'Senate Bills',
            count: stats.senateBillsCount,
            color: _justicePurple,
          ),
        ].where((item) => item.count > 0).toList();

      case 'partySponsorship':
        return [
          PieChartItem(
            label: 'Democrat',
            count: stats.totalDemocratSponsorships,
            color: _democratBlue,
          ),
          PieChartItem(
            label: 'Republican',
            count: stats.totalRepublicanSponsorships,
            color: _republicanRed,
          ),
        ].where((item) => item.count > 0).toList();

      case 'bipartisanBreakdown':
        return [
          PieChartItem(
            label: 'Bipartisan',
            count: stats.bipartisanBillsCount,
            color: _justicePurple,
          ),
          PieChartItem(
            label: 'Democrat Only',
            count: stats.democratOnlyBillsCount,
            color: _democratBlue,
          ),
          PieChartItem(
            label: 'Republican Only',
            count: stats.republicanOnlyBillsCount,
            color: _republicanRed,
          ),
        ].where((item) => item.count > 0).toList();

      case 'chamberDistribution':
        return [
          PieChartItem(
            label: 'House',
            count: stats.houseLegislatorsCount,
            color: _momentumBlue,
          ),
          PieChartItem(
            label: 'Senate',
            count: stats.senateLegislatorsCount,
            color: _justicePurple,
          ),
        ].where((item) => item.count > 0).toList();

      case 'partyDistribution':
        return [
          PieChartItem(
            label: 'Democrats',
            count: stats.democratLegislatorsCount,
            color: _democratBlue,
          ),
          PieChartItem(
            label: 'Republicans',
            count: stats.republicanLegislatorsCount,
            color: _republicanRed,
          ),
        ].where((item) => item.count > 0).toList();

      case 'textCoverageBreakdown':
        return [
          PieChartItem(
            label: 'With Text',
            count: stats.billsWithTextCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'Without Text',
            count: stats.billsWithoutTextCount,
            color: _actionRed,
          ),
          PieChartItem(
            label: 'Deferred',
            count: stats.billsTextDeferredCount,
            color: _sunriseGold,
          ),
        ].where((item) => item.count > 0).toList();

      case 'aiAnalysisBreakdown':
        return [
          PieChartItem(
            label: 'Analyzed',
            count: stats.billsAiAnalyzedCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'Pending',
            count: stats.billsAiPendingCount,
            color: _sunriseGold,
          ),
          PieChartItem(
            label: 'Errors',
            count: stats.billsAiErrorCount,
            color: _actionRed,
          ),
          PieChartItem(
            label: 'Awaiting',
            count: stats.billsAwaitingAiAnalysisCount,
            color: Colors.grey,
          ),
        ].where((item) => item.count > 0).toList();

      case 'aiPositionRecommendations':
        return [
          PieChartItem(
            label: 'Support',
            count: stats.aiRecommendsSupportCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'Oppose',
            count: stats.aiRecommendsOpposeCount,
            color: _republicanRed,
          ),
          PieChartItem(
            label: 'Watching',
            count: stats.aiRecommendsWatchingCount,
            color: _sunriseGold,
          ),
          PieChartItem(
            label: 'Neutral',
            count: stats.aiRecommendsNeutralCount,
            color: Colors.grey,
          ),
        ].where((item) => item.count > 0).toList();

      case 'aiPriorityRecommendations':
        return [
          PieChartItem(
            label: 'Critical',
            count: stats.aiRecommendsCriticalCount,
            color: _actionRed,
          ),
          PieChartItem(
            label: 'High',
            count: stats.aiRecommendsHighCount,
            color: _sunriseGold,
          ),
          PieChartItem(
            label: 'Medium',
            count: stats.aiRecommendsMediumCount,
            color: _momentumBlue,
          ),
          PieChartItem(
            label: 'Low',
            count: stats.aiRecommendsLowCount,
            color: _grassrootsGreen,
          ),
        ].where((item) => item.count > 0).toList();

      case 'voteBreakdown':
        return [
          PieChartItem(
            label: 'Passed',
            count: stats.votesPassedCount,
            color: _grassrootsGreen,
          ),
          PieChartItem(
            label: 'Failed',
            count: stats.votesFailedCount,
            color: _actionRed,
          ),
        ].where((item) => item.count > 0).toList();

      default:
        return [];
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Failed to load statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ======== EDIT MODE ========

  Widget _buildEditMode() {
    return Scaffold(
      body: Column(
        children: [
          _buildEditHeader(isMobile: _isMobileLayout),
          Expanded(
            child: Row(
              children: [
                if (_showPalette && !_isMobileLayout)
                  SizedBox(width: 280, child: _buildWidgetPalette()),
                Expanded(child: _buildEditableGrid()),
              ],
            ),
          ),
        ],
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
                  TextButton.icon(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white70,
                      size: 20,
                    ),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      _loadConfig();
                      _toggleEditMode();
                    },
                  ),
                  const Spacer(),
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _grassrootsGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _toggleEditMode,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Widget'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _showMobilePalette,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _setConfig(
                          _isMobileLayout
                              ? _getDefaultMobileConfig()
                              : _getDefaultConfig(),
                        );
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
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.restore, color: Colors.white70, size: 18),
            label: const Text('Reset', style: TextStyle(color: Colors.white70)),
            onPressed: () {
              setState(() {
                _setConfig(
                  _isMobileLayout
                      ? _getDefaultMobileConfig()
                      : _getDefaultConfig(),
                );
              });
            },
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              _loadConfig();
              _toggleEditMode();
            },
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text(
              'Save & Exit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _grassrootsGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
    );
  }

  void _showMobilePalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
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
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  children: LegislationDataCategory.values.map((category) {
                    final sources = LegislationDataSources.getByCategory(
                      category,
                    );
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

  Widget _buildMobilePaletteCategory(
    LegislationDataCategory category,
    List<LegislationDataSource> sources,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            LegislationDataSources.getCategoryLabel(category),
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

  Widget _buildMobilePaletteItem(LegislationDataSource source) {
    return Card(
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
          if (source.supportedWidgets.length == 1) {
            _addWidget(source, source.supportedWidgets.first);
          } else {
            _showWidgetTypeSelector(source);
          }
        },
      ),
    );
  }

  void _showWidgetTypeSelector(LegislationDataSource source) {
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

  Widget _buildWidgetPalette() {
    final categories = LegislationDataCategory.values
        .where((c) => LegislationDataSources.getByCategory(c).isNotEmpty)
        .toList();

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
            decoration: const BoxDecoration(color: _unityBlue),
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
              padding: const EdgeInsets.all(12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final sources = LegislationDataSources.getByCategory(category);

                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      LegislationDataSources.getCategoryLabel(category),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    initiallyExpanded: index == 0,
                    children: sources
                        .map((source) => _buildPaletteItem(source))
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItem(LegislationDataSource source) {
    final defaultType = source.supportedWidgets.isNotEmpty
        ? source.supportedWidgets.first
        : LegislationWidgetType.statCard;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          if (source.supportedWidgets.length > 1) {
            _showWidgetTypeSelector(source);
          } else {
            _addWidget(source, defaultType);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(source.icon, color: _momentumBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      source.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      source.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                source.supportedWidgets.length > 1
                    ? Icons.add_circle_outline
                    : Icons.add_circle,
                color: _grassrootsGreen,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableGrid() {
    final stats = _stats ?? LegislationStats.empty();

    return Container(
      color: Colors.grey[100],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _isMobileLayout ? 2 : 4;
          final horizontalPadding = _isMobileLayout ? 12.0 : 24.0;
          final widgetWidth =
              (constraints.maxWidth -
                  horizontalPadding * 2 -
                  (columns - 1) * 16) /
              columns;
          final widgetHeight = widgetWidth * 0.8;

          final sortedWidgets =
              List<LegislationWidgetConfig>.from(_config.widgets)..sort((a, b) {
                if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
                return a.gridX.compareTo(b.gridX);
              });

          return SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instructions bar
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
                        child: const Icon(
                          Icons.drag_indicator,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isMobileLayout
                            ? 'Tap widgets to edit or reorder'
                            : 'Drag from palette to add, or tap widgets to edit',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Widgets with drop zones
                _buildWidgetsWithDropZones(
                  sortedWidgets,
                  stats,
                  widgetWidth,
                  widgetHeight,
                  columns,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWidgetsWithDropZones(
    List<LegislationWidgetConfig> widgets,
    LegislationStats stats,
    double widgetWidth,
    double widgetHeight,
    int columns,
  ) {
    final items = <Widget>[];

    // Add drop zone at beginning
    items.add(_buildReorderDropZone(0, widgetWidth));

    for (int i = 0; i < widgets.length; i++) {
      final widget = widgets[i];
      final width = _getWidgetWidth(widget, widgetWidth, columns);
      final height = _getWidgetHeight(widget, widgetHeight);
      final source = LegislationDataSources.getByKey(widget.dataSourceKey);
      final widgetLabel = source?.label ?? widget.dataSourceKey;
      final widgetIcon = source?.icon ?? Icons.widgets;

      items.add(
        RepaintBoundary(
          child: LongPressDraggable<_WidgetReorderData>(
            key: ValueKey('draggable_${widget.id}'),
            data: _WidgetReorderData(fromIndex: i, config: widget),
            delay: const Duration(milliseconds: 150),
            hapticFeedbackOnStart: true,
            onDragStarted: () {
              if (mounted) setState(() => _isDragging = true);
            },
            onDragEnd: (_) {
              if (mounted) setState(() => _isDragging = false);
            },
            onDraggableCanceled: (_, __) {
              if (mounted) setState(() => _isDragging = false);
            },
            onDragCompleted: () {
              if (mounted) setState(() => _isDragging = false);
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
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _momentumBlue.withOpacity(0.5),
                    width: 2,
                  ),
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: _buildEditableWidget(widget, stats, i),
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
        final data = details.data;
        return data is _PaletteDragData || data is _WidgetReorderData;
      },
      onAcceptWithDetails: (details) {
        if (!mounted) return;
        final data = details.data;
        if (data is _PaletteDragData) {
          _addWidgetAtIndex(data.source, data.type, insertIndex);
        } else if (data is _WidgetReorderData) {
          _reorderWidgetToIndex(data.fromIndex, insertIndex);
        }
        setState(() => _isDragging = false);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final isReorder = candidateData.any((d) => d is _WidgetReorderData);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: isHovering ? widgetWidth * 0.4 : 8,
          height: isHovering ? 80 : 60,
          margin: EdgeInsets.symmetric(horizontal: isHovering ? 4 : 0),
          decoration: BoxDecoration(
            color: isHovering
                ? (isReorder
                      ? _grassrootsGreen.withOpacity(0.3)
                      : _momentumBlue.withOpacity(0.3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isHovering
                ? Border.all(
                    color: isReorder ? _grassrootsGreen : _momentumBlue,
                    width: 2,
                  )
                : null,
          ),
          child: isHovering
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: isReorder ? _grassrootsGreen : _momentumBlue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Drop here',
                        style: TextStyle(
                          fontSize: 10,
                          color: isReorder ? _grassrootsGreen : _momentumBlue,
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

  void _reorderWidgetToIndex(int fromIndex, int toIndex) {
    if (!mounted) return;
    if (fromIndex == toIndex || fromIndex == toIndex - 1) return;
    final currentWidgets = _config.widgets;
    if (fromIndex < 0 || fromIndex >= currentWidgets.length) return;
    setState(() {
      final widgetsList = List<LegislationWidgetConfig>.from(currentWidgets);
      final item = widgetsList.removeAt(fromIndex);
      final adjustedTo = fromIndex < toIndex ? toIndex - 1 : toIndex;
      widgetsList.insert(adjustedTo.clamp(0, widgetsList.length), item);
      for (int i = 0; i < widgetsList.length; i++) {
        widgetsList[i] = widgetsList[i].copyWith(gridY: i);
      }
      _setConfig(_config.copyWith(widgets: widgetsList));
    });
    _saveConfig();
  }

  Widget _buildEditableWidget(
    LegislationWidgetConfig config,
    LegislationStats stats,
    int index,
  ) {
    return Stack(
      children: [
        // The actual widget
        _buildWidget(config, stats),
        // Edit overlay - tap opens options
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showWidgetOptions(config, index),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _momentumBlue.withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Position indicator (#1, #2, etc.)
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _unityBlue.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#${index + 1}',
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
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_indicator, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Hold to drag',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        // Settings button
        Positioned(
          top: 8,
          right: 40,
          child: GestureDetector(
            onTap: () => _showWidgetOptions(config, index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _momentumBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: Colors.white, size: 16),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeWidget(config.id),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _actionRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showWidgetOptions(LegislationWidgetConfig config, [int? index]) {
    if (!mounted) return;
    final source = LegislationDataSources.getByKey(config.dataSourceKey);
    final currentGradientIndex = LegislationWidgetGradients.indexOfColors(
      config.gradientColors,
    );

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
                  // Header with delete button
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
                        icon: const Icon(
                          Icons.delete_outline,
                          color: _actionRed,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _removeWidget(config.id);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Widget type selection
                  const Text(
                    'Display as:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        (source?.supportedWidgets ??
                                [LegislationWidgetType.statCard])
                            .map((type) {
                              final isSelected = config.type == type;
                              return ChoiceChip(
                                label: Text(_getWidgetTypeLabel(type)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    _updateWidget(
                                      config.copyWith(
                                        type: type,
                                        size: _getSizeForType(type),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            })
                            .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Size selection
                  const Text(
                    'Size:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: LegislationWidgetSize.values.map((size) {
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

                  // Color selection
                  const Text(
                    'Color:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: LegislationWidgetGradients.all.length,
                    itemBuilder: (context, gradientIndex) {
                      final gradient =
                          LegislationWidgetGradients.all[gradientIndex];
                      final isSelected = currentGradientIndex == gradientIndex;
                      return GestureDetector(
                        onTap: () {
                          _updateWidget(
                            config.copyWith(gradientColors: gradient),
                          );
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
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  ),
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
                        LegislationWidgetGradients.names[currentGradientIndex],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateWidget(LegislationWidgetConfig updatedConfig) {
    if (!mounted) return;
    setState(() {
      final widgetsList = _config.widgets.map((w) {
        if (w.id == updatedConfig.id) {
          return updatedConfig;
        }
        return w;
      }).toList();
      _setConfig(_config.copyWith(widgets: widgetsList));
    });
    _saveConfig();
  }

  String _getSizeLabel(LegislationWidgetSize size) {
    switch (size) {
      case LegislationWidgetSize.mini:
        return 'Mini';
      case LegislationWidgetSize.small:
        return 'Small';
      case LegislationWidgetSize.medium:
        return 'Medium';
      case LegislationWidgetSize.large:
        return 'Large';
      case LegislationWidgetSize.wide:
        return 'Wide';
      case LegislationWidgetSize.tall:
        return 'Tall';
      case LegislationWidgetSize.hero:
        return 'Hero';
      case LegislationWidgetSize.mobileFull:
        return 'Full Width';
    }
  }

  IconData _getWidgetTypeIcon(LegislationWidgetType type) {
    switch (type) {
      case LegislationWidgetType.statCard:
        return Icons.dashboard;
      case LegislationWidgetType.barChart:
        return Icons.bar_chart;
      case LegislationWidgetType.lineChart:
        return Icons.show_chart;
      case LegislationWidgetType.pieChart:
        return Icons.pie_chart;
      case LegislationWidgetType.donutChart:
        return Icons.donut_small;
      case LegislationWidgetType.leaderboard:
        return Icons.leaderboard;
      case LegislationWidgetType.partyComparison:
        return Icons.compare_arrows;
      case LegislationWidgetType.progressRing:
        return Icons.donut_large;
    }
  }

  String _getWidgetTypeLabel(LegislationWidgetType type) {
    switch (type) {
      case LegislationWidgetType.statCard:
        return 'Stat Card';
      case LegislationWidgetType.barChart:
        return 'Bar Chart';
      case LegislationWidgetType.lineChart:
        return 'Line Chart';
      case LegislationWidgetType.pieChart:
        return 'Pie Chart';
      case LegislationWidgetType.donutChart:
        return 'Donut Chart';
      case LegislationWidgetType.leaderboard:
        return 'Leaderboard';
      case LegislationWidgetType.partyComparison:
        return 'Party Comparison';
      case LegislationWidgetType.progressRing:
        return 'Progress Ring';
    }
  }
}
