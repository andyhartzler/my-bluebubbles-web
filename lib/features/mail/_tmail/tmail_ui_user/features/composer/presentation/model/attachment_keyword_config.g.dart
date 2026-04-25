// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_keyword_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttachmentKeywordConfig _$AttachmentKeywordConfigFromJson(
        Map<String, dynamic> json) =>
    AttachmentKeywordConfig(
      includeList: (json['includeList'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      excludeList: (json['excludeList'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AttachmentKeywordConfigToJson(
        AttachmentKeywordConfig instance) =>
    <String, dynamic>{
      'includeList': instance.includeList,
      'excludeList': instance.excludeList,
    };
