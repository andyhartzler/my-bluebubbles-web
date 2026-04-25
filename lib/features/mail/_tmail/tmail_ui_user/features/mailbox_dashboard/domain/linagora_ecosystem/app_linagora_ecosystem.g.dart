// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_linagora_ecosystem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppLinagoraEcosystem _$AppLinagoraEcosystemFromJson(
        Map<String, dynamic> json) =>
    AppLinagoraEcosystem(
      appName: json['appName'] as String?,
      logoURL: json['logoURL'] as String?,
      androidPackageId: json['androidPackageId'] as String?,
      iosUrlScheme: json['iosUrlScheme'] as String?,
      iosAppStoreLink: json['iosAppStoreLink'] as String?,
      webLink:
          json['webLink'] == null ? null : Uri.parse(json['webLink'] as String),
    );

Map<String, dynamic> _$AppLinagoraEcosystemToJson(
        AppLinagoraEcosystem instance) =>
    <String, dynamic>{
      if (instance.appName case final value?) 'appName': value,
      if (instance.logoURL case final value?) 'logoURL': value,
      if (instance.androidPackageId case final value?)
        'androidPackageId': value,
      if (instance.iosUrlScheme case final value?) 'iosUrlScheme': value,
      if (instance.iosAppStoreLink case final value?) 'iosAppStoreLink': value,
      if (instance.webLink?.toString() case final value?) 'webLink': value,
    };
