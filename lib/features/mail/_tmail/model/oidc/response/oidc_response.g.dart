// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OIDCResponse _$OIDCResponseFromJson(Map<String, dynamic> json) => OIDCResponse(
  json['subject'] as String,
  (json['links'] as List<dynamic>)
      .map((e) => OIDCLinkDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OIDCResponseToJson(OIDCResponse instance) =>
    <String, dynamic>{'subject': instance.subject, 'links': instance.links};
