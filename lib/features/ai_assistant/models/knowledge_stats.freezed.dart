// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'knowledge_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$KnowledgeStats {
  int get totalDocuments;
  int get pendingEmbeddings;
  int get failedEmbeddings;
  Map<String, int> get documentsByTable;
  Map<String, int> get documentsByType;
  double get monthlyUsageDollars;
  int get totalQueries;
  List<TableConfig> get tableConfigs;

  /// Create a copy of KnowledgeStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $KnowledgeStatsCopyWith<KnowledgeStats> get copyWith =>
      _$KnowledgeStatsCopyWithImpl<KnowledgeStats>(
          this as KnowledgeStats, _$identity);

  /// Serializes this KnowledgeStats to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is KnowledgeStats &&
            (identical(other.totalDocuments, totalDocuments) ||
                other.totalDocuments == totalDocuments) &&
            (identical(other.pendingEmbeddings, pendingEmbeddings) ||
                other.pendingEmbeddings == pendingEmbeddings) &&
            (identical(other.failedEmbeddings, failedEmbeddings) ||
                other.failedEmbeddings == failedEmbeddings) &&
            const DeepCollectionEquality()
                .equals(other.documentsByTable, documentsByTable) &&
            const DeepCollectionEquality()
                .equals(other.documentsByType, documentsByType) &&
            (identical(other.monthlyUsageDollars, monthlyUsageDollars) ||
                other.monthlyUsageDollars == monthlyUsageDollars) &&
            (identical(other.totalQueries, totalQueries) ||
                other.totalQueries == totalQueries) &&
            const DeepCollectionEquality()
                .equals(other.tableConfigs, tableConfigs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalDocuments,
      pendingEmbeddings,
      failedEmbeddings,
      const DeepCollectionEquality().hash(documentsByTable),
      const DeepCollectionEquality().hash(documentsByType),
      monthlyUsageDollars,
      totalQueries,
      const DeepCollectionEquality().hash(tableConfigs));

  @override
  String toString() {
    return 'KnowledgeStats(totalDocuments: $totalDocuments, pendingEmbeddings: $pendingEmbeddings, failedEmbeddings: $failedEmbeddings, documentsByTable: $documentsByTable, documentsByType: $documentsByType, monthlyUsageDollars: $monthlyUsageDollars, totalQueries: $totalQueries, tableConfigs: $tableConfigs)';
  }
}

/// @nodoc
abstract mixin class $KnowledgeStatsCopyWith<$Res> {
  factory $KnowledgeStatsCopyWith(
          KnowledgeStats value, $Res Function(KnowledgeStats) _then) =
      _$KnowledgeStatsCopyWithImpl;
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
class _$KnowledgeStatsCopyWithImpl<$Res>
    implements $KnowledgeStatsCopyWith<$Res> {
  _$KnowledgeStatsCopyWithImpl(this._self, this._then);

  final KnowledgeStats _self;
  final $Res Function(KnowledgeStats) _then;

  /// Create a copy of KnowledgeStats
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      totalDocuments: null == totalDocuments
          ? _self.totalDocuments
          : totalDocuments // ignore: cast_nullable_to_non_nullable
              as int,
      pendingEmbeddings: null == pendingEmbeddings
          ? _self.pendingEmbeddings
          : pendingEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      failedEmbeddings: null == failedEmbeddings
          ? _self.failedEmbeddings
          : failedEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      documentsByTable: null == documentsByTable
          ? _self.documentsByTable
          : documentsByTable // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      documentsByType: null == documentsByType
          ? _self.documentsByType
          : documentsByType // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      monthlyUsageDollars: null == monthlyUsageDollars
          ? _self.monthlyUsageDollars
          : monthlyUsageDollars // ignore: cast_nullable_to_non_nullable
              as double,
      totalQueries: null == totalQueries
          ? _self.totalQueries
          : totalQueries // ignore: cast_nullable_to_non_nullable
              as int,
      tableConfigs: null == tableConfigs
          ? _self.tableConfigs
          : tableConfigs // ignore: cast_nullable_to_non_nullable
              as List<TableConfig>,
    ));
  }
}

/// Adds pattern-matching-related methods to [KnowledgeStats].
extension KnowledgeStatsPatterns on KnowledgeStats {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_KnowledgeStats value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _KnowledgeStats() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_KnowledgeStats value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KnowledgeStats():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_KnowledgeStats value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KnowledgeStats() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            int totalDocuments,
            int pendingEmbeddings,
            int failedEmbeddings,
            Map<String, int> documentsByTable,
            Map<String, int> documentsByType,
            double monthlyUsageDollars,
            int totalQueries,
            List<TableConfig> tableConfigs)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _KnowledgeStats() when $default != null:
        return $default(
            _that.totalDocuments,
            _that.pendingEmbeddings,
            _that.failedEmbeddings,
            _that.documentsByTable,
            _that.documentsByType,
            _that.monthlyUsageDollars,
            _that.totalQueries,
            _that.tableConfigs);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            int totalDocuments,
            int pendingEmbeddings,
            int failedEmbeddings,
            Map<String, int> documentsByTable,
            Map<String, int> documentsByType,
            double monthlyUsageDollars,
            int totalQueries,
            List<TableConfig> tableConfigs)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KnowledgeStats():
        return $default(
            _that.totalDocuments,
            _that.pendingEmbeddings,
            _that.failedEmbeddings,
            _that.documentsByTable,
            _that.documentsByType,
            _that.monthlyUsageDollars,
            _that.totalQueries,
            _that.tableConfigs);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            int totalDocuments,
            int pendingEmbeddings,
            int failedEmbeddings,
            Map<String, int> documentsByTable,
            Map<String, int> documentsByType,
            double monthlyUsageDollars,
            int totalQueries,
            List<TableConfig> tableConfigs)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _KnowledgeStats() when $default != null:
        return $default(
            _that.totalDocuments,
            _that.pendingEmbeddings,
            _that.failedEmbeddings,
            _that.documentsByTable,
            _that.documentsByType,
            _that.monthlyUsageDollars,
            _that.totalQueries,
            _that.tableConfigs);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _KnowledgeStats extends KnowledgeStats {
  const _KnowledgeStats(
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
  factory _KnowledgeStats.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeStatsFromJson(json);

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

  /// Create a copy of KnowledgeStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$KnowledgeStatsCopyWith<_KnowledgeStats> get copyWith =>
      __$KnowledgeStatsCopyWithImpl<_KnowledgeStats>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$KnowledgeStatsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _KnowledgeStats &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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

  @override
  String toString() {
    return 'KnowledgeStats(totalDocuments: $totalDocuments, pendingEmbeddings: $pendingEmbeddings, failedEmbeddings: $failedEmbeddings, documentsByTable: $documentsByTable, documentsByType: $documentsByType, monthlyUsageDollars: $monthlyUsageDollars, totalQueries: $totalQueries, tableConfigs: $tableConfigs)';
  }
}

/// @nodoc
abstract mixin class _$KnowledgeStatsCopyWith<$Res>
    implements $KnowledgeStatsCopyWith<$Res> {
  factory _$KnowledgeStatsCopyWith(
          _KnowledgeStats value, $Res Function(_KnowledgeStats) _then) =
      __$KnowledgeStatsCopyWithImpl;
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
class __$KnowledgeStatsCopyWithImpl<$Res>
    implements _$KnowledgeStatsCopyWith<$Res> {
  __$KnowledgeStatsCopyWithImpl(this._self, this._then);

  final _KnowledgeStats _self;
  final $Res Function(_KnowledgeStats) _then;

  /// Create a copy of KnowledgeStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_KnowledgeStats(
      totalDocuments: null == totalDocuments
          ? _self.totalDocuments
          : totalDocuments // ignore: cast_nullable_to_non_nullable
              as int,
      pendingEmbeddings: null == pendingEmbeddings
          ? _self.pendingEmbeddings
          : pendingEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      failedEmbeddings: null == failedEmbeddings
          ? _self.failedEmbeddings
          : failedEmbeddings // ignore: cast_nullable_to_non_nullable
              as int,
      documentsByTable: null == documentsByTable
          ? _self._documentsByTable
          : documentsByTable // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      documentsByType: null == documentsByType
          ? _self._documentsByType
          : documentsByType // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      monthlyUsageDollars: null == monthlyUsageDollars
          ? _self.monthlyUsageDollars
          : monthlyUsageDollars // ignore: cast_nullable_to_non_nullable
              as double,
      totalQueries: null == totalQueries
          ? _self.totalQueries
          : totalQueries // ignore: cast_nullable_to_non_nullable
              as int,
      tableConfigs: null == tableConfigs
          ? _self._tableConfigs
          : tableConfigs // ignore: cast_nullable_to_non_nullable
              as List<TableConfig>,
    ));
  }
}

/// @nodoc
mixin _$TableConfig {
  @JsonKey(name: 'table_name')
  String get tableName;
  @JsonKey(name: 'is_enabled')
  bool get isEnabled;
  @JsonKey(name: 'is_discovered')
  bool get isDiscovered;
  @JsonKey(name: 'trigger_installed')
  bool get triggerInstalled;
  @JsonKey(name: 'last_full_sync_at')
  DateTime? get lastSyncAt;
  @JsonKey(name: 'row_count')
  int? get rowCount;

  /// Create a copy of TableConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TableConfigCopyWith<TableConfig> get copyWith =>
      _$TableConfigCopyWithImpl<TableConfig>(this as TableConfig, _$identity);

  /// Serializes this TableConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TableConfig &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tableName, isEnabled,
      isDiscovered, triggerInstalled, lastSyncAt, rowCount);

  @override
  String toString() {
    return 'TableConfig(tableName: $tableName, isEnabled: $isEnabled, isDiscovered: $isDiscovered, triggerInstalled: $triggerInstalled, lastSyncAt: $lastSyncAt, rowCount: $rowCount)';
  }
}

/// @nodoc
abstract mixin class $TableConfigCopyWith<$Res> {
  factory $TableConfigCopyWith(
          TableConfig value, $Res Function(TableConfig) _then) =
      _$TableConfigCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'table_name') String tableName,
      @JsonKey(name: 'is_enabled') bool isEnabled,
      @JsonKey(name: 'is_discovered') bool isDiscovered,
      @JsonKey(name: 'trigger_installed') bool triggerInstalled,
      @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
      @JsonKey(name: 'row_count') int? rowCount});
}

/// @nodoc
class _$TableConfigCopyWithImpl<$Res> implements $TableConfigCopyWith<$Res> {
  _$TableConfigCopyWithImpl(this._self, this._then);

  final TableConfig _self;
  final $Res Function(TableConfig) _then;

  /// Create a copy of TableConfig
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      tableName: null == tableName
          ? _self.tableName
          : tableName // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _self.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isDiscovered: null == isDiscovered
          ? _self.isDiscovered
          : isDiscovered // ignore: cast_nullable_to_non_nullable
              as bool,
      triggerInstalled: null == triggerInstalled
          ? _self.triggerInstalled
          : triggerInstalled // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncAt: freezed == lastSyncAt
          ? _self.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rowCount: freezed == rowCount
          ? _self.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TableConfig].
extension TableConfigPatterns on TableConfig {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_TableConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TableConfig() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_TableConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TableConfig():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_TableConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TableConfig() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            @JsonKey(name: 'table_name') String tableName,
            @JsonKey(name: 'is_enabled') bool isEnabled,
            @JsonKey(name: 'is_discovered') bool isDiscovered,
            @JsonKey(name: 'trigger_installed') bool triggerInstalled,
            @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
            @JsonKey(name: 'row_count') int? rowCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TableConfig() when $default != null:
        return $default(_that.tableName, _that.isEnabled, _that.isDiscovered,
            _that.triggerInstalled, _that.lastSyncAt, _that.rowCount);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            @JsonKey(name: 'table_name') String tableName,
            @JsonKey(name: 'is_enabled') bool isEnabled,
            @JsonKey(name: 'is_discovered') bool isDiscovered,
            @JsonKey(name: 'trigger_installed') bool triggerInstalled,
            @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
            @JsonKey(name: 'row_count') int? rowCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TableConfig():
        return $default(_that.tableName, _that.isEnabled, _that.isDiscovered,
            _that.triggerInstalled, _that.lastSyncAt, _that.rowCount);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            @JsonKey(name: 'table_name') String tableName,
            @JsonKey(name: 'is_enabled') bool isEnabled,
            @JsonKey(name: 'is_discovered') bool isDiscovered,
            @JsonKey(name: 'trigger_installed') bool triggerInstalled,
            @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
            @JsonKey(name: 'row_count') int? rowCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TableConfig() when $default != null:
        return $default(_that.tableName, _that.isEnabled, _that.isDiscovered,
            _that.triggerInstalled, _that.lastSyncAt, _that.rowCount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TableConfig implements TableConfig {
  const _TableConfig(
      {@JsonKey(name: 'table_name') required this.tableName,
      @JsonKey(name: 'is_enabled') this.isEnabled = false,
      @JsonKey(name: 'is_discovered') this.isDiscovered = false,
      @JsonKey(name: 'trigger_installed') this.triggerInstalled = false,
      @JsonKey(name: 'last_full_sync_at') this.lastSyncAt,
      @JsonKey(name: 'row_count') this.rowCount});
  factory _TableConfig.fromJson(Map<String, dynamic> json) =>
      _$TableConfigFromJson(json);

  @override
  @JsonKey(name: 'table_name')
  final String tableName;
  @override
  @JsonKey(name: 'is_enabled')
  final bool isEnabled;
  @override
  @JsonKey(name: 'is_discovered')
  final bool isDiscovered;
  @override
  @JsonKey(name: 'trigger_installed')
  final bool triggerInstalled;
  @override
  @JsonKey(name: 'last_full_sync_at')
  final DateTime? lastSyncAt;
  @override
  @JsonKey(name: 'row_count')
  final int? rowCount;

  /// Create a copy of TableConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TableConfigCopyWith<_TableConfig> get copyWith =>
      __$TableConfigCopyWithImpl<_TableConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TableConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TableConfig &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tableName, isEnabled,
      isDiscovered, triggerInstalled, lastSyncAt, rowCount);

  @override
  String toString() {
    return 'TableConfig(tableName: $tableName, isEnabled: $isEnabled, isDiscovered: $isDiscovered, triggerInstalled: $triggerInstalled, lastSyncAt: $lastSyncAt, rowCount: $rowCount)';
  }
}

/// @nodoc
abstract mixin class _$TableConfigCopyWith<$Res>
    implements $TableConfigCopyWith<$Res> {
  factory _$TableConfigCopyWith(
          _TableConfig value, $Res Function(_TableConfig) _then) =
      __$TableConfigCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'table_name') String tableName,
      @JsonKey(name: 'is_enabled') bool isEnabled,
      @JsonKey(name: 'is_discovered') bool isDiscovered,
      @JsonKey(name: 'trigger_installed') bool triggerInstalled,
      @JsonKey(name: 'last_full_sync_at') DateTime? lastSyncAt,
      @JsonKey(name: 'row_count') int? rowCount});
}

/// @nodoc
class __$TableConfigCopyWithImpl<$Res> implements _$TableConfigCopyWith<$Res> {
  __$TableConfigCopyWithImpl(this._self, this._then);

  final _TableConfig _self;
  final $Res Function(_TableConfig) _then;

  /// Create a copy of TableConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? tableName = null,
    Object? isEnabled = null,
    Object? isDiscovered = null,
    Object? triggerInstalled = null,
    Object? lastSyncAt = freezed,
    Object? rowCount = freezed,
  }) {
    return _then(_TableConfig(
      tableName: null == tableName
          ? _self.tableName
          : tableName // ignore: cast_nullable_to_non_nullable
              as String,
      isEnabled: null == isEnabled
          ? _self.isEnabled
          : isEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isDiscovered: null == isDiscovered
          ? _self.isDiscovered
          : isDiscovered // ignore: cast_nullable_to_non_nullable
              as bool,
      triggerInstalled: null == triggerInstalled
          ? _self.triggerInstalled
          : triggerInstalled // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSyncAt: freezed == lastSyncAt
          ? _self.lastSyncAt
          : lastSyncAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rowCount: freezed == rowCount
          ? _self.rowCount
          : rowCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

// dart format on
