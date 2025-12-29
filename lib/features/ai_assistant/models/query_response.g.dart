// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QueryIntentImpl _$$QueryIntentImplFromJson(Map<String, dynamic> json) =>
    _$QueryIntentImpl(
      type: json['type'] as String,
      entity: json['entity'] as String?,
      temporal: json['temporal'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      filters: json['filters'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$QueryIntentImplToJson(_$QueryIntentImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'entity': instance.entity,
      'temporal': instance.temporal,
      'confidence': instance.confidence,
      'keywords': instance.keywords,
      'filters': instance.filters,
    };

_$MemoriesUsedImpl _$$MemoriesUsedImplFromJson(Map<String, dynamic> json) =>
    _$MemoriesUsedImpl(
      session: (json['session'] as num?)?.toInt() ?? 0,
      user: (json['user'] as num?)?.toInt() ?? 0,
      org: (json['org'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$MemoriesUsedImplToJson(_$MemoriesUsedImpl instance) =>
    <String, dynamic>{
      'session': instance.session,
      'user': instance.user,
      'org': instance.org,
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
