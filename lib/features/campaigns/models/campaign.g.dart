// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'campaign.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CampaignImpl _$$CampaignImplFromJson(Map<String, dynamic> json) =>
    _$CampaignImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      subject: json['subject'] as String?,
      segmentId: json['segment_id'] as String?,
      templateId: json['template_id'] as String?,
      creatorId: json['creator_id'] as String?,
      status: $enumDecodeNullable(_$CampaignStatusEnumMap, json['status']) ??
          CampaignStatus.draft,
      scheduledFor: json['scheduled_for'] == null
          ? null
          : DateTime.parse(json['scheduled_for'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$CampaignImplToJson(_$CampaignImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'subject': instance.subject,
      'segment_id': instance.segmentId,
      'template_id': instance.templateId,
      'creator_id': instance.creatorId,
      'status': _$CampaignStatusEnumMap[instance.status]!,
      'scheduled_for': instance.scheduledFor?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$CampaignStatusEnumMap = {
  CampaignStatus.draft: 'draft',
  CampaignStatus.processing: 'processing',
  CampaignStatus.scheduled: 'scheduled',
  CampaignStatus.sending: 'sending',
  CampaignStatus.completed: 'completed',
  CampaignStatus.failed: 'failed',
};
