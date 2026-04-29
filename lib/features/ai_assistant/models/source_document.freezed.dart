// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceDocument {

 String get id;@JsonKey(name: 'source_type') String get sourceType;@JsonKey(name: 'source_table') String? get sourceTable; String? get title; double? get similarity;@JsonKey(name: 'retrieval_method') String? get retrievalMethod;
/// Create a copy of SourceDocument
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceDocumentCopyWith<SourceDocument> get copyWith => _$SourceDocumentCopyWithImpl<SourceDocument>(this as SourceDocument, _$identity);

  /// Serializes this SourceDocument to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.sourceTable, sourceTable) || other.sourceTable == sourceTable)&&(identical(other.title, title) || other.title == title)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.retrievalMethod, retrievalMethod) || other.retrievalMethod == retrievalMethod));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sourceType,sourceTable,title,similarity,retrievalMethod);

@override
String toString() {
  return 'SourceDocument(id: $id, sourceType: $sourceType, sourceTable: $sourceTable, title: $title, similarity: $similarity, retrievalMethod: $retrievalMethod)';
}


}

/// @nodoc
abstract mixin class $SourceDocumentCopyWith<$Res>  {
  factory $SourceDocumentCopyWith(SourceDocument value, $Res Function(SourceDocument) _then) = _$SourceDocumentCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'source_type') String sourceType,@JsonKey(name: 'source_table') String? sourceTable, String? title, double? similarity,@JsonKey(name: 'retrieval_method') String? retrievalMethod
});




}
/// @nodoc
class _$SourceDocumentCopyWithImpl<$Res>
    implements $SourceDocumentCopyWith<$Res> {
  _$SourceDocumentCopyWithImpl(this._self, this._then);

  final SourceDocument _self;
  final $Res Function(SourceDocument) _then;

/// Create a copy of SourceDocument
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sourceType = null,Object? sourceTable = freezed,Object? title = freezed,Object? similarity = freezed,Object? retrievalMethod = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,sourceTable: freezed == sourceTable ? _self.sourceTable : sourceTable // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,similarity: freezed == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double?,retrievalMethod: freezed == retrievalMethod ? _self.retrievalMethod : retrievalMethod // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceDocument].
extension SourceDocumentPatterns on SourceDocument {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceDocument value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceDocument() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceDocument value)  $default,){
final _that = this;
switch (_that) {
case _SourceDocument():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceDocument value)?  $default,){
final _that = this;
switch (_that) {
case _SourceDocument() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'source_type')  String sourceType, @JsonKey(name: 'source_table')  String? sourceTable,  String? title,  double? similarity, @JsonKey(name: 'retrieval_method')  String? retrievalMethod)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceDocument() when $default != null:
return $default(_that.id,_that.sourceType,_that.sourceTable,_that.title,_that.similarity,_that.retrievalMethod);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'source_type')  String sourceType, @JsonKey(name: 'source_table')  String? sourceTable,  String? title,  double? similarity, @JsonKey(name: 'retrieval_method')  String? retrievalMethod)  $default,) {final _that = this;
switch (_that) {
case _SourceDocument():
return $default(_that.id,_that.sourceType,_that.sourceTable,_that.title,_that.similarity,_that.retrievalMethod);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'source_type')  String sourceType, @JsonKey(name: 'source_table')  String? sourceTable,  String? title,  double? similarity, @JsonKey(name: 'retrieval_method')  String? retrievalMethod)?  $default,) {final _that = this;
switch (_that) {
case _SourceDocument() when $default != null:
return $default(_that.id,_that.sourceType,_that.sourceTable,_that.title,_that.similarity,_that.retrievalMethod);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SourceDocument implements SourceDocument {
  const _SourceDocument({required this.id, @JsonKey(name: 'source_type') required this.sourceType, @JsonKey(name: 'source_table') this.sourceTable, this.title, this.similarity, @JsonKey(name: 'retrieval_method') this.retrievalMethod});
  factory _SourceDocument.fromJson(Map<String, dynamic> json) => _$SourceDocumentFromJson(json);

@override final  String id;
@override@JsonKey(name: 'source_type') final  String sourceType;
@override@JsonKey(name: 'source_table') final  String? sourceTable;
@override final  String? title;
@override final  double? similarity;
@override@JsonKey(name: 'retrieval_method') final  String? retrievalMethod;

/// Create a copy of SourceDocument
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceDocumentCopyWith<_SourceDocument> get copyWith => __$SourceDocumentCopyWithImpl<_SourceDocument>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SourceDocumentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceDocument&&(identical(other.id, id) || other.id == id)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.sourceTable, sourceTable) || other.sourceTable == sourceTable)&&(identical(other.title, title) || other.title == title)&&(identical(other.similarity, similarity) || other.similarity == similarity)&&(identical(other.retrievalMethod, retrievalMethod) || other.retrievalMethod == retrievalMethod));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sourceType,sourceTable,title,similarity,retrievalMethod);

@override
String toString() {
  return 'SourceDocument(id: $id, sourceType: $sourceType, sourceTable: $sourceTable, title: $title, similarity: $similarity, retrievalMethod: $retrievalMethod)';
}


}

/// @nodoc
abstract mixin class _$SourceDocumentCopyWith<$Res> implements $SourceDocumentCopyWith<$Res> {
  factory _$SourceDocumentCopyWith(_SourceDocument value, $Res Function(_SourceDocument) _then) = __$SourceDocumentCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'source_type') String sourceType,@JsonKey(name: 'source_table') String? sourceTable, String? title, double? similarity,@JsonKey(name: 'retrieval_method') String? retrievalMethod
});




}
/// @nodoc
class __$SourceDocumentCopyWithImpl<$Res>
    implements _$SourceDocumentCopyWith<$Res> {
  __$SourceDocumentCopyWithImpl(this._self, this._then);

  final _SourceDocument _self;
  final $Res Function(_SourceDocument) _then;

/// Create a copy of SourceDocument
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sourceType = null,Object? sourceTable = freezed,Object? title = freezed,Object? similarity = freezed,Object? retrievalMethod = freezed,}) {
  return _then(_SourceDocument(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,sourceTable: freezed == sourceTable ? _self.sourceTable : sourceTable // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,similarity: freezed == similarity ? _self.similarity : similarity // ignore: cast_nullable_to_non_nullable
as double?,retrievalMethod: freezed == retrievalMethod ? _self.retrievalMethod : retrievalMethod // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
