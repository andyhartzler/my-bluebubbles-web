import 'package:freezed_annotation/freezed_annotation.dart';

part 'knowledge_stats.freezed.dart';
part 'knowledge_stats.g.dart';

@freezed
abstract class KnowledgeStats with _$KnowledgeStats {
  const KnowledgeStats._();

  const factory KnowledgeStats({
    @Default(0) int totalDocuments,
    @Default(0) int pendingEmbeddings,
    @Default(0) int failedEmbeddings,
    @Default({}) Map<String, int> documentsByTable,
    @Default({}) Map<String, int> documentsByType,
    @Default(0.0) double monthlyUsageDollars,
    @Default(0) int totalQueries,
    @Default([]) List<TableConfig> tableConfigs,
  }) = _KnowledgeStats;

  factory KnowledgeStats.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeStatsFromJson(json);

  int get completedDocuments => totalDocuments - pendingEmbeddings - failedEmbeddings;
  double get completionRate => totalDocuments > 0
      ? (completedDocuments / totalDocuments) * 100
      : 0;
}

@freezed
abstract class TableConfig with _$TableConfig {
  const factory TableConfig({
    @JsonKey(name: 'table_name') required String tableName,
    @JsonKey(name: 'is_enabled') @Default(false) bool isEnabled,
    @JsonKey(name: 'is_discovered') @Default(false) bool isDiscovered,
    @JsonKey(name: 'trigger_installed') @Default(false) bool triggerInstalled,
    @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
    @JsonKey(name: 'row_count') int? rowCount,
  }) = _TableConfig;

  factory TableConfig.fromJson(Map<String, dynamic> json) =>
      _$TableConfigFromJson(json);
}
