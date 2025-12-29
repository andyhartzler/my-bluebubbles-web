// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$KnowledgeStatsImpl _$$KnowledgeStatsImplFromJson(Map<String, dynamic> json) =>
    _$KnowledgeStatsImpl(
      totalDocuments: (json['totalDocuments'] as num?)?.toInt() ?? 0,
      pendingEmbeddings: (json['pendingEmbeddings'] as num?)?.toInt() ?? 0,
      failedEmbeddings: (json['failedEmbeddings'] as num?)?.toInt() ?? 0,
      documentsByTable:
          (json['documentsByTable'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toInt()),
              ) ??
              const {},
      documentsByType: (json['documentsByType'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      monthlyUsageDollars:
          (json['monthlyUsageDollars'] as num?)?.toDouble() ?? 0.0,
      totalQueries: (json['totalQueries'] as num?)?.toInt() ?? 0,
      tableConfigs: (json['tableConfigs'] as List<dynamic>?)
              ?.map((e) => TableConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$KnowledgeStatsImplToJson(
        _$KnowledgeStatsImpl instance) =>
    <String, dynamic>{
      'totalDocuments': instance.totalDocuments,
      'pendingEmbeddings': instance.pendingEmbeddings,
      'failedEmbeddings': instance.failedEmbeddings,
      'documentsByTable': instance.documentsByTable,
      'documentsByType': instance.documentsByType,
      'monthlyUsageDollars': instance.monthlyUsageDollars,
      'totalQueries': instance.totalQueries,
      'tableConfigs': instance.tableConfigs,
    };

_$TableConfigImpl _$$TableConfigImplFromJson(Map<String, dynamic> json) =>
    _$TableConfigImpl(
      tableName: json['table_name'] as String,
      isEnabled: json['is_enabled'] as bool? ?? false,
      isDiscovered: json['is_discovered'] as bool? ?? false,
      triggerInstalled: json['trigger_installed'] as bool? ?? false,
      lastSyncAt: json['last_full_sync_at'] == null
          ? null
          : DateTime.parse(json['last_full_sync_at'] as String),
      rowCount: (json['row_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$TableConfigImplToJson(_$TableConfigImpl instance) =>
    <String, dynamic>{
      'table_name': instance.tableName,
      'is_enabled': instance.isEnabled,
      'is_discovered': instance.isDiscovered,
      'trigger_installed': instance.triggerInstalled,
      'last_full_sync_at': instance.lastSyncAt?.toIso8601String(),
      'row_count': instance.rowCount,
    };
