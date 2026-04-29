// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linagora_app.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinagoraApp _$LinagoraAppFromJson(Map<String, dynamic> json) => LinagoraApp(
  appUri: Uri.parse(json['appLink'] as String),
  iconName: json['icon'] as String?,
  publicIconUri: json['publicIconUri'] == null
      ? null
      : Uri.parse(json['publicIconUri'] as String),
  appName: json['appName'] as String?,
  androidPackageId: json['androidPackageId'] as String?,
  iosUrlScheme: json['iosUrlScheme'] as String?,
  iosAppStoreLink: json['iosAppStoreLink'] as String?,
);

Map<String, dynamic> _$LinagoraAppToJson(LinagoraApp instance) =>
    <String, dynamic>{
      'appName': ?instance.appName,
      'androidPackageId': ?instance.androidPackageId,
      'iosUrlScheme': ?instance.iosUrlScheme,
      'iosAppStoreLink': ?instance.iosAppStoreLink,
      'icon': ?instance.iconName,
      'appLink': instance.appUri.toString(),
      'publicIconUri': ?instance.publicIconUri?.toString(),
    };
