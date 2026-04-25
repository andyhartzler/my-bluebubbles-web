// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_oidc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenOIDC _$TokenOIDCFromJson(Map<String, dynamic> json) => TokenOIDC(
      json['token'] as String,
      const TokenIdConverter().fromJson(json['tokenId'] as String),
      json['refreshToken'] as String,
      expiredTime: json['expiredTime'] == null
          ? null
          : DateTime.parse(json['expiredTime'] as String),
    );

Map<String, dynamic> _$TokenOIDCToJson(TokenOIDC instance) => <String, dynamic>{
      'token': instance.token,
      'tokenId': const TokenIdConverter().toJson(instance.tokenId),
      if (instance.expiredTime?.toIso8601String() case final value?)
        'expiredTime': value,
      'refreshToken': instance.refreshToken,
    };
