// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) {
  return _ChatMessage.fromJson(json);
}

/// @nodoc
mixin _$ChatMessage {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'session_id')
  String get sessionId => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  @JsonKey(name: 'source_documents')
  List<SourceDocument> get sourceDocuments =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'tokens_used')
  Map<String, dynamic>? get tokensUsed => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'session_id') String sessionId,
      String role,
      String content,
      @JsonKey(name: 'source_documents') List<SourceDocument> sourceDocuments,
      @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed});
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? sessionId = null,
    Object? role = null,
    Object? content = null,
    Object? sourceDocuments = null,
    Object? tokensUsed = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      sourceDocuments: null == sourceDocuments
          ? _value.sourceDocuments
          : sourceDocuments // ignore: cast_nullable_to_non_nullable
              as List<SourceDocument>,
      tokensUsed: freezed == tokensUsed
          ? _value.tokensUsed
          : tokensUsed // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'session_id') String sessionId,
      String role,
      String content,
      @JsonKey(name: 'source_documents') List<SourceDocument> sourceDocuments,
      @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed});
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? sessionId = null,
    Object? role = null,
    Object? content = null,
    Object? sourceDocuments = null,
    Object? tokensUsed = freezed,
  }) {
    return _then(_$ChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sessionId: null == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      sourceDocuments: null == sourceDocuments
          ? _value._sourceDocuments
          : sourceDocuments // ignore: cast_nullable_to_non_nullable
              as List<SourceDocument>,
      tokensUsed: freezed == tokensUsed
          ? _value._tokensUsed
          : tokensUsed // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatMessageImpl implements _ChatMessage {
  const _$ChatMessageImpl(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'session_id') required this.sessionId,
      required this.role,
      required this.content,
      @JsonKey(name: 'source_documents')
      final List<SourceDocument> sourceDocuments = const [],
      @JsonKey(name: 'tokens_used') final Map<String, dynamic>? tokensUsed})
      : _sourceDocuments = sourceDocuments,
        _tokensUsed = tokensUsed;

  factory _$ChatMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatMessageImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'session_id')
  final String sessionId;
  @override
  final String role;
  @override
  final String content;
  final List<SourceDocument> _sourceDocuments;
  @override
  @JsonKey(name: 'source_documents')
  List<SourceDocument> get sourceDocuments {
    if (_sourceDocuments is EqualUnmodifiableListView) return _sourceDocuments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sourceDocuments);
  }

  final Map<String, dynamic>? _tokensUsed;
  @override
  @JsonKey(name: 'tokens_used')
  Map<String, dynamic>? get tokensUsed {
    final value = _tokensUsed;
    if (value == null) return null;
    if (_tokensUsed is EqualUnmodifiableMapView) return _tokensUsed;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, createdAt: $createdAt, sessionId: $sessionId, role: $role, content: $content, sourceDocuments: $sourceDocuments, tokensUsed: $tokensUsed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality()
                .equals(other._sourceDocuments, _sourceDocuments) &&
            const DeepCollectionEquality()
                .equals(other._tokensUsed, _tokensUsed));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      sessionId,
      role,
      content,
      const DeepCollectionEquality().hash(_sourceDocuments),
      const DeepCollectionEquality().hash(_tokensUsed));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatMessageImplToJson(
      this,
    );
  }
}

abstract class _ChatMessage implements ChatMessage {
  const factory _ChatMessage(
          {required final String id,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'session_id') required final String sessionId,
          required final String role,
          required final String content,
          @JsonKey(name: 'source_documents')
          final List<SourceDocument> sourceDocuments,
          @JsonKey(name: 'tokens_used') final Map<String, dynamic>? tokensUsed}) =
      _$ChatMessageImpl;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) =
      _$ChatMessageImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'session_id')
  String get sessionId;
  @override
  String get role;
  @override
  String get content;
  @override
  @JsonKey(name: 'source_documents')
  List<SourceDocument> get sourceDocuments;
  @override
  @JsonKey(name: 'tokens_used')
  Map<String, dynamic>? get tokensUsed;
  @override
  @JsonKey(ignore: true)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
