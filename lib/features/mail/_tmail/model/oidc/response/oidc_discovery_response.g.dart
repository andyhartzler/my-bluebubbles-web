// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_discovery_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OIDCDiscoveryResponse _$OIDCDiscoveryResponseFromJson(
        Map<String, dynamic> json) =>
    OIDCDiscoveryResponse(
      json['authorization_endpoint'] as String?,
      json['token_endpoint'] as String?,
      json['end_session_endpoint'] as String?,
      json['userinfo_endpoint'] as String?,
    );

Map<String, dynamic> _$OIDCDiscoveryResponseToJson(
        OIDCDiscoveryResponse instance) =>
    <String, dynamic>{
      if (instance.authorizationEndpoint case final value?)
        'authorization_endpoint': value,
      if (instance.tokenEndpoint case final value?) 'token_endpoint': value,
      if (instance.endSessionEndpoint case final value?)
        'end_session_endpoint': value,
      if (instance.userInfoEndpoint case final value?)
        'userinfo_endpoint': value,
    };
