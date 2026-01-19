import 'dart:convert';
import 'package:flutter/material.dart';

/// Types of widgets available for the dashboard
enum DashboardWidgetType {
  statCard,
  barChart,
  lineChart,
  pieChart,
  donutChart,
  leaderboard,
  progressRing,
  sparkline,
  heatmap,
  trendCard,
  memberList,  // For displaying members with profile photos
  dynamicDistribution,  // Bar chart with dropdown to switch data sources
  quickLinksButton,  // Button that navigates to Quick Links page
}

/// Size options for widgets
enum DashboardWidgetSize {
  mini,       // 1x1 on grid - compact square with number on top, name below
  small,      // 1x0.5 on grid - half height compact row
  medium,     // 1x1 on grid - standard card size
  large,      // 2x1 on grid - wide card
  featured,   // 2x1.5 on grid - allows small cards on both sides in 4-column layout
  wide,       // 3x1 on grid - extra wide
  tall,       // 1x2 on grid - vertical
  hero,       // 3x2 on grid - full featured
  mobileFull, // Full width on mobile with tall proportions (like tall but full width)
}

/// Data source categories
enum DashboardDataCategory {
  members,
  chapters,
  donations,
  communications,
  events,
  demographics,
  geography,
  growth,
  engagement,
  resources,  // Quick links, documents, tools
  legislation,  // Legislation tracking and advocacy
  socialMedia,  // Social media platform stats
  email,  // Email campaigns and newsletters
}

/// Single widget configuration
class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  final DashboardWidgetSize size;
  final String dataSourceKey;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Color> gradientColors;
  final int gridX;
  final int gridY;
  final bool visible;
  final Map<String, dynamic> options;
  /// Optional swipe row ID - widgets with the same swipeRowId will be grouped
  /// into a horizontal swipeable row on mobile
  final String? swipeRowId;

  const DashboardWidgetConfig({
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

  DashboardWidgetConfig copyWith({
    String? id,
    DashboardWidgetType? type,
    DashboardWidgetSize? size,
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
    return DashboardWidgetConfig(
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

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    IconData? icon;
    if (json['iconCodePoint'] != null) {
      icon = IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      );
    }

    // Handle visible field - can be bool or int (from database)
    bool visible = true;
    final visibleValue = json['visible'];
    if (visibleValue is bool) {
      visible = visibleValue;
    } else if (visibleValue is int) {
      visible = visibleValue != 0;
    }

    // Handle size index safely - mini was added as index 0, so we need to
    // handle existing data that used the old enum indices
    int sizeIndex = json['size'] as int? ?? 1; // Default to small (index 1 now)
    if (sizeIndex >= DashboardWidgetSize.values.length) {
      sizeIndex = 1; // Default to small if out of range
    }

    return DashboardWidgetConfig(
      id: json['id'] as String,
      type: DashboardWidgetType.values[json['type'] as int? ?? 0],
      size: DashboardWidgetSize.values[sizeIndex],
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
      case DashboardWidgetSize.mini:    // 1x1 square
      case DashboardWidgetSize.small:   // 1x0.5 compact
      case DashboardWidgetSize.medium:  // 1x1 standard
      case DashboardWidgetSize.tall:    // 1x2 vertical
        return 1;
      case DashboardWidgetSize.large:   // 2x1 wide
      case DashboardWidgetSize.featured: // 2x1.5 - same width as large
        return 2;
      case DashboardWidgetSize.wide:    // 3x1 extra wide
      case DashboardWidgetSize.hero:    // 3x2 full featured
      case DashboardWidgetSize.mobileFull:
        return 3;
    }
  }

  /// Get the height in grid units
  int get gridHeight {
    switch (size) {
      case DashboardWidgetSize.small:   // Half height
        return 1; // Uses 0.5 multiplier
      case DashboardWidgetSize.mini:    // Square
      case DashboardWidgetSize.medium:  // Standard
      case DashboardWidgetSize.large:   // Wide card
      case DashboardWidgetSize.wide:    // Extra wide
        return 1;
      case DashboardWidgetSize.featured: // 2x1.5 - uses 2 grid height but 1.5 multiplier
      case DashboardWidgetSize.tall:    // Vertical
      case DashboardWidgetSize.hero:    // Full featured
      case DashboardWidgetSize.mobileFull:
        return 2;
    }
  }

  /// Get the actual height multiplier for rendering
  /// - mini is 0.5 (square - half height and half width)
  /// - small is 0.5 (half height compact row)
  /// - featured is 1.5 (between large's 1 and hero's 2)
  /// - others use their gridHeight
  double get heightMultiplier {
    switch (size) {
      case DashboardWidgetSize.mini:
        return 0.5; // Mini is a square: half height
      case DashboardWidgetSize.small:
        return 0.5; // Small is half height
      case DashboardWidgetSize.featured:
        return 1.5; // Featured is between large and hero
      default:
        return gridHeight.toDouble();
    }
  }

  /// Get the actual width multiplier for rendering
  /// - mini is 0.5 (square - half width)
  /// - featured is 2.0 (same as large, allowing small cards on both sides in a 4-column grid)
  /// - others use their gridWidth
  double get widthMultiplier {
    switch (size) {
      case DashboardWidgetSize.mini:
        return 0.5; // Mini is a square: half width
      case DashboardWidgetSize.featured:
        return 2.0; // Featured width allows small cards on left and right (1+2+1=4 columns)
      default:
        return gridWidth.toDouble();
    }
  }
}

/// Full dashboard configuration
class DashboardConfig {
  final String id;
  final String name;
  final List<DashboardWidgetConfig> widgets;
  final int columns;
  final DateTime? lastModified;

  const DashboardConfig({
    required this.id,
    required this.name,
    required this.widgets,
    this.columns = 4,
    this.lastModified,
  });

  DashboardConfig copyWith({
    String? id,
    String? name,
    List<DashboardWidgetConfig>? widgets,
    int? columns,
    DateTime? lastModified,
  }) {
    return DashboardConfig(
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

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    return DashboardConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      widgets: (json['widgets'] as List?)
          ?.map((e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      columns: json['columns'] as int? ?? 4,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static DashboardConfig fromJsonString(String jsonString) {
    return DashboardConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// Available data sources with metadata
class DashboardDataSource {
  final String key;
  final String label;
  final String description;
  final DashboardDataCategory category;
  final List<DashboardWidgetType> supportedWidgets;
  final IconData icon;
  final bool isDistribution; // true for chart data, false for single values

  const DashboardDataSource({
    required this.key,
    required this.label,
    required this.description,
    required this.category,
    required this.supportedWidgets,
    required this.icon,
    this.isDistribution = false,
  });
}

/// Registry of all available data sources
class DashboardDataSources {
  static const List<DashboardDataSource> all = [
    // Member Stats
    DashboardDataSource(
      key: 'totalMembers',
      label: 'Total Members',
      description: 'Total number of members in the database',
      category: DashboardDataCategory.members,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard, DashboardWidgetType.progressRing],
      icon: Icons.people,
    ),
    DashboardDataSource(
      key: 'totalMembersWithPhone',
      label: 'Members with Phone',
      description: 'Members with a phone number on file',
      category: DashboardDataCategory.members,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.progressRing],
      icon: Icons.phone,
    ),
    DashboardDataSource(
      key: 'totalSubscribers',
      label: 'Total Subscribers',
      description: 'Email newsletter subscribers',
      category: DashboardDataCategory.members,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.email,
    ),
    DashboardDataSource(
      key: 'totalDonors',
      label: 'Total Donors',
      description: 'Unique donors who have contributed',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.volunteer_activism,
    ),
    DashboardDataSource(
      key: 'newMembersThisWeek',
      label: 'New This Week',
      description: 'Members who joined this week',
      category: DashboardDataCategory.growth,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.trending_up,
    ),
    DashboardDataSource(
      key: 'newMembersThisMonth',
      label: 'New This Month',
      description: 'Members who joined this month',
      category: DashboardDataCategory.growth,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.calendar_month,
    ),
    DashboardDataSource(
      key: 'newMembersThisYear',
      label: 'New This Year',
      description: 'Members who joined this year',
      category: DashboardDataCategory.growth,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.calendar_today,
    ),
    DashboardDataSource(
      key: 'averageMemberAge',
      label: 'Average Age',
      description: 'Average age of members',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.cake,
    ),

    // Chapter Stats
    DashboardDataSource(
      key: 'totalChapters',
      label: 'Total Chapters',
      description: 'All chapters (chartered and unchartered)',
      category: DashboardDataCategory.chapters,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.groups,
    ),
    DashboardDataSource(
      key: 'totalCharteredChapters',
      label: 'Chartered Chapters',
      description: 'Officially chartered chapters',
      category: DashboardDataCategory.chapters,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.progressRing],
      icon: Icons.verified,
    ),
    DashboardDataSource(
      key: 'totalCollegeChapters',
      label: 'College Chapters',
      description: 'Chapters at colleges and universities',
      category: DashboardDataCategory.chapters,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.school,
    ),
    DashboardDataSource(
      key: 'totalHighschoolChapters',
      label: 'High School Chapters',
      description: 'Chapters at high schools',
      category: DashboardDataCategory.chapters,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.history_edu,
    ),

    // Geography
    DashboardDataSource(
      key: 'totalUniqueCounties',
      label: 'Counties Represented',
      description: 'Number of unique counties with members',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.progressRing],
      icon: Icons.map,
    ),
    DashboardDataSource(
      key: 'totalUniqueCongressionalDistricts',
      label: 'Congressional Districts',
      description: 'Unique congressional districts represented',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.location_city,
    ),
    DashboardDataSource(
      key: 'totalUniqueHouseDistricts',
      label: 'House Districts',
      description: 'State House districts represented',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.home_work,
    ),
    DashboardDataSource(
      key: 'totalUniqueSenateDistricts',
      label: 'Senate Districts',
      description: 'State Senate districts represented',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.account_balance,
    ),

    // Donations
    DashboardDataSource(
      key: 'totalDonationsAmount',
      label: 'Total Donations',
      description: 'Total amount donated all-time',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.attach_money,
    ),
    DashboardDataSource(
      key: 'totalDonationCount',
      label: 'Donation Count',
      description: 'Total number of donations',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.receipt_long,
    ),
    DashboardDataSource(
      key: 'averageDonationAmount',
      label: 'Avg Donation',
      description: 'Average donation amount',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.analytics,
    ),
    DashboardDataSource(
      key: 'donationsThisMonth',
      label: 'Donations This Month',
      description: 'Total donated this month',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.today,
    ),
    DashboardDataSource(
      key: 'donationsThisYear',
      label: 'Donations This Year',
      description: 'Total donated this year',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.event_note,
    ),

    // Communications
    DashboardDataSource(
      key: 'totalSlackMessages',
      label: 'Slack Messages',
      description: 'Total Slack messages sent',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.chat,
    ),
    DashboardDataSource(
      key: 'slackMessagesThisMonth',
      label: 'Slack This Month',
      description: 'Slack messages sent this month',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.chat_bubble,
    ),
    DashboardDataSource(
      key: 'totalSocialImpressions',
      label: 'Social Impressions',
      description: 'Total social media impressions',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.visibility,
    ),

    // Events
    DashboardDataSource(
      key: 'totalEvents',
      label: 'Total Events',
      description: 'All events created',
      category: DashboardDataCategory.events,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.event,
    ),
    DashboardDataSource(
      key: 'upcomingEvents',
      label: 'Upcoming Events',
      description: 'Events scheduled in the future',
      category: DashboardDataCategory.events,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.upcoming,
    ),
    DashboardDataSource(
      key: 'totalEventAttendees',
      label: 'Event Attendees',
      description: 'Total event attendance count',
      category: DashboardDataCategory.events,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.group_add,
    ),

    // Age Demographics
    DashboardDataSource(
      key: 'ageDistribution',
      label: 'Age Distribution',
      description: 'Members by age bucket',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart, DashboardWidgetType.donutChart],
      icon: Icons.pie_chart,
      isDistribution: true,
    ),

    // Distribution Charts
    DashboardDataSource(
      key: 'membersByCounty',
      label: 'Members by County',
      description: 'Distribution of members across counties',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.bar_chart,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByCongressionalDistrict',
      label: 'By Congressional District',
      description: 'Members per congressional district',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.bar_chart,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByChapter',
      label: 'Members by Chapter',
      description: 'Distribution across chapters',
      category: DashboardDataCategory.chapters,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.bar_chart,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByCommittee',
      label: 'Members by Committee',
      description: 'Distribution across committees',
      category: DashboardDataCategory.engagement,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.groups,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByCollege',
      label: 'Members by College',
      description: 'Distribution across colleges',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.school,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByHighSchool',
      label: 'Members by High School',
      description: 'Distribution across high schools',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart],
      icon: Icons.school,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByGraduationYear',
      label: 'By Graduation Year',
      description: 'Distribution by graduation year',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.lineChart],
      icon: Icons.school,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByEducationLevel',
      label: 'By Education Level',
      description: 'Distribution by education level',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.school,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByCommunityType',
      label: 'By Community Type',
      description: 'Urban, suburban, rural distribution',
      category: DashboardDataCategory.geography,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart, DashboardWidgetType.donutChart],
      icon: Icons.location_city,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByGenderIdentity',
      label: 'By Gender Identity',
      description: 'Gender identity distribution',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart, DashboardWidgetType.donutChart],
      icon: Icons.wc,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByRace',
      label: 'By Race/Ethnicity',
      description: 'Racial/ethnic distribution',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.diversity_3,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersBySexualOrientation',
      label: 'By Sexual Orientation',
      description: 'Sexual orientation distribution',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.favorite,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByVoterRegistration',
      label: 'Voter Registration',
      description: 'Voter registration status',
      category: DashboardDataCategory.engagement,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart, DashboardWidgetType.donutChart],
      icon: Icons.how_to_vote,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByIndustry',
      label: 'By Industry',
      description: 'Employment industry distribution',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.work,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersByReferralSource',
      label: 'Referral Sources',
      description: 'How members found us',
      category: DashboardDataCategory.growth,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.share,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'membersJoinedByMonth',
      label: 'Growth Over Time',
      description: 'Member signups by month',
      category: DashboardDataCategory.growth,
      supportedWidgets: [DashboardWidgetType.lineChart, DashboardWidgetType.barChart, DashboardWidgetType.sparkline],
      icon: Icons.show_chart,
      isDistribution: true,
    ),

    // Leaderboards
    DashboardDataSource(
      key: 'top5Donors',
      label: 'Top Donors',
      description: 'Highest contributing donors',
      category: DashboardDataCategory.donations,
      supportedWidgets: [DashboardWidgetType.leaderboard],
      icon: Icons.emoji_events,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'top50SlackMembers',
      label: 'Top Slack Members',
      description: 'Most active Slack participants',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.leaderboard],
      icon: Icons.leaderboard,
      isDistribution: true,
    ),

    // Member Lists
    DashboardDataSource(
      key: 'recentlyJoinedMembers',
      label: 'Recently Joined',
      description: 'Members who recently signed up',
      category: DashboardDataCategory.members,
      supportedWidgets: [DashboardWidgetType.memberList],
      icon: Icons.person_add,
      isDistribution: true,
    ),

    // Dynamic Distribution Chart
    DashboardDataSource(
      key: 'dynamicDistribution',
      label: 'Distribution Explorer',
      description: 'Interactive chart with dropdown to explore different member distributions',
      category: DashboardDataCategory.demographics,
      supportedWidgets: [DashboardWidgetType.dynamicDistribution],
      icon: Icons.analytics,
      isDistribution: true,
    ),

    // Quick Links
    DashboardDataSource(
      key: 'quickLinks',
      label: 'Quick Links',
      description: 'Access important links, documents, and resources',
      category: DashboardDataCategory.resources,
      supportedWidgets: [DashboardWidgetType.quickLinksButton],
      icon: Icons.link,
      isDistribution: false,
    ),

    // ============ SLACK ANALYTICS ============
    DashboardDataSource(
      key: 'slackActiveUsers',
      label: 'Slack Active Users',
      description: 'Number of active users in Slack workspace',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.group_work,
    ),
    DashboardDataSource(
      key: 'slackMessagesThisWeek',
      label: 'Slack This Week',
      description: 'Slack messages sent this week',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.chat_bubble,
    ),
    DashboardDataSource(
      key: 'slackChannelActivity',
      label: 'Channel Activity',
      description: 'Message distribution across Slack channels',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.tag,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'slackEngagementTrend',
      label: 'Slack Engagement Trend',
      description: 'Slack engagement over time',
      category: DashboardDataCategory.communications,
      supportedWidgets: [DashboardWidgetType.lineChart, DashboardWidgetType.sparkline],
      icon: Icons.trending_up,
      isDistribution: true,
    ),

    // ============ SOCIAL MEDIA STATS ============
    DashboardDataSource(
      key: 'totalFollowers',
      label: 'Total Followers',
      description: 'Combined followers across all social platforms',
      category: DashboardDataCategory.socialMedia,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.people_outline,
    ),
    DashboardDataSource(
      key: 'socialMediaReach',
      label: 'Social Reach',
      description: 'Total reach across social media platforms',
      category: DashboardDataCategory.socialMedia,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.language,
    ),
    DashboardDataSource(
      key: 'socialEngagementRate',
      label: 'Engagement Rate',
      description: 'Average engagement rate across platforms',
      category: DashboardDataCategory.socialMedia,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.progressRing],
      icon: Icons.thumb_up_alt,
    ),
    DashboardDataSource(
      key: 'followersByPlatform',
      label: 'Followers by Platform',
      description: 'Follower distribution across social platforms',
      category: DashboardDataCategory.socialMedia,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart, DashboardWidgetType.donutChart],
      icon: Icons.share,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'socialGrowthTrend',
      label: 'Social Growth',
      description: 'Follower growth over time',
      category: DashboardDataCategory.socialMedia,
      supportedWidgets: [DashboardWidgetType.lineChart, DashboardWidgetType.sparkline],
      icon: Icons.show_chart,
      isDistribution: true,
    ),

    // ============ LEGISLATION STATISTICS ============
    DashboardDataSource(
      key: 'totalBillsTracked',
      label: 'Bills Tracked',
      description: 'Total number of bills being tracked',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.gavel,
    ),
    DashboardDataSource(
      key: 'billsSupported',
      label: 'Bills Supported',
      description: 'Bills with support position',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.thumb_up,
    ),
    DashboardDataSource(
      key: 'billsOpposed',
      label: 'Bills Opposed',
      description: 'Bills with oppose position',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.thumb_down,
    ),
    DashboardDataSource(
      key: 'priorityBills',
      label: 'Priority Bills',
      description: 'High-priority legislation items',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.priority_high,
    ),
    DashboardDataSource(
      key: 'billsByPosition',
      label: 'Bills by Position',
      description: 'Distribution of bills by position (support/oppose/neutral)',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.pieChart, DashboardWidgetType.donutChart, DashboardWidgetType.barChart],
      icon: Icons.pie_chart,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'billsByPriority',
      label: 'Bills by Priority',
      description: 'Distribution of bills by priority level',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.flag,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'billsByCategory',
      label: 'Bills by Category',
      description: 'Distribution of bills by legislative category',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.barChart, DashboardWidgetType.pieChart],
      icon: Icons.category,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'legislativeActionsTaken',
      label: 'Actions Taken',
      description: 'Total advocacy actions taken on legislation',
      category: DashboardDataCategory.legislation,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.campaign,
    ),

    // ============ EMAIL CAMPAIGN STATS ============
    DashboardDataSource(
      key: 'totalEmailsSent',
      label: 'Emails Sent',
      description: 'Total emails sent in campaigns',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.email,
    ),
    DashboardDataSource(
      key: 'emailOpenRate',
      label: 'Open Rate',
      description: 'Average email open rate',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.progressRing],
      icon: Icons.mark_email_read,
    ),
    DashboardDataSource(
      key: 'emailClickRate',
      label: 'Click Rate',
      description: 'Average email click-through rate',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.progressRing],
      icon: Icons.ads_click,
    ),
    DashboardDataSource(
      key: 'emailUnsubscribeRate',
      label: 'Unsubscribe Rate',
      description: 'Average email unsubscribe rate',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.unsubscribe,
    ),
    DashboardDataSource(
      key: 'emailCampaignPerformance',
      label: 'Campaign Performance',
      description: 'Email campaign performance over time',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.lineChart, DashboardWidgetType.barChart],
      icon: Icons.insights,
      isDistribution: true,
    ),
    DashboardDataSource(
      key: 'emailsThisMonth',
      label: 'Emails This Month',
      description: 'Emails sent this month',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.statCard, DashboardWidgetType.trendCard],
      icon: Icons.calendar_month,
    ),
    DashboardDataSource(
      key: 'activeCampaigns',
      label: 'Active Campaigns',
      description: 'Number of active email campaigns',
      category: DashboardDataCategory.email,
      supportedWidgets: [DashboardWidgetType.statCard],
      icon: Icons.campaign,
    ),
  ];

  static DashboardDataSource? getByKey(String key) {
    try {
      return all.firstWhere((ds) => ds.key == key);
    } catch (_) {
      return null;
    }
  }

  static List<DashboardDataSource> getByCategory(DashboardDataCategory category) {
    return all.where((ds) => ds.category == category).toList();
  }

  static List<DashboardDataSource> getForWidgetType(DashboardWidgetType type) {
    return all.where((ds) => ds.supportedWidgets.contains(type)).toList();
  }
}
