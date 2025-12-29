import 'package:freezed_annotation/freezed_annotation.dart';

part 'query_response.freezed.dart';
part 'query_response.g.dart';

/// Task classification from Knowledge Chat V2
@freezed
class TaskClassification with _$TaskClassification {
  const factory TaskClassification({
    /// One of: simple_lookup, entity_search, explanation, comprehensive_research, content_generation
    required String type,
    /// One of: narrow, moderate, exhaustive
    required String scope,
    /// Data sources queried
    @JsonKey(name: 'dataNeeds') @Default([]) List<String> dataNeeds,
    /// Confidence score 0.0 to 1.0
    @Default(0.5) double confidence,
  }) = _TaskClassification;

  factory TaskClassification.fromJson(Map<String, dynamic> json) =>
      _$TaskClassificationFromJson(json);
}

/// Usage information from AI response
@freezed
class UsageInfo with _$UsageInfo {
  const factory UsageInfo({
    @JsonKey(name: 'input_tokens') @Default(0) int inputTokens,
    @JsonKey(name: 'output_tokens') @Default(0) int outputTokens,
    String? model,
    @JsonKey(name: 'processing_time_ms') @Default(0) int processingTimeMs,
  }) = _UsageInfo;

  factory UsageInfo.fromJson(Map<String, dynamic> json) =>
      _$UsageInfoFromJson(json);
}
