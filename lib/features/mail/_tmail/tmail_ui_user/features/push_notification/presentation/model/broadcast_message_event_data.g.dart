// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_message_event_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BroadcastMessageEventData _$BroadcastMessageEventDataFromJson(
        Map<String, dynamic> json) =>
    BroadcastMessageEventData(
      json['messageId'] as String?,
      json['data'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$BroadcastMessageEventDataToJson(
        BroadcastMessageEventData instance) =>
    <String, dynamic>{
      if (instance.messageId case final value?) 'messageId': value,
      if (instance.data case final value?) 'data': value,
    };
