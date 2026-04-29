// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'query_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskClassification {

/// One of: simple_lookup, entity_search, explanation, comprehensive_research, content_generation
 String get type;/// One of: narrow, moderate, exhaustive
 String get scope;/// Data sources queried
@JsonKey(name: 'dataNeeds') List<String> get dataNeeds;/// Confidence score 0.0 to 1.0
 double get confidence;
/// Create a copy of TaskClassification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskClassificationCopyWith<TaskClassification> get copyWith => _$TaskClassificationCopyWithImpl<TaskClassification>(this as TaskClassification, _$identity);

  /// Serializes this TaskClassification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskClassification&&(identical(other.type, type) || other.type == type)&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other.dataNeeds, dataNeeds)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,scope,const DeepCollectionEquality().hash(dataNeeds),confidence);

@override
String toString() {
  return 'TaskClassification(type: $type, scope: $scope, dataNeeds: $dataNeeds, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class $TaskClassificationCopyWith<$Res>  {
  factory $TaskClassificationCopyWith(TaskClassification value, $Res Function(TaskClassification) _then) = _$TaskClassificationCopyWithImpl;
@useResult
$Res call({
 String type, String scope,@JsonKey(name: 'dataNeeds') List<String> dataNeeds, double confidence
});




}
/// @nodoc
class _$TaskClassificationCopyWithImpl<$Res>
    implements $TaskClassificationCopyWith<$Res> {
  _$TaskClassificationCopyWithImpl(this._self, this._then);

  final TaskClassification _self;
  final $Res Function(TaskClassification) _then;

/// Create a copy of TaskClassification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? scope = null,Object? dataNeeds = null,Object? confidence = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,dataNeeds: null == dataNeeds ? _self.dataNeeds : dataNeeds // ignore: cast_nullable_to_non_nullable
as List<String>,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskClassification].
extension TaskClassificationPatterns on TaskClassification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskClassification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskClassification() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskClassification value)  $default,){
final _that = this;
switch (_that) {
case _TaskClassification():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskClassification value)?  $default,){
final _that = this;
switch (_that) {
case _TaskClassification() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String scope, @JsonKey(name: 'dataNeeds')  List<String> dataNeeds,  double confidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskClassification() when $default != null:
return $default(_that.type,_that.scope,_that.dataNeeds,_that.confidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String scope, @JsonKey(name: 'dataNeeds')  List<String> dataNeeds,  double confidence)  $default,) {final _that = this;
switch (_that) {
case _TaskClassification():
return $default(_that.type,_that.scope,_that.dataNeeds,_that.confidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String scope, @JsonKey(name: 'dataNeeds')  List<String> dataNeeds,  double confidence)?  $default,) {final _that = this;
switch (_that) {
case _TaskClassification() when $default != null:
return $default(_that.type,_that.scope,_that.dataNeeds,_that.confidence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskClassification implements TaskClassification {
  const _TaskClassification({required this.type, required this.scope, @JsonKey(name: 'dataNeeds') final  List<String> dataNeeds = const [], this.confidence = 0.5}): _dataNeeds = dataNeeds;
  factory _TaskClassification.fromJson(Map<String, dynamic> json) => _$TaskClassificationFromJson(json);

/// One of: simple_lookup, entity_search, explanation, comprehensive_research, content_generation
@override final  String type;
/// One of: narrow, moderate, exhaustive
@override final  String scope;
/// Data sources queried
 final  List<String> _dataNeeds;
/// Data sources queried
@override@JsonKey(name: 'dataNeeds') List<String> get dataNeeds {
  if (_dataNeeds is EqualUnmodifiableListView) return _dataNeeds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dataNeeds);
}

/// Confidence score 0.0 to 1.0
@override@JsonKey() final  double confidence;

/// Create a copy of TaskClassification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskClassificationCopyWith<_TaskClassification> get copyWith => __$TaskClassificationCopyWithImpl<_TaskClassification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskClassificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskClassification&&(identical(other.type, type) || other.type == type)&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other._dataNeeds, _dataNeeds)&&(identical(other.confidence, confidence) || other.confidence == confidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,scope,const DeepCollectionEquality().hash(_dataNeeds),confidence);

@override
String toString() {
  return 'TaskClassification(type: $type, scope: $scope, dataNeeds: $dataNeeds, confidence: $confidence)';
}


}

/// @nodoc
abstract mixin class _$TaskClassificationCopyWith<$Res> implements $TaskClassificationCopyWith<$Res> {
  factory _$TaskClassificationCopyWith(_TaskClassification value, $Res Function(_TaskClassification) _then) = __$TaskClassificationCopyWithImpl;
@override @useResult
$Res call({
 String type, String scope,@JsonKey(name: 'dataNeeds') List<String> dataNeeds, double confidence
});




}
/// @nodoc
class __$TaskClassificationCopyWithImpl<$Res>
    implements _$TaskClassificationCopyWith<$Res> {
  __$TaskClassificationCopyWithImpl(this._self, this._then);

  final _TaskClassification _self;
  final $Res Function(_TaskClassification) _then;

/// Create a copy of TaskClassification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? scope = null,Object? dataNeeds = null,Object? confidence = null,}) {
  return _then(_TaskClassification(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,dataNeeds: null == dataNeeds ? _self._dataNeeds : dataNeeds // ignore: cast_nullable_to_non_nullable
as List<String>,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$UsageInfo {

@JsonKey(name: 'input_tokens') int get inputTokens;@JsonKey(name: 'output_tokens') int get outputTokens; String? get model;@JsonKey(name: 'processing_time_ms') int get processingTimeMs;
/// Create a copy of UsageInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageInfoCopyWith<UsageInfo> get copyWith => _$UsageInfoCopyWithImpl<UsageInfo>(this as UsageInfo, _$identity);

  /// Serializes this UsageInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageInfo&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.model, model) || other.model == model)&&(identical(other.processingTimeMs, processingTimeMs) || other.processingTimeMs == processingTimeMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inputTokens,outputTokens,model,processingTimeMs);

@override
String toString() {
  return 'UsageInfo(inputTokens: $inputTokens, outputTokens: $outputTokens, model: $model, processingTimeMs: $processingTimeMs)';
}


}

/// @nodoc
abstract mixin class $UsageInfoCopyWith<$Res>  {
  factory $UsageInfoCopyWith(UsageInfo value, $Res Function(UsageInfo) _then) = _$UsageInfoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'input_tokens') int inputTokens,@JsonKey(name: 'output_tokens') int outputTokens, String? model,@JsonKey(name: 'processing_time_ms') int processingTimeMs
});




}
/// @nodoc
class _$UsageInfoCopyWithImpl<$Res>
    implements $UsageInfoCopyWith<$Res> {
  _$UsageInfoCopyWithImpl(this._self, this._then);

  final UsageInfo _self;
  final $Res Function(UsageInfo) _then;

/// Create a copy of UsageInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? inputTokens = null,Object? outputTokens = null,Object? model = freezed,Object? processingTimeMs = null,}) {
  return _then(_self.copyWith(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,processingTimeMs: null == processingTimeMs ? _self.processingTimeMs : processingTimeMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageInfo].
extension UsageInfoPatterns on UsageInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageInfo value)  $default,){
final _that = this;
switch (_that) {
case _UsageInfo():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UsageInfo() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'input_tokens')  int inputTokens, @JsonKey(name: 'output_tokens')  int outputTokens,  String? model, @JsonKey(name: 'processing_time_ms')  int processingTimeMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageInfo() when $default != null:
return $default(_that.inputTokens,_that.outputTokens,_that.model,_that.processingTimeMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'input_tokens')  int inputTokens, @JsonKey(name: 'output_tokens')  int outputTokens,  String? model, @JsonKey(name: 'processing_time_ms')  int processingTimeMs)  $default,) {final _that = this;
switch (_that) {
case _UsageInfo():
return $default(_that.inputTokens,_that.outputTokens,_that.model,_that.processingTimeMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'input_tokens')  int inputTokens, @JsonKey(name: 'output_tokens')  int outputTokens,  String? model, @JsonKey(name: 'processing_time_ms')  int processingTimeMs)?  $default,) {final _that = this;
switch (_that) {
case _UsageInfo() when $default != null:
return $default(_that.inputTokens,_that.outputTokens,_that.model,_that.processingTimeMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageInfo implements UsageInfo {
  const _UsageInfo({@JsonKey(name: 'input_tokens') this.inputTokens = 0, @JsonKey(name: 'output_tokens') this.outputTokens = 0, this.model, @JsonKey(name: 'processing_time_ms') this.processingTimeMs = 0});
  factory _UsageInfo.fromJson(Map<String, dynamic> json) => _$UsageInfoFromJson(json);

@override@JsonKey(name: 'input_tokens') final  int inputTokens;
@override@JsonKey(name: 'output_tokens') final  int outputTokens;
@override final  String? model;
@override@JsonKey(name: 'processing_time_ms') final  int processingTimeMs;

/// Create a copy of UsageInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageInfoCopyWith<_UsageInfo> get copyWith => __$UsageInfoCopyWithImpl<_UsageInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageInfo&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.model, model) || other.model == model)&&(identical(other.processingTimeMs, processingTimeMs) || other.processingTimeMs == processingTimeMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inputTokens,outputTokens,model,processingTimeMs);

@override
String toString() {
  return 'UsageInfo(inputTokens: $inputTokens, outputTokens: $outputTokens, model: $model, processingTimeMs: $processingTimeMs)';
}


}

/// @nodoc
abstract mixin class _$UsageInfoCopyWith<$Res> implements $UsageInfoCopyWith<$Res> {
  factory _$UsageInfoCopyWith(_UsageInfo value, $Res Function(_UsageInfo) _then) = __$UsageInfoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'input_tokens') int inputTokens,@JsonKey(name: 'output_tokens') int outputTokens, String? model,@JsonKey(name: 'processing_time_ms') int processingTimeMs
});




}
/// @nodoc
class __$UsageInfoCopyWithImpl<$Res>
    implements _$UsageInfoCopyWith<$Res> {
  __$UsageInfoCopyWithImpl(this._self, this._then);

  final _UsageInfo _self;
  final $Res Function(_UsageInfo) _then;

/// Create a copy of UsageInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? inputTokens = null,Object? outputTokens = null,Object? model = freezed,Object? processingTimeMs = null,}) {
  return _then(_UsageInfo(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,processingTimeMs: null == processingTimeMs ? _self.processingTimeMs : processingTimeMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
