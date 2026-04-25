// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_web_socket_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectWebSocketMessage _$ConnectWebSocketMessageFromJson(
        Map<String, dynamic> json) =>
    ConnectWebSocketMessage(
      webSocketAction: $enumDecode(_$WebSocketActionEnumMap, json['action']),
      webSocketUrl: json['url'] as String,
      webSocketTicket: json['ticket'] as String,
    );

Map<String, dynamic> _$ConnectWebSocketMessageToJson(
        ConnectWebSocketMessage instance) =>
    <String, dynamic>{
      'action': _$WebSocketActionEnumMap[instance.webSocketAction]!,
      'url': instance.webSocketUrl,
      'ticket': instance.webSocketTicket,
    };

const _$WebSocketActionEnumMap = {
  WebSocketAction.connect: 'connect',
  WebSocketAction.disconnect: 'disconnect',
};
