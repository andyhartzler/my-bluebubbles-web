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

TaskClassification _$TaskClassificationFromJson(Map<String, dynamic> json) {
  return _TaskClassification.fromJson(json);
}

/// @nodoc
mixin _$TaskClassification {
  /// One of: simple_lookup, entity_search, explanation, comprehensive_research, content_generation
  String get type => throw _privateConstructorUsedError;

  /// One of: narrow, moderate, exhaustive
  String get scope => throw _privateConstructorUsedError;

  /// Data sources queried
  @JsonKey(name: 'dataNeeds')
  List<String> get dataNeeds => throw _privateConstructorUsedError;

  /// Confidence score 0.0 to 1.0
  double get confidence => throw _privateConstructorUsedError;

  /// Serializes this TaskClassification to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskClassification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskClassificationCopyWith<TaskClassification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskClassificationCopyWith<$Res> {
  factory $TaskClassificationCopyWith(
          TaskClassification value, $Res Function(TaskClassification) then) =
      _$TaskClassificationCopyWithImpl<$Res, TaskClassification>;
  @useResult
  $Res call(
      {String type,
      String scope,
      @JsonKey(name: 'dataNeeds') List<String> dataNeeds,
      double confidence});
}

/// @nodoc
class _$TaskClassificationCopyWithImpl<$Res, $Val extends TaskClassification>
    implements $TaskClassificationCopyWith<$Res> {
  _$TaskClassificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskClassification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? scope = null,
    Object? dataNeeds = null,
    Object? confidence = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      scope: null == scope
          ? _value.scope
          : scope // ignore: cast_nullable_to_non_nullable
              as String,
      dataNeeds: null == dataNeeds
          ? _value.dataNeeds
          : dataNeeds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskClassificationImplCopyWith<$Res>
    implements $TaskClassificationCopyWith<$Res> {
  factory _$$TaskClassificationImplCopyWith(_$TaskClassificationImpl value,
          $Res Function(_$TaskClassificationImpl) then) =
      __$$TaskClassificationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      String scope,
      @JsonKey(name: 'dataNeeds') List<String> dataNeeds,
      double confidence});
}

/// @nodoc
class __$$TaskClassificationImplCopyWithImpl<$Res>
    extends _$TaskClassificationCopyWithImpl<$Res, _$TaskClassificationImpl>
    implements _$$TaskClassificationImplCopyWith<$Res> {
  __$$TaskClassificationImplCopyWithImpl(_$TaskClassificationImpl _value,
      $Res Function(_$TaskClassificationImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskClassification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? scope = null,
    Object? dataNeeds = null,
    Object? confidence = null,
  }) {
    return _then(_$TaskClassificationImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      scope: null == scope
          ? _value.scope
          : scope // ignore: cast_nullable_to_non_nullable
              as String,
      dataNeeds: null == dataNeeds
          ? _value._dataNeeds
          : dataNeeds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      confidence: null == confidence
          ? _value.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskClassificationImpl implements _TaskClassification {
  const _$TaskClassificationImpl(
      {required this.type,
      required this.scope,
      @JsonKey(name: 'dataNeeds') final List<String> dataNeeds = const [],
      this.confidence = 0.5})
      : _dataNeeds = dataNeeds;

  factory _$TaskClassificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskClassificationImplFromJson(json);

  /// One of: simple_lookup, entity_search, explanation, comprehensive_research, content_generation
  @override
  final String type;

  /// One of: narrow, moderate, exhaustive
  @override
  final String scope;

  /// Data sources queried
  final List<String> _dataNeeds;

  /// Data sources queried
  @override
  @JsonKey(name: 'dataNeeds')
  List<String> get dataNeeds {
    if (_dataNeeds is EqualUnmodifiableListView) return _dataNeeds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dataNeeds);
  }

  /// Confidence score 0.0 to 1.0
  @override
  @JsonKey()
  final double confidence;

  @override
  String toString() {
    return 'TaskClassification(type: $type, scope: $scope, dataNeeds: $dataNeeds, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskClassificationImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.scope, scope) || other.scope == scope) &&
            const DeepCollectionEquality()
                .equals(other._dataNeeds, _dataNeeds) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, scope,
      const DeepCollectionEquality().hash(_dataNeeds), confidence);

  /// Create a copy of TaskClassification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskClassificationImplCopyWith<_$TaskClassificationImpl> get copyWith =>
      __$$TaskClassificationImplCopyWithImpl<_$TaskClassificationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskClassificationImplToJson(
      this,
    );
  }
}

abstract class _TaskClassification implements TaskClassification {
  const factory _TaskClassification(
      {required final String type,
      required final String scope,
      @JsonKey(name: 'dataNeeds') final List<String> dataNeeds,
      final double confidence}) = _$TaskClassificationImpl;

  factory _TaskClassification.fromJson(Map<String, dynamic> json) =
      _$TaskClassificationImpl.fromJson;

  /// One of: simple_lookup, entity_search, explanation, comprehensive_research, content_generation
  @override
  String get type;

  /// One of: narrow, moderate, exhaustive
  @override
  String get scope;

  /// Data sources queried
  @override
  @JsonKey(name: 'dataNeeds')
  List<String> get dataNeeds;

  /// Confidence score 0.0 to 1.0
  @override
  double get confidence;

  /// Create a copy of TaskClassification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskClassificationImplCopyWith<_$TaskClassificationImpl> get copyWith =>
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

  /// Serializes this UsageInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UsageInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UsageInfo
  /// with the given fields replaced by the non-null parameter values.
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
          : inputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      outputTokens: null == outputTokens
          ? _value.outputTokens
          : outputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      model: freezed == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
      processingTimeMs: null == processingTimeMs
          ? _value.processingTimeMs
          : processingTimeMs // ignore: cast_nullable_to_non_nullable
              as int,
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

  /// Create a copy of UsageInfo
  /// with the given fields replaced by the non-null parameter values.
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
          : inputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      outputTokens: null == outputTokens
          ? _value.outputTokens
          : outputTokens // ignore: cast_nullable_to_non_nullable
              as int,
      model: freezed == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String?,
      processingTimeMs: null == processingTimeMs
          ? _value.processingTimeMs
          : processingTimeMs // ignore: cast_nullable_to_non_nullable
              as int,
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, inputTokens, outputTokens, model, processingTimeMs);

  /// Create a copy of UsageInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UsageInfoImplCopyWith<_$UsageInfoImpl> get copyWith =>
      __$$UsageInfoImplCopyWithImpl<_$UsageInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UsageInfoImplToJson(
      this,
    );
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

  /// Create a copy of UsageInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UsageInfoImplCopyWith<_$UsageInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
