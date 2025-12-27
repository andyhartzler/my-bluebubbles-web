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
      documentsByType:
          (json['documentsByType'] as Map<String, dynamic>?)?.map(
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
      'tableConfigs': instance.tableConfigs.map((e) => e.toJson()).toList(),
    };

_$TableConfigImpl _$$TableConfigImplFromJson(Map<String, dynamic> json) =>
    _$TableConfigImpl(
      tableName: json['tableName'] as String,
      isEnabled: json['isEnabled'] as bool? ?? false,
      isDiscovered: json['isDiscovered'] as bool? ?? false,
      triggerInstalled: json['triggerInstalled'] as bool? ?? false,
      lastSyncAt: json['last_full_sync_at'] == null
          ? null
          : DateTime.parse(json['last_full_sync_at'] as String),
      rowCount: (json['rowCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$TableConfigImplToJson(_$TableConfigImpl instance) =>
    <String, dynamic>{
      'tableName': instance.tableName,
      'isEnabled': instance.isEnabled,
      'isDiscovered': instance.isDiscovered,
      'triggerInstalled': instance.triggerInstalled,
      'last_full_sync_at': instance.lastSyncAt?.toIso8601String(),
      'rowCount': instance.rowCount,
    };
