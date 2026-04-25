// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationPayload _$NotificationPayloadFromJson(Map<String, dynamic> json) =>
    NotificationPayload(
      emailId:
          const EmailIdNullableConverter().fromJson(json['emailId'] as String?),
      newState:
          const StateNullableConverter().fromJson(json['newState'] as String?),
    );

Map<String, dynamic> _$NotificationPayloadToJson(
        NotificationPayload instance) =>
    <String, dynamic>{
      if (const EmailIdNullableConverter().toJson(instance.emailId)
          case final value?)
        'emailId': value,
      if (const StateNullableConverter().toJson(instance.newState)
          case final value?)
        'newState': value,
    };
