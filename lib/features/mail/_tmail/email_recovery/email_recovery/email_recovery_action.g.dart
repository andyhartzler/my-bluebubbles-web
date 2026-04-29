// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_recovery_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmailRecoveryAction _$EmailRecoveryActionFromJson(Map<String, dynamic> json) =>
    EmailRecoveryAction(
      id: const EmailRecoveryActionIdNullableConverter().fromJson(
        json['id'] as String?,
      ),
      deletedBefore: const UTCDateNullableConverter().fromJson(
        json['deletedBefore'] as String?,
      ),
      deletedAfter: const UTCDateNullableConverter().fromJson(
        json['deletedAfter'] as String?,
      ),
      receivedBefore: const UTCDateNullableConverter().fromJson(
        json['receivedBefore'] as String?,
      ),
      receivedAfter: const UTCDateNullableConverter().fromJson(
        json['receivedAfter'] as String?,
      ),
      hasAttachment: json['hasAttachment'] as bool?,
      subject: json['subject'] as String?,
      sender: json['sender'] as String?,
      recipients: (json['recipients'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      successfulRestoreCount: const UnsignedIntNullableConverter().fromJson(
        (json['successfulRestoreCount'] as num?)?.toInt(),
      ),
      errorRestoreCount: const UnsignedIntNullableConverter().fromJson(
        (json['errorRestoreCount'] as num?)?.toInt(),
      ),
      status: $enumDecodeNullable(_$EmailRecoveryStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$EmailRecoveryActionToJson(
  EmailRecoveryAction instance,
) => <String, dynamic>{
  'id': ?const EmailRecoveryActionIdNullableConverter().toJson(instance.id),
  'deletedBefore': ?const UTCDateNullableConverter().toJson(
    instance.deletedBefore,
  ),
  'deletedAfter': ?const UTCDateNullableConverter().toJson(
    instance.deletedAfter,
  ),
  'receivedBefore': ?const UTCDateNullableConverter().toJson(
    instance.receivedBefore,
  ),
  'receivedAfter': ?const UTCDateNullableConverter().toJson(
    instance.receivedAfter,
  ),
  'hasAttachment': ?instance.hasAttachment,
  'subject': ?instance.subject,
  'sender': ?instance.sender,
  'recipients': ?instance.recipients,
  'successfulRestoreCount': ?const UnsignedIntNullableConverter().toJson(
    instance.successfulRestoreCount,
  ),
  'errorRestoreCount': ?const UnsignedIntNullableConverter().toJson(
    instance.errorRestoreCount,
  ),
  'status': ?_$EmailRecoveryStatusEnumMap[instance.status],
};

const _$EmailRecoveryStatusEnumMap = {
  EmailRecoveryStatus.waiting: 'waiting',
  EmailRecoveryStatus.inProgress: 'inProgress',
  EmailRecoveryStatus.completed: 'completed',
  EmailRecoveryStatus.failed: 'failed',
  EmailRecoveryStatus.canceled: 'canceled',
};
