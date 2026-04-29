// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatMessage {
  String get id;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'session_id')
  String get sessionId;
  String get role;
  String get content;
  @JsonKey(name: 'source_documents')
  List<SourceDocument> get sourceDocuments;
  @JsonKey(name: 'tokens_used')
  Map<String, dynamic>? get tokensUsed;
  @JsonKey(includeFromJson: false, includeToJson: false)
  FeedbackState get feedbackState;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      _$ChatMessageCopyWithImpl<ChatMessage>(this as ChatMessage, _$identity);

  /// Serializes this ChatMessage to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChatMessage &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality()
                .equals(other.sourceDocuments, sourceDocuments) &&
            const DeepCollectionEquality()
                .equals(other.tokensUsed, tokensUsed) &&
            (identical(other.feedbackState, feedbackState) ||
                other.feedbackState == feedbackState));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      sessionId,
      role,
      content,
      const DeepCollectionEquality().hash(sourceDocuments),
      const DeepCollectionEquality().hash(tokensUsed),
      feedbackState);

  @override
  String toString() {
    return 'ChatMessage(id: $id, createdAt: $createdAt, sessionId: $sessionId, role: $role, content: $content, sourceDocuments: $sourceDocuments, tokensUsed: $tokensUsed, feedbackState: $feedbackState)';
  }
}

/// @nodoc
abstract mixin class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) _then) =
      _$ChatMessageCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'session_id') String sessionId,
      String role,
      String content,
      @JsonKey(name: 'source_documents') List<SourceDocument> sourceDocuments,
      @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed,
      @JsonKey(includeFromJson: false, includeToJson: false)
      FeedbackState feedbackState});
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res> implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._self, this._then);

  final ChatMessage _self;
  final $Res Function(ChatMessage) _then;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
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
    Object? feedbackState = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      sourceDocuments: null == sourceDocuments
          ? _self.sourceDocuments
          : sourceDocuments // ignore: cast_nullable_to_non_nullable
              as List<SourceDocument>,
      tokensUsed: freezed == tokensUsed
          ? _self.tokensUsed
          : tokensUsed // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      feedbackState: null == feedbackState
          ? _self.feedbackState
          : feedbackState // ignore: cast_nullable_to_non_nullable
              as FeedbackState,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChatMessage].
extension ChatMessagePatterns on ChatMessage {
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
    TResult Function(_ChatMessage value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatMessage() when $default != null:
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
    TResult Function(_ChatMessage value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMessage():
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
    TResult? Function(_ChatMessage value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMessage() when $default != null:
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
            String id,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'session_id') String sessionId,
            String role,
            String content,
            @JsonKey(name: 'source_documents')
            List<SourceDocument> sourceDocuments,
            @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed,
            @JsonKey(includeFromJson: false, includeToJson: false)
            FeedbackState feedbackState)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChatMessage() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.sessionId,
            _that.role,
            _that.content,
            _that.sourceDocuments,
            _that.tokensUsed,
            _that.feedbackState);
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
            String id,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'session_id') String sessionId,
            String role,
            String content,
            @JsonKey(name: 'source_documents')
            List<SourceDocument> sourceDocuments,
            @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed,
            @JsonKey(includeFromJson: false, includeToJson: false)
            FeedbackState feedbackState)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMessage():
        return $default(
            _that.id,
            _that.createdAt,
            _that.sessionId,
            _that.role,
            _that.content,
            _that.sourceDocuments,
            _that.tokensUsed,
            _that.feedbackState);
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
            String id,
            @JsonKey(name: 'created_at') DateTime createdAt,
            @JsonKey(name: 'session_id') String sessionId,
            String role,
            String content,
            @JsonKey(name: 'source_documents')
            List<SourceDocument> sourceDocuments,
            @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed,
            @JsonKey(includeFromJson: false, includeToJson: false)
            FeedbackState feedbackState)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChatMessage() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.sessionId,
            _that.role,
            _that.content,
            _that.sourceDocuments,
            _that.tokensUsed,
            _that.feedbackState);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ChatMessage implements ChatMessage {
  const _ChatMessage(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'session_id') required this.sessionId,
      required this.role,
      required this.content,
      @JsonKey(name: 'source_documents')
      final List<SourceDocument> sourceDocuments = const [],
      @JsonKey(name: 'tokens_used') final Map<String, dynamic>? tokensUsed,
      @JsonKey(includeFromJson: false, includeToJson: false)
      this.feedbackState = FeedbackState.none})
      : _sourceDocuments = sourceDocuments,
        _tokensUsed = tokensUsed;
  factory _ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

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
  @JsonKey(includeFromJson: false, includeToJson: false)
  final FeedbackState feedbackState;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChatMessageCopyWith<_ChatMessage> get copyWith =>
      __$ChatMessageCopyWithImpl<_ChatMessage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChatMessageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChatMessage &&
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
                .equals(other._tokensUsed, _tokensUsed) &&
            (identical(other.feedbackState, feedbackState) ||
                other.feedbackState == feedbackState));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      sessionId,
      role,
      content,
      const DeepCollectionEquality().hash(_sourceDocuments),
      const DeepCollectionEquality().hash(_tokensUsed),
      feedbackState);

  @override
  String toString() {
    return 'ChatMessage(id: $id, createdAt: $createdAt, sessionId: $sessionId, role: $role, content: $content, sourceDocuments: $sourceDocuments, tokensUsed: $tokensUsed, feedbackState: $feedbackState)';
  }
}

/// @nodoc
abstract mixin class _$ChatMessageCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$ChatMessageCopyWith(
          _ChatMessage value, $Res Function(_ChatMessage) _then) =
      __$ChatMessageCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'session_id') String sessionId,
      String role,
      String content,
      @JsonKey(name: 'source_documents') List<SourceDocument> sourceDocuments,
      @JsonKey(name: 'tokens_used') Map<String, dynamic>? tokensUsed,
      @JsonKey(includeFromJson: false, includeToJson: false)
      FeedbackState feedbackState});
}

/// @nodoc
class __$ChatMessageCopyWithImpl<$Res> implements _$ChatMessageCopyWith<$Res> {
  __$ChatMessageCopyWithImpl(this._self, this._then);

  final _ChatMessage _self;
  final $Res Function(_ChatMessage) _then;

  /// Create a copy of ChatMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? sessionId = null,
    Object? role = null,
    Object? content = null,
    Object? sourceDocuments = null,
    Object? tokensUsed = freezed,
    Object? feedbackState = null,
  }) {
    return _then(_ChatMessage(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      sessionId: null == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      sourceDocuments: null == sourceDocuments
          ? _self._sourceDocuments
          : sourceDocuments // ignore: cast_nullable_to_non_nullable
              as List<SourceDocument>,
      tokensUsed: freezed == tokensUsed
          ? _self._tokensUsed
          : tokensUsed // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      feedbackState: null == feedbackState
          ? _self.feedbackState
          : feedbackState // ignore: cast_nullable_to_non_nullable
              as FeedbackState,
    ));
  }
}

// dart format on
