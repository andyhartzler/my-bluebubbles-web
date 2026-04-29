// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_notification_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobNotificationTemplate {
  String get id;
  @JsonKey(name: 'trigger_type')
  String get triggerType;
  @JsonKey(name: 'recipient_type')
  String get recipientType;
  String get name;
  String? get description;
  @JsonKey(name: 'email_enabled')
  bool get emailEnabled;
  @JsonKey(name: 'email_subject')
  String? get emailSubject;
  @JsonKey(name: 'email_html')
  String? get emailHtml;
  @JsonKey(name: 'email_plain_text')
  String? get emailPlainText;
  @JsonKey(name: 'sms_enabled')
  bool get smsEnabled;
  @JsonKey(name: 'sms_body')
  String? get smsBody;
  @JsonKey(name: 'is_active')
  bool get isActive;
  @JsonKey(name: 'is_default')
  bool get isDefault;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @JsonKey(name: 'updated_by')
  String? get updatedBy;

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JobNotificationTemplateCopyWith<JobNotificationTemplate> get copyWith =>
      _$JobNotificationTemplateCopyWithImpl<JobNotificationTemplate>(
          this as JobNotificationTemplate, _$identity);

  /// Serializes this JobNotificationTemplate to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JobNotificationTemplate &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.triggerType, triggerType) ||
                other.triggerType == triggerType) &&
            (identical(other.recipientType, recipientType) ||
                other.recipientType == recipientType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.emailEnabled, emailEnabled) ||
                other.emailEnabled == emailEnabled) &&
            (identical(other.emailSubject, emailSubject) ||
                other.emailSubject == emailSubject) &&
            (identical(other.emailHtml, emailHtml) ||
                other.emailHtml == emailHtml) &&
            (identical(other.emailPlainText, emailPlainText) ||
                other.emailPlainText == emailPlainText) &&
            (identical(other.smsEnabled, smsEnabled) ||
                other.smsEnabled == smsEnabled) &&
            (identical(other.smsBody, smsBody) || other.smsBody == smsBody) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      triggerType,
      recipientType,
      name,
      description,
      emailEnabled,
      emailSubject,
      emailHtml,
      emailPlainText,
      smsEnabled,
      smsBody,
      isActive,
      isDefault,
      createdAt,
      updatedAt,
      createdBy,
      updatedBy);

  @override
  String toString() {
    return 'JobNotificationTemplate(id: $id, triggerType: $triggerType, recipientType: $recipientType, name: $name, description: $description, emailEnabled: $emailEnabled, emailSubject: $emailSubject, emailHtml: $emailHtml, emailPlainText: $emailPlainText, smsEnabled: $smsEnabled, smsBody: $smsBody, isActive: $isActive, isDefault: $isDefault, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy)';
  }
}

/// @nodoc
abstract mixin class $JobNotificationTemplateCopyWith<$Res> {
  factory $JobNotificationTemplateCopyWith(JobNotificationTemplate value,
          $Res Function(JobNotificationTemplate) _then) =
      _$JobNotificationTemplateCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'trigger_type') String triggerType,
      @JsonKey(name: 'recipient_type') String recipientType,
      String name,
      String? description,
      @JsonKey(name: 'email_enabled') bool emailEnabled,
      @JsonKey(name: 'email_subject') String? emailSubject,
      @JsonKey(name: 'email_html') String? emailHtml,
      @JsonKey(name: 'email_plain_text') String? emailPlainText,
      @JsonKey(name: 'sms_enabled') bool smsEnabled,
      @JsonKey(name: 'sms_body') String? smsBody,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'is_default') bool isDefault,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      @JsonKey(name: 'created_by') String? createdBy,
      @JsonKey(name: 'updated_by') String? updatedBy});
}

/// @nodoc
class _$JobNotificationTemplateCopyWithImpl<$Res>
    implements $JobNotificationTemplateCopyWith<$Res> {
  _$JobNotificationTemplateCopyWithImpl(this._self, this._then);

  final JobNotificationTemplate _self;
  final $Res Function(JobNotificationTemplate) _then;

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? triggerType = null,
    Object? recipientType = null,
    Object? name = null,
    Object? description = freezed,
    Object? emailEnabled = null,
    Object? emailSubject = freezed,
    Object? emailHtml = freezed,
    Object? emailPlainText = freezed,
    Object? smsEnabled = null,
    Object? smsBody = freezed,
    Object? isActive = null,
    Object? isDefault = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      triggerType: null == triggerType
          ? _self.triggerType
          : triggerType // ignore: cast_nullable_to_non_nullable
              as String,
      recipientType: null == recipientType
          ? _self.recipientType
          : recipientType // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      emailEnabled: null == emailEnabled
          ? _self.emailEnabled
          : emailEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      emailSubject: freezed == emailSubject
          ? _self.emailSubject
          : emailSubject // ignore: cast_nullable_to_non_nullable
              as String?,
      emailHtml: freezed == emailHtml
          ? _self.emailHtml
          : emailHtml // ignore: cast_nullable_to_non_nullable
              as String?,
      emailPlainText: freezed == emailPlainText
          ? _self.emailPlainText
          : emailPlainText // ignore: cast_nullable_to_non_nullable
              as String?,
      smsEnabled: null == smsEnabled
          ? _self.smsEnabled
          : smsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smsBody: freezed == smsBody
          ? _self.smsBody
          : smsBody // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: freezed == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedBy: freezed == updatedBy
          ? _self.updatedBy
          : updatedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [JobNotificationTemplate].
extension JobNotificationTemplatePatterns on JobNotificationTemplate {
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
    TResult Function(_JobNotificationTemplate value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobNotificationTemplate() when $default != null:
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
    TResult Function(_JobNotificationTemplate value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobNotificationTemplate():
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
    TResult? Function(_JobNotificationTemplate value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobNotificationTemplate() when $default != null:
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
            @JsonKey(name: 'trigger_type') String triggerType,
            @JsonKey(name: 'recipient_type') String recipientType,
            String name,
            String? description,
            @JsonKey(name: 'email_enabled') bool emailEnabled,
            @JsonKey(name: 'email_subject') String? emailSubject,
            @JsonKey(name: 'email_html') String? emailHtml,
            @JsonKey(name: 'email_plain_text') String? emailPlainText,
            @JsonKey(name: 'sms_enabled') bool smsEnabled,
            @JsonKey(name: 'sms_body') String? smsBody,
            @JsonKey(name: 'is_active') bool isActive,
            @JsonKey(name: 'is_default') bool isDefault,
            @JsonKey(name: 'created_at') DateTime? createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt,
            @JsonKey(name: 'created_by') String? createdBy,
            @JsonKey(name: 'updated_by') String? updatedBy)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobNotificationTemplate() when $default != null:
        return $default(
            _that.id,
            _that.triggerType,
            _that.recipientType,
            _that.name,
            _that.description,
            _that.emailEnabled,
            _that.emailSubject,
            _that.emailHtml,
            _that.emailPlainText,
            _that.smsEnabled,
            _that.smsBody,
            _that.isActive,
            _that.isDefault,
            _that.createdAt,
            _that.updatedAt,
            _that.createdBy,
            _that.updatedBy);
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
            @JsonKey(name: 'trigger_type') String triggerType,
            @JsonKey(name: 'recipient_type') String recipientType,
            String name,
            String? description,
            @JsonKey(name: 'email_enabled') bool emailEnabled,
            @JsonKey(name: 'email_subject') String? emailSubject,
            @JsonKey(name: 'email_html') String? emailHtml,
            @JsonKey(name: 'email_plain_text') String? emailPlainText,
            @JsonKey(name: 'sms_enabled') bool smsEnabled,
            @JsonKey(name: 'sms_body') String? smsBody,
            @JsonKey(name: 'is_active') bool isActive,
            @JsonKey(name: 'is_default') bool isDefault,
            @JsonKey(name: 'created_at') DateTime? createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt,
            @JsonKey(name: 'created_by') String? createdBy,
            @JsonKey(name: 'updated_by') String? updatedBy)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobNotificationTemplate():
        return $default(
            _that.id,
            _that.triggerType,
            _that.recipientType,
            _that.name,
            _that.description,
            _that.emailEnabled,
            _that.emailSubject,
            _that.emailHtml,
            _that.emailPlainText,
            _that.smsEnabled,
            _that.smsBody,
            _that.isActive,
            _that.isDefault,
            _that.createdAt,
            _that.updatedAt,
            _that.createdBy,
            _that.updatedBy);
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
            @JsonKey(name: 'trigger_type') String triggerType,
            @JsonKey(name: 'recipient_type') String recipientType,
            String name,
            String? description,
            @JsonKey(name: 'email_enabled') bool emailEnabled,
            @JsonKey(name: 'email_subject') String? emailSubject,
            @JsonKey(name: 'email_html') String? emailHtml,
            @JsonKey(name: 'email_plain_text') String? emailPlainText,
            @JsonKey(name: 'sms_enabled') bool smsEnabled,
            @JsonKey(name: 'sms_body') String? smsBody,
            @JsonKey(name: 'is_active') bool isActive,
            @JsonKey(name: 'is_default') bool isDefault,
            @JsonKey(name: 'created_at') DateTime? createdAt,
            @JsonKey(name: 'updated_at') DateTime? updatedAt,
            @JsonKey(name: 'created_by') String? createdBy,
            @JsonKey(name: 'updated_by') String? updatedBy)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobNotificationTemplate() when $default != null:
        return $default(
            _that.id,
            _that.triggerType,
            _that.recipientType,
            _that.name,
            _that.description,
            _that.emailEnabled,
            _that.emailSubject,
            _that.emailHtml,
            _that.emailPlainText,
            _that.smsEnabled,
            _that.smsBody,
            _that.isActive,
            _that.isDefault,
            _that.createdAt,
            _that.updatedAt,
            _that.createdBy,
            _that.updatedBy);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _JobNotificationTemplate extends JobNotificationTemplate {
  const _JobNotificationTemplate(
      {required this.id,
      @JsonKey(name: 'trigger_type') required this.triggerType,
      @JsonKey(name: 'recipient_type') required this.recipientType,
      required this.name,
      this.description,
      @JsonKey(name: 'email_enabled') this.emailEnabled = true,
      @JsonKey(name: 'email_subject') this.emailSubject,
      @JsonKey(name: 'email_html') this.emailHtml,
      @JsonKey(name: 'email_plain_text') this.emailPlainText,
      @JsonKey(name: 'sms_enabled') this.smsEnabled = false,
      @JsonKey(name: 'sms_body') this.smsBody,
      @JsonKey(name: 'is_active') this.isActive = true,
      @JsonKey(name: 'is_default') this.isDefault = false,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt,
      @JsonKey(name: 'created_by') this.createdBy,
      @JsonKey(name: 'updated_by') this.updatedBy})
      : super._();
  factory _JobNotificationTemplate.fromJson(Map<String, dynamic> json) =>
      _$JobNotificationTemplateFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'trigger_type')
  final String triggerType;
  @override
  @JsonKey(name: 'recipient_type')
  final String recipientType;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey(name: 'email_enabled')
  final bool emailEnabled;
  @override
  @JsonKey(name: 'email_subject')
  final String? emailSubject;
  @override
  @JsonKey(name: 'email_html')
  final String? emailHtml;
  @override
  @JsonKey(name: 'email_plain_text')
  final String? emailPlainText;
  @override
  @JsonKey(name: 'sms_enabled')
  final bool smsEnabled;
  @override
  @JsonKey(name: 'sms_body')
  final String? smsBody;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'is_default')
  final bool isDefault;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @override
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @override
  @JsonKey(name: 'updated_by')
  final String? updatedBy;

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JobNotificationTemplateCopyWith<_JobNotificationTemplate> get copyWith =>
      __$JobNotificationTemplateCopyWithImpl<_JobNotificationTemplate>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JobNotificationTemplateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JobNotificationTemplate &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.triggerType, triggerType) ||
                other.triggerType == triggerType) &&
            (identical(other.recipientType, recipientType) ||
                other.recipientType == recipientType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.emailEnabled, emailEnabled) ||
                other.emailEnabled == emailEnabled) &&
            (identical(other.emailSubject, emailSubject) ||
                other.emailSubject == emailSubject) &&
            (identical(other.emailHtml, emailHtml) ||
                other.emailHtml == emailHtml) &&
            (identical(other.emailPlainText, emailPlainText) ||
                other.emailPlainText == emailPlainText) &&
            (identical(other.smsEnabled, smsEnabled) ||
                other.smsEnabled == smsEnabled) &&
            (identical(other.smsBody, smsBody) || other.smsBody == smsBody) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.updatedBy, updatedBy) ||
                other.updatedBy == updatedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      triggerType,
      recipientType,
      name,
      description,
      emailEnabled,
      emailSubject,
      emailHtml,
      emailPlainText,
      smsEnabled,
      smsBody,
      isActive,
      isDefault,
      createdAt,
      updatedAt,
      createdBy,
      updatedBy);

  @override
  String toString() {
    return 'JobNotificationTemplate(id: $id, triggerType: $triggerType, recipientType: $recipientType, name: $name, description: $description, emailEnabled: $emailEnabled, emailSubject: $emailSubject, emailHtml: $emailHtml, emailPlainText: $emailPlainText, smsEnabled: $smsEnabled, smsBody: $smsBody, isActive: $isActive, isDefault: $isDefault, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy)';
  }
}

/// @nodoc
abstract mixin class _$JobNotificationTemplateCopyWith<$Res>
    implements $JobNotificationTemplateCopyWith<$Res> {
  factory _$JobNotificationTemplateCopyWith(_JobNotificationTemplate value,
          $Res Function(_JobNotificationTemplate) _then) =
      __$JobNotificationTemplateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'trigger_type') String triggerType,
      @JsonKey(name: 'recipient_type') String recipientType,
      String name,
      String? description,
      @JsonKey(name: 'email_enabled') bool emailEnabled,
      @JsonKey(name: 'email_subject') String? emailSubject,
      @JsonKey(name: 'email_html') String? emailHtml,
      @JsonKey(name: 'email_plain_text') String? emailPlainText,
      @JsonKey(name: 'sms_enabled') bool smsEnabled,
      @JsonKey(name: 'sms_body') String? smsBody,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'is_default') bool isDefault,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      @JsonKey(name: 'created_by') String? createdBy,
      @JsonKey(name: 'updated_by') String? updatedBy});
}

/// @nodoc
class __$JobNotificationTemplateCopyWithImpl<$Res>
    implements _$JobNotificationTemplateCopyWith<$Res> {
  __$JobNotificationTemplateCopyWithImpl(this._self, this._then);

  final _JobNotificationTemplate _self;
  final $Res Function(_JobNotificationTemplate) _then;

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? triggerType = null,
    Object? recipientType = null,
    Object? name = null,
    Object? description = freezed,
    Object? emailEnabled = null,
    Object? emailSubject = freezed,
    Object? emailHtml = freezed,
    Object? emailPlainText = freezed,
    Object? smsEnabled = null,
    Object? smsBody = freezed,
    Object? isActive = null,
    Object? isDefault = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? createdBy = freezed,
    Object? updatedBy = freezed,
  }) {
    return _then(_JobNotificationTemplate(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      triggerType: null == triggerType
          ? _self.triggerType
          : triggerType // ignore: cast_nullable_to_non_nullable
              as String,
      recipientType: null == recipientType
          ? _self.recipientType
          : recipientType // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      emailEnabled: null == emailEnabled
          ? _self.emailEnabled
          : emailEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      emailSubject: freezed == emailSubject
          ? _self.emailSubject
          : emailSubject // ignore: cast_nullable_to_non_nullable
              as String?,
      emailHtml: freezed == emailHtml
          ? _self.emailHtml
          : emailHtml // ignore: cast_nullable_to_non_nullable
              as String?,
      emailPlainText: freezed == emailPlainText
          ? _self.emailPlainText
          : emailPlainText // ignore: cast_nullable_to_non_nullable
              as String?,
      smsEnabled: null == smsEnabled
          ? _self.smsEnabled
          : smsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smsBody: freezed == smsBody
          ? _self.smsBody
          : smsBody // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: freezed == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedBy: freezed == updatedBy
          ? _self.updatedBy
          : updatedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
