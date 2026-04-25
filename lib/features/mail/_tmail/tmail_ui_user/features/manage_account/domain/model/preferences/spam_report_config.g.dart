// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spam_report_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpamReportConfig _$SpamReportConfigFromJson(Map<String, dynamic> json) =>
    SpamReportConfig(
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastTimeDismissedMilliseconds:
          (json['lastTimeDismissedMilliseconds'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SpamReportConfigToJson(SpamReportConfig instance) =>
    <String, dynamic>{
      'isEnabled': instance.isEnabled,
      'lastTimeDismissedMilliseconds': instance.lastTimeDismissedMilliseconds,
    };
