// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CampaignAnalyticsImpl _$$CampaignAnalyticsImplFromJson(
        Map<String, dynamic> json) =>
    _$CampaignAnalyticsImpl(
      campaignId: json['campaign_id'] as String,
      totalRecipients: (json['totalRecipients'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      queuedCount: (json['queuedCount'] as num?)?.toInt() ?? 0,
      processingCount: (json['processingCount'] as num?)?.toInt() ?? 0,
      sentCount: (json['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['deliveredCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      bouncedCount: (json['bouncedCount'] as num?)?.toInt() ?? 0,
      openedCount: (json['openedCount'] as num?)?.toInt() ?? 0,
      clickedCount: (json['clickedCount'] as num?)?.toInt() ?? 0,
      unsubscribedCount: (json['unsubscribedCount'] as num?)?.toInt() ?? 0,
      refreshedAt: json['refreshed_at'] == null
          ? null
          : DateTime.parse(json['refreshed_at'] as String),
    );

Map<String, dynamic> _$$CampaignAnalyticsImplToJson(
        _$CampaignAnalyticsImpl instance) =>
    <String, dynamic>{
      'campaign_id': instance.campaignId,
      'totalRecipients': instance.totalRecipients,
      'pendingCount': instance.pendingCount,
      'queuedCount': instance.queuedCount,
      'processingCount': instance.processingCount,
      'sentCount': instance.sentCount,
      'deliveredCount': instance.deliveredCount,
      'failedCount': instance.failedCount,
      'bouncedCount': instance.bouncedCount,
      'openedCount': instance.openedCount,
      'clickedCount': instance.clickedCount,
      'unsubscribedCount': instance.unsubscribedCount,
      'refreshed_at': instance.refreshedAt?.toIso8601String(),
    };
