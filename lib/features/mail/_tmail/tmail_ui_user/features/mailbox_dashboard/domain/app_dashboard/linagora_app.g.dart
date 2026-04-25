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
      if (instance.appName case final value?) 'appName': value,
      if (instance.androidPackageId case final value?)
        'androidPackageId': value,
      if (instance.iosUrlScheme case final value?) 'iosUrlScheme': value,
      if (instance.iosAppStoreLink case final value?) 'iosAppStoreLink': value,
      if (instance.iconName case final value?) 'icon': value,
      'appLink': instance.appUri.toString(),
      if (instance.publicIconUri?.toString() case final value?)
        'publicIconUri': value,
    };
