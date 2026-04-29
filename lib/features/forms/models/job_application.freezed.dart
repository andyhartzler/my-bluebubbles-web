// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobApplication {
  String get id;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'job_id')
  String get jobId; // Applicant Information
  @JsonKey(name: 'applicant_name')
  String get applicantName;
  @JsonKey(name: 'applicant_email')
  String get applicantEmail;
  @JsonKey(name: 'applicant_phone')
  String? get applicantPhone;
  @JsonKey(name: 'applicant_city')
  String? get applicantCity;
  @JsonKey(name: 'applicant_zip_code')
  String? get applicantZipCode;
  @JsonKey(name: 'resume_url')
  String? get resumeUrl;
  @JsonKey(name: 'cover_letter')
  String? get coverLetter; // Application Data
  @JsonKey(name: 'application_data')
  Map<String, dynamic>?
      get applicationData; // Custom Question Responses: { "question_id": "response_value" }
// response_value can be string, array (for checkbox), or boolean
  @JsonKey(name: 'custom_question_responses')
  Map<String, dynamic>
      get customQuestionResponses; // Status: submitted, reviewed, shortlisted, rejected, accepted
  String get status; // Link to member if applicable
  @JsonKey(name: 'member_id')
  String? get memberId;

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JobApplicationCopyWith<JobApplication> get copyWith =>
      _$JobApplicationCopyWithImpl<JobApplication>(
          this as JobApplication, _$identity);

  /// Serializes this JobApplication to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JobApplication &&
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
                .equals(other.applicationData, applicationData) &&
            const DeepCollectionEquality().equals(
                other.customQuestionResponses, customQuestionResponses) &&
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
      const DeepCollectionEquality().hash(applicationData),
      const DeepCollectionEquality().hash(customQuestionResponses),
      status,
      memberId);

  @override
  String toString() {
    return 'JobApplication(id: $id, createdAt: $createdAt, jobId: $jobId, applicantName: $applicantName, applicantEmail: $applicantEmail, applicantPhone: $applicantPhone, applicantCity: $applicantCity, applicantZipCode: $applicantZipCode, resumeUrl: $resumeUrl, coverLetter: $coverLetter, applicationData: $applicationData, customQuestionResponses: $customQuestionResponses, status: $status, memberId: $memberId)';
  }
}

/// @nodoc
abstract mixin class $JobApplicationCopyWith<$Res> {
  factory $JobApplicationCopyWith(
          JobApplication value, $Res Function(JobApplication) _then) =
      _$JobApplicationCopyWithImpl;
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
class _$JobApplicationCopyWithImpl<$Res>
    implements $JobApplicationCopyWith<$Res> {
  _$JobApplicationCopyWithImpl(this._self, this._then);

  final JobApplication _self;
  final $Res Function(JobApplication) _then;

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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _self.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      applicantName: null == applicantName
          ? _self.applicantName
          : applicantName // ignore: cast_nullable_to_non_nullable
              as String,
      applicantEmail: null == applicantEmail
          ? _self.applicantEmail
          : applicantEmail // ignore: cast_nullable_to_non_nullable
              as String,
      applicantPhone: freezed == applicantPhone
          ? _self.applicantPhone
          : applicantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantCity: freezed == applicantCity
          ? _self.applicantCity
          : applicantCity // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantZipCode: freezed == applicantZipCode
          ? _self.applicantZipCode
          : applicantZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      resumeUrl: freezed == resumeUrl
          ? _self.resumeUrl
          : resumeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      coverLetter: freezed == coverLetter
          ? _self.coverLetter
          : coverLetter // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationData: freezed == applicationData
          ? _self.applicationData
          : applicationData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      customQuestionResponses: null == customQuestionResponses
          ? _self.customQuestionResponses
          : customQuestionResponses // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: freezed == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [JobApplication].
extension JobApplicationPatterns on JobApplication {
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
    TResult Function(_JobApplication value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobApplication() when $default != null:
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
    TResult Function(_JobApplication value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobApplication():
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
    TResult? Function(_JobApplication value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobApplication() when $default != null:
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
            @JsonKey(name: 'job_id') String jobId,
            @JsonKey(name: 'applicant_name') String applicantName,
            @JsonKey(name: 'applicant_email') String applicantEmail,
            @JsonKey(name: 'applicant_phone') String? applicantPhone,
            @JsonKey(name: 'applicant_city') String? applicantCity,
            @JsonKey(name: 'applicant_zip_code') String? applicantZipCode,
            @JsonKey(name: 'resume_url') String? resumeUrl,
            @JsonKey(name: 'cover_letter') String? coverLetter,
            @JsonKey(name: 'application_data')
            Map<String, dynamic>? applicationData,
            @JsonKey(name: 'custom_question_responses')
            Map<String, dynamic> customQuestionResponses,
            String status,
            @JsonKey(name: 'member_id') String? memberId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobApplication() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.jobId,
            _that.applicantName,
            _that.applicantEmail,
            _that.applicantPhone,
            _that.applicantCity,
            _that.applicantZipCode,
            _that.resumeUrl,
            _that.coverLetter,
            _that.applicationData,
            _that.customQuestionResponses,
            _that.status,
            _that.memberId);
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
            @JsonKey(name: 'job_id') String jobId,
            @JsonKey(name: 'applicant_name') String applicantName,
            @JsonKey(name: 'applicant_email') String applicantEmail,
            @JsonKey(name: 'applicant_phone') String? applicantPhone,
            @JsonKey(name: 'applicant_city') String? applicantCity,
            @JsonKey(name: 'applicant_zip_code') String? applicantZipCode,
            @JsonKey(name: 'resume_url') String? resumeUrl,
            @JsonKey(name: 'cover_letter') String? coverLetter,
            @JsonKey(name: 'application_data')
            Map<String, dynamic>? applicationData,
            @JsonKey(name: 'custom_question_responses')
            Map<String, dynamic> customQuestionResponses,
            String status,
            @JsonKey(name: 'member_id') String? memberId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobApplication():
        return $default(
            _that.id,
            _that.createdAt,
            _that.jobId,
            _that.applicantName,
            _that.applicantEmail,
            _that.applicantPhone,
            _that.applicantCity,
            _that.applicantZipCode,
            _that.resumeUrl,
            _that.coverLetter,
            _that.applicationData,
            _that.customQuestionResponses,
            _that.status,
            _that.memberId);
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
            @JsonKey(name: 'job_id') String jobId,
            @JsonKey(name: 'applicant_name') String applicantName,
            @JsonKey(name: 'applicant_email') String applicantEmail,
            @JsonKey(name: 'applicant_phone') String? applicantPhone,
            @JsonKey(name: 'applicant_city') String? applicantCity,
            @JsonKey(name: 'applicant_zip_code') String? applicantZipCode,
            @JsonKey(name: 'resume_url') String? resumeUrl,
            @JsonKey(name: 'cover_letter') String? coverLetter,
            @JsonKey(name: 'application_data')
            Map<String, dynamic>? applicationData,
            @JsonKey(name: 'custom_question_responses')
            Map<String, dynamic> customQuestionResponses,
            String status,
            @JsonKey(name: 'member_id') String? memberId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobApplication() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.jobId,
            _that.applicantName,
            _that.applicantEmail,
            _that.applicantPhone,
            _that.applicantCity,
            _that.applicantZipCode,
            _that.resumeUrl,
            _that.coverLetter,
            _that.applicationData,
            _that.customQuestionResponses,
            _that.status,
            _that.memberId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _JobApplication extends JobApplication {
  const _JobApplication(
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
  factory _JobApplication.fromJson(Map<String, dynamic> json) =>
      _$JobApplicationFromJson(json);

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

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JobApplicationCopyWith<_JobApplication> get copyWith =>
      __$JobApplicationCopyWithImpl<_JobApplication>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JobApplicationToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JobApplication &&
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

  @override
  String toString() {
    return 'JobApplication(id: $id, createdAt: $createdAt, jobId: $jobId, applicantName: $applicantName, applicantEmail: $applicantEmail, applicantPhone: $applicantPhone, applicantCity: $applicantCity, applicantZipCode: $applicantZipCode, resumeUrl: $resumeUrl, coverLetter: $coverLetter, applicationData: $applicationData, customQuestionResponses: $customQuestionResponses, status: $status, memberId: $memberId)';
  }
}

/// @nodoc
abstract mixin class _$JobApplicationCopyWith<$Res>
    implements $JobApplicationCopyWith<$Res> {
  factory _$JobApplicationCopyWith(
          _JobApplication value, $Res Function(_JobApplication) _then) =
      __$JobApplicationCopyWithImpl;
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
class __$JobApplicationCopyWithImpl<$Res>
    implements _$JobApplicationCopyWith<$Res> {
  __$JobApplicationCopyWithImpl(this._self, this._then);

  final _JobApplication _self;
  final $Res Function(_JobApplication) _then;

  /// Create a copy of JobApplication
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_JobApplication(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _self.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      applicantName: null == applicantName
          ? _self.applicantName
          : applicantName // ignore: cast_nullable_to_non_nullable
              as String,
      applicantEmail: null == applicantEmail
          ? _self.applicantEmail
          : applicantEmail // ignore: cast_nullable_to_non_nullable
              as String,
      applicantPhone: freezed == applicantPhone
          ? _self.applicantPhone
          : applicantPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantCity: freezed == applicantCity
          ? _self.applicantCity
          : applicantCity // ignore: cast_nullable_to_non_nullable
              as String?,
      applicantZipCode: freezed == applicantZipCode
          ? _self.applicantZipCode
          : applicantZipCode // ignore: cast_nullable_to_non_nullable
              as String?,
      resumeUrl: freezed == resumeUrl
          ? _self.resumeUrl
          : resumeUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      coverLetter: freezed == coverLetter
          ? _self.coverLetter
          : coverLetter // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationData: freezed == applicationData
          ? _self._applicationData
          : applicationData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      customQuestionResponses: null == customQuestionResponses
          ? _self._customQuestionResponses
          : customQuestionResponses // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: freezed == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
