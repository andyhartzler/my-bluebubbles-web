// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SourceDocument _$SourceDocumentFromJson(Map<String, dynamic> json) {
  return _SourceDocument.fromJson(json);
}

/// @nodoc
mixin _$SourceDocument {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_type')
  String get sourceType => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_table')
  String? get sourceTable => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  double? get similarity => throw _privateConstructorUsedError;
  @JsonKey(name: 'retrieval_method')
  String? get retrievalMethod => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SourceDocumentCopyWith<SourceDocument> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SourceDocumentCopyWith<$Res> {
  factory $SourceDocumentCopyWith(
          SourceDocument value, $Res Function(SourceDocument) then) =
      _$SourceDocumentCopyWithImpl<$Res, SourceDocument>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'source_type') String sourceType,
      @JsonKey(name: 'source_table') String? sourceTable,
      String? title,
      double? similarity,
      @JsonKey(name: 'retrieval_method') String? retrievalMethod});
}

/// @nodoc
class _$SourceDocumentCopyWithImpl<$Res, $Val extends SourceDocument>
    implements $SourceDocumentCopyWith<$Res> {
  _$SourceDocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceType = null,
    Object? sourceTable = freezed,
    Object? title = freezed,
    Object? similarity = freezed,
    Object? retrievalMethod = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sourceType: null == sourceType
          ? _value.sourceType
          : sourceType // ignore: cast_nullable_to_non_nullable
              as String,
      sourceTable: freezed == sourceTable
          ? _value.sourceTable
          : sourceTable // ignore: cast_nullable_to_non_nullable
              as String?,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      similarity: freezed == similarity
          ? _value.similarity
          : similarity // ignore: cast_nullable_to_non_nullable
              as double?,
      retrievalMethod: freezed == retrievalMethod
          ? _value.retrievalMethod
          : retrievalMethod // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SourceDocumentImplCopyWith<$Res>
    implements $SourceDocumentCopyWith<$Res> {
  factory _$$SourceDocumentImplCopyWith(_$SourceDocumentImpl value,
          $Res Function(_$SourceDocumentImpl) then) =
      __$$SourceDocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'source_type') String sourceType,
      @JsonKey(name: 'source_table') String? sourceTable,
      String? title,
      double? similarity,
      @JsonKey(name: 'retrieval_method') String? retrievalMethod});
}

/// @nodoc
class __$$SourceDocumentImplCopyWithImpl<$Res>
    extends _$SourceDocumentCopyWithImpl<$Res, _$SourceDocumentImpl>
    implements _$$SourceDocumentImplCopyWith<$Res> {
  __$$SourceDocumentImplCopyWithImpl(
      _$SourceDocumentImpl _value, $Res Function(_$SourceDocumentImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sourceType = null,
    Object? sourceTable = freezed,
    Object? title = freezed,
    Object? similarity = freezed,
    Object? retrievalMethod = freezed,
  }) {
    return _then(_$SourceDocumentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      sourceType: null == sourceType
          ? _value.sourceType
          : sourceType // ignore: cast_nullable_to_non_nullable
              as String,
      sourceTable: freezed == sourceTable
          ? _value.sourceTable
          : sourceTable // ignore: cast_nullable_to_non_nullable
              as String?,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      similarity: freezed == similarity
          ? _value.similarity
          : similarity // ignore: cast_nullable_to_non_nullable
              as double?,
      retrievalMethod: freezed == retrievalMethod
          ? _value.retrievalMethod
          : retrievalMethod // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SourceDocumentImpl implements _SourceDocument {
  const _$SourceDocumentImpl(
      {required this.id,
      @JsonKey(name: 'source_type') required this.sourceType,
      @JsonKey(name: 'source_table') this.sourceTable,
      this.title,
      this.similarity,
      @JsonKey(name: 'retrieval_method') this.retrievalMethod});

  factory _$SourceDocumentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SourceDocumentImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'source_type')
  final String sourceType;
  @override
  @JsonKey(name: 'source_table')
  final String? sourceTable;
  @override
  final String? title;
  @override
  final double? similarity;
  @override
  @JsonKey(name: 'retrieval_method')
  final String? retrievalMethod;

  @override
  String toString() {
    return 'SourceDocument(id: $id, sourceType: $sourceType, sourceTable: $sourceTable, title: $title, similarity: $similarity, retrievalMethod: $retrievalMethod)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SourceDocumentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sourceType, sourceType) ||
                other.sourceType == sourceType) &&
            (identical(other.sourceTable, sourceTable) ||
                other.sourceTable == sourceTable) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.similarity, similarity) ||
                other.similarity == similarity) &&
            (identical(other.retrievalMethod, retrievalMethod) ||
                other.retrievalMethod == retrievalMethod));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, sourceType, sourceTable, title, similarity, retrievalMethod);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SourceDocumentImplCopyWith<_$SourceDocumentImpl> get copyWith =>
      __$$SourceDocumentImplCopyWithImpl<_$SourceDocumentImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SourceDocumentImplToJson(
      this,
    );
  }
}

abstract class _SourceDocument implements SourceDocument {
  const factory _SourceDocument(
      {required final String id,
      @JsonKey(name: 'source_type') required final String sourceType,
      @JsonKey(name: 'source_table') final String? sourceTable,
      final String? title,
      final double? similarity,
      @JsonKey(name: 'retrieval_method') final String? retrievalMethod}) = _$SourceDocumentImpl;

  factory _SourceDocument.fromJson(Map<String, dynamic> json) =
      _$SourceDocumentImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'source_type')
  String get sourceType;
  @override
  @JsonKey(name: 'source_table')
  String? get sourceTable;
  @override
  String? get title;
  @override
  double? get similarity;
  @override
  @JsonKey(name: 'retrieval_method')
  String? get retrievalMethod;
  @override
  @JsonKey(ignore: true)
  _$$SourceDocumentImplCopyWith<_$SourceDocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
