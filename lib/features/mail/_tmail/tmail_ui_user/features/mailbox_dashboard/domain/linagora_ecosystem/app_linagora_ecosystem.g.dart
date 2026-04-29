// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_linagora_ecosystem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppLinagoraEcosystem _$AppLinagoraEcosystemFromJson(
  Map<String, dynamic> json,
) => AppLinagoraEcosystem(
  appName: json['appName'] as String?,
  logoURL: json['logoURL'] as String?,
  androidPackageId: json['androidPackageId'] as String?,
  iosUrlScheme: json['iosUrlScheme'] as String?,
  iosAppStoreLink: json['iosAppStoreLink'] as String?,
  webLink: json['webLink'] == null
      ? null
      : Uri.parse(json['webLink'] as String),
);

Map<String, dynamic> _$AppLinagoraEcosystemToJson(
  AppLinagoraEcosystem instance,
) => <String, dynamic>{
  'appName': ?instance.appName,
  'logoURL': ?instance.logoURL,
  'androidPackageId': ?instance.androidPackageId,
  'iosUrlScheme': ?instance.iosUrlScheme,
  'iosAppStoreLink': ?instance.iosAppStoreLink,
  'webLink': ?instance.webLink?.toString(),
};
