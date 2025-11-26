import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign_analytics.freezed.dart';
part 'campaign_analytics.g.dart';

@freezed
class CampaignAnalytics with _$CampaignAnalytics {
  const factory CampaignAnalytics({
    @JsonKey(name: 'campaign_id') required String campaignId,
    @JsonKey(defaultValue: 0) int totalRecipients,
    @JsonKey(defaultValue: 0) int pendingCount,
    @JsonKey(defaultValue: 0) int queuedCount,
    @JsonKey(defaultValue: 0) int processingCount,
    @JsonKey(defaultValue: 0) int sentCount,
    @JsonKey(defaultValue: 0) int deliveredCount,
    @JsonKey(defaultValue: 0) int failedCount,
    @JsonKey(defaultValue: 0) int bouncedCount,
    @JsonKey(defaultValue: 0) int openedCount,
    @JsonKey(defaultValue: 0) int clickedCount,
    @JsonKey(defaultValue: 0) int unsubscribedCount,
    @JsonKey(name: 'refreshed_at') DateTime? refreshedAt,
  }) = _CampaignAnalytics;

  factory CampaignAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CampaignAnalyticsFromJson(json);
}
