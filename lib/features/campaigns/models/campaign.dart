import 'package:freezed_annotation/freezed_annotation.dart';

import 'campaign_analytics.dart';

part 'campaign.freezed.dart';
part 'campaign.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum CampaignStatus {
  draft,
  processing,
  scheduled,
  sending,
  completed,
  failed,
}

@freezed
class Campaign with _$Campaign {
  const factory Campaign({
    required String id,
    required String name,
    String? description,
    String? subject,
    @JsonKey(name: 'segment_id') String? segmentId,
    @JsonKey(name: 'template_id') String? templateId,
    @JsonKey(name: 'creator_id') String? creatorId,
    @Default(CampaignStatus.draft) CampaignStatus status,
    @JsonKey(name: 'scheduled_for') DateTime? scheduledFor,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(includeFromJson: false, includeToJson: false)
    CampaignAnalytics? analytics,
  }) = _Campaign;

  factory Campaign.fromJson(Map<String, dynamic> json) => _$CampaignFromJson(json);
}
