// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tmail_server_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TMailServerSettings _$TMailServerSettingsFromJson(Map<String, dynamic> json) =>
    TMailServerSettings(
      id: const ServerSettingsIdNullableConverter().fromJson(
        json['id'] as String?,
      ),
      settings: json['settings'] == null
          ? null
          : TMailServerSettingOptions.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TMailServerSettingsToJson(
  TMailServerSettings instance,
) => <String, dynamic>{
  'id': ?const ServerSettingsIdNullableConverter().toJson(instance.id),
  'settings': ?instance.settings?.toJson(),
};

TMailServerSettingOptions _$TMailServerSettingOptionsFromJson(
  Map<String, dynamic> json,
) => TMailServerSettingOptions(
  alwaysReadReceipts: const BooleanNullableConverter().fromJson(
    json['read.receipts.always'] as String?,
  ),
  displaySenderPriority: const BooleanNullableConverter().fromJson(
    json['display.sender.priority'] as String?,
  ),
  language: json['language'] as String?,
  aiNeedsActionEnabled: const BooleanNullableConverter().fromJson(
    json['ai.needs-action.enabled'] as String?,
  ),
);

Map<String, dynamic> _$TMailServerSettingOptionsToJson(
  TMailServerSettingOptions instance,
) => <String, dynamic>{
  'read.receipts.always': ?const BooleanNullableConverter().toJson(
    instance.alwaysReadReceipts,
  ),
  'display.sender.priority': ?const BooleanNullableConverter().toJson(
    instance.displaySenderPriority,
  ),
  'language': ?instance.language,
  'ai.needs-action.enabled': ?const BooleanNullableConverter().toJson(
    instance.aiNeedsActionEnabled,
  ),
};
