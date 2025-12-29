// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

JobApplication _$JobApplicationFromJson(Map<String, dynamic> json) {
  return _JobApplication.fromJson(json);
}

/// @nodoc
mixin _$JobApplication {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'job_id')
  String get jobId =>
      throw _privateConstructorUsedError; // Applicant Information
  @JsonKey(name: 'applicant_name')
  String get applicantName => throw _privateConstructorUsedError;
  @JsonKey(name: 'applicant_email')
  String get applicantEmail => throw _privateConstructorUsedError;
  @JsonKey(name: 'applicant_phone')
  String? get applicantPhone => throw _privateConstructorUsedError;
  @JsonKey(name: 'applicant_city')
  String? get applicantCity => throw _privateConstructorUsedError;
  @JsonKey(name: 'applicant_zip_code')
  String? get applicantZipCode => throw _privateConstructorUsedError;
  @JsonKey(name: 'resume_url')
  String? get resumeUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'cover_letter')
  String? get coverLetter =>
      throw _privateConstructorUsedError; // Application Data
  @JsonKey(name: 'application_data')
  Map<String, dynamic>? get applicationData =>
      throw _privateConstructorUsedError; // Custom Question Responses: { "question_id": "response_value" }
// response_value can be string, array (for checkbox), or boolean
  @JsonKey(name: 'custom_question_responses')
  Map<String, dynamic> get customQuestionResponses =>
      throw _privateConstructorUsedError; // Status: submitted, reviewed, shortlisted, rejected, accepted
  String get status =>
      throw _privateConstructorUsedError; // Link to member if applicable
  @JsonKey(name: 'member_id')
  String? get memberId => throw _privateConstructorUsedError;

  /// Serializes this JobApplication to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobApplicationCopyWith<JobApplication> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobApplicationCopyWith<$Res> {
  factory $JobApplicationCopyWith(
          JobApplication value, $Res Function(JobApplication) then) =
      _$JobApplicationCopyWithImpl<$Res, JobApplication>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'job_id') String jobId,
      @JsonKey(name: 'applicant_name') String applicantName,
      @JsonKey(name: 'applicant_email') String applicantEmail,
      @JsonKey(name: 'applicant_phone') String? applicantPhone,
      @JsonKey(name: 'applicant_city') String? applicantCity,
      @JsonKey(name: 'applicant_zip_code') String? applicantZipCode,
      @JsonKey(name: 'resume_url') String? resumeUrl,
      @JsonKey(name: 'cover_letter') String? coverLetter,
      @JsonKey(name: 'application_data') Map<String, dynamic>? applicationData,
      @JsonKey(name: 'custom_question_responses')
      Map<String, dynamic> customQuestionResponses,
      String status,
      @JsonKey(name: 'member_id') String? memberId});
}

/// @nodoc
class _$JobApplicationCopyWithImpl<$Res, $Val extends JobApplication>
    implements $JobApplicationCopyWith<$Res> {
  _$JobApplicationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? jobId = null,
    Object? applicantName = null,
    Object? applicantEmail = null,
    Object? applicantPhone = freezed,
    Object? applicantCity = freezed,
    Object? applicantZipCode = freezed,
    Object? resumeUrl = freezed,
    Object? coverLetter = freezed,
    Object? applicationData = freezed,
    Object? customQuestionResponses = null,
    Object? status = null,
    Object? memberId = freezed,
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
      jobId: null == jobId
          ? _value.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      applicantName: null == applicantName
          ? _value.applicantName
          : applicantName // ignore: cast_nullable_to_non_nullable
              as String,
      applicantEmail: null == applicantEmail
          ? _value.applicantEmail
          : applicantEmail // ignore: cast_nullable_to_non_nullable
              as String,
      applicantPhone: freezed == applicantPhone
          ? _value.applicantPhone
          : applicantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantCity: freezed == applicantCity
          ? _value.applicantCity
          : applicantCity // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantZipCode: freezed == applicantZipCode
          ? _value.applicantZipCode
          : applicantZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      resumeUrl: freezed == resumeUrl
          ? _value.resumeUrl
          : resumeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      coverLetter: freezed == coverLetter
          ? _value.coverLetter
          : coverLetter // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationData: freezed == applicationData
          ? _value.applicationData
          : applicationData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      customQuestionResponses: null == customQuestionResponses
          ? _value.customQuestionResponses
          : customQuestionResponses // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: freezed == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobApplicationImplCopyWith<$Res>
    implements $JobApplicationCopyWith<$Res> {
  factory _$$JobApplicationImplCopyWith(_$JobApplicationImpl value,
          $Res Function(_$JobApplicationImpl) then) =
      __$$JobApplicationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'job_id') String jobId,
      @JsonKey(name: 'applicant_name') String applicantName,
      @JsonKey(name: 'applicant_email') String applicantEmail,
      @JsonKey(name: 'applicant_phone') String? applicantPhone,
      @JsonKey(name: 'applicant_city') String? applicantCity,
      @JsonKey(name: 'applicant_zip_code') String? applicantZipCode,
      @JsonKey(name: 'resume_url') String? resumeUrl,
      @JsonKey(name: 'cover_letter') String? coverLetter,
      @JsonKey(name: 'application_data') Map<String, dynamic>? applicationData,
      @JsonKey(name: 'custom_question_responses')
      Map<String, dynamic> customQuestionResponses,
      String status,
      @JsonKey(name: 'member_id') String? memberId});
}

/// @nodoc
class __$$JobApplicationImplCopyWithImpl<$Res>
    extends _$JobApplicationCopyWithImpl<$Res, _$JobApplicationImpl>
    implements _$$JobApplicationImplCopyWith<$Res> {
  __$$JobApplicationImplCopyWithImpl(
      _$JobApplicationImpl _value, $Res Function(_$JobApplicationImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? jobId = null,
    Object? applicantName = null,
    Object? applicantEmail = null,
    Object? applicantPhone = freezed,
    Object? applicantCity = freezed,
    Object? applicantZipCode = freezed,
    Object? resumeUrl = freezed,
    Object? coverLetter = freezed,
    Object? applicationData = freezed,
    Object? customQuestionResponses = null,
    Object? status = null,
    Object? memberId = freezed,
  }) {
    return _then(_$JobApplicationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _value.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      applicantName: null == applicantName
          ? _value.applicantName
          : applicantName // ignore: cast_nullable_to_non_nullable
              as String,
      applicantEmail: null == applicantEmail
          ? _value.applicantEmail
          : applicantEmail // ignore: cast_nullable_to_non_nullable
              as String,
      applicantPhone: freezed == applicantPhone
          ? _value.applicantPhone
          : applicantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantCity: freezed == applicantCity
          ? _value.applicantCity
          : applicantCity // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantZipCode: freezed == applicantZipCode
          ? _value.applicantZipCode
          : applicantZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      resumeUrl: freezed == resumeUrl
          ? _value.resumeUrl
          : resumeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      coverLetter: freezed == coverLetter
          ? _value.coverLetter
          : coverLetter // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationData: freezed == applicationData
          ? _value._applicationData
          : applicationData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      customQuestionResponses: null == customQuestionResponses
          ? _value._customQuestionResponses
          : customQuestionResponses // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: freezed == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobApplicationImpl extends _JobApplication {
  const _$JobApplicationImpl(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'job_id') required this.jobId,
      @JsonKey(name: 'applicant_name') required this.applicantName,
      @JsonKey(name: 'applicant_email') required this.applicantEmail,
      @JsonKey(name: 'applicant_phone') this.applicantPhone,
      @JsonKey(name: 'applicant_city') this.applicantCity,
      @JsonKey(name: 'applicant_zip_code') this.applicantZipCode,
      @JsonKey(name: 'resume_url') this.resumeUrl,
      @JsonKey(name: 'cover_letter') this.coverLetter,
      @JsonKey(name: 'application_data')
      final Map<String, dynamic>? applicationData,
      @JsonKey(name: 'custom_question_responses')
      final Map<String, dynamic> customQuestionResponses = const {},
      this.status = 'submitted',
      @JsonKey(name: 'member_id') this.memberId})
      : _applicationData = applicationData,
        _customQuestionResponses = customQuestionResponses,
        super._();

  factory _$JobApplicationImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobApplicationImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'job_id')
  final String jobId;
// Applicant Information
  @override
  @JsonKey(name: 'applicant_name')
  final String applicantName;
  @override
  @JsonKey(name: 'applicant_email')
  final String applicantEmail;
  @override
  @JsonKey(name: 'applicant_phone')
  final String? applicantPhone;
  @override
  @JsonKey(name: 'applicant_city')
  final String? applicantCity;
  @override
  @JsonKey(name: 'applicant_zip_code')
  final String? applicantZipCode;
  @override
  @JsonKey(name: 'resume_url')
  final String? resumeUrl;
  @override
  @JsonKey(name: 'cover_letter')
  final String? coverLetter;
// Application Data
  final Map<String, dynamic>? _applicationData;
// Application Data
  @override
  @JsonKey(name: 'application_data')
  Map<String, dynamic>? get applicationData {
    final value = _applicationData;
    if (value == null) return null;
    if (_applicationData is EqualUnmodifiableMapView) return _applicationData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// Custom Question Responses: { "question_id": "response_value" }
// response_value can be string, array (for checkbox), or boolean
  final Map<String, dynamic> _customQuestionResponses;
// Custom Question Responses: { "question_id": "response_value" }
// response_value can be string, array (for checkbox), or boolean
  @override
  @JsonKey(name: 'custom_question_responses')
  Map<String, dynamic> get customQuestionResponses {
    if (_customQuestionResponses is EqualUnmodifiableMapView)
      return _customQuestionResponses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_customQuestionResponses);
  }

// Status: submitted, reviewed, shortlisted, rejected, accepted
  @override
  @JsonKey()
  final String status;
// Link to member if applicable
  @override
  @JsonKey(name: 'member_id')
  final String? memberId;

  @override
  String toString() {
    return 'JobApplication(id: $id, createdAt: $createdAt, jobId: $jobId, applicantName: $applicantName, applicantEmail: $applicantEmail, applicantPhone: $applicantPhone, applicantCity: $applicantCity, applicantZipCode: $applicantZipCode, resumeUrl: $resumeUrl, coverLetter: $coverLetter, applicationData: $applicationData, customQuestionResponses: $customQuestionResponses, status: $status, memberId: $memberId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobApplicationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.applicantName, applicantName) ||
                other.applicantName == applicantName) &&
            (identical(other.applicantEmail, applicantEmail) ||
                other.applicantEmail == applicantEmail) &&
            (identical(other.applicantPhone, applicantPhone) ||
                other.applicantPhone == applicantPhone) &&
            (identical(other.applicantCity, applicantCity) ||
                other.applicantCity == applicantCity) &&
            (identical(other.applicantZipCode, applicantZipCode) ||
                other.applicantZipCode == applicantZipCode) &&
            (identical(other.resumeUrl, resumeUrl) ||
                other.resumeUrl == resumeUrl) &&
            (identical(other.coverLetter, coverLetter) ||
                other.coverLetter == coverLetter) &&
            const DeepCollectionEquality()
                .equals(other._applicationData, _applicationData) &&
            const DeepCollectionEquality().equals(
                other._customQuestionResponses, _customQuestionResponses) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      createdAt,
      jobId,
      applicantName,
      applicantEmail,
      applicantPhone,
      applicantCity,
      applicantZipCode,
      resumeUrl,
      coverLetter,
      const DeepCollectionEquality().hash(_applicationData),
      const DeepCollectionEquality().hash(_customQuestionResponses),
      status,
      memberId);

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobApplicationImplCopyWith<_$JobApplicationImpl> get copyWith =>
      __$$JobApplicationImplCopyWithImpl<_$JobApplicationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobApplicationImplToJson(
      this,
    );
  }
}

abstract class _JobApplication extends JobApplication {
  const factory _JobApplication(
      {required final String id,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'job_id') required final String jobId,
      @JsonKey(name: 'applicant_name') required final String applicantName,
      @JsonKey(name: 'applicant_email') required final String applicantEmail,
      @JsonKey(name: 'applicant_phone') final String? applicantPhone,
      @JsonKey(name: 'applicant_city') final String? applicantCity,
      @JsonKey(name: 'applicant_zip_code') final String? applicantZipCode,
      @JsonKey(name: 'resume_url') final String? resumeUrl,
      @JsonKey(name: 'cover_letter') final String? coverLetter,
      @JsonKey(name: 'application_data')
      final Map<String, dynamic>? applicationData,
      @JsonKey(name: 'custom_question_responses')
      final Map<String, dynamic> customQuestionResponses,
      final String status,
      @JsonKey(name: 'member_id')
      final String? memberId}) = _$JobApplicationImpl;
  const _JobApplication._() : super._();

  factory _JobApplication.fromJson(Map<String, dynamic> json) =
      _$JobApplicationImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'job_id')
  String get jobId; // Applicant Information
  @override
  @JsonKey(name: 'applicant_name')
  String get applicantName;
  @override
  @JsonKey(name: 'applicant_email')
  String get applicantEmail;
  @override
  @JsonKey(name: 'applicant_phone')
  String? get applicantPhone;
  @override
  @JsonKey(name: 'applicant_city')
  String? get applicantCity;
  @override
  @JsonKey(name: 'applicant_zip_code')
  String? get applicantZipCode;
  @override
  @JsonKey(name: 'resume_url')
  String? get resumeUrl;
  @override
  @JsonKey(name: 'cover_letter')
  String? get coverLetter; // Application Data
  @override
  @JsonKey(name: 'application_data')
  Map<String, dynamic>?
      get applicationData; // Custom Question Responses: { "question_id": "response_value" }
// response_value can be string, array (for checkbox), or boolean
  @override
  @JsonKey(name: 'custom_question_responses')
  Map<String, dynamic>
      get customQuestionResponses; // Status: submitted, reviewed, shortlisted, rejected, accepted
  @override
  String get status; // Link to member if applicable
  @override
  @JsonKey(name: 'member_id')
  String? get memberId;

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobApplicationImplCopyWith<_$JobApplicationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
