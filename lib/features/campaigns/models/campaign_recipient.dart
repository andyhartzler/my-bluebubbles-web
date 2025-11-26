import 'package:freezed_annotation/freezed_annotation.dart';

part 'campaign_recipient.freezed.dart';
part 'campaign_recipient.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum CampaignChannel {
  sms,
  email,
}

@JsonEnum(fieldRename: FieldRename.snake)
enum CampaignRecipientStatus {
  pending,
  queued,
  processing,
  sending,
  delivered,
  failed,
  bounced,
  opened,
  clicked,
  unsubscribed,
}

@freezed
class CampaignRecipient with _$CampaignRecipient {
  const factory CampaignRecipient({
    required String id,
    @JsonKey(name: 'campaign_id') required String campaignId,
    @JsonKey(name: 'recipient_id') String? recipientId,
    String? name,
    required String address,
    @Default(CampaignChannel.sms)
    CampaignChannel channel,
    @Default(CampaignRecipientStatus.pending)
    CampaignRecipientStatus status,
    @JsonKey(name: 'error_message') String? errorMessage,
    @JsonKey(name: 'queued_at') DateTime? queuedAt,
    @JsonKey(name: 'sent_at') DateTime? sentAt,
    @JsonKey(name: 'delivered_at') DateTime? deliveredAt,
    @JsonKey(name: 'opened_at') DateTime? openedAt,
    @JsonKey(name: 'clicked_at') DateTime? clickedAt,
    @JsonKey(name: 'unsubscribed_at') DateTime? unsubscribedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _CampaignRecipient;

  factory CampaignRecipient.fromJson(Map<String, dynamic> json) =>
      _$CampaignRecipientFromJson(json);
}
