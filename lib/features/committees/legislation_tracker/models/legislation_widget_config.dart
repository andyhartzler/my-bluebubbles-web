import 'dart:convert';
import 'package:flutter/material.dart';

/// Types of widgets available for the legislation dashboard
enum LegislationWidgetType {
  statCard,
  barChart,
  lineChart,
  pieChart,
  donutChart,
  leaderboard,
  partyComparison,
  progressRing,
}

/// Size options for widgets
enum LegislationWidgetSize {
  mini,       // 1x1 on grid - compact square with number on top, name below
  small,      // 1x0.5 on grid - half height compact row
  medium,     // 1x1 on grid - standard card size
  large,      // 2x1 on grid - wide card
  wide,       // 3x1 on grid - extra wide
  tall,       // 1x2 on grid - vertical
  hero,       // 3x2 on grid - full featured
  mobileFull, // Full width on mobile with tall proportions
}

/// Data source categories for legislation dashboard
enum LegislationDataCategory {
  billCounts,
  positions,
  priorities,
  legislativeStatus,
  chamberOrigin,
  partyStats,
  bipartisan,
  legislators,
  leaderboards,
  textPdf,
  aiAnalysis,
  aiRecommendations,
  sessionStats,
  activity,
  voteStats,
  documentStats,
  sponsorStats,
  categoryTags,
  alerts,
  notes,
  syncStats,
}

/// Single widget configuration
class LegislationWidgetConfig {
  final String id;
  final LegislationWidgetType type;
  final LegislationWidgetSize size;
  final String dataSourceKey;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Color> gradientColors;
  final int gridX;
  final int gridY;
  final bool visible;
  final Map<String, dynamic> options;
  final String? swipeRowId;

  const LegislationWidgetConfig({
    required this.id,
    required this.type,
    required this.size,
    required this.dataSourceKey,
    required this.title,
    this.subtitle,
    this.icon,
    this.gradientColors = const [],
    this.gridX = 0,
    this.gridY = 0,
    this.visible = true,
    this.options = const {},
    this.swipeRowId,
  });

  LegislationWidgetConfig copyWith({
    String? id,
    LegislationWidgetType? type,
    LegislationWidgetSize? size,
    String? dataSourceKey,
    String? title,
    String? subtitle,
    IconData? icon,
    List<Color>? gradientColors,
    int? gridX,
    int? gridY,
    bool? visible,
    Map<String, dynamic>? options,
    String? swipeRowId,
    bool clearSwipeRowId = false,
  }) {
    return LegislationWidgetConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      size: size ?? this.size,
      dataSourceKey: dataSourceKey ?? this.dataSourceKey,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      gradientColors: gradientColors ?? this.gradientColors,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      visible: visible ?? this.visible,
      options: options ?? this.options,
      swipeRowId: clearSwipeRowId ? null : (swipeRowId ?? this.swipeRowId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'size': size.index,
    'dataSourceKey': dataSourceKey,
    'title': title,
    'subtitle': subtitle,
    'iconCodePoint': icon?.codePoint,
    'iconFontFamily': icon?.fontFamily,
    'gradientColors': gradientColors.map((c) => c.value).toList(),
    'gridX': gridX,
    'gridY': gridY,
    'visible': visible,
    'options': options,
    'swipeRowId': swipeRowId,
  };

  factory LegislationWidgetConfig.fromJson(Map<String, dynamic> json) {
    IconData? icon;
    if (json['iconCodePoint'] != null) {
      icon = IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      );
    }

    bool visible = true;
    final visibleValue = json['visible'];
    if (visibleValue is bool) {
      visible = visibleValue;
    } else if (visibleValue is int) {
      visible = visibleValue != 0;
    }

    int sizeIndex = json['size'] as int? ?? 1;
    if (sizeIndex >= LegislationWidgetSize.values.length) {
      sizeIndex = 1;
    }

    return LegislationWidgetConfig(
      id: json['id'] as String,
      type: LegislationWidgetType.values[json['type'] as int? ?? 0],
      size: LegislationWidgetSize.values[sizeIndex],
      dataSourceKey: json['dataSourceKey'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      icon: icon,
      gradientColors: (json['gradientColors'] as List?)
          ?.map((e) => Color(e as int))
          .toList() ?? [],
      gridX: json['gridX'] as int? ?? 0,
      gridY: json['gridY'] as int? ?? 0,
      visible: visible,
      options: json['options'] as Map<String, dynamic>? ?? {},
      swipeRowId: json['swipeRowId'] as String?,
    );
  }

  /// Get the width in grid units
  int get gridWidth {
    switch (size) {
      case LegislationWidgetSize.mini:    // 1x1 square
      case LegislationWidgetSize.small:   // 1x0.5 compact
      case LegislationWidgetSize.medium:  // 1x1 standard
      case LegislationWidgetSize.tall:    // 1x2 vertical
        return 1;
      case LegislationWidgetSize.large:   // 2x1 wide
        return 2;
      case LegislationWidgetSize.wide:    // 3x1 extra wide
      case LegislationWidgetSize.hero:    // 3x2 full featured
      case LegislationWidgetSize.mobileFull:
        return 3;
    }
  }

  /// Get the height in grid units
  int get gridHeight {
    switch (size) {
      case LegislationWidgetSize.small:   // Half height
        return 1; // Uses 0.5 multiplier
      case LegislationWidgetSize.mini:    // Square
      case LegislationWidgetSize.medium:  // Standard
      case LegislationWidgetSize.large:   // Wide card
      case LegislationWidgetSize.wide:    // Extra wide
        return 1;
      case LegislationWidgetSize.tall:    // Vertical
      case LegislationWidgetSize.hero:    // Full featured
      case LegislationWidgetSize.mobileFull:
        return 2;
    }
  }

  /// Get the actual height multiplier for rendering
  /// - mini is 0.5 (square - half height and half width)
  /// - small is 0.5 (half height compact row)
  /// - others use their gridHeight
  double get heightMultiplier {
    switch (size) {
      case LegislationWidgetSize.mini:
        return 0.5; // Mini is a square: half height
      case LegislationWidgetSize.small:
        return 0.5; // Small is half height
      default:
        return gridHeight.toDouble();
    }
  }

  /// Get the actual width multiplier for rendering
  /// - mini is 0.5 (square - half width)
  /// - others use their gridWidth
  double get widthMultiplier {
    switch (size) {
      case LegislationWidgetSize.mini:
        return 0.5; // Mini is a square: half width
      default:
        return gridWidth.toDouble();
    }
  }
}

/// Full dashboard configuration
class LegislationDashboardConfig {
  final String id;
  final String name;
  final List<LegislationWidgetConfig> widgets;
  final int columns;
  final DateTime? lastModified;

  const LegislationDashboardConfig({
    required this.id,
    required this.name,
    required this.widgets,
    this.columns = 4,
    this.lastModified,
  });

  LegislationDashboardConfig copyWith({
    String? id,
    String? name,
    List<LegislationWidgetConfig>? widgets,
    int? columns,
    DateTime? lastModified,
  }) {
    return LegislationDashboardConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      widgets: widgets ?? this.widgets,
      columns: columns ?? this.columns,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'widgets': widgets.map((w) => w.toJson()).toList(),
    'columns': columns,
    'lastModified': lastModified?.toIso8601String(),
  };

  factory LegislationDashboardConfig.fromJson(Map<String, dynamic> json) {
    return LegislationDashboardConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      widgets: (json['widgets'] as List?)
          ?.map((e) => LegislationWidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      columns: json['columns'] as int? ?? 4,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static LegislationDashboardConfig fromJsonString(String jsonString) {
    return LegislationDashboardConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// Available data sources with metadata
class LegislationDataSource {
  final String key;
  final String label;
  final String description;
  final LegislationDataCategory category;
  final List<LegislationWidgetType> supportedWidgets;
  final IconData icon;
  final bool isDistribution;

  const LegislationDataSource({
    required this.key,
    required this.label,
    required this.description,
    required this.category,
    required this.supportedWidgets,
    required this.icon,
    this.isDistribution = false,
  });
}

/// Registry of all available data sources for legislation dashboard
class LegislationDataSources {
  static const List<LegislationDataSource> all = [
    // ==================== BILL COUNTS ====================
    LegislationDataSource(
      key: 'totalBills',
      label: 'Total Bills',
      description: 'All bills (archived + active)',
      category: LegislationDataCategory.billCounts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.folder,
    ),
    LegislationDataSource(
      key: 'totalActiveBills',
      label: 'Active Bills',
      description: 'Total number of active bills being tracked',
      category: LegislationDataCategory.billCounts,
      supportedWidgets: [LegislationWidgetType.statCard, LegislationWidgetType.progressRing],
      icon: Icons.gavel,
    ),
    LegislationDataSource(
      key: 'totalArchivedBills',
      label: 'Archived Bills',
      description: 'Bills that have been archived',
      category: LegislationDataCategory.billCounts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.archive,
    ),
    LegislationDataSource(
      key: 'billsCurrentSession',
      label: 'Current Session',
      description: 'Bills in the current legislative session',
      category: LegislationDataCategory.billCounts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.calendar_today,
    ),

    // ==================== POSITIONS ====================
    LegislationDataSource(
      key: 'positionBreakdown',
      label: 'Position Breakdown',
      description: 'Distribution of bill positions',
      category: LegislationDataCategory.positions,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.pie_chart,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'supportCount',
      label: 'Supporting',
      description: 'Bills we support',
      category: LegislationDataCategory.positions,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.thumb_up,
    ),
    LegislationDataSource(
      key: 'opposeCount',
      label: 'Opposing',
      description: 'Bills we oppose',
      category: LegislationDataCategory.positions,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.thumb_down,
    ),
    LegislationDataSource(
      key: 'watchingCount',
      label: 'Watching',
      description: 'Bills we are watching',
      category: LegislationDataCategory.positions,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.visibility,
    ),
    LegislationDataSource(
      key: 'neutralCount',
      label: 'Neutral',
      description: 'Bills with neutral position',
      category: LegislationDataCategory.positions,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.remove_circle_outline,
    ),
    LegislationDataSource(
      key: 'noPositionCount',
      label: 'No Position',
      description: 'Bills without a position',
      category: LegislationDataCategory.positions,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.help_outline,
    ),

    // ==================== PRIORITIES ====================
    LegislationDataSource(
      key: 'priorityBreakdown',
      label: 'Priority Levels',
      description: 'Distribution of bill priorities',
      category: LegislationDataCategory.priorities,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.flag,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'criticalCount',
      label: 'Critical',
      description: 'Critical priority bills',
      category: LegislationDataCategory.priorities,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.priority_high,
    ),
    LegislationDataSource(
      key: 'highCount',
      label: 'High Priority',
      description: 'High priority bills',
      category: LegislationDataCategory.priorities,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.arrow_upward,
    ),
    LegislationDataSource(
      key: 'mediumCount',
      label: 'Medium Priority',
      description: 'Medium priority bills',
      category: LegislationDataCategory.priorities,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.remove,
    ),
    LegislationDataSource(
      key: 'lowCount',
      label: 'Low Priority',
      description: 'Low priority bills',
      category: LegislationDataCategory.priorities,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.arrow_downward,
    ),
    LegislationDataSource(
      key: 'noPriorityCount',
      label: 'No Priority',
      description: 'Bills without a priority set',
      category: LegislationDataCategory.priorities,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.help_outline,
    ),

    // ==================== LEGISLATIVE STATUS ====================
    LegislationDataSource(
      key: 'statusBreakdown',
      label: 'Status Breakdown',
      description: 'Bills by legislative status',
      category: LegislationDataCategory.legislativeStatus,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.timeline,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'passedLowerCount',
      label: 'Passed House',
      description: 'Bills that passed the House',
      category: LegislationDataCategory.legislativeStatus,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.check_circle_outline,
    ),
    LegislationDataSource(
      key: 'passedUpperCount',
      label: 'Passed Senate',
      description: 'Bills that passed the Senate',
      category: LegislationDataCategory.legislativeStatus,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.check_circle_outline,
    ),
    LegislationDataSource(
      key: 'passedBothChambersCount',
      label: 'Passed Both',
      description: 'Bills that passed both chambers',
      category: LegislationDataCategory.legislativeStatus,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.done_all,
    ),
    LegislationDataSource(
      key: 'signedCount',
      label: 'Signed by Governor',
      description: 'Bills signed into law',
      category: LegislationDataCategory.legislativeStatus,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.verified,
    ),
    LegislationDataSource(
      key: 'vetoedCount',
      label: 'Vetoed',
      description: 'Bills vetoed by the governor',
      category: LegislationDataCategory.legislativeStatus,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.cancel,
    ),

    // ==================== CHAMBER ORIGIN ====================
    LegislationDataSource(
      key: 'chamberOriginBreakdown',
      label: 'Chamber Origin',
      description: 'Bills by originating chamber',
      category: LegislationDataCategory.chamberOrigin,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.account_balance,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'houseBillsCount',
      label: 'House Bills',
      description: 'Bills originating in the House',
      category: LegislationDataCategory.chamberOrigin,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.home_work,
    ),
    LegislationDataSource(
      key: 'senateBillsCount',
      label: 'Senate Bills',
      description: 'Bills originating in the Senate',
      category: LegislationDataCategory.chamberOrigin,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.account_balance,
    ),

    // ==================== PARTY SPONSORSHIP ====================
    LegislationDataSource(
      key: 'partySponsorship',
      label: 'Party Comparison',
      description: 'Compare Democrat vs Republican sponsorship',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.partyComparison, LegislationWidgetType.barChart],
      icon: Icons.compare_arrows,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'democratPrimarySponsors',
      label: 'Democrat Primary Sponsors',
      description: 'Bills primarily sponsored by Democrats',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),
    LegislationDataSource(
      key: 'republicanPrimarySponsors',
      label: 'Republican Primary Sponsors',
      description: 'Bills primarily sponsored by Republicans',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),
    LegislationDataSource(
      key: 'democratCosponsors',
      label: 'Democrat Co-Sponsors',
      description: 'Total Democrat co-sponsorships',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.group,
    ),
    LegislationDataSource(
      key: 'republicanCosponsors',
      label: 'Republican Co-Sponsors',
      description: 'Total Republican co-sponsorships',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.group,
    ),
    LegislationDataSource(
      key: 'totalDemocratSponsorships',
      label: 'Total Dem Sponsorships',
      description: 'All Democrat sponsorships (primary + co)',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.groups,
    ),
    LegislationDataSource(
      key: 'totalRepublicanSponsorships',
      label: 'Total GOP Sponsorships',
      description: 'All Republican sponsorships (primary + co)',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.groups,
    ),
    LegislationDataSource(
      key: 'avgBillsPerDemocrat',
      label: 'Avg Bills/Democrat',
      description: 'Average sponsorships per Democrat legislator',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.analytics,
    ),
    LegislationDataSource(
      key: 'avgBillsPerRepublican',
      label: 'Avg Bills/Republican',
      description: 'Average sponsorships per Republican legislator',
      category: LegislationDataCategory.partyStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.analytics,
    ),

    // ==================== BIPARTISAN ====================
    LegislationDataSource(
      key: 'bipartisanBreakdown',
      label: 'Bipartisan Breakdown',
      description: 'Bills by party collaboration',
      category: LegislationDataCategory.bipartisan,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.handshake,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'bipartisanBillsCount',
      label: 'Bipartisan Bills',
      description: 'Bills with sponsors from both parties',
      category: LegislationDataCategory.bipartisan,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.handshake,
    ),
    LegislationDataSource(
      key: 'democratOnlyBillsCount',
      label: 'Democrat-Only Bills',
      description: 'Bills with only Democrat sponsors',
      category: LegislationDataCategory.bipartisan,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),
    LegislationDataSource(
      key: 'republicanOnlyBillsCount',
      label: 'Republican-Only Bills',
      description: 'Bills with only Republican sponsors',
      category: LegislationDataCategory.bipartisan,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),

    // ==================== LEGISLATORS ====================
    LegislationDataSource(
      key: 'totalLegislators',
      label: 'Total Legislators',
      description: 'Total number of current legislators',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.people,
    ),
    LegislationDataSource(
      key: 'houseLegislators',
      label: 'House Members',
      description: 'Number of House representatives',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.home_work,
    ),
    LegislationDataSource(
      key: 'senateLegislators',
      label: 'Senate Members',
      description: 'Number of Senators',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.account_balance,
    ),
    LegislationDataSource(
      key: 'democratLegislators',
      label: 'Democrat Legislators',
      description: 'Number of Democrat legislators',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),
    LegislationDataSource(
      key: 'republicanLegislators',
      label: 'Republican Legislators',
      description: 'Number of Republican legislators',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),
    LegislationDataSource(
      key: 'chamberDistribution',
      label: 'Chamber Distribution',
      description: 'House vs Senate breakdown',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart],
      icon: Icons.donut_small,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'partyDistribution',
      label: 'Party Distribution',
      description: 'Democrat vs Republican breakdown',
      category: LegislationDataCategory.legislators,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart],
      icon: Icons.pie_chart,
      isDistribution: true,
    ),

    // ==================== LEADERBOARDS ====================
    LegislationDataSource(
      key: 'top10DemocratSponsors',
      label: 'Top Democrat Sponsors',
      description: 'Most active Democrat bill sponsors',
      category: LegislationDataCategory.leaderboards,
      supportedWidgets: [LegislationWidgetType.leaderboard],
      icon: Icons.emoji_events,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'top10RepublicanSponsors',
      label: 'Top Republican Sponsors',
      description: 'Most active Republican bill sponsors',
      category: LegislationDataCategory.leaderboards,
      supportedWidgets: [LegislationWidgetType.leaderboard],
      icon: Icons.emoji_events,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'top10DemocratCosponsors',
      label: 'Top Democrat Co-Sponsors',
      description: 'Most active Democrat co-sponsors',
      category: LegislationDataCategory.leaderboards,
      supportedWidgets: [LegislationWidgetType.leaderboard],
      icon: Icons.emoji_events,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'top10RepublicanCosponsors',
      label: 'Top Republican Co-Sponsors',
      description: 'Most active Republican co-sponsors',
      category: LegislationDataCategory.leaderboards,
      supportedWidgets: [LegislationWidgetType.leaderboard],
      icon: Icons.emoji_events,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'top10MostSponsoredBills',
      label: 'Most Sponsored Bills',
      description: 'Bills with the most sponsors',
      category: LegislationDataCategory.leaderboards,
      supportedWidgets: [LegislationWidgetType.leaderboard],
      icon: Icons.star,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'top10MostActiveBills',
      label: 'Most Active Bills',
      description: 'Bills with the most recent activity',
      category: LegislationDataCategory.leaderboards,
      supportedWidgets: [LegislationWidgetType.leaderboard],
      icon: Icons.bolt,
      isDistribution: true,
    ),

    // ==================== TEXT & PDF STATS ====================
    LegislationDataSource(
      key: 'textCoverageBreakdown',
      label: 'Text Coverage',
      description: 'Bills with/without text',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.progressRing],
      icon: Icons.description,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'billsWithTextCount',
      label: 'Bills with Text',
      description: 'Bills with extracted text content',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.description,
    ),
    LegislationDataSource(
      key: 'billsWithoutTextCount',
      label: 'Bills without Text',
      description: 'Bills without text content',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.text_snippet,
    ),
    LegislationDataSource(
      key: 'billsWithPdfCount',
      label: 'Bills with PDF',
      description: 'Bills with stored PDF file',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.picture_as_pdf,
    ),
    LegislationDataSource(
      key: 'billsTextDeferredCount',
      label: 'Text Deferred',
      description: 'Bills where text extraction was deferred',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.hourglass_empty,
    ),
    LegislationDataSource(
      key: 'totalBillTextWordCount',
      label: 'Total Word Count',
      description: 'Sum of all bill text word counts',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.text_fields,
    ),
    LegislationDataSource(
      key: 'avgBillTextWordCount',
      label: 'Avg Word Count',
      description: 'Average word count per bill',
      category: LegislationDataCategory.textPdf,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.text_fields,
    ),

    // ==================== AI ANALYSIS ====================
    LegislationDataSource(
      key: 'aiAnalysisProgress',
      label: 'AI Analysis Progress',
      description: 'Percentage of bills analyzed by AI',
      category: LegislationDataCategory.aiAnalysis,
      supportedWidgets: [LegislationWidgetType.progressRing, LegislationWidgetType.statCard],
      icon: Icons.psychology,
    ),
    LegislationDataSource(
      key: 'aiAnalysisBreakdown',
      label: 'AI Analysis Status',
      description: 'Breakdown of AI analysis states',
      category: LegislationDataCategory.aiAnalysis,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.psychology,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'billsAiAnalyzedCount',
      label: 'Bills Analyzed',
      description: 'Bills with completed AI analysis',
      category: LegislationDataCategory.aiAnalysis,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.check_circle,
    ),
    LegislationDataSource(
      key: 'billsAiPendingCount',
      label: 'Analysis Pending',
      description: 'Bills with AI analysis in progress',
      category: LegislationDataCategory.aiAnalysis,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.pending,
    ),
    LegislationDataSource(
      key: 'billsAiErrorCount',
      label: 'Analysis Errors',
      description: 'Bills where AI analysis failed',
      category: LegislationDataCategory.aiAnalysis,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.error,
    ),
    LegislationDataSource(
      key: 'billsAwaitingAiAnalysisCount',
      label: 'Awaiting Analysis',
      description: 'Bills with text but no AI analysis yet',
      category: LegislationDataCategory.aiAnalysis,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.hourglass_empty,
    ),

    // ==================== AI RECOMMENDATIONS ====================
    LegislationDataSource(
      key: 'aiPositionRecommendations',
      label: 'AI Position Recommendations',
      description: 'AI-recommended positions breakdown',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.recommend,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'aiRecommendsSupportCount',
      label: 'AI: Support',
      description: 'Bills AI recommended support',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.thumb_up,
    ),
    LegislationDataSource(
      key: 'aiRecommendsOpposeCount',
      label: 'AI: Oppose',
      description: 'Bills AI recommended oppose',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.thumb_down,
    ),
    LegislationDataSource(
      key: 'aiRecommendsWatchingCount',
      label: 'AI: Watching',
      description: 'Bills AI recommended watching',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.visibility,
    ),
    LegislationDataSource(
      key: 'aiRecommendsNeutralCount',
      label: 'AI: Neutral',
      description: 'Bills AI recommended neutral',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.remove_circle_outline,
    ),
    LegislationDataSource(
      key: 'aiPriorityRecommendations',
      label: 'AI Priority Recommendations',
      description: 'AI-recommended priorities breakdown',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.flag,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'aiRecommendsCriticalCount',
      label: 'AI: Critical',
      description: 'Bills AI recommended critical priority',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.priority_high,
    ),
    LegislationDataSource(
      key: 'aiRecommendsHighCount',
      label: 'AI: High',
      description: 'Bills AI recommended high priority',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.arrow_upward,
    ),
    LegislationDataSource(
      key: 'aiRecommendsMediumCount',
      label: 'AI: Medium',
      description: 'Bills AI recommended medium priority',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.remove,
    ),
    LegislationDataSource(
      key: 'aiRecommendsLowCount',
      label: 'AI: Low',
      description: 'Bills AI recommended low priority',
      category: LegislationDataCategory.aiRecommendations,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.arrow_downward,
    ),

    // ==================== SESSION STATS ====================
    LegislationDataSource(
      key: 'currentSession',
      label: 'Current Session',
      description: 'Most recent legislative session',
      category: LegislationDataCategory.sessionStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.calendar_today,
    ),
    LegislationDataSource(
      key: 'billsCurrentSessionCount',
      label: 'Current Session Bills',
      description: 'Bills in the current session',
      category: LegislationDataCategory.sessionStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.calendar_view_month,
    ),

    // ==================== ACTIVITY / TIMELINE ====================
    LegislationDataSource(
      key: 'billsIntroducedThisWeek',
      label: 'Bills This Week',
      description: 'Bills introduced in the past week',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.trending_up,
    ),
    LegislationDataSource(
      key: 'billsIntroducedThisMonth',
      label: 'Bills This Month',
      description: 'Bills introduced in the past month',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.date_range,
    ),
    LegislationDataSource(
      key: 'billsIntroducedThisYear',
      label: 'Bills This Year',
      description: 'Bills introduced this calendar year',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.calendar_today,
    ),
    LegislationDataSource(
      key: 'actionsThisWeek',
      label: 'Actions This Week',
      description: 'Legislative actions taken this week',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.bolt,
    ),
    LegislationDataSource(
      key: 'actionsThisMonth',
      label: 'Actions This Month',
      description: 'Legislative actions taken this month',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.flash_on,
    ),
    LegislationDataSource(
      key: 'totalActionsCount',
      label: 'Total Actions',
      description: 'Total actions across all bills',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.list_alt,
    ),
    LegislationDataSource(
      key: 'billsWithRecentAction7dCount',
      label: 'Active Last 7 Days',
      description: 'Bills with action in last 7 days',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.update,
    ),
    LegislationDataSource(
      key: 'billsWithRecentAction30dCount',
      label: 'Active Last 30 Days',
      description: 'Bills with action in last 30 days',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.update,
    ),
    LegislationDataSource(
      key: 'avgActionsPerBill',
      label: 'Avg Actions/Bill',
      description: 'Average number of actions per bill',
      category: LegislationDataCategory.activity,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.analytics,
    ),

    // ==================== VOTE STATS ====================
    LegislationDataSource(
      key: 'voteBreakdown',
      label: 'Vote Outcomes',
      description: 'Passed vs Failed votes',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.pieChart, LegislationWidgetType.donutChart, LegislationWidgetType.barChart],
      icon: Icons.how_to_vote,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'totalVotesCount',
      label: 'Total Votes',
      description: 'Total recorded votes',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.how_to_vote,
    ),
    LegislationDataSource(
      key: 'votesPassedCount',
      label: 'Votes Passed',
      description: 'Votes that passed',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.check_circle,
    ),
    LegislationDataSource(
      key: 'votesFailedCount',
      label: 'Votes Failed',
      description: 'Votes that failed',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.cancel,
    ),
    LegislationDataSource(
      key: 'avgVotesPerBill',
      label: 'Avg Votes/Bill',
      description: 'Average votes per bill',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.analytics,
    ),
    LegislationDataSource(
      key: 'votesThisWeek',
      label: 'Votes This Week',
      description: 'Votes recorded in last 7 days',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.how_to_vote,
    ),
    LegislationDataSource(
      key: 'votesThisMonth',
      label: 'Votes This Month',
      description: 'Votes recorded in last 30 days',
      category: LegislationDataCategory.voteStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.how_to_vote,
    ),

    // ==================== DOCUMENT STATS ====================
    LegislationDataSource(
      key: 'totalDocumentsCount',
      label: 'Total Documents',
      description: 'Total attached documents',
      category: LegislationDataCategory.documentStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.folder_open,
    ),
    LegislationDataSource(
      key: 'totalVersionsCount',
      label: 'Total Versions',
      description: 'Total bill text versions',
      category: LegislationDataCategory.documentStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.history,
    ),

    // ==================== SPONSOR STATS ====================
    LegislationDataSource(
      key: 'totalSponsorsCount',
      label: 'Total Sponsors',
      description: 'Total sponsor records (all types)',
      category: LegislationDataCategory.sponsorStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.people,
    ),
    LegislationDataSource(
      key: 'totalPrimarySponsorsCount',
      label: 'Primary Sponsors',
      description: 'Total primary sponsor records',
      category: LegislationDataCategory.sponsorStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person,
    ),
    LegislationDataSource(
      key: 'totalCosponsorsCount',
      label: 'Co-Sponsors',
      description: 'Total co-sponsor records',
      category: LegislationDataCategory.sponsorStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.group,
    ),
    LegislationDataSource(
      key: 'avgSponsorsPerBill',
      label: 'Avg Sponsors/Bill',
      description: 'Average sponsors per bill',
      category: LegislationDataCategory.sponsorStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.analytics,
    ),
    LegislationDataSource(
      key: 'uniqueSponsorsCount',
      label: 'Unique Sponsors',
      description: 'Count of unique sponsor names',
      category: LegislationDataCategory.sponsorStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.person_search,
    ),

    // ==================== CATEGORY & TAG STATS ====================
    LegislationDataSource(
      key: 'billsWithCategoriesCount',
      label: 'Bills with Categories',
      description: 'Bills with assigned categories',
      category: LegislationDataCategory.categoryTags,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.category,
    ),
    LegislationDataSource(
      key: 'billsWithTagsCount',
      label: 'Bills with Tags',
      description: 'Bills with assigned tags',
      category: LegislationDataCategory.categoryTags,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.label,
    ),
    LegislationDataSource(
      key: 'topCategories',
      label: 'Top Categories',
      description: 'Top 20 categories by bill count',
      category: LegislationDataCategory.categoryTags,
      supportedWidgets: [LegislationWidgetType.barChart, LegislationWidgetType.leaderboard],
      icon: Icons.category,
      isDistribution: true,
    ),
    LegislationDataSource(
      key: 'topSubjects',
      label: 'Top Subjects',
      description: 'Top 20 subjects by bill count',
      category: LegislationDataCategory.categoryTags,
      supportedWidgets: [LegislationWidgetType.barChart, LegislationWidgetType.leaderboard],
      icon: Icons.topic,
      isDistribution: true,
    ),

    // ==================== ALERT STATS ====================
    LegislationDataSource(
      key: 'totalAlertsCount',
      label: 'Total Alerts',
      description: 'Total alert configurations',
      category: LegislationDataCategory.alerts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.notifications,
    ),
    LegislationDataSource(
      key: 'activeAlertsCount',
      label: 'Active Alerts',
      description: 'Currently active alerts',
      category: LegislationDataCategory.alerts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.notifications_active,
    ),
    LegislationDataSource(
      key: 'alertsSentTodayCount',
      label: 'Alerts Today',
      description: 'Alerts sent today',
      category: LegislationDataCategory.alerts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.today,
    ),
    LegislationDataSource(
      key: 'alertsSentThisWeekCount',
      label: 'Alerts This Week',
      description: 'Alerts sent in last 7 days',
      category: LegislationDataCategory.alerts,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.date_range,
    ),

    // ==================== NOTE STATS ====================
    LegislationDataSource(
      key: 'totalNotesCount',
      label: 'Total Notes',
      description: 'Total notes across all bills',
      category: LegislationDataCategory.notes,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.note,
    ),
    LegislationDataSource(
      key: 'billsWithNotesCount',
      label: 'Bills with Notes',
      description: 'Number of bills that have notes',
      category: LegislationDataCategory.notes,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.note_add,
    ),

    // ==================== SYNC STATS ====================
    LegislationDataSource(
      key: 'billsNeedingDetailSyncCount',
      label: 'Needs Detail Sync',
      description: 'Bills needing detail sync',
      category: LegislationDataCategory.syncStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.sync_problem,
    ),
    LegislationDataSource(
      key: 'billsNeedingTextExtractCount',
      label: 'Needs Text Extract',
      description: 'Bills needing text extraction',
      category: LegislationDataCategory.syncStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.text_snippet,
    ),
    LegislationDataSource(
      key: 'billsNeedingSponsorLinkCount',
      label: 'Needs Sponsor Link',
      description: 'Bills needing sponsor linking',
      category: LegislationDataCategory.syncStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.link,
    ),
    LegislationDataSource(
      key: 'billsWithSyncErrorsCount',
      label: 'Sync Errors',
      description: 'Bills with sync errors',
      category: LegislationDataCategory.syncStats,
      supportedWidgets: [LegislationWidgetType.statCard],
      icon: Icons.error_outline,
    ),
  ];

  static LegislationDataSource? getByKey(String key) {
    try {
      return all.firstWhere((ds) => ds.key == key);
    } catch (_) {
      return null;
    }
  }

  static List<LegislationDataSource> getByCategory(LegislationDataCategory category) {
    return all.where((ds) => ds.category == category).toList();
  }

  static List<LegislationDataSource> getForWidgetType(LegislationWidgetType type) {
    return all.where((ds) => ds.supportedWidgets.contains(type)).toList();
  }

  static String getCategoryLabel(LegislationDataCategory category) {
    switch (category) {
      case LegislationDataCategory.billCounts:
        return 'Bill Counts';
      case LegislationDataCategory.positions:
        return 'Positions';
      case LegislationDataCategory.priorities:
        return 'Priorities';
      case LegislationDataCategory.legislativeStatus:
        return 'Legislative Status';
      case LegislationDataCategory.chamberOrigin:
        return 'Chamber Origin';
      case LegislationDataCategory.partyStats:
        return 'Party Statistics';
      case LegislationDataCategory.bipartisan:
        return 'Bipartisan';
      case LegislationDataCategory.legislators:
        return 'Legislators';
      case LegislationDataCategory.leaderboards:
        return 'Leaderboards';
      case LegislationDataCategory.textPdf:
        return 'Text & PDF';
      case LegislationDataCategory.aiAnalysis:
        return 'AI Analysis';
      case LegislationDataCategory.aiRecommendations:
        return 'AI Recommendations';
      case LegislationDataCategory.sessionStats:
        return 'Session';
      case LegislationDataCategory.activity:
        return 'Activity & Timeline';
      case LegislationDataCategory.voteStats:
        return 'Votes';
      case LegislationDataCategory.documentStats:
        return 'Documents';
      case LegislationDataCategory.sponsorStats:
        return 'Sponsors';
      case LegislationDataCategory.categoryTags:
        return 'Categories & Tags';
      case LegislationDataCategory.alerts:
        return 'Alerts';
      case LegislationDataCategory.notes:
        return 'Notes';
      case LegislationDataCategory.syncStats:
        return 'Sync Status';
    }
  }
}

/// Pre-defined gradient color combinations for legislation dashboard widgets
/// Matches the CRM dashboard gradients for consistency
class LegislationWidgetGradients {
  // Extended color palette for blue variants
  static const _deepNavy = Color(0xFF0D1B2A);
  static const _oceanBlue = Color(0xFF1B4965);
  static const _darkSlate = Color(0xFF1A365D);
  static const _skyBlue = Color(0xFF63B3ED);
  static const _royalBlue = Color(0xFF4169E1);
  static const _midnightBlue = Color(0xFF191970);
  static const _indigoBlue = Color(0xFF4338CA);
  static const _tealBlue = Color(0xFF0D9488);

  static const List<List<Color>> all = [
    // Brand gradients
    [Color(0xFF273351), Color(0xFF32A6DE)],    // Unity Blue
    [Color(0xFF32A6DE), Color(0xFF6A1B9A)],    // Momentum Purple
    [Color(0xFF43A047), Color(0xFF32A6DE)],    // Grassroots Teal
    [Color(0xFFFDB813), Color(0xFFE63946)],    // Sunrise Fire
    [Color(0xFF6A1B9A), Color(0xFFE63946)],    // Purple Heat
    [Color(0xFFE63946), Color(0xFFFDB813)],    // Warm Sunset
    [Color(0xFF43A047), Color(0xFFFDB813)],    // Nature Glow
    [Color(0xFF273351), Color(0xFF43A047)],    // Forest Blue
    // Blue variants
    [_deepNavy, _oceanBlue],                    // Deep Ocean
    [_darkSlate, _oceanBlue],                   // Slate Ocean
    [Color(0xFF273351), _skyBlue],              // Sky Gradient
    [_royalBlue, Color(0xFF32A6DE)],            // Royal Momentum
    [_midnightBlue, _indigoBlue],               // Midnight Indigo
    [_tealBlue, Color(0xFF32A6DE)],             // Teal Momentum
    [_deepNavy, Color(0xFF32A6DE)],             // Navy Momentum
    [_indigoBlue, _skyBlue],                    // Indigo Sky
  ];

  static const List<String> names = [
    'Unity Blue',
    'Momentum Purple',
    'Grassroots Teal',
    'Sunrise Fire',
    'Purple Heat',
    'Warm Sunset',
    'Nature Glow',
    'Forest Blue',
    'Deep Ocean',
    'Slate Ocean',
    'Sky Gradient',
    'Royal Momentum',
    'Midnight Indigo',
    'Teal Momentum',
    'Navy Momentum',
    'Indigo Sky',
  ];

  /// Find the index of a gradient in the predefined list
  static int? indexOfColors(List<Color> colors) {
    if (colors.length < 2) return null;
    for (int i = 0; i < all.length; i++) {
      if (all[i].length >= 2 &&
          all[i][0].value == colors[0].value &&
          all[i][1].value == colors[1].value) {
        return i;
      }
    }
    return null;
  }

  /// Get gradient by index, with fallback
  static List<Color> getGradient(int index) {
    if (index >= 0 && index < all.length) {
      return all[index];
    }
    return all[0]; // Default to Unity Blue
  }
}
