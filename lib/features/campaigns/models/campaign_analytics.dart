import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign_analytics.freezed.dart';
part 'campaign_analytics.g.dart';

@freezed
class CampaignAnalytics with _$CampaignAnalytics {
  const factory CampaignAnalytics({
    @JsonKey(name: 'campaign_id') required String campaignId,
    @Default(0) int totalRecipients,
    @Default(0) int pendingCount,
    @Default(0) int queuedCount,
    @Default(0) int processingCount,
    @Default(0) int sentCount,
    @Default(0) int deliveredCount,
    @Default(0) int failedCount,
    @Default(0) int bouncedCount,
    @Default(0) int openedCount,
    @Default(0) int clickedCount,
    @Default(0) int unsubscribedCount,
    @JsonKey(name: 'refreshed_at') DateTime? refreshedAt,
  }) = _CampaignAnalytics;

  factory CampaignAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CampaignAnalyticsFromJson(json);
}
