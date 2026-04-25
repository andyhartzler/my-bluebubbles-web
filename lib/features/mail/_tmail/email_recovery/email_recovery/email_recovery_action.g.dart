// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_recovery_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmailRecoveryAction _$EmailRecoveryActionFromJson(Map<String, dynamic> json) =>
    EmailRecoveryAction(
      id: const EmailRecoveryActionIdNullableConverter()
          .fromJson(json['id'] as String?),
      deletedBefore: const UTCDateNullableConverter()
          .fromJson(json['deletedBefore'] as String?),
      deletedAfter: const UTCDateNullableConverter()
          .fromJson(json['deletedAfter'] as String?),
      receivedBefore: const UTCDateNullableConverter()
          .fromJson(json['receivedBefore'] as String?),
      receivedAfter: const UTCDateNullableConverter()
          .fromJson(json['receivedAfter'] as String?),
      hasAttachment: json['hasAttachment'] as bool?,
      subject: json['subject'] as String?,
      sender: json['sender'] as String?,
      recipients: (json['recipients'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      successfulRestoreCount: const UnsignedIntNullableConverter()
          .fromJson((json['successfulRestoreCount'] as num?)?.toInt()),
      errorRestoreCount: const UnsignedIntNullableConverter()
          .fromJson((json['errorRestoreCount'] as num?)?.toInt()),
      status: $enumDecodeNullable(_$EmailRecoveryStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$EmailRecoveryActionToJson(
        EmailRecoveryAction instance) =>
    <String, dynamic>{
      if (const EmailRecoveryActionIdNullableConverter().toJson(instance.id)
          case final value?)
        'id': value,
      if (const UTCDateNullableConverter().toJson(instance.deletedBefore)
          case final value?)
        'deletedBefore': value,
      if (const UTCDateNullableConverter().toJson(instance.deletedAfter)
          case final value?)
        'deletedAfter': value,
      if (const UTCDateNullableConverter().toJson(instance.receivedBefore)
          case final value?)
        'receivedBefore': value,
      if (const UTCDateNullableConverter().toJson(instance.receivedAfter)
          case final value?)
        'receivedAfter': value,
      if (instance.hasAttachment case final value?) 'hasAttachment': value,
      if (instance.subject case final value?) 'subject': value,
      if (instance.sender case final value?) 'sender': value,
      if (instance.recipients case final value?) 'recipients': value,
      if (const UnsignedIntNullableConverter()
              .toJson(instance.successfulRestoreCount)
          case final value?)
        'successfulRestoreCount': value,
      if (const UnsignedIntNullableConverter()
              .toJson(instance.errorRestoreCount)
          case final value?)
        'errorRestoreCount': value,
      if (_$EmailRecoveryStatusEnumMap[instance.status] case final value?)
        'status': value,
    };

const _$EmailRecoveryStatusEnumMap = {
  EmailRecoveryStatus.waiting: 'waiting',
  EmailRecoveryStatus.inProgress: 'inProgress',
  EmailRecoveryStatus.completed: 'completed',
  EmailRecoveryStatus.failed: 'failed',
  EmailRecoveryStatus.canceled: 'canceled',
};
