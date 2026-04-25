// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_socket_ticket.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebSocketTicket _$WebSocketTicketFromJson(Map<String, dynamic> json) =>
    WebSocketTicket(
      value: json['value'] as String?,
      clientAddress: json['clientAddress'] as String?,
      generatedOn: json['generatedOn'] == null
          ? null
          : DateTime.parse(json['generatedOn'] as String),
      validUntil: json['validUntil'] == null
          ? null
          : DateTime.parse(json['validUntil'] as String),
      username: json['username'] as String?,
    );

Map<String, dynamic> _$WebSocketTicketToJson(WebSocketTicket instance) =>
    <String, dynamic>{
      if (instance.value case final value?) 'value': value,
      if (instance.clientAddress case final value?) 'clientAddress': value,
      if (instance.generatedOn?.toIso8601String() case final value?)
        'generatedOn': value,
      if (instance.validUntil?.toIso8601String() case final value?)
        'validUntil': value,
      if (instance.username case final value?) 'username': value,
    };
