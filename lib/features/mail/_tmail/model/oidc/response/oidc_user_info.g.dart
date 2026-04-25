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
      if (instance.id case final value?) 'sid': value,
      if (instance.email case final value?) 'email': value,
      if (instance.sub case final value?) 'sub': value,
      if (instance.name case final value?) 'name': value,
      if (instance.preferredUsername case final value?)
        'preferred_username': value,
      if (instance.givenName case final value?) 'given_name': value,
      if (instance.familyName case final value?) 'family_name': value,
      if (instance.workplaceFqdn case final value?) 'workplaceFqdn': value,
    };
