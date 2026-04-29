// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_link_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OIDCLinkDto _$OIDCLinkDtoFromJson(Map<String, dynamic> json) => OIDCLinkDto(
  const UriConverter().fromJson(json['rel'] as String),
  const UriConverter().fromJson(json['href'] as String),
);

Map<String, dynamic> _$OIDCLinkDtoToJson(OIDCLinkDto instance) =>
    <String, dynamic>{
      'rel': const UriConverter().toJson(instance.rel),
      'href': const UriConverter().toJson(instance.href),
    };
