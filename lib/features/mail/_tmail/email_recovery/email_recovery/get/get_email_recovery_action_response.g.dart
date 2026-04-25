// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_email_recovery_action_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetEmailRecoveryActionResponse _$GetEmailRecoveryActionResponseFromJson(
        Map<String, dynamic> json) =>
    GetEmailRecoveryActionResponse(
      (json['list'] as List<dynamic>)
          .map((e) => EmailRecoveryAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      (json['notFound'] as List<dynamic>?)
          ?.map((e) => const IdConverter().fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$GetEmailRecoveryActionResponseToJson(
        GetEmailRecoveryActionResponse instance) =>
    <String, dynamic>{
      'list': instance.list,
      'notFound': instance.notFound?.map(const IdConverter().toJson).toList(),
    };
