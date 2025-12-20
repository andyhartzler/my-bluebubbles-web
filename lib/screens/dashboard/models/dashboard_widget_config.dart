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
}

/// Size options for widgets
enum DashboardWidgetSize {
  small,   // 1x1 on grid
  medium,  // 2x1 on grid
  large,   // 2x2 on grid
  wide,    // 3x1 on grid
  tall,    // 1x2 on grid
  hero,    // 3x2 on grid
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
  };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    IconData? icon;
    if (json['iconCodePoint'] != null) {
      icon = IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      );
    }

    return DashboardWidgetConfig(
      id: json['id'] as String,
      type: DashboardWidgetType.values[json['type'] as int? ?? 0],
      size: DashboardWidgetSize.values[json['size'] as int? ?? 0],
      dataSourceKey: json['dataSourceKey'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      icon: icon,
      gradientColors: (json['gradientColors'] as List?)
          ?.map((e) => Color(e as int))
          .toList() ?? [],
      gridX: json['gridX'] as int? ?? 0,
      gridY: json['gridY'] as int? ?? 0,
      visible: json['visible'] as bool? ?? true,
      options: json['options'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Get the width in grid units
  int get gridWidth {
    switch (size) {
      case DashboardWidgetSize.small:
      case DashboardWidgetSize.tall:
        return 1;
      case DashboardWidgetSize.medium:
      case DashboardWidgetSize.large:
        return 2;
      case DashboardWidgetSize.wide:
      case DashboardWidgetSize.hero:
        return 3;
    }
  }

  /// Get the height in grid units
  int get gridHeight {
    switch (size) {
      case DashboardWidgetSize.small:
      case DashboardWidgetSize.medium:
      case DashboardWidgetSize.wide:
        return 1;
      case DashboardWidgetSize.tall:
      case DashboardWidgetSize.large:
        return 2;
      case DashboardWidgetSize.hero:
        return 2;
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
