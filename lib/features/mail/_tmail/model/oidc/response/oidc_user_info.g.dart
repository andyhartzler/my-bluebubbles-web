// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_user_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcUserInfo _$OidcUserInfoFromJson(Map<String, dynamic> json) => OidcUserInfo(
  id: json['sid'] as String?,
  sub: json['sub'] as String?,
  name: json['name'] as String?,
  preferredUsername: json['preferred_username'] as String?,
  givenName: json['given_name'] as String?,
  familyName: json['family_name'] as String?,
  email: json['email'] as String?,
  workplaceFqdn: json['workplaceFqdn'] as String?,
);

Map<String, dynamic> _$OidcUserInfoToJson(OidcUserInfo instance) =>
    <String, dynamic>{
      'sid': ?instance.id,
      'email': ?instance.email,
      'sub': ?instance.sub,
      'name': ?instance.name,
      'preferred_username': ?instance.preferredUsername,
      'given_name': ?instance.givenName,
      'family_name': ?instance.familyName,
      'workplaceFqdn': ?instance.workplaceFqdn,
    };
