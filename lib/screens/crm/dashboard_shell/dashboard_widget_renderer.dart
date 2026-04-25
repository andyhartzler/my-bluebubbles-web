import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/dashboard_metrics.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/dashboard/models/dashboard_widget_config.dart';
import 'package:bluebubbles/screens/dashboard/widgets/dashboard_widgets.dart';

/// Read-only renderer used by per-user Dashboard pages on the
/// `DashboardShellScreen`. Covers the most common widget types
/// (statCard, trendCard, progressRing, leaderboard, memberList,
/// dynamicDistribution, quickLinksButton). Chart types fall back to
/// a labelled card with a "see Universal" CTA — v2 will land the
/// full renderer plus edit mode.
///
/// Mirrors the dispatch in `_DashboardScreenState._buildWidgetInternal`
/// (dashboard_screen.dart) without modifying the existing screen.
class DashboardWidgetRenderer {
  static Widget render({
    required DashboardWidgetConfig config,
    required DashboardMetrics metrics,
    int quickLinksCount = 0,
    List<Member> recentMembers = const [],
    VoidCallback? onTap,
  }) {
    try {
      return _renderInternal(
        config: config,
        metrics: metrics,
        quickLinksCount: quickLinksCount,
        recentMembers: recentMembers,
        onTap: onTap,
      );
    } catch (e) {
      return _errorCard(config, e.toString());
    }
  }

  static Widget _renderInternal({
    required DashboardWidgetConfig config,
    required DashboardMetrics metrics,
    required int quickLinksCount,
    required List<Member> recentMembers,
    VoidCallback? onTap,
  }) {
    switch (config.type) {
      case DashboardWidgetType.statCard:
      case DashboardWidgetType.trendCard:
        return StatCardWidget(
          config: config,
          value: _scalarValue(config.dataSourceKey, metrics),
          onTap: onTap,
        );

      case DashboardWidgetType.progressRing:
        final raw = _scalarValue(config.dataSourceKey, metrics);
        int total = 100;
        bool isPct = false;
        switch (config.dataSourceKey) {
          case 'totalUniqueCounties':
            total = 114;
            break;
          case 'totalUniqueCongressionalDistricts':
            total = 8;
            break;
          case 'totalUniqueHouseDistricts':
            total = 163;
            break;
          case 'totalUniqueSenateDistricts':
            total = 34;
            break;
          case 'socialEngagementRate':
          case 'emailOpenRate':
          case 'emailClickRate':
            total = 100;
            isPct = true;
            break;
        }
        final current =
            isPct ? (raw is num ? (raw * 100).toInt() : 0) : (raw is num ? raw.toInt() : 0);
        return ProgressRingWidget(
          config: config,
          current: current,
          total: total,
        );

      case DashboardWidgetType.leaderboard:
        if (config.dataSourceKey == 'top5Donors') {
          return LeaderboardWidget(
            config: config,
            data: metrics.top5Donors,
            isDonors: true,
            onTap: onTap,
          );
        } else if (config.dataSourceKey == 'top50SlackMembers') {
          return LeaderboardWidget(
            config: config,
            data: metrics.top50SlackMembers,
            isDonors: false,
            onTap: onTap,
          );
        }
        return _stubCard(config);

      case DashboardWidgetType.memberList:
        return MemberListWidget(
          config: config,
          members: recentMembers,
          onMemberTap: (_) {},
        );

      case DashboardWidgetType.dynamicDistribution:
        return DynamicDistributionChartWidget(config: config, metrics: metrics);

      case DashboardWidgetType.quickLinksButton:
        return QuickLinksButtonWidget(
          config: config,
          linkCount: quickLinksCount,
          onTap: onTap,
        );

      case DashboardWidgetType.barChart:
      case DashboardWidgetType.lineChart:
      case DashboardWidgetType.pieChart:
      case DashboardWidgetType.donutChart:
      case DashboardWidgetType.sparkline:
      case DashboardWidgetType.heatmap:
        // v1 stub for chart-style widgets on personal pages — full
        // renderer comes in v2 along with personal-page edit mode.
        return _stubCard(config);
    }
  }

  /// Look up a scalar metric value by `dataSourceKey`. Mirrors the
  /// switch in `_DashboardScreenState._getValueForDataSource` for the
  /// keys that map to scalar fields on `DashboardMetrics`.
  static dynamic _scalarValue(String key, DashboardMetrics m) {
    switch (key) {
      case 'totalMembers':
        return m.totalMembers;
      case 'totalMembersWithPhone':
        return m.totalMembersWithPhone;
      case 'totalSubscribers':
        return m.totalSubscribers;
      case 'totalDonors':
        return m.totalDonors;
      case 'totalChapters':
        return m.totalChapters;
      case 'totalCharteredChapters':
        return m.totalCharteredChapters;
      case 'totalCollegeChapters':
        return m.totalCollegeChapters;
      case 'totalHighschoolChapters':
        return m.totalHighschoolChapters;
      case 'totalUniqueCounties':
        return m.totalUniqueCounties;
      case 'totalUniqueCongressionalDistricts':
        return m.totalUniqueCongressionalDistricts;
      case 'totalUniqueHouseDistricts':
        return m.totalUniqueHouseDistricts;
      case 'totalUniqueSenateDistricts':
        return m.totalUniqueSenateDistricts;
      case 'totalDonationsAmount':
        return m.totalDonationsAmount;
      case 'totalDonationCount':
        return m.totalDonationCount;
      case 'averageDonationAmount':
        return m.averageDonationAmount;
      case 'donationsThisMonth':
        return m.donationsThisMonth;
      case 'donationsThisYear':
        return m.donationsThisYear;
      case 'totalSlackMessages':
        return m.totalSlackMessages;
      case 'slackMessagesThisMonth':
        return m.slackMessagesThisMonth;
      case 'slackMessagesThisWeek':
        return m.slackMessagesThisWeek;
      case 'slackActiveUsers':
        return m.slackActiveUsers;
      case 'totalSocialImpressions':
        return m.totalSocialImpressions;
      case 'totalFollowers':
        return m.totalFollowers;
      case 'socialMediaReach':
        return m.socialMediaReach;
      case 'socialEngagementRate':
        return m.socialEngagementRate;
      case 'totalBillsTracked':
        return m.totalBillsTracked;
      case 'billsSupported':
        return m.billsSupported;
      case 'billsOpposed':
        return m.billsOpposed;
      case 'priorityBills':
        return m.priorityBills;
      case 'totalEmailsSent':
        return m.totalEmailsSent;
      case 'emailOpenRate':
        // Open rate = opened / sent (computed from totals)
        return m.totalEmailsSent > 0
            ? (m.totalEmailsOpened / m.totalEmailsSent)
            : 0;
      case 'emailClickRate':
        // Click rate = clicked / sent (computed from totals)
        return m.totalEmailsSent > 0
            ? (m.totalEmailsClicked / m.totalEmailsSent)
            : 0;
      case 'newMembersThisWeek':
        return m.newMembersThisWeek;
      case 'newMembersThisMonth':
        return m.newMembersThisMonth;
      case 'newMembersThisYear':
        return m.newMembersThisYear;
      case 'totalEvents':
        return m.totalEvents;
      case 'upcomingEvents':
        return m.upcomingEvents;
      case 'totalEventAttendees':
        return m.totalEventAttendees;
      default:
        return 0;
    }
  }

  static Widget _stubCard(DashboardWidgetConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (config.icon != null) Icon(config.icon, size: 20, color: Colors.grey),
            const SizedBox(height: 6),
            Text(
              config.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'Live values on the Universal tab',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _errorCard(DashboardWidgetConfig config, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 24),
            const SizedBox(height: 6),
            Text(config.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
