// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskClassification _$TaskClassificationFromJson(Map<String, dynamic> json) =>
    _TaskClassification(
      type: json['type'] as String,
      scope: json['scope'] as String,
      dataNeeds:
          (json['dataNeeds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );

Map<String, dynamic> _$TaskClassificationToJson(_TaskClassification instance) =>
    <String, dynamic>{
      'type': instance.type,
      'scope': instance.scope,
      'dataNeeds': instance.dataNeeds,
      'confidence': instance.confidence,
    };

_UsageInfo _$UsageInfoFromJson(Map<String, dynamic> json) => _UsageInfo(
  inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
  outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
  model: json['model'] as String?,
  processingTimeMs: (json['processing_time_ms'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UsageInfoToJson(_UsageInfo instance) =>
    <String, dynamic>{
      'input_tokens': instance.inputTokens,
      'output_tokens': instance.outputTokens,
      'model': instance.model,
      'processing_time_ms': instance.processingTimeMs,
    };
