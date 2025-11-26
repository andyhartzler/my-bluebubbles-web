import 'package:collection/collection.dart';

import 'campaign.dart';

class CampaignAnalytics {
  const CampaignAnalytics({
    this.campaign,
    this.totalRecipients = 0,
    this.delivered = 0,
    this.opened = 0,
    this.clicked = 0,
    this.bounced = 0,
    this.uniqueClickers = 0,
    this.sendTimeline = const <TimeSeriesPoint>[],
    this.openTimeline = const <TimeSeriesPoint>[],
    this.clickTimeline = const <TimeSeriesPoint>[],
    this.topLinks = const <CampaignLinkAnalytics>[],
  });

  final Campaign? campaign;
  final int totalRecipients;
  final int delivered;
  final int opened;
  final int clicked;
  final int bounced;
  final int uniqueClickers;
  final List<TimeSeriesPoint> sendTimeline;
  final List<TimeSeriesPoint> openTimeline;
  final List<TimeSeriesPoint> clickTimeline;
  final List<CampaignLinkAnalytics> topLinks;

  double get deliveryRate => totalRecipients == 0
      ? 0
      : (delivered / totalRecipients).clamp(0, 1);

  double get openRate => totalRecipients == 0
      ? 0
      : (opened / totalRecipients).clamp(0, 1);

  double get clickRate => totalRecipients == 0
      ? 0
      : (clicked / totalRecipients).clamp(0, 1);

  double get uniqueClickRate => totalRecipients == 0
      ? 0
      : (uniqueClickers / totalRecipients).clamp(0, 1);

  CampaignAnalytics copyWith({
    Campaign? campaign,
    int? totalRecipients,
    int? delivered,
    int? opened,
    int? clicked,
    int? bounced,
    int? uniqueClickers,
    List<TimeSeriesPoint>? sendTimeline,
    List<TimeSeriesPoint>? openTimeline,
    List<TimeSeriesPoint>? clickTimeline,
    List<CampaignLinkAnalytics>? topLinks,
  }) {
    return CampaignAnalytics(
      campaign: campaign ?? this.campaign,
      totalRecipients: totalRecipients ?? this.totalRecipients,
      delivered: delivered ?? this.delivered,
      opened: opened ?? this.opened,
      clicked: clicked ?? this.clicked,
      bounced: bounced ?? this.bounced,
      uniqueClickers: uniqueClickers ?? this.uniqueClickers,
      sendTimeline: sendTimeline ?? this.sendTimeline,
      openTimeline: openTimeline ?? this.openTimeline,
      clickTimeline: clickTimeline ?? this.clickTimeline,
      topLinks: topLinks ?? this.topLinks,
    );
  }

  static const CampaignAnalytics empty = CampaignAnalytics();
}

class CampaignLinkAnalytics {
  const CampaignLinkAnalytics({
    required this.id,
    required this.url,
    required this.clicks,
    required this.uniqueClicks,
    this.label,
  });

  final String id;
  final String url;
  final int clicks;
  final int uniqueClicks;
  final String? label;

  static CampaignLinkAnalytics? fromMap(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final String? id = value['id']?.toString() ?? value['link_id']?.toString();
    final String? url = value['url']?.toString();
    if (id == null || url == null) return null;
    return CampaignLinkAnalytics(
      id: id,
      url: url,
      clicks: _parseInt(value['clicks']) ?? 0,
      uniqueClicks: _parseInt(value['uniqueClicks'] ?? value['unique_clicks']) ?? 0,
      label: value['label']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class TimeSeriesPoint {
  const TimeSeriesPoint(this.timestamp, this.count);

  final DateTime timestamp;
  final int count;

  static List<TimeSeriesPoint> aggregateByDay(Iterable<DateTime> dates) {
    final Map<DateTime, int> buckets = <DateTime, int>{};
    for (final DateTime date in dates) {
      final DateTime dayBucket = DateTime(date.year, date.month, date.day);
      buckets[dayBucket] = (buckets[dayBucket] ?? 0) + 1;
    }

    return buckets.entries
        .map((entry) => TimeSeriesPoint(entry.key, entry.value))
        .sortedBy((point) => point.timestamp);
  }
}
