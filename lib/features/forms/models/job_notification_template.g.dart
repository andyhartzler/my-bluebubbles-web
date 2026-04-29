// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_notification_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JobNotificationTemplate _$JobNotificationTemplateFromJson(
        Map<String, dynamic> json) =>
    _JobNotificationTemplate(
      id: json['id'] as String,
      triggerType: json['trigger_type'] as String,
      recipientType: json['recipient_type'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      emailEnabled: json['email_enabled'] as bool? ?? true,
      emailSubject: json['email_subject'] as String?,
      emailHtml: json['email_html'] as String?,
      emailPlainText: json['email_plain_text'] as String?,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
      smsBody: json['sms_body'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );

Map<String, dynamic> _$JobNotificationTemplateToJson(
        _JobNotificationTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trigger_type': instance.triggerType,
      'recipient_type': instance.recipientType,
      'name': instance.name,
      'description': instance.description,
      'email_enabled': instance.emailEnabled,
      'email_subject': instance.emailSubject,
      'email_html': instance.emailHtml,
      'email_plain_text': instance.emailPlainText,
      'sms_enabled': instance.smsEnabled,
      'sms_body': instance.smsBody,
      'is_active': instance.isActive,
      'is_default': instance.isDefault,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'created_by': instance.createdBy,
      'updated_by': instance.updatedBy,
    };
