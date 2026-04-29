// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capability_server_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SettingsCapability _$SettingsCapabilityFromJson(Map<String, dynamic> json) =>
    SettingsCapability(
      readOnlyProperties: (json['readOnlyProperties'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SettingsCapabilityToJson(SettingsCapability instance) =>
    <String, dynamic>{'readOnlyProperties': instance.readOnlyProperties};
