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
      'value': ?instance.value,
      'clientAddress': ?instance.clientAddress,
      'generatedOn': ?instance.generatedOn?.toIso8601String(),
      'validUntil': ?instance.validUntil?.toIso8601String(),
      'username': ?instance.username,
    };
