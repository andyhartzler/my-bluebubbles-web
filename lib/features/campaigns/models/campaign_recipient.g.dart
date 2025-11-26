// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign_recipient.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CampaignRecipientImpl _$$CampaignRecipientImplFromJson(
        Map<String, dynamic> json) =>
    _$CampaignRecipientImpl(
      id: json['id'] as String,
      campaignId: json['campaign_id'] as String,
      recipientId: json['recipient_id'] as String?,
      name: json['name'] as String?,
      address: json['address'] as String,
      channel: $enumDecodeNullable(_$CampaignChannelEnumMap, json['channel']) ??
          CampaignChannel.sms,
      status: $enumDecodeNullable(
              _$CampaignRecipientStatusEnumMap, json['status']) ??
          CampaignRecipientStatus.pending,
      errorMessage: json['error_message'] as String?,
      queuedAt: json['queued_at'] == null
          ? null
          : DateTime.parse(json['queued_at'] as String),
      sentAt: json['sent_at'] == null
          ? null
          : DateTime.parse(json['sent_at'] as String),
      deliveredAt: json['delivered_at'] == null
          ? null
          : DateTime.parse(json['delivered_at'] as String),
      openedAt: json['opened_at'] == null
          ? null
          : DateTime.parse(json['opened_at'] as String),
      clickedAt: json['clicked_at'] == null
          ? null
          : DateTime.parse(json['clicked_at'] as String),
      unsubscribedAt: json['unsubscribed_at'] == null
          ? null
          : DateTime.parse(json['unsubscribed_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$CampaignRecipientImplToJson(
        _$CampaignRecipientImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'campaign_id': instance.campaignId,
      'recipient_id': instance.recipientId,
      'name': instance.name,
      'address': instance.address,
      'channel': _$CampaignChannelEnumMap[instance.channel]!,
      'status': _$CampaignRecipientStatusEnumMap[instance.status]!,
      'error_message': instance.errorMessage,
      'queued_at': instance.queuedAt?.toIso8601String(),
      'sent_at': instance.sentAt?.toIso8601String(),
      'delivered_at': instance.deliveredAt?.toIso8601String(),
      'opened_at': instance.openedAt?.toIso8601String(),
      'clicked_at': instance.clickedAt?.toIso8601String(),
      'unsubscribed_at': instance.unsubscribedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$CampaignChannelEnumMap = {
  CampaignChannel.sms: 'sms',
  CampaignChannel.email: 'email',
};

const _$CampaignRecipientStatusEnumMap = {
  CampaignRecipientStatus.pending: 'pending',
  CampaignRecipientStatus.queued: 'queued',
  CampaignRecipientStatus.processing: 'processing',
  CampaignRecipientStatus.sending: 'sending',
  CampaignRecipientStatus.delivered: 'delivered',
  CampaignRecipientStatus.failed: 'failed',
  CampaignRecipientStatus.bounced: 'bounced',
  CampaignRecipientStatus.opened: 'opened',
  CampaignRecipientStatus.clicked: 'clicked',
  CampaignRecipientStatus.unsubscribed: 'unsubscribed',
};
