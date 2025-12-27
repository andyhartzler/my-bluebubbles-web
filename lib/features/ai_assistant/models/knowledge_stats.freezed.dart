// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'knowledge_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

KnowledgeStats _$KnowledgeStatsFromJson(Map<String, dynamic> json) {
  return _KnowledgeStats.fromJson(json);
}

/// @nodoc
mixin _$KnowledgeStats {
  int get totalDocuments => throw _privateConstructorUsedError;
  int get pendingEmbeddings => throw _privateConstructorUsedError;
  int get failedEmbeddings => throw _privateConstructorUsedError;
  Map<String, int> get documentsByTable => throw _privateConstructorUsedError;
  Map<String, int> get documentsByType => throw _privateConstructorUsedError;
  double get monthlyUsageDollars => throw _privateConstructorUsedError;
  int get totalQueries => throw _privateConstructorUsedError;
  List<TableConfig> get tableConfigs => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $KnowledgeStatsCopyWith<KnowledgeStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KnowledgeStatsCopyWith<$Res> {
  factory $KnowledgeStatsCopyWith(
          KnowledgeStats value, $Res Function(KnowledgeStats) then) =
      _$KnowledgeStatsCopyWithImpl<$Res, KnowledgeStats>;
  @useResult
  $Res call(
      {int totalDocuments,
      int pendingEmbeddings,
      int failedEmbeddings,
      Map<String, int> documentsByTable,
      Map<String, int> documentsByType,
      double monthlyUsageDollars,
      int totalQueries,
      List<TableConfig> tableConfigs});
}

/// @nodoc
class _$KnowledgeStatsCopyWithImpl<$Res, $Val extends KnowledgeStats>
    implements $KnowledgeStatsCopyWith<$Res> {
  _$KnowledgeStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalDocuments = null,
    Object? pendingEmbeddings = null,
    Object? failedEmbeddings = null,
    Object? documentsByTable = null,
    Object? documentsByType = null,
    Object? monthlyUsageDollars = null,
    Object? totalQueries = null,
    Object? tableConfigs = null,
  }) {
    return _then(_value.copyWith(
      totalDocuments: null == totalDocuments
          ? _value.totalDocuments
          : totalDocuments // ignore: cast_nullable_to_non_nullable
              as int,
      pendingEmbeddings: null == pendingEmbeddings
          ? _value.pendingEmbeddings
          : pendingEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      failedEmbeddings: null == failedEmbeddings
          ? _value.failedEmbeddings
          : failedEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      documentsByTable: null == documentsByTable
          ? _value.documentsByTable
          : documentsByTable // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      documentsByType: null == documentsByType
          ? _value.documentsByType
          : documentsByType // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      monthlyUsageDollars: null == monthlyUsageDollars
          ? _value.monthlyUsageDollars
          : monthlyUsageDollars // ignore: cast_nullable_to_non_nullable
              as double,
      totalQueries: null == totalQueries
          ? _value.totalQueries
          : totalQueries // ignore: cast_nullable_to_non_nullable
              as int,
      tableConfigs: null == tableConfigs
          ? _value.tableConfigs
          : tableConfigs // ignore: cast_nullable_to_non_nullable
              as List<TableConfig>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$KnowledgeStatsImplCopyWith<$Res>
    implements $KnowledgeStatsCopyWith<$Res> {
  factory _$$KnowledgeStatsImplCopyWith(_$KnowledgeStatsImpl value,
          $Res Function(_$KnowledgeStatsImpl) then) =
      __$$KnowledgeStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int totalDocuments,
      int pendingEmbeddings,
      int failedEmbeddings,
      Map<String, int> documentsByTable,
      Map<String, int> documentsByType,
      double monthlyUsageDollars,
      int totalQueries,
      List<TableConfig> tableConfigs});
}

/// @nodoc
class __$$KnowledgeStatsImplCopyWithImpl<$Res>
    extends _$KnowledgeStatsCopyWithImpl<$Res, _$KnowledgeStatsImpl>
    implements _$$KnowledgeStatsImplCopyWith<$Res> {
  __$$KnowledgeStatsImplCopyWithImpl(
      _$KnowledgeStatsImpl _value, $Res Function(_$KnowledgeStatsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalDocuments = null,
    Object? pendingEmbeddings = null,
    Object? failedEmbeddings = null,
    Object? documentsByTable = null,
    Object? documentsByType = null,
    Object? monthlyUsageDollars = null,
    Object? totalQueries = null,
    Object? tableConfigs = null,
  }) {
    return _then(_$KnowledgeStatsImpl(
      totalDocuments: null == totalDocuments
          ? _value.totalDocuments
          : totalDocuments // ignore: cast_nullable_to_non_nullable
              as int,
      pendingEmbeddings: null == pendingEmbeddings
          ? _value.pendingEmbeddings
          : pendingEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      failedEmbeddings: null == failedEmbeddings
          ? _value.failedEmbeddings
          : failedEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      documentsByTable: null == documentsByTable
          ? _value._documentsByTable
          : documentsByTable // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      documentsByType: null == documentsByType
          ? _value._documentsByType
          : documentsByType // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      monthlyUsageDollars: null == monthlyUsageDollars
          ? _value.monthlyUsageDollars
          : monthlyUsageDollars // ignore: cast_nullable_to_non_nullable
              as double,
      totalQueries: null == totalQueries
          ? _value.totalQueries
          : totalQueries // ignore: cast_nullable_to_non_nullable
              as int,
      tableConfigs: null == tableConfigs
          ? _value._tableConfigs
          : tableConfigs // ignore: cast_nullable_to_non_nullable
              as List<TableConfig>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$KnowledgeStatsImpl extends _KnowledgeStats {
  const _$KnowledgeStatsImpl(
      {this.totalDocuments = 0,
      this.pendingEmbeddings = 0,
      this.failedEmbeddings = 0,
      final Map<String, int> documentsByTable = const {},
      final Map<String, int> documentsByType = const {},
      this.monthlyUsageDollars = 0.0,
      this.totalQueries = 0,
      final List<TableConfig> tableConfigs = const []})
      : _documentsByTable = documentsByTable,
        _documentsByType = documentsByType,
        _tableConfigs = tableConfigs,
        super._();

  factory _$KnowledgeStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$KnowledgeStatsImplFromJson(json);

  @override
  @JsonKey()
  final int totalDocuments;
  @override
  @JsonKey()
  final int pendingEmbeddings;
  @override
  @JsonKey()
  final int failedEmbeddings;
  final Map<String, int> _documentsByTable;
  @override
  @JsonKey()
  Map<String, int> get documentsByTable {
    if (_documentsByTable is EqualUnmodifiableMapView) return _documentsByTable;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_documentsByTable);
  }

  final Map<String, int> _documentsByType;
  @override
  @JsonKey()
  Map<String, int> get documentsByType {
    if (_documentsByType is EqualUnmodifiableMapView) return _documentsByType;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_documentsByType);
  }

  @override
  @JsonKey()
  final double monthlyUsageDollars;
  @override
  @JsonKey()
  final int totalQueries;
  final List<TableConfig> _tableConfigs;
  @override
  @JsonKey()
  List<TableConfig> get tableConfigs {
    if (_tableConfigs is EqualUnmodifiableListView) return _tableConfigs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tableConfigs);
  }

  @override
  String toString() {
    return 'KnowledgeStats(totalDocuments: $totalDocuments, pendingEmbeddings: $pendingEmbeddings, failedEmbeddings: $failedEmbeddings, documentsByTable: $documentsByTable, documentsByType: $documentsByType, monthlyUsageDollars: $monthlyUsageDollars, totalQueries: $totalQueries, tableConfigs: $tableConfigs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KnowledgeStatsImpl &&
            (identical(other.totalDocuments, totalDocuments) ||
                other.totalDocuments == totalDocuments) &&
            (identical(other.pendingEmbeddings, pendingEmbeddings) ||
                other.pendingEmbeddings == pendingEmbeddings) &&
            (identical(other.failedEmbeddings, failedEmbeddings) ||
                other.failedEmbeddings == failedEmbeddings) &&
            const DeepCollectionEquality()
                .equals(other._documentsByTable, _documentsByTable) &&
            const DeepCollectionEquality()
                .equals(other._documentsByType, _documentsByType) &&
            (identical(other.monthlyUsageDollars, monthlyUsageDollars) ||
                other.monthlyUsageDollars == monthlyUsageDollars) &&
            (identical(other.totalQueries, totalQueries) ||
                other.totalQueries == totalQueries) &&
            const DeepCollectionEquality()
                .equals(other._tableConfigs, _tableConfigs));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalDocuments,
      pendingEmbeddings,
      failedEmbeddings,
      const DeepCollectionEquality().hash(_documentsByTable),
      const DeepCollectionEquality().hash(_documentsByType),
      monthlyUsageDollars,
      totalQueries,
      const DeepCollectionEquality().hash(_tableConfigs));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$KnowledgeStatsImplCopyWith<_$KnowledgeStatsImpl> get copyWith =>
      __$$KnowledgeStatsImplCopyWithImpl<_$KnowledgeStatsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$KnowledgeStatsImplToJson(
      this,
    );
  }
}

abstract class _KnowledgeStats extends KnowledgeStats {
  const factory _KnowledgeStats(
      {final int totalDocuments,
      final int pendingEmbeddings,
      final int failedEmbeddings,
      final Map<String, int> documentsByTable,
      final Map<String, int> documentsByType,
      final double monthlyUsageDollars,
      final int totalQueries,
      final List<TableConfig> tableConfigs}) = _$KnowledgeStatsImpl;
  const _KnowledgeStats._() : super._();

  factory _KnowledgeStats.fromJson(Map<String, dynamic> json) =
      _$KnowledgeStatsImpl.fromJson;

  @override
  int get totalDocuments;
  @override
  int get pendingEmbeddings;
  @override
  int get failedEmbeddings;
  @override
  Map<String, int> get documentsByTable;
  @override
  Map<String, int> get documentsByType;
  @override
  double get monthlyUsageDollars;
  @override
  int get totalQueries;
  @override
  List<TableConfig> get tableConfigs;
  @override
  @JsonKey(ignore: true)
  _$$KnowledgeStatsImplCopyWith<_$KnowledgeStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TableConfig _$TableConfigFromJson(Map<String, dynamic> json) {
  return _TableConfig.fromJson(json);
}

/// @nodoc
mixin _$TableConfig {
  String get tableName => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;
  bool get isDiscovered => throw _privateConstructorUsedError;
  bool get triggerInstalled => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_full_sync_at')
  DateTime? get lastSyncAt => throw _privateConstructorUsedError;
  int? get rowCount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TableConfigCopyWith<TableConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TableConfigCopyWith<$Res> {
  factory $TableConfigCopyWith(
          TableConfig value, $Res Function(TableConfig) then) =
      _$TableConfigCopyWithImpl<$Res, TableConfig>;
  @useResult
  $Res call(
      {String tableName,
      bool isEnabled,
      bool isDiscovered,
      bool triggerInstalled,
      @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
      int? rowCount});
}

/// @nodoc
class _$TableConfigCopyWithImpl<$Res, $Val extends TableConfig>
    implements $TableConfigCopyWith<$Res> {
  _$TableConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tableName = null,
    Object? isEnabled = null,
    Object? isDiscovered = null,
    Object? triggerInstalled = null,
    Object? lastSyncAt = freezed,
    Object? rowCount = freezed,
  }) {
    return _then(_value.copyWith(
      tableName: null == tableName
          ? _value.tableName
          : tableName // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isDiscovered: null == isDiscovered
          ? _value.isDiscovered
          : isDiscovered // ignore: cast_nullable_to_non_nullable
              as bool,
      triggerInstalled: null == triggerInstalled
          ? _value.triggerInstalled
          : triggerInstalled // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncAt: freezed == lastSyncAt
          ? _value.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rowCount: freezed == rowCount
          ? _value.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TableConfigImplCopyWith<$Res>
    implements $TableConfigCopyWith<$Res> {
  factory _$$TableConfigImplCopyWith(
          _$TableConfigImpl value, $Res Function(_$TableConfigImpl) then) =
      __$$TableConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String tableName,
      bool isEnabled,
      bool isDiscovered,
      bool triggerInstalled,
      @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
      int? rowCount});
}

/// @nodoc
class __$$TableConfigImplCopyWithImpl<$Res>
    extends _$TableConfigCopyWithImpl<$Res, _$TableConfigImpl>
    implements _$$TableConfigImplCopyWith<$Res> {
  __$$TableConfigImplCopyWithImpl(
      _$TableConfigImpl _value, $Res Function(_$TableConfigImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tableName = null,
    Object? isEnabled = null,
    Object? isDiscovered = null,
    Object? triggerInstalled = null,
    Object? lastSyncAt = freezed,
    Object? rowCount = freezed,
  }) {
    return _then(_$TableConfigImpl(
      tableName: null == tableName
          ? _value.tableName
          : tableName // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _value.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isDiscovered: null == isDiscovered
          ? _value.isDiscovered
          : isDiscovered // ignore: cast_nullable_to_non_nullable
              as bool,
      triggerInstalled: null == triggerInstalled
          ? _value.triggerInstalled
          : triggerInstalled // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncAt: freezed == lastSyncAt
          ? _value.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rowCount: freezed == rowCount
          ? _value.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TableConfigImpl implements _TableConfig {
  const _$TableConfigImpl(
      {required this.tableName,
      this.isEnabled = false,
      this.isDiscovered = false,
      this.triggerInstalled = false,
      @JsonKey(name: 'last_full_sync_at') this.lastSyncAt,
      this.rowCount});

  factory _$TableConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$TableConfigImplFromJson(json);

  @override
  final String tableName;
  @override
  @JsonKey()
  final bool isEnabled;
  @override
  @JsonKey()
  final bool isDiscovered;
  @override
  @JsonKey()
  final bool triggerInstalled;
  @override
  @JsonKey(name: 'last_full_sync_at')
  final DateTime? lastSyncAt;
  @override
  final int? rowCount;

  @override
  String toString() {
    return 'TableConfig(tableName: $tableName, isEnabled: $isEnabled, isDiscovered: $isDiscovered, triggerInstalled: $triggerInstalled, lastSyncAt: $lastSyncAt, rowCount: $rowCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TableConfigImpl &&
            (identical(other.tableName, tableName) ||
                other.tableName == tableName) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled) &&
            (identical(other.isDiscovered, isDiscovered) ||
                other.isDiscovered == isDiscovered) &&
            (identical(other.triggerInstalled, triggerInstalled) ||
                other.triggerInstalled == triggerInstalled) &&
            (identical(other.lastSyncAt, lastSyncAt) ||
                other.lastSyncAt == lastSyncAt) &&
            (identical(other.rowCount, rowCount) ||
                other.rowCount == rowCount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, tableName, isEnabled,
      isDiscovered, triggerInstalled, lastSyncAt, rowCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TableConfigImplCopyWith<_$TableConfigImpl> get copyWith =>
      __$$TableConfigImplCopyWithImpl<_$TableConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TableConfigImplToJson(
      this,
    );
  }
}

abstract class _TableConfig implements TableConfig {
  const factory _TableConfig(
      {required final String tableName,
      final bool isEnabled,
      final bool isDiscovered,
      final bool triggerInstalled,
      @JsonKey(name: 'last_full_sync_at') final DateTime? lastSyncAt,
      final int? rowCount}) = _$TableConfigImpl;

  factory _TableConfig.fromJson(Map<String, dynamic> json) =
      _$TableConfigImpl.fromJson;

  @override
  String get tableName;
  @override
  bool get isEnabled;
  @override
  bool get isDiscovered;
  @override
  bool get triggerInstalled;
  @override
  @JsonKey(name: 'last_full_sync_at')
  DateTime? get lastSyncAt;
  @override
  int? get rowCount;
  @override
  @JsonKey(ignore: true)
  _$$TableConfigImplCopyWith<_$TableConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
