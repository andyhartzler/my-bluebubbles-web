// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskClassificationImpl _$$TaskClassificationImplFromJson(
        Map<String, dynamic> json) =>
    _$TaskClassificationImpl(
      type: json['type'] as String,
      scope: json['scope'] as String,
      dataNeeds: (json['dataNeeds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );

Map<String, dynamic> _$$TaskClassificationImplToJson(
        _$TaskClassificationImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'scope': instance.scope,
      'dataNeeds': instance.dataNeeds,
      'confidence': instance.confidence,
    };

_$UsageInfoImpl _$$UsageInfoImplFromJson(Map<String, dynamic> json) =>
    _$UsageInfoImpl(
      inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
      model: json['model'] as String?,
      processingTimeMs: (json['processing_time_ms'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$UsageInfoImplToJson(_$UsageInfoImpl instance) =>
    <String, dynamic>{
      'input_tokens': instance.inputTokens,
      'output_tokens': instance.outputTokens,
      'model': instance.model,
      'processing_time_ms': instance.processingTimeMs,
    };
