// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_discovery_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OIDCDiscoveryResponse _$OIDCDiscoveryResponseFromJson(
  Map<String, dynamic> json,
) => OIDCDiscoveryResponse(
  json['authorization_endpoint'] as String?,
  json['token_endpoint'] as String?,
  json['end_session_endpoint'] as String?,
  json['userinfo_endpoint'] as String?,
);

Map<String, dynamic> _$OIDCDiscoveryResponseToJson(
  OIDCDiscoveryResponse instance,
) => <String, dynamic>{
  'authorization_endpoint': ?instance.authorizationEndpoint,
  'token_endpoint': ?instance.tokenEndpoint,
  'end_session_endpoint': ?instance.endSessionEndpoint,
  'userinfo_endpoint': ?instance.userInfoEndpoint,
};
