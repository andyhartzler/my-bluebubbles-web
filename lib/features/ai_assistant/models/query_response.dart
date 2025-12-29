import 'package:freezed_annotation/freezed_annotation.dart';

part 'query_response.freezed.dart';
part 'query_response.g.dart';

/// Intent detected from user query
@freezed
class QueryIntent with _$QueryIntent {
  const factory QueryIntent({
    required String type,
    String? entity,
    String? temporal,
    @Default(0.5) double confidence,
    @Default([]) List<String> keywords,
    Map<String, dynamic>? filters,
  }) = _QueryIntent;

  factory QueryIntent.fromJson(Map<String, dynamic> json) =>
      _$QueryIntentFromJson(json);
}

/// Memory usage information from AI response
@freezed
class MemoriesUsed with _$MemoriesUsed {
  const factory MemoriesUsed({
    @Default(0) int session,
    @Default(0) int user,
    @Default(0) int org,
  }) = _MemoriesUsed;

  factory MemoriesUsed.fromJson(Map<String, dynamic> json) =>
      _$MemoriesUsedFromJson(json);

  int get total => session + user + org;
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
