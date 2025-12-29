// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'query_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

QueryIntent _$QueryIntentFromJson(Map<String, dynamic> json) {
  return _QueryIntent.fromJson(json);
}

/// @nodoc
mixin _$QueryIntent {
  String get type => throw _privateConstructorUsedError;
  String? get entity => throw _privateConstructorUsedError;
  String? get temporal => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;
  List<String> get keywords => throw _privateConstructorUsedError;
  Map<String, dynamic>? get filters => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $QueryIntentCopyWith<QueryIntent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QueryIntentCopyWith<$Res> {
  factory $QueryIntentCopyWith(
          QueryIntent value, $Res Function(QueryIntent) then) =
      _$QueryIntentCopyWithImpl<$Res, QueryIntent>;
  @useResult
  $Res call(
      {String type,
      String? entity,
      String? temporal,
      double confidence,
      List<String> keywords,
      Map<String, dynamic>? filters});
}

/// @nodoc
class _$QueryIntentCopyWithImpl<$Res, $Val extends QueryIntent>
    implements $QueryIntentCopyWith<$Res> {
  _$QueryIntentCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? entity = freezed,
    Object? temporal = freezed,
    Object? confidence = null,
    Object? keywords = null,
    Object? filters = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type as String,
      entity: freezed == entity
          ? _value.entity
          : entity as String?,
      temporal: freezed == temporal
          ? _value.temporal
          : temporal as String?,
      confidence: null == confidence
          ? _value.confidence
          : confidence as double,
      keywords: null == keywords
          ? _value.keywords
          : keywords as List<String>,
      filters: freezed == filters
          ? _value.filters
          : filters as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QueryIntentImplCopyWith<$Res>
    implements $QueryIntentCopyWith<$Res> {
  factory _$$QueryIntentImplCopyWith(
          _$QueryIntentImpl value, $Res Function(_$QueryIntentImpl) then) =
      __$$QueryIntentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      String? entity,
      String? temporal,
      double confidence,
      List<String> keywords,
      Map<String, dynamic>? filters});
}

/// @nodoc
class __$$QueryIntentImplCopyWithImpl<$Res>
    extends _$QueryIntentCopyWithImpl<$Res, _$QueryIntentImpl>
    implements _$$QueryIntentImplCopyWith<$Res> {
  __$$QueryIntentImplCopyWithImpl(
      _$QueryIntentImpl _value, $Res Function(_$QueryIntentImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? entity = freezed,
    Object? temporal = freezed,
    Object? confidence = null,
    Object? keywords = null,
    Object? filters = freezed,
  }) {
    return _then(_$QueryIntentImpl(
      type: null == type
          ? _value.type
          : type as String,
      entity: freezed == entity
          ? _value.entity
          : entity as String?,
      temporal: freezed == temporal
          ? _value.temporal
          : temporal as String?,
      confidence: null == confidence
          ? _value.confidence
          : confidence as double,
      keywords: null == keywords
          ? _value._keywords
          : keywords as List<String>,
      filters: freezed == filters
          ? _value._filters
          : filters as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QueryIntentImpl implements _QueryIntent {
  const _$QueryIntentImpl(
      {required this.type,
      this.entity,
      this.temporal,
      this.confidence = 0.5,
      final List<String> keywords = const [],
      final Map<String, dynamic>? filters})
      : _keywords = keywords,
        _filters = filters;

  factory _$QueryIntentImpl.fromJson(Map<String, dynamic> json) =>
      _$$QueryIntentImplFromJson(json);

  @override
  final String type;
  @override
  final String? entity;
  @override
  final String? temporal;
  @override
  @JsonKey()
  final double confidence;
  final List<String> _keywords;
  @override
  @JsonKey()
  List<String> get keywords {
    if (_keywords is EqualUnmodifiableListView) return _keywords;
    return EqualUnmodifiableListView(_keywords);
  }

  final Map<String, dynamic>? _filters;
  @override
  Map<String, dynamic>? get filters {
    final value = _filters;
    if (value == null) return null;
    if (_filters is EqualUnmodifiableMapView) return _filters;
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'QueryIntent(type: $type, entity: $entity, temporal: $temporal, confidence: $confidence, keywords: $keywords, filters: $filters)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QueryIntentImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.entity, entity) || other.entity == entity) &&
            (identical(other.temporal, temporal) ||
                other.temporal == temporal) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            const DeepCollectionEquality().equals(other._keywords, _keywords) &&
            const DeepCollectionEquality().equals(other._filters, _filters));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      type,
      entity,
      temporal,
      confidence,
      const DeepCollectionEquality().hash(_keywords),
      const DeepCollectionEquality().hash(_filters));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$QueryIntentImplCopyWith<_$QueryIntentImpl> get copyWith =>
      __$$QueryIntentImplCopyWithImpl<_$QueryIntentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QueryIntentImplToJson(this);
  }
}

abstract class _QueryIntent implements QueryIntent {
  const factory _QueryIntent(
      {required final String type,
      final String? entity,
      final String? temporal,
      final double confidence,
      final List<String> keywords,
      final Map<String, dynamic>? filters}) = _$QueryIntentImpl;

  factory _QueryIntent.fromJson(Map<String, dynamic> json) =
      _$QueryIntentImpl.fromJson;

  @override
  String get type;
  @override
  String? get entity;
  @override
  String? get temporal;
  @override
  double get confidence;
  @override
  List<String> get keywords;
  @override
  Map<String, dynamic>? get filters;
  @override
  @JsonKey(ignore: true)
  _$$QueryIntentImplCopyWith<_$QueryIntentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MemoriesUsed _$MemoriesUsedFromJson(Map<String, dynamic> json) {
  return _MemoriesUsed.fromJson(json);
}

/// @nodoc
mixin _$MemoriesUsed {
  int get session => throw _privateConstructorUsedError;
  int get user => throw _privateConstructorUsedError;
  int get org => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MemoriesUsedCopyWith<MemoriesUsed> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MemoriesUsedCopyWith<$Res> {
  factory $MemoriesUsedCopyWith(
          MemoriesUsed value, $Res Function(MemoriesUsed) then) =
      _$MemoriesUsedCopyWithImpl<$Res, MemoriesUsed>;
  @useResult
  $Res call({int session, int user, int org});
}

/// @nodoc
class _$MemoriesUsedCopyWithImpl<$Res, $Val extends MemoriesUsed>
    implements $MemoriesUsedCopyWith<$Res> {
  _$MemoriesUsedCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? user = null,
    Object? org = null,
  }) {
    return _then(_value.copyWith(
      session: null == session
          ? _value.session
          : session as int,
      user: null == user
          ? _value.user
          : user as int,
      org: null == org
          ? _value.org
          : org as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MemoriesUsedImplCopyWith<$Res>
    implements $MemoriesUsedCopyWith<$Res> {
  factory _$$MemoriesUsedImplCopyWith(
          _$MemoriesUsedImpl value, $Res Function(_$MemoriesUsedImpl) then) =
      __$$MemoriesUsedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int session, int user, int org});
}

/// @nodoc
class __$$MemoriesUsedImplCopyWithImpl<$Res>
    extends _$MemoriesUsedCopyWithImpl<$Res, _$MemoriesUsedImpl>
    implements _$$MemoriesUsedImplCopyWith<$Res> {
  __$$MemoriesUsedImplCopyWithImpl(
      _$MemoriesUsedImpl _value, $Res Function(_$MemoriesUsedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? session = null,
    Object? user = null,
    Object? org = null,
  }) {
    return _then(_$MemoriesUsedImpl(
      session: null == session
          ? _value.session
          : session as int,
      user: null == user
          ? _value.user
          : user as int,
      org: null == org
          ? _value.org
          : org as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MemoriesUsedImpl implements _MemoriesUsed {
  const _$MemoriesUsedImpl({this.session = 0, this.user = 0, this.org = 0});

  factory _$MemoriesUsedImpl.fromJson(Map<String, dynamic> json) =>
      _$$MemoriesUsedImplFromJson(json);

  @override
  @JsonKey()
  final int session;
  @override
  @JsonKey()
  final int user;
  @override
  @JsonKey()
  final int org;

  @override
  String toString() {
    return 'MemoriesUsed(session: $session, user: $user, org: $org)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MemoriesUsedImpl &&
            (identical(other.session, session) || other.session == session) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.org, org) || other.org == org));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, session, user, org);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MemoriesUsedImplCopyWith<_$MemoriesUsedImpl> get copyWith =>
      __$$MemoriesUsedImplCopyWithImpl<_$MemoriesUsedImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MemoriesUsedImplToJson(this);
  }
}

abstract class _MemoriesUsed implements MemoriesUsed {
  const factory _MemoriesUsed(
      {final int session, final int user, final int org}) = _$MemoriesUsedImpl;

  factory _MemoriesUsed.fromJson(Map<String, dynamic> json) =
      _$MemoriesUsedImpl.fromJson;

  @override
  int get session;
  @override
  int get user;
  @override
  int get org;
  @override
  @JsonKey(ignore: true)
  _$$MemoriesUsedImplCopyWith<_$MemoriesUsedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UsageInfo _$UsageInfoFromJson(Map<String, dynamic> json) {
  return _UsageInfo.fromJson(json);
}

/// @nodoc
mixin _$UsageInfo {
  @JsonKey(name: 'input_tokens')
  int get inputTokens => throw _privateConstructorUsedError;
  @JsonKey(name: 'output_tokens')
  int get outputTokens => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  @JsonKey(name: 'processing_time_ms')
  int get processingTimeMs => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $UsageInfoCopyWith<UsageInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UsageInfoCopyWith<$Res> {
  factory $UsageInfoCopyWith(UsageInfo value, $Res Function(UsageInfo) then) =
      _$UsageInfoCopyWithImpl<$Res, UsageInfo>;
  @useResult
  $Res call(
      {@JsonKey(name: 'input_tokens') int inputTokens,
      @JsonKey(name: 'output_tokens') int outputTokens,
      String? model,
      @JsonKey(name: 'processing_time_ms') int processingTimeMs});
}

/// @nodoc
class _$UsageInfoCopyWithImpl<$Res, $Val extends UsageInfo>
    implements $UsageInfoCopyWith<$Res> {
  _$UsageInfoCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputTokens = null,
    Object? outputTokens = null,
    Object? model = freezed,
    Object? processingTimeMs = null,
  }) {
    return _then(_value.copyWith(
      inputTokens: null == inputTokens
          ? _value.inputTokens
          : inputTokens as int,
      outputTokens: null == outputTokens
          ? _value.outputTokens
          : outputTokens as int,
      model: freezed == model
          ? _value.model
          : model as String?,
      processingTimeMs: null == processingTimeMs
          ? _value.processingTimeMs
          : processingTimeMs as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UsageInfoImplCopyWith<$Res>
    implements $UsageInfoCopyWith<$Res> {
  factory _$$UsageInfoImplCopyWith(
          _$UsageInfoImpl value, $Res Function(_$UsageInfoImpl) then) =
      __$$UsageInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'input_tokens') int inputTokens,
      @JsonKey(name: 'output_tokens') int outputTokens,
      String? model,
      @JsonKey(name: 'processing_time_ms') int processingTimeMs});
}

/// @nodoc
class __$$UsageInfoImplCopyWithImpl<$Res>
    extends _$UsageInfoCopyWithImpl<$Res, _$UsageInfoImpl>
    implements _$$UsageInfoImplCopyWith<$Res> {
  __$$UsageInfoImplCopyWithImpl(
      _$UsageInfoImpl _value, $Res Function(_$UsageInfoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputTokens = null,
    Object? outputTokens = null,
    Object? model = freezed,
    Object? processingTimeMs = null,
  }) {
    return _then(_$UsageInfoImpl(
      inputTokens: null == inputTokens
          ? _value.inputTokens
          : inputTokens as int,
      outputTokens: null == outputTokens
          ? _value.outputTokens
          : outputTokens as int,
      model: freezed == model
          ? _value.model
          : model as String?,
      processingTimeMs: null == processingTimeMs
          ? _value.processingTimeMs
          : processingTimeMs as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UsageInfoImpl implements _UsageInfo {
  const _$UsageInfoImpl(
      {@JsonKey(name: 'input_tokens') this.inputTokens = 0,
      @JsonKey(name: 'output_tokens') this.outputTokens = 0,
      this.model,
      @JsonKey(name: 'processing_time_ms') this.processingTimeMs = 0});

  factory _$UsageInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$UsageInfoImplFromJson(json);

  @override
  @JsonKey(name: 'input_tokens')
  final int inputTokens;
  @override
  @JsonKey(name: 'output_tokens')
  final int outputTokens;
  @override
  final String? model;
  @override
  @JsonKey(name: 'processing_time_ms')
  final int processingTimeMs;

  @override
  String toString() {
    return 'UsageInfo(inputTokens: $inputTokens, outputTokens: $outputTokens, model: $model, processingTimeMs: $processingTimeMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UsageInfoImpl &&
            (identical(other.inputTokens, inputTokens) ||
                other.inputTokens == inputTokens) &&
            (identical(other.outputTokens, outputTokens) ||
                other.outputTokens == outputTokens) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.processingTimeMs, processingTimeMs) ||
                other.processingTimeMs == processingTimeMs));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, inputTokens, outputTokens, model, processingTimeMs);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageInfoImplCopyWith<_$UsageInfoImpl> get copyWith =>
      __$$UsageInfoImplCopyWithImpl<_$UsageInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UsageInfoImplToJson(this);
  }
}

abstract class _UsageInfo implements UsageInfo {
  const factory _UsageInfo(
          {@JsonKey(name: 'input_tokens') final int inputTokens,
          @JsonKey(name: 'output_tokens') final int outputTokens,
          final String? model,
          @JsonKey(name: 'processing_time_ms') final int processingTimeMs}) =
      _$UsageInfoImpl;

  factory _UsageInfo.fromJson(Map<String, dynamic> json) =
      _$UsageInfoImpl.fromJson;

  @override
  @JsonKey(name: 'input_tokens')
  int get inputTokens;
  @override
  @JsonKey(name: 'output_tokens')
  int get outputTokens;
  @override
  String? get model;
  @override
  @JsonKey(name: 'processing_time_ms')
  int get processingTimeMs;
  @override
  @JsonKey(ignore: true)
  _$$UsageInfoImplCopyWith<_$UsageInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
