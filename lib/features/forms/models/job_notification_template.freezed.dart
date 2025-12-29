// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_notification_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

JobNotificationTemplate _$JobNotificationTemplateFromJson(
    Map<String, dynamic> json) {
  return _JobNotificationTemplate.fromJson(json);
}

/// @nodoc
mixin _$JobNotificationTemplate {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'trigger_type')
  String get triggerType => throw _privateConstructorUsedError;
  @JsonKey(name: 'recipient_type')
  String get recipientType => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_enabled')
  bool get emailEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_subject')
  String? get emailSubject => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_html')
  String? get emailHtml => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_plain_text')
  String? get emailPlainText => throw _privateConstructorUsedError;
  @JsonKey(name: 'sms_enabled')
  bool get smsEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'sms_body')
  String? get smsBody => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_default')
  bool get isDefault => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String? get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_by')
  String? get updatedBy => throw _privateConstructorUsedError;

  /// Serializes this JobNotificationTemplate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobNotificationTemplateCopyWith<JobNotificationTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobNotificationTemplateCopyWith<$Res> {
  factory $JobNotificationTemplateCopyWith(JobNotificationTemplate value,
          $Res Function(JobNotificationTemplate) then) =
      _$JobNotificationTemplateCopyWithImpl<$Res, JobNotificationTemplate>;
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
class _$JobNotificationTemplateCopyWithImpl<$Res,
        $Val extends JobNotificationTemplate>
    implements $JobNotificationTemplateCopyWith<$Res> {
  _$JobNotificationTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      triggerType: null == triggerType
          ? _value.triggerType
          : triggerType // ignore: cast_nullable_to_non_nullable
              as String,
      recipientType: null == recipientType
          ? _value.recipientType
          : recipientType // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      emailEnabled: null == emailEnabled
          ? _value.emailEnabled
          : emailEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      emailSubject: freezed == emailSubject
          ? _value.emailSubject
          : emailSubject // ignore: cast_nullable_to_non_nullable
              as String?,
      emailHtml: freezed == emailHtml
          ? _value.emailHtml
          : emailHtml // ignore: cast_nullable_to_non_nullable
              as String?,
      emailPlainText: freezed == emailPlainText
          ? _value.emailPlainText
          : emailPlainText // ignore: cast_nullable_to_non_nullable
              as String?,
      smsEnabled: null == smsEnabled
          ? _value.smsEnabled
          : smsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smsBody: freezed == smsBody
          ? _value.smsBody
          : smsBody // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isDefault: null == isDefault
          ? _value.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedBy: freezed == updatedBy
          ? _value.updatedBy
          : updatedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobNotificationTemplateImplCopyWith<$Res>
    implements $JobNotificationTemplateCopyWith<$Res> {
  factory _$$JobNotificationTemplateImplCopyWith(
          _$JobNotificationTemplateImpl value,
          $Res Function(_$JobNotificationTemplateImpl) then) =
      __$$JobNotificationTemplateImplCopyWithImpl<$Res>;
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
class __$$JobNotificationTemplateImplCopyWithImpl<$Res>
    extends _$JobNotificationTemplateCopyWithImpl<$Res,
        _$JobNotificationTemplateImpl>
    implements _$$JobNotificationTemplateImplCopyWith<$Res> {
  __$$JobNotificationTemplateImplCopyWithImpl(
      _$JobNotificationTemplateImpl _value,
      $Res Function(_$JobNotificationTemplateImpl) _then)
      : super(_value, _then);

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
    return _then(_$JobNotificationTemplateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      triggerType: null == triggerType
          ? _value.triggerType
          : triggerType // ignore: cast_nullable_to_non_nullable
              as String,
      recipientType: null == recipientType
          ? _value.recipientType
          : recipientType // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      emailEnabled: null == emailEnabled
          ? _value.emailEnabled
          : emailEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      emailSubject: freezed == emailSubject
          ? _value.emailSubject
          : emailSubject // ignore: cast_nullable_to_non_nullable
              as String?,
      emailHtml: freezed == emailHtml
          ? _value.emailHtml
          : emailHtml // ignore: cast_nullable_to_non_nullable
              as String?,
      emailPlainText: freezed == emailPlainText
          ? _value.emailPlainText
          : emailPlainText // ignore: cast_nullable_to_non_nullable
              as String?,
      smsEnabled: null == smsEnabled
          ? _value.smsEnabled
          : smsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smsBody: freezed == smsBody
          ? _value.smsBody
          : smsBody // ignore: cast_nullable_to_non_nullable
              as String?,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isDefault: null == isDefault
          ? _value.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      updatedBy: freezed == updatedBy
          ? _value.updatedBy
          : updatedBy // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobNotificationTemplateImpl extends _JobNotificationTemplate {
  const _$JobNotificationTemplateImpl(
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

  factory _$JobNotificationTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobNotificationTemplateImplFromJson(json);

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

  @override
  String toString() {
    return 'JobNotificationTemplate(id: $id, triggerType: $triggerType, recipientType: $recipientType, name: $name, description: $description, emailEnabled: $emailEnabled, emailSubject: $emailSubject, emailHtml: $emailHtml, emailPlainText: $emailPlainText, smsEnabled: $smsEnabled, smsBody: $smsBody, isActive: $isActive, isDefault: $isDefault, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, updatedBy: $updatedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobNotificationTemplateImpl &&
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

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobNotificationTemplateImplCopyWith<_$JobNotificationTemplateImpl>
      get copyWith => __$$JobNotificationTemplateImplCopyWithImpl<
          _$JobNotificationTemplateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobNotificationTemplateImplToJson(
      this,
    );
  }
}

abstract class _JobNotificationTemplate extends JobNotificationTemplate {
  const factory _JobNotificationTemplate(
          {required final String id,
          @JsonKey(name: 'trigger_type') required final String triggerType,
          @JsonKey(name: 'recipient_type') required final String recipientType,
          required final String name,
          final String? description,
          @JsonKey(name: 'email_enabled') final bool emailEnabled,
          @JsonKey(name: 'email_subject') final String? emailSubject,
          @JsonKey(name: 'email_html') final String? emailHtml,
          @JsonKey(name: 'email_plain_text') final String? emailPlainText,
          @JsonKey(name: 'sms_enabled') final bool smsEnabled,
          @JsonKey(name: 'sms_body') final String? smsBody,
          @JsonKey(name: 'is_active') final bool isActive,
          @JsonKey(name: 'is_default') final bool isDefault,
          @JsonKey(name: 'created_at') final DateTime? createdAt,
          @JsonKey(name: 'updated_at') final DateTime? updatedAt,
          @JsonKey(name: 'created_by') final String? createdBy,
          @JsonKey(name: 'updated_by') final String? updatedBy}) =
      _$JobNotificationTemplateImpl;
  const _JobNotificationTemplate._() : super._();

  factory _JobNotificationTemplate.fromJson(Map<String, dynamic> json) =
      _$JobNotificationTemplateImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'trigger_type')
  String get triggerType;
  @override
  @JsonKey(name: 'recipient_type')
  String get recipientType;
  @override
  String get name;
  @override
  String? get description;
  @override
  @JsonKey(name: 'email_enabled')
  bool get emailEnabled;
  @override
  @JsonKey(name: 'email_subject')
  String? get emailSubject;
  @override
  @JsonKey(name: 'email_html')
  String? get emailHtml;
  @override
  @JsonKey(name: 'email_plain_text')
  String? get emailPlainText;
  @override
  @JsonKey(name: 'sms_enabled')
  bool get smsEnabled;
  @override
  @JsonKey(name: 'sms_body')
  String? get smsBody;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'is_default')
  bool get isDefault;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;
  @override
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @override
  @JsonKey(name: 'updated_by')
  String? get updatedBy;

  /// Create a copy of JobNotificationTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobNotificationTemplateImplCopyWith<_$JobNotificationTemplateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
