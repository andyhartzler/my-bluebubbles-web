// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CustomQuestion _$CustomQuestionFromJson(Map<String, dynamic> json) {
  return _CustomQuestion.fromJson(json);
}

/// @nodoc
mixin _$CustomQuestion {
  String get id => throw _privateConstructorUsedError;
  String get question => throw _privateConstructorUsedError;
  CustomQuestionType get type => throw _privateConstructorUsedError;
  bool get required => throw _privateConstructorUsedError;
  List<String> get options => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CustomQuestionCopyWith<CustomQuestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CustomQuestionCopyWith<$Res> {
  factory $CustomQuestionCopyWith(
          CustomQuestion value, $Res Function(CustomQuestion) then) =
      _$CustomQuestionCopyWithImpl<$Res, CustomQuestion>;
  @useResult
  $Res call(
      {String id,
      String question,
      CustomQuestionType type,
      bool required,
      List<String> options,
      int order});
}

/// @nodoc
class _$CustomQuestionCopyWithImpl<$Res, $Val extends CustomQuestion>
    implements $CustomQuestionCopyWith<$Res> {
  _$CustomQuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? question = null,
    Object? type = null,
    Object? required = null,
    Object? options = null,
    Object? order = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as CustomQuestionType,
      required: null == required
          ? _value.required
          : required // ignore: cast_nullable_to_non_nullable
              as bool,
      options: null == options
          ? _value.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>,
      order: null == order
          ? _value.order
          : order // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CustomQuestionImplCopyWith<$Res>
    implements $CustomQuestionCopyWith<$Res> {
  factory _$$CustomQuestionImplCopyWith(_$CustomQuestionImpl value,
          $Res Function(_$CustomQuestionImpl) then) =
      __$$CustomQuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String question,
      CustomQuestionType type,
      bool required,
      List<String> options,
      int order});
}

/// @nodoc
class __$$CustomQuestionImplCopyWithImpl<$Res>
    extends _$CustomQuestionCopyWithImpl<$Res, _$CustomQuestionImpl>
    implements _$$CustomQuestionImplCopyWith<$Res> {
  __$$CustomQuestionImplCopyWithImpl(
      _$CustomQuestionImpl _value, $Res Function(_$CustomQuestionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? question = null,
    Object? type = null,
    Object? required = null,
    Object? options = null,
    Object? order = null,
  }) {
    return _then(_$CustomQuestionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      question: null == question
          ? _value.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as CustomQuestionType,
      required: null == required
          ? _value.required
          : required // ignore: cast_nullable_to_non_nullable
              as bool,
      options: null == options
          ? _value._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>,
      order: null == order
          ? _value.order
          : order // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CustomQuestionImpl implements _CustomQuestion {
  const _$CustomQuestionImpl(
      {required this.id,
      required this.question,
      this.type = CustomQuestionType.text,
      this.required = false,
      final List<String> options = const [],
      this.order = 0})
      : _options = options;

  factory _$CustomQuestionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CustomQuestionImplFromJson(json);

  @override
  final String id;
  @override
  final String question;
  @override
  @JsonKey()
  final CustomQuestionType type;
  @override
  @JsonKey()
  final bool required;
  final List<String> _options;
  @override
  @JsonKey()
  List<String> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  @JsonKey()
  final int order;

  @override
  String toString() {
    return 'CustomQuestion(id: $id, question: $question, type: $type, required: $required, options: $options, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CustomQuestionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.required, required) ||
                other.required == required) &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.order, order) || other.order == order));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, question, type, required,
      const DeepCollectionEquality().hash(_options), order);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CustomQuestionImplCopyWith<_$CustomQuestionImpl> get copyWith =>
      __$$CustomQuestionImplCopyWithImpl<_$CustomQuestionImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CustomQuestionImplToJson(
      this,
    );
  }
}

abstract class _CustomQuestion implements CustomQuestion {
  const factory _CustomQuestion(
      {required final String id,
      required final String question,
      final CustomQuestionType type,
      final bool required,
      final List<String> options,
      final int order}) = _$CustomQuestionImpl;

  factory _CustomQuestion.fromJson(Map<String, dynamic> json) =
      _$CustomQuestionImpl.fromJson;

  @override
  String get id;
  @override
  String get question;
  @override
  CustomQuestionType get type;
  @override
  bool get required;
  @override
  List<String> get options;
  @override
  int get order;
  @override
  @JsonKey(ignore: true)
  _$$CustomQuestionImplCopyWith<_$CustomQuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Job _$JobFromJson(Map<String, dynamic> json) {
  return _Job.fromJson(json);
}

/// @nodoc
mixin _$Job {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get organization => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'job_type')
  String get jobType => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_type')
  String? get locationType => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_paid')
  bool get isPaid => throw _privateConstructorUsedError;
  @JsonKey(name: 'salary_range')
  String? get salaryRange => throw _privateConstructorUsedError;
  @JsonKey(name: 'hourly_rate')
  String? get hourlyRate => throw _privateConstructorUsedError;
  String? get requirements => throw _privateConstructorUsedError;
  String? get qualifications => throw _privateConstructorUsedError;
  @JsonKey(name: 'contact_email')
  String get contactEmail => throw _privateConstructorUsedError;
  @JsonKey(name: 'contact_name')
  String? get contactName => throw _privateConstructorUsedError;
  @JsonKey(name: 'contact_phone')
  String? get contactPhone => throw _privateConstructorUsedError;
  @JsonKey(name: 'application_url')
  String? get applicationUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'application_instructions')
  String? get applicationInstructions => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'approved_at')
  DateTime? get approvedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'approved_by')
  String? get approvedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'rejection_reason')
  String? get rejectionReason => throw _privateConstructorUsedError;
  @JsonKey(name: 'submitter_name')
  String get submitterName => throw _privateConstructorUsedError;
  @JsonKey(name: 'submitter_email')
  String get submitterEmail => throw _privateConstructorUsedError;
  @JsonKey(name: 'submitter_organization')
  String? get submitterOrganization => throw _privateConstructorUsedError;
  @JsonKey(name: 'submitter_phone')
  String? get submitterPhone => throw _privateConstructorUsedError;
  String? get slug => throw _privateConstructorUsedError;
  bool get featured => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'application_count')
  int get applicationCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'view_count')
  int get viewCount => throw _privateConstructorUsedError;
  @JsonKey(
      name: 'custom_questions',
      fromJson: _customQuestionsFromJson,
      toJson: _customQuestionsToJson)
  List<CustomQuestion> get customQuestions =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'resume_enabled')
  bool? get resumeEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'resume_required')
  bool? get resumeRequired => throw _privateConstructorUsedError;
  @JsonKey(name: 'cover_letter_enabled')
  bool? get coverLetterEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'cover_letter_required')
  bool? get coverLetterRequired => throw _privateConstructorUsedError;
  @JsonKey(name: 'references_enabled')
  bool get referencesEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'references_required')
  bool get referencesRequired => throw _privateConstructorUsedError;
  @JsonKey(name: 'references_count')
  int get referencesCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'use_external_apply')
  bool get useExternalApply => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $JobCopyWith<Job> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobCopyWith<$Res> {
  factory $JobCopyWith(Job value, $Res Function(Job) then) =
      _$JobCopyWithImpl<$Res, Job>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      String title,
      String organization,
      String description,
      @JsonKey(name: 'job_type') String jobType,
      String? location,
      @JsonKey(name: 'location_type') String? locationType,
      @JsonKey(name: 'is_paid') bool isPaid,
      @JsonKey(name: 'salary_range') String? salaryRange,
      @JsonKey(name: 'hourly_rate') String? hourlyRate,
      String? requirements,
      String? qualifications,
      @JsonKey(name: 'contact_email') String contactEmail,
      @JsonKey(name: 'contact_name') String? contactName,
      @JsonKey(name: 'contact_phone') String? contactPhone,
      @JsonKey(name: 'application_url') String? applicationUrl,
      @JsonKey(name: 'application_instructions') String? applicationInstructions,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      String status,
      @JsonKey(name: 'approved_at') DateTime? approvedAt,
      @JsonKey(name: 'approved_by') String? approvedBy,
      @JsonKey(name: 'rejection_reason') String? rejectionReason,
      @JsonKey(name: 'submitter_name') String submitterName,
      @JsonKey(name: 'submitter_email') String submitterEmail,
      @JsonKey(name: 'submitter_organization') String? submitterOrganization,
      @JsonKey(name: 'submitter_phone') String? submitterPhone,
      String? slug,
      bool featured,
      List<String>? tags,
      @JsonKey(name: 'application_count') int applicationCount,
      @JsonKey(name: 'view_count') int viewCount,
      @JsonKey(name: 'custom_questions', fromJson: _customQuestionsFromJson, toJson: _customQuestionsToJson)
      List<CustomQuestion> customQuestions,
      @JsonKey(name: 'resume_enabled') bool? resumeEnabled,
      @JsonKey(name: 'resume_required') bool? resumeRequired,
      @JsonKey(name: 'cover_letter_enabled') bool? coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required') bool? coverLetterRequired,
      @JsonKey(name: 'references_enabled') bool referencesEnabled,
      @JsonKey(name: 'references_required') bool referencesRequired,
      @JsonKey(name: 'references_count') int referencesCount,
      @JsonKey(name: 'use_external_apply') bool useExternalApply});
}

/// @nodoc
class _$JobCopyWithImpl<$Res, $Val extends Job> implements $JobCopyWith<$Res> {
  _$JobCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? title = null,
    Object? organization = null,
    Object? description = null,
    Object? jobType = null,
    Object? location = freezed,
    Object? locationType = freezed,
    Object? isPaid = null,
    Object? salaryRange = freezed,
    Object? hourlyRate = freezed,
    Object? requirements = freezed,
    Object? qualifications = freezed,
    Object? contactEmail = null,
    Object? contactName = freezed,
    Object? contactPhone = freezed,
    Object? applicationUrl = freezed,
    Object? applicationInstructions = freezed,
    Object? expiresAt = freezed,
    Object? status = null,
    Object? approvedAt = freezed,
    Object? approvedBy = freezed,
    Object? rejectionReason = freezed,
    Object? submitterName = null,
    Object? submitterEmail = null,
    Object? submitterOrganization = freezed,
    Object? submitterPhone = freezed,
    Object? slug = freezed,
    Object? featured = null,
    Object? tags = freezed,
    Object? applicationCount = null,
    Object? viewCount = null,
    Object? customQuestions = null,
    Object? resumeEnabled = freezed,
    Object? resumeRequired = freezed,
    Object? coverLetterEnabled = freezed,
    Object? coverLetterRequired = freezed,
    Object? referencesEnabled = null,
    Object? referencesRequired = null,
    Object? referencesCount = null,
    Object? useExternalApply = null,
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
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      organization: null == organization
          ? _value.organization
          : organization // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      jobType: null == jobType
          ? _value.jobType
          : jobType // ignore: cast_nullable_to_non_nullable
              as String,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      locationType: freezed == locationType
          ? _value.locationType
          : locationType // ignore: cast_nullable_to_non_nullable
              as String?,
      isPaid: null == isPaid
          ? _value.isPaid
          : isPaid // ignore: cast_nullable_to_non_nullable
              as bool,
      salaryRange: freezed == salaryRange
          ? _value.salaryRange
          : salaryRange // ignore: cast_nullable_to_non_nullable
              as String?,
      hourlyRate: freezed == hourlyRate
          ? _value.hourlyRate
          : hourlyRate // ignore: cast_nullable_to_non_nullable
              as String?,
      requirements: freezed == requirements
          ? _value.requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as String?,
      qualifications: freezed == qualifications
          ? _value.qualifications
          : qualifications // ignore: cast_nullable_to_non_nullable
              as String?,
      contactEmail: null == contactEmail
          ? _value.contactEmail
          : contactEmail // ignore: cast_nullable_to_non_nullable
              as String,
      contactName: freezed == contactName
          ? _value.contactName
          : contactName // ignore: cast_nullable_to_non_nullable
              as String?,
      contactPhone: freezed == contactPhone
          ? _value.contactPhone
          : contactPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationUrl: freezed == applicationUrl
          ? _value.applicationUrl
          : applicationUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationInstructions: freezed == applicationInstructions
          ? _value.applicationInstructions
          : applicationInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      approvedAt: freezed == approvedAt
          ? _value.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      approvedBy: freezed == approvedBy
          ? _value.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      rejectionReason: freezed == rejectionReason
          ? _value.rejectionReason
          : rejectionReason // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterName: null == submitterName
          ? _value.submitterName
          : submitterName // ignore: cast_nullable_to_non_nullable
              as String,
      submitterEmail: null == submitterEmail
          ? _value.submitterEmail
          : submitterEmail // ignore: cast_nullable_to_non_nullable
              as String,
      submitterOrganization: freezed == submitterOrganization
          ? _value.submitterOrganization
          : submitterOrganization // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterPhone: freezed == submitterPhone
          ? _value.submitterPhone
          : submitterPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      slug: freezed == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      featured: null == featured
          ? _value.featured
          : featured // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      applicationCount: null == applicationCount
          ? _value.applicationCount
          : applicationCount // ignore: cast_nullable_to_non_nullable
              as int,
      viewCount: null == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      customQuestions: null == customQuestions
          ? _value.customQuestions
          : customQuestions // ignore: cast_nullable_to_non_nullable
              as List<CustomQuestion>,
      resumeEnabled: freezed == resumeEnabled
          ? _value.resumeEnabled
          : resumeEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      resumeRequired: freezed == resumeRequired
          ? _value.resumeRequired
          : resumeRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterEnabled: freezed == coverLetterEnabled
          ? _value.coverLetterEnabled
          : coverLetterEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterRequired: freezed == coverLetterRequired
          ? _value.coverLetterRequired
          : coverLetterRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      referencesEnabled: null == referencesEnabled
          ? _value.referencesEnabled
          : referencesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesRequired: null == referencesRequired
          ? _value.referencesRequired
          : referencesRequired // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesCount: null == referencesCount
          ? _value.referencesCount
          : referencesCount // ignore: cast_nullable_to_non_nullable
              as int,
      useExternalApply: null == useExternalApply
          ? _value.useExternalApply
          : useExternalApply // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobImplCopyWith<$Res> implements $JobCopyWith<$Res> {
  factory _$$JobImplCopyWith(_$JobImpl value, $Res Function(_$JobImpl) then) =
      __$$JobImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      String title,
      String organization,
      String description,
      @JsonKey(name: 'job_type') String jobType,
      String? location,
      @JsonKey(name: 'location_type') String? locationType,
      @JsonKey(name: 'is_paid') bool isPaid,
      @JsonKey(name: 'salary_range') String? salaryRange,
      @JsonKey(name: 'hourly_rate') String? hourlyRate,
      String? requirements,
      String? qualifications,
      @JsonKey(name: 'contact_email') String contactEmail,
      @JsonKey(name: 'contact_name') String? contactName,
      @JsonKey(name: 'contact_phone') String? contactPhone,
      @JsonKey(name: 'application_url') String? applicationUrl,
      @JsonKey(name: 'application_instructions') String? applicationInstructions,
      @JsonKey(name: 'expires_at') DateTime? expiresAt,
      String status,
      @JsonKey(name: 'approved_at') DateTime? approvedAt,
      @JsonKey(name: 'approved_by') String? approvedBy,
      @JsonKey(name: 'rejection_reason') String? rejectionReason,
      @JsonKey(name: 'submitter_name') String submitterName,
      @JsonKey(name: 'submitter_email') String submitterEmail,
      @JsonKey(name: 'submitter_organization') String? submitterOrganization,
      @JsonKey(name: 'submitter_phone') String? submitterPhone,
      String? slug,
      bool featured,
      List<String>? tags,
      @JsonKey(name: 'application_count') int applicationCount,
      @JsonKey(name: 'view_count') int viewCount,
      @JsonKey(name: 'custom_questions', fromJson: _customQuestionsFromJson, toJson: _customQuestionsToJson)
      List<CustomQuestion> customQuestions,
      @JsonKey(name: 'resume_enabled') bool? resumeEnabled,
      @JsonKey(name: 'resume_required') bool? resumeRequired,
      @JsonKey(name: 'cover_letter_enabled') bool? coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required') bool? coverLetterRequired,
      @JsonKey(name: 'references_enabled') bool referencesEnabled,
      @JsonKey(name: 'references_required') bool referencesRequired,
      @JsonKey(name: 'references_count') int referencesCount,
      @JsonKey(name: 'use_external_apply') bool useExternalApply});
}

/// @nodoc
class __$$JobImplCopyWithImpl<$Res> extends _$JobCopyWithImpl<$Res, _$JobImpl>
    implements _$$JobImplCopyWith<$Res> {
  __$$JobImplCopyWithImpl(_$JobImpl _value, $Res Function(_$JobImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? title = null,
    Object? organization = null,
    Object? description = null,
    Object? jobType = null,
    Object? location = freezed,
    Object? locationType = freezed,
    Object? isPaid = null,
    Object? salaryRange = freezed,
    Object? hourlyRate = freezed,
    Object? requirements = freezed,
    Object? qualifications = freezed,
    Object? contactEmail = null,
    Object? contactName = freezed,
    Object? contactPhone = freezed,
    Object? applicationUrl = freezed,
    Object? applicationInstructions = freezed,
    Object? expiresAt = freezed,
    Object? status = null,
    Object? approvedAt = freezed,
    Object? approvedBy = freezed,
    Object? rejectionReason = freezed,
    Object? submitterName = null,
    Object? submitterEmail = null,
    Object? submitterOrganization = freezed,
    Object? submitterPhone = freezed,
    Object? slug = freezed,
    Object? featured = null,
    Object? tags = freezed,
    Object? applicationCount = null,
    Object? viewCount = null,
    Object? customQuestions = null,
    Object? resumeEnabled = freezed,
    Object? resumeRequired = freezed,
    Object? coverLetterEnabled = freezed,
    Object? coverLetterRequired = freezed,
    Object? referencesEnabled = null,
    Object? referencesRequired = null,
    Object? referencesCount = null,
    Object? useExternalApply = null,
  }) {
    return _then(_$JobImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      organization: null == organization
          ? _value.organization
          : organization // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      jobType: null == jobType
          ? _value.jobType
          : jobType // ignore: cast_nullable_to_non_nullable
              as String,
      location: freezed == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      locationType: freezed == locationType
          ? _value.locationType
          : locationType // ignore: cast_nullable_to_non_nullable
              as String?,
      isPaid: null == isPaid
          ? _value.isPaid
          : isPaid // ignore: cast_nullable_to_non_nullable
              as bool,
      salaryRange: freezed == salaryRange
          ? _value.salaryRange
          : salaryRange // ignore: cast_nullable_to_non_nullable
              as String?,
      hourlyRate: freezed == hourlyRate
          ? _value.hourlyRate
          : hourlyRate // ignore: cast_nullable_to_non_nullable
              as String?,
      requirements: freezed == requirements
          ? _value.requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as String?,
      qualifications: freezed == qualifications
          ? _value.qualifications
          : qualifications // ignore: cast_nullable_to_non_nullable
              as String?,
      contactEmail: null == contactEmail
          ? _value.contactEmail
          : contactEmail // ignore: cast_nullable_to_non_nullable
              as String,
      contactName: freezed == contactName
          ? _value.contactName
          : contactName // ignore: cast_nullable_to_non_nullable
              as String?,
      contactPhone: freezed == contactPhone
          ? _value.contactPhone
          : contactPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationUrl: freezed == applicationUrl
          ? _value.applicationUrl
          : applicationUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationInstructions: freezed == applicationInstructions
          ? _value.applicationInstructions
          : applicationInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      approvedAt: freezed == approvedAt
          ? _value.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      approvedBy: freezed == approvedBy
          ? _value.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      rejectionReason: freezed == rejectionReason
          ? _value.rejectionReason
          : rejectionReason // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterName: null == submitterName
          ? _value.submitterName
          : submitterName // ignore: cast_nullable_to_non_nullable
              as String,
      submitterEmail: null == submitterEmail
          ? _value.submitterEmail
          : submitterEmail // ignore: cast_nullable_to_non_nullable
              as String,
      submitterOrganization: freezed == submitterOrganization
          ? _value.submitterOrganization
          : submitterOrganization // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterPhone: freezed == submitterPhone
          ? _value.submitterPhone
          : submitterPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      slug: freezed == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      featured: null == featured
          ? _value.featured
          : featured // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      applicationCount: null == applicationCount
          ? _value.applicationCount
          : applicationCount // ignore: cast_nullable_to_non_nullable
              as int,
      viewCount: null == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      customQuestions: null == customQuestions
          ? _value._customQuestions
          : customQuestions // ignore: cast_nullable_to_non_nullable
              as List<CustomQuestion>,
      resumeEnabled: freezed == resumeEnabled
          ? _value.resumeEnabled
          : resumeEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      resumeRequired: freezed == resumeRequired
          ? _value.resumeRequired
          : resumeRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterEnabled: freezed == coverLetterEnabled
          ? _value.coverLetterEnabled
          : coverLetterEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterRequired: freezed == coverLetterRequired
          ? _value.coverLetterRequired
          : coverLetterRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      referencesEnabled: null == referencesEnabled
          ? _value.referencesEnabled
          : referencesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesRequired: null == referencesRequired
          ? _value.referencesRequired
          : referencesRequired // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesCount: null == referencesCount
          ? _value.referencesCount
          : referencesCount // ignore: cast_nullable_to_non_nullable
              as int,
      useExternalApply: null == useExternalApply
          ? _value.useExternalApply
          : useExternalApply // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobImpl implements _Job {
  const _$JobImpl(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      required this.title,
      required this.organization,
      required this.description,
      @JsonKey(name: 'job_type') required this.jobType,
      this.location,
      @JsonKey(name: 'location_type') this.locationType,
      @JsonKey(name: 'is_paid') this.isPaid = false,
      @JsonKey(name: 'salary_range') this.salaryRange,
      @JsonKey(name: 'hourly_rate') this.hourlyRate,
      this.requirements,
      this.qualifications,
      @JsonKey(name: 'contact_email') required this.contactEmail,
      @JsonKey(name: 'contact_name') this.contactName,
      @JsonKey(name: 'contact_phone') this.contactPhone,
      @JsonKey(name: 'application_url') this.applicationUrl,
      @JsonKey(name: 'application_instructions') this.applicationInstructions,
      @JsonKey(name: 'expires_at') this.expiresAt,
      this.status = 'pending',
      @JsonKey(name: 'approved_at') this.approvedAt,
      @JsonKey(name: 'approved_by') this.approvedBy,
      @JsonKey(name: 'rejection_reason') this.rejectionReason,
      @JsonKey(name: 'submitter_name') required this.submitterName,
      @JsonKey(name: 'submitter_email') required this.submitterEmail,
      @JsonKey(name: 'submitter_organization') this.submitterOrganization,
      @JsonKey(name: 'submitter_phone') this.submitterPhone,
      this.slug,
      this.featured = false,
      final List<String>? tags,
      @JsonKey(name: 'application_count') this.applicationCount = 0,
      @JsonKey(name: 'view_count') this.viewCount = 0,
      @JsonKey(name: 'custom_questions', fromJson: _customQuestionsFromJson, toJson: _customQuestionsToJson)
      final List<CustomQuestion> customQuestions = const [],
      @JsonKey(name: 'resume_enabled') this.resumeEnabled,
      @JsonKey(name: 'resume_required') this.resumeRequired,
      @JsonKey(name: 'cover_letter_enabled') this.coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required') this.coverLetterRequired,
      @JsonKey(name: 'references_enabled') this.referencesEnabled = false,
      @JsonKey(name: 'references_required') this.referencesRequired = false,
      @JsonKey(name: 'references_count') this.referencesCount = 2,
      @JsonKey(name: 'use_external_apply') this.useExternalApply = false})
      : _tags = tags,
        _customQuestions = customQuestions;

  factory _$JobImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  final String title;
  @override
  final String organization;
  @override
  final String description;
  @override
  @JsonKey(name: 'job_type')
  final String jobType;
  @override
  final String? location;
  @override
  @JsonKey(name: 'location_type')
  final String? locationType;
  @override
  @JsonKey(name: 'is_paid')
  final bool isPaid;
  @override
  @JsonKey(name: 'salary_range')
  final String? salaryRange;
  @override
  @JsonKey(name: 'hourly_rate')
  final String? hourlyRate;
  @override
  final String? requirements;
  @override
  final String? qualifications;
  @override
  @JsonKey(name: 'contact_email')
  final String contactEmail;
  @override
  @JsonKey(name: 'contact_name')
  final String? contactName;
  @override
  @JsonKey(name: 'contact_phone')
  final String? contactPhone;
  @override
  @JsonKey(name: 'application_url')
  final String? applicationUrl;
  @override
  @JsonKey(name: 'application_instructions')
  final String? applicationInstructions;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'approved_at')
  final DateTime? approvedAt;
  @override
  @JsonKey(name: 'approved_by')
  final String? approvedBy;
  @override
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;
  @override
  @JsonKey(name: 'submitter_name')
  final String submitterName;
  @override
  @JsonKey(name: 'submitter_email')
  final String submitterEmail;
  @override
  @JsonKey(name: 'submitter_organization')
  final String? submitterOrganization;
  @override
  @JsonKey(name: 'submitter_phone')
  final String? submitterPhone;
  @override
  final String? slug;
  @override
  @JsonKey()
  final bool featured;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'application_count')
  final int applicationCount;
  @override
  @JsonKey(name: 'view_count')
  final int viewCount;
  final List<CustomQuestion> _customQuestions;
  @override
  @JsonKey(
      name: 'custom_questions',
      fromJson: _customQuestionsFromJson,
      toJson: _customQuestionsToJson)
  List<CustomQuestion> get customQuestions {
    if (_customQuestions is EqualUnmodifiableListView) return _customQuestions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customQuestions);
  }

  @override
  @JsonKey(name: 'resume_enabled')
  final bool? resumeEnabled;
  @override
  @JsonKey(name: 'resume_required')
  final bool? resumeRequired;
  @override
  @JsonKey(name: 'cover_letter_enabled')
  final bool? coverLetterEnabled;
  @override
  @JsonKey(name: 'cover_letter_required')
  final bool? coverLetterRequired;
  @override
  @JsonKey(name: 'references_enabled')
  final bool referencesEnabled;
  @override
  @JsonKey(name: 'references_required')
  final bool referencesRequired;
  @override
  @JsonKey(name: 'references_count')
  final int referencesCount;
  @override
  @JsonKey(name: 'use_external_apply')
  final bool useExternalApply;

  @override
  String toString() {
    return 'Job(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, title: $title, organization: $organization, description: $description, jobType: $jobType, location: $location, locationType: $locationType, isPaid: $isPaid, salaryRange: $salaryRange, hourlyRate: $hourlyRate, requirements: $requirements, qualifications: $qualifications, contactEmail: $contactEmail, contactName: $contactName, contactPhone: $contactPhone, applicationUrl: $applicationUrl, applicationInstructions: $applicationInstructions, expiresAt: $expiresAt, status: $status, approvedAt: $approvedAt, approvedBy: $approvedBy, rejectionReason: $rejectionReason, submitterName: $submitterName, submitterEmail: $submitterEmail, submitterOrganization: $submitterOrganization, submitterPhone: $submitterPhone, slug: $slug, featured: $featured, tags: $tags, applicationCount: $applicationCount, viewCount: $viewCount, customQuestions: $customQuestions, resumeEnabled: $resumeEnabled, resumeRequired: $resumeRequired, coverLetterEnabled: $coverLetterEnabled, coverLetterRequired: $coverLetterRequired, referencesEnabled: $referencesEnabled, referencesRequired: $referencesRequired, referencesCount: $referencesCount, useExternalApply: $useExternalApply)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.organization, organization) ||
                other.organization == organization) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.jobType, jobType) || other.jobType == jobType) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.locationType, locationType) ||
                other.locationType == locationType) &&
            (identical(other.isPaid, isPaid) || other.isPaid == isPaid) &&
            (identical(other.salaryRange, salaryRange) ||
                other.salaryRange == salaryRange) &&
            (identical(other.hourlyRate, hourlyRate) ||
                other.hourlyRate == hourlyRate) &&
            (identical(other.requirements, requirements) ||
                other.requirements == requirements) &&
            (identical(other.qualifications, qualifications) ||
                other.qualifications == qualifications) &&
            (identical(other.contactEmail, contactEmail) ||
                other.contactEmail == contactEmail) &&
            (identical(other.contactName, contactName) ||
                other.contactName == contactName) &&
            (identical(other.contactPhone, contactPhone) ||
                other.contactPhone == contactPhone) &&
            (identical(other.applicationUrl, applicationUrl) ||
                other.applicationUrl == applicationUrl) &&
            (identical(other.applicationInstructions, applicationInstructions) ||
                other.applicationInstructions == applicationInstructions) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.approvedAt, approvedAt) ||
                other.approvedAt == approvedAt) &&
            (identical(other.approvedBy, approvedBy) ||
                other.approvedBy == approvedBy) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason) &&
            (identical(other.submitterName, submitterName) ||
                other.submitterName == submitterName) &&
            (identical(other.submitterEmail, submitterEmail) ||
                other.submitterEmail == submitterEmail) &&
            (identical(other.submitterOrganization, submitterOrganization) ||
                other.submitterOrganization == submitterOrganization) &&
            (identical(other.submitterPhone, submitterPhone) ||
                other.submitterPhone == submitterPhone) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.featured, featured) ||
                other.featured == featured) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.applicationCount, applicationCount) ||
                other.applicationCount == applicationCount) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            const DeepCollectionEquality()
                .equals(other._customQuestions, _customQuestions) &&
            (identical(other.resumeEnabled, resumeEnabled) ||
                other.resumeEnabled == resumeEnabled) &&
            (identical(other.resumeRequired, resumeRequired) ||
                other.resumeRequired == resumeRequired) &&
            (identical(other.coverLetterEnabled, coverLetterEnabled) ||
                other.coverLetterEnabled == coverLetterEnabled) &&
            (identical(other.coverLetterRequired, coverLetterRequired) ||
                other.coverLetterRequired == coverLetterRequired) &&
            (identical(other.referencesEnabled, referencesEnabled) ||
                other.referencesEnabled == referencesEnabled) &&
            (identical(other.referencesRequired, referencesRequired) ||
                other.referencesRequired == referencesRequired) &&
            (identical(other.referencesCount, referencesCount) ||
                other.referencesCount == referencesCount) &&
            (identical(other.useExternalApply, useExternalApply) ||
                other.useExternalApply == useExternalApply));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        createdAt,
        updatedAt,
        title,
        organization,
        description,
        jobType,
        location,
        locationType,
        isPaid,
        salaryRange,
        hourlyRate,
        requirements,
        qualifications,
        contactEmail,
        contactName,
        contactPhone,
        applicationUrl,
        applicationInstructions,
        expiresAt,
        status,
        approvedAt,
        approvedBy,
        rejectionReason,
        submitterName,
        submitterEmail,
        submitterOrganization,
        submitterPhone,
        slug,
        featured,
        const DeepCollectionEquality().hash(_tags),
        applicationCount,
        viewCount,
        const DeepCollectionEquality().hash(_customQuestions),
        resumeEnabled,
        resumeRequired,
        coverLetterEnabled,
        coverLetterRequired,
        referencesEnabled,
        referencesRequired,
        referencesCount,
        useExternalApply,
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$JobImplCopyWith<_$JobImpl> get copyWith =>
      __$$JobImplCopyWithImpl<_$JobImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobImplToJson(
      this,
    );
  }
}

abstract class _Job implements Job {
  const factory _Job(
      {required final String id,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'updated_at') required final DateTime updatedAt,
      required final String title,
      required final String organization,
      required final String description,
      @JsonKey(name: 'job_type') required final String jobType,
      final String? location,
      @JsonKey(name: 'location_type') final String? locationType,
      @JsonKey(name: 'is_paid') final bool isPaid,
      @JsonKey(name: 'salary_range') final String? salaryRange,
      @JsonKey(name: 'hourly_rate') final String? hourlyRate,
      final String? requirements,
      final String? qualifications,
      @JsonKey(name: 'contact_email') required final String contactEmail,
      @JsonKey(name: 'contact_name') final String? contactName,
      @JsonKey(name: 'contact_phone') final String? contactPhone,
      @JsonKey(name: 'application_url') final String? applicationUrl,
      @JsonKey(name: 'application_instructions')
      final String? applicationInstructions,
      @JsonKey(name: 'expires_at') final DateTime? expiresAt,
      final String status,
      @JsonKey(name: 'approved_at') final DateTime? approvedAt,
      @JsonKey(name: 'approved_by') final String? approvedBy,
      @JsonKey(name: 'rejection_reason') final String? rejectionReason,
      @JsonKey(name: 'submitter_name') required final String submitterName,
      @JsonKey(name: 'submitter_email') required final String submitterEmail,
      @JsonKey(name: 'submitter_organization')
      final String? submitterOrganization,
      @JsonKey(name: 'submitter_phone') final String? submitterPhone,
      final String? slug,
      final bool featured,
      final List<String>? tags,
      @JsonKey(name: 'application_count') final int applicationCount,
      @JsonKey(name: 'view_count') final int viewCount,
      @JsonKey(name: 'custom_questions', fromJson: _customQuestionsFromJson, toJson: _customQuestionsToJson)
      final List<CustomQuestion> customQuestions,
      @JsonKey(name: 'resume_enabled') final bool? resumeEnabled,
      @JsonKey(name: 'resume_required') final bool? resumeRequired,
      @JsonKey(name: 'cover_letter_enabled') final bool? coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required') final bool? coverLetterRequired,
      @JsonKey(name: 'references_enabled') final bool referencesEnabled,
      @JsonKey(name: 'references_required') final bool referencesRequired,
      @JsonKey(name: 'references_count') final int referencesCount,
      @JsonKey(name: 'use_external_apply')
      final bool useExternalApply}) = _$JobImpl;

  factory _Job.fromJson(Map<String, dynamic> json) = _$JobImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  String get title;
  @override
  String get organization;
  @override
  String get description;
  @override
  @JsonKey(name: 'job_type')
  String get jobType;
  @override
  String? get location;
  @override
  @JsonKey(name: 'location_type')
  String? get locationType;
  @override
  @JsonKey(name: 'is_paid')
  bool get isPaid;
  @override
  @JsonKey(name: 'salary_range')
  String? get salaryRange;
  @override
  @JsonKey(name: 'hourly_rate')
  String? get hourlyRate;
  @override
  String? get requirements;
  @override
  String? get qualifications;
  @override
  @JsonKey(name: 'contact_email')
  String get contactEmail;
  @override
  @JsonKey(name: 'contact_name')
  String? get contactName;
  @override
  @JsonKey(name: 'contact_phone')
  String? get contactPhone;
  @override
  @JsonKey(name: 'application_url')
  String? get applicationUrl;
  @override
  @JsonKey(name: 'application_instructions')
  String? get applicationInstructions;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @override
  String get status;
  @override
  @JsonKey(name: 'approved_at')
  DateTime? get approvedAt;
  @override
  @JsonKey(name: 'approved_by')
  String? get approvedBy;
  @override
  @JsonKey(name: 'rejection_reason')
  String? get rejectionReason;
  @override
  @JsonKey(name: 'submitter_name')
  String get submitterName;
  @override
  @JsonKey(name: 'submitter_email')
  String get submitterEmail;
  @override
  @JsonKey(name: 'submitter_organization')
  String? get submitterOrganization;
  @override
  @JsonKey(name: 'submitter_phone')
  String? get submitterPhone;
  @override
  String? get slug;
  @override
  bool get featured;
  @override
  List<String>? get tags;
  @override
  @JsonKey(name: 'application_count')
  int get applicationCount;
  @override
  @JsonKey(name: 'view_count')
  int get viewCount;
  @override
  @JsonKey(
      name: 'custom_questions',
      fromJson: _customQuestionsFromJson,
      toJson: _customQuestionsToJson)
  List<CustomQuestion> get customQuestions;
  @override
  @JsonKey(name: 'resume_enabled')
  bool? get resumeEnabled;
  @override
  @JsonKey(name: 'resume_required')
  bool? get resumeRequired;
  @override
  @JsonKey(name: 'cover_letter_enabled')
  bool? get coverLetterEnabled;
  @override
  @JsonKey(name: 'cover_letter_required')
  bool? get coverLetterRequired;
  @override
  @JsonKey(name: 'references_enabled')
  bool get referencesEnabled;
  @override
  @JsonKey(name: 'references_required')
  bool get referencesRequired;
  @override
  @JsonKey(name: 'references_count')
  int get referencesCount;
  @override
  @JsonKey(name: 'use_external_apply')
  bool get useExternalApply;
  @override
  @JsonKey(ignore: true)
  _$$JobImplCopyWith<_$JobImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
