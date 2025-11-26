// GENERATED CODE - MANUALLY WRITTEN UNTIL BUILD RUNNER IS AVAILABLE.
// ignore_for_file: type=lint

part of 'campaign_analytics.dart';

_$_CampaignAnalytics _$CampaignAnalyticsFromJson(Map<String, dynamic> json) =>
    _$_CampaignAnalytics(
      campaignId: json['campaign_id'] as String,
      totalRecipients: json['total_recipients'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      queuedCount: json['queued_count'] as int? ?? 0,
      processingCount: json['processing_count'] as int? ?? 0,
      sentCount: json['sent_count'] as int? ?? 0,
      deliveredCount: json['delivered_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      bouncedCount: json['bounced_count'] as int? ?? 0,
      openedCount: json['opened_count'] as int? ?? 0,
      clickedCount: json['clicked_count'] as int? ?? 0,
      unsubscribedCount: json['unsubscribed_count'] as int? ?? 0,
      refreshedAt: json['refreshed_at'] == null
          ? null
          : DateTime.parse(json['refreshed_at'] as String),
    );

Map<String, dynamic> _$CampaignAnalyticsToJson(CampaignAnalytics instance) =>
    <String, dynamic>{
      'campaign_id': instance.campaignId,
      'total_recipients': instance.totalRecipients,
      'pending_count': instance.pendingCount,
      'queued_count': instance.queuedCount,
      'processing_count': instance.processingCount,
      'sent_count': instance.sentCount,
      'delivered_count': instance.deliveredCount,
      'failed_count': instance.failedCount,
      'bounced_count': instance.bouncedCount,
      'opened_count': instance.openedCount,
      'clicked_count': instance.clickedCount,
      'unsubscribed_count': instance.unsubscribedCount,
      'refreshed_at': instance.refreshedAt?.toIso8601String(),
    };
