/// Model for cached analytics metrics
class SlackAnalyticsMetric {
  const SlackAnalyticsMetric({
    required this.metricName,
    required this.metricValue,
    required this.timePeriod,
    this.periodStart,
    this.periodEnd,
    this.computedAt,
  });

  factory SlackAnalyticsMetric.fromJson(Map<String, dynamic> json) {
    return SlackAnalyticsMetric(
      metricName: json['metric_name']?.toString() ?? '',
      metricValue: json['metric_value'] ?? {},
      timePeriod: json['time_period']?.toString() ?? '',
      periodStart: json['period_start'] != null
          ? DateTime.tryParse(json['period_start'].toString())
          : null,
      periodEnd: json['period_end'] != null
          ? DateTime.tryParse(json['period_end'].toString())
          : null,
      computedAt: json['computed_at'] != null
          ? DateTime.tryParse(json['computed_at'].toString())
          : null,
    );
  }

  final String metricName;
  final dynamic metricValue;
  final String timePeriod;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? computedAt;

  /// Check if the cached data is stale (older than 1 hour)
  bool get isStale {
    if (computedAt == null) return true;
    return DateTime.now().difference(computedAt!).inHours > 1;
  }
}

/// Summary analytics data
class SlackAnalyticsSummary {
  const SlackAnalyticsSummary({
    this.totalMessagesAllTime = 0,
    this.totalMessagesRecent = 0,
    this.linkedUsers = 0,
    this.unmatchedUsers = 0,
    this.rejectedUsers = 0,
    this.activeChannels = 0,
    this.computedAt,
  });

  factory SlackAnalyticsSummary.fromMetrics(List<SlackAnalyticsMetric> metrics) {
    int totalAllTime = 0;
    int totalRecent = 0;
    int linked = 0;
    int unmatched = 0;
    int rejected = 0;
    int channels = 0;
    DateTime? computed;

    for (final metric in metrics) {
      if (metric.metricName == 'total_messages') {
        final value = metric.metricValue as Map<String, dynamic>?;
        totalAllTime = (value?['all_time'] as num?)?.toInt() ?? 0;
        totalRecent = (value?['recent'] as num?)?.toInt() ?? 0;
        computed = metric.computedAt;
      } else if (metric.metricName == 'user_counts') {
        final value = metric.metricValue as Map<String, dynamic>?;
        linked = (value?['linked_users'] as num?)?.toInt() ?? 0;
        unmatched = (value?['unmatched_users'] as num?)?.toInt() ?? 0;
        rejected = (value?['rejected_users'] as num?)?.toInt() ?? 0;
        channels = (value?['active_channels'] as num?)?.toInt() ?? 0;
      }
    }

    return SlackAnalyticsSummary(
      totalMessagesAllTime: totalAllTime,
      totalMessagesRecent: totalRecent,
      linkedUsers: linked,
      unmatchedUsers: unmatched,
      rejectedUsers: rejected,
      activeChannels: channels,
      computedAt: computed,
    );
  }

  final int totalMessagesAllTime;
  final int totalMessagesRecent;
  final int linkedUsers;
  final int unmatchedUsers;
  final int rejectedUsers;
  final int activeChannels;
  final DateTime? computedAt;

  bool get isStale {
    if (computedAt == null) return true;
    return DateTime.now().difference(computedAt!).inHours > 1;
  }
}

/// Data point for time-series charts
class DailyMessageCount {
  const DailyMessageCount({
    required this.date,
    required this.count,
  });

  factory DailyMessageCount.fromJson(Map<String, dynamic> json) {
    return DailyMessageCount(
      date: json['date']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  final String date;
  final int count;
}

/// Channel activity data
class ChannelActivity {
  const ChannelActivity({
    required this.channelId,
    required this.channelName,
    required this.committee,
    required this.messageCount,
  });

  factory ChannelActivity.fromJson(Map<String, dynamic> json) {
    return ChannelActivity(
      channelId: json['channel_id']?.toString() ?? '',
      channelName: json['channel_name']?.toString() ?? '',
      committee: json['committee']?.toString() ?? '',
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String channelId;
  final String channelName;
  final String committee;
  final int messageCount;
}

/// User activity data
class UserActivity {
  const UserActivity({
    required this.slackUserId,
    required this.name,
    this.memberId,
    required this.isLinked,
    required this.messageCount,
  });

  factory UserActivity.fromJson(Map<String, dynamic> json) {
    return UserActivity(
      slackUserId: json['slack_user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      memberId: json['member_id']?.toString(),
      isLinked: json['is_linked'] as bool? ?? false,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String slackUserId;
  final String name;
  final String? memberId;
  final bool isLinked;
  final int messageCount;
}

/// Day of week activity data
class DayOfWeekActivity {
  const DayOfWeekActivity({
    required this.day,
    required this.dayName,
    required this.messageCount,
  });

  factory DayOfWeekActivity.fromJson(Map<String, dynamic> json) {
    return DayOfWeekActivity(
      day: (json['day'] as num?)?.toInt() ?? 0,
      dayName: json['day_name']?.toString() ?? '',
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int day;
  final String dayName;
  final int messageCount;
}

/// Hourly activity data
class HourlyActivity {
  const HourlyActivity({
    required this.hour,
    required this.messageCount,
  });

  factory HourlyActivity.fromJson(Map<String, dynamic> json) {
    return HourlyActivity(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  final int hour;
  final int messageCount;

  String get hourLabel {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

/// Membership change log entry
class MembershipChange {
  const MembershipChange({
    required this.id,
    this.memberId,
    this.slackUserId,
    required this.slackChannelId,
    required this.action,
    required this.source,
    this.createdAt,
    this.metadata,
  });

  factory MembershipChange.fromJson(Map<String, dynamic> json) {
    return MembershipChange(
      id: json['id']?.toString() ?? '',
      memberId: json['member_id']?.toString(),
      slackUserId: json['slack_user_id']?.toString(),
      slackChannelId: json['slack_channel_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String? memberId;
  final String? slackUserId;
  final String slackChannelId;
  final String action;
  final String source;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;
}
