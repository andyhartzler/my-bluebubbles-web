// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomQuestion {
  String get id;
  String get question;
  CustomQuestionType get type;
  @SafeBoolConverter()
  bool get required;
  List<String> get options;
  int get order;

  /// Create a copy of CustomQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CustomQuestionCopyWith<CustomQuestion> get copyWith =>
      _$CustomQuestionCopyWithImpl<CustomQuestion>(
          this as CustomQuestion, _$identity);

  /// Serializes this CustomQuestion to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CustomQuestion &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.required, required) ||
                other.required == required) &&
            const DeepCollectionEquality().equals(other.options, options) &&
            (identical(other.order, order) || other.order == order));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, question, type, required,
      const DeepCollectionEquality().hash(options), order);

  @override
  String toString() {
    return 'CustomQuestion(id: $id, question: $question, type: $type, required: $required, options: $options, order: $order)';
  }
}

/// @nodoc
abstract mixin class $CustomQuestionCopyWith<$Res> {
  factory $CustomQuestionCopyWith(
          CustomQuestion value, $Res Function(CustomQuestion) _then) =
      _$CustomQuestionCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String question,
      CustomQuestionType type,
      @SafeBoolConverter() bool required,
      List<String> options,
      int order});
}

/// @nodoc
class _$CustomQuestionCopyWithImpl<$Res>
    implements $CustomQuestionCopyWith<$Res> {
  _$CustomQuestionCopyWithImpl(this._self, this._then);

  final CustomQuestion _self;
  final $Res Function(CustomQuestion) _then;

  /// Create a copy of CustomQuestion
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      question: null == question
          ? _self.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as CustomQuestionType,
      required: null == required
          ? _self.required
          : required // ignore: cast_nullable_to_non_nullable
              as bool,
      options: null == options
          ? _self.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>,
      order: null == order
          ? _self.order
          : order // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [CustomQuestion].
extension CustomQuestionPatterns on CustomQuestion {
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
    TResult Function(_CustomQuestion value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomQuestion() when $default != null:
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
    TResult Function(_CustomQuestion value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomQuestion():
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
    TResult? Function(_CustomQuestion value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomQuestion() when $default != null:
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
            String question,
            CustomQuestionType type,
            @SafeBoolConverter() bool required,
            List<String> options,
            int order)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CustomQuestion() when $default != null:
        return $default(_that.id, _that.question, _that.type, _that.required,
            _that.options, _that.order);
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
    TResult Function(String id, String question, CustomQuestionType type,
            @SafeBoolConverter() bool required, List<String> options, int order)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomQuestion():
        return $default(_that.id, _that.question, _that.type, _that.required,
            _that.options, _that.order);
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
            String question,
            CustomQuestionType type,
            @SafeBoolConverter() bool required,
            List<String> options,
            int order)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CustomQuestion() when $default != null:
        return $default(_that.id, _that.question, _that.type, _that.required,
            _that.options, _that.order);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CustomQuestion implements CustomQuestion {
  const _CustomQuestion(
      {required this.id,
      required this.question,
      this.type = CustomQuestionType.text,
      @SafeBoolConverter() this.required = false,
      final List<String> options = const [],
      this.order = 0})
      : _options = options;
  factory _CustomQuestion.fromJson(Map<String, dynamic> json) =>
      _$CustomQuestionFromJson(json);

  @override
  final String id;
  @override
  final String question;
  @override
  @JsonKey()
  final CustomQuestionType type;
  @override
  @JsonKey()
  @SafeBoolConverter()
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

  /// Create a copy of CustomQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CustomQuestionCopyWith<_CustomQuestion> get copyWith =>
      __$CustomQuestionCopyWithImpl<_CustomQuestion>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CustomQuestionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CustomQuestion &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.required, required) ||
                other.required == required) &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.order, order) || other.order == order));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, question, type, required,
      const DeepCollectionEquality().hash(_options), order);

  @override
  String toString() {
    return 'CustomQuestion(id: $id, question: $question, type: $type, required: $required, options: $options, order: $order)';
  }
}

/// @nodoc
abstract mixin class _$CustomQuestionCopyWith<$Res>
    implements $CustomQuestionCopyWith<$Res> {
  factory _$CustomQuestionCopyWith(
          _CustomQuestion value, $Res Function(_CustomQuestion) _then) =
      __$CustomQuestionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String question,
      CustomQuestionType type,
      @SafeBoolConverter() bool required,
      List<String> options,
      int order});
}

/// @nodoc
class __$CustomQuestionCopyWithImpl<$Res>
    implements _$CustomQuestionCopyWith<$Res> {
  __$CustomQuestionCopyWithImpl(this._self, this._then);

  final _CustomQuestion _self;
  final $Res Function(_CustomQuestion) _then;

  /// Create a copy of CustomQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? question = null,
    Object? type = null,
    Object? required = null,
    Object? options = null,
    Object? order = null,
  }) {
    return _then(_CustomQuestion(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      question: null == question
          ? _self.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as CustomQuestionType,
      required: null == required
          ? _self.required
          : required // ignore: cast_nullable_to_non_nullable
              as bool,
      options: null == options
          ? _self._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>,
      order: null == order
          ? _self.order
          : order // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$Job {
  String get id;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt; // Job Information
  String get title;
  String get organization;
  String get description; // Job Type & Location
  @JsonKey(name: 'job_type')
  String get jobType;
  String? get location;
  @JsonKey(name: 'location_type')
  String? get locationType; // Compensation
  @JsonKey(name: 'is_paid')
  @SafeBoolConverter()
  bool get isPaid;
  @JsonKey(name: 'salary_range')
  String? get salaryRange;
  @JsonKey(name: 'hourly_rate')
  String? get hourlyRate; // Requirements
  String? get requirements;
  String? get qualifications; // Contact Information
  @JsonKey(name: 'contact_email')
  String get contactEmail;
  @JsonKey(name: 'contact_name')
  String? get contactName;
  @JsonKey(name: 'contact_phone')
  String? get contactPhone;
  @JsonKey(name: 'application_url')
  String? get applicationUrl;
  @JsonKey(name: 'application_instructions')
  String? get applicationInstructions; // Metadata
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  String get status;
  @JsonKey(name: 'approved_at')
  DateTime? get approvedAt;
  @JsonKey(name: 'approved_by')
  String? get approvedBy;
  @JsonKey(name: 'rejection_reason')
  String? get rejectionReason; // Submission Information
  @JsonKey(name: 'submitter_name')
  String get submitterName;
  @JsonKey(name: 'submitter_email')
  String get submitterEmail;
  @JsonKey(name: 'submitter_organization')
  String? get submitterOrganization;
  @JsonKey(name: 'submitter_phone')
  String? get submitterPhone; // SEO & Display
  String? get slug;
  @SafeBoolConverter()
  bool get featured;
  List<String>? get tags; // Application Tracking
  @JsonKey(name: 'application_count')
  int get applicationCount;
  @JsonKey(name: 'view_count')
  int get viewCount; // Custom Questions for Applications
  @JsonKey(
      name: 'custom_questions',
      fromJson: _customQuestionsFromJson,
      toJson: _customQuestionsToJson)
  List<CustomQuestion> get customQuestions; // Resume & Cover Letter Options
  @JsonKey(name: 'resume_enabled')
  @SafeNullableBoolConverter()
  bool? get resumeEnabled;
  @JsonKey(name: 'resume_required')
  @SafeNullableBoolConverter()
  bool? get resumeRequired;
  @JsonKey(name: 'cover_letter_enabled')
  @SafeNullableBoolConverter()
  bool? get coverLetterEnabled;
  @JsonKey(name: 'cover_letter_required')
  @SafeNullableBoolConverter()
  bool? get coverLetterRequired; // References Options
  @JsonKey(name: 'references_enabled')
  @SafeBoolConverter()
  bool get referencesEnabled;
  @JsonKey(name: 'references_required')
  @SafeBoolConverter()
  bool get referencesRequired;
  @JsonKey(name: 'references_count')
  int get referencesCount; // External Application Option
  @JsonKey(name: 'use_external_apply')
  @SafeBoolConverter()
  bool get useExternalApply;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JobCopyWith<Job> get copyWith =>
      _$JobCopyWithImpl<Job>(this as Job, _$identity);

  /// Serializes this Job to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Job &&
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
            (identical(
                    other.applicationInstructions, applicationInstructions) ||
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
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.applicationCount, applicationCount) ||
                other.applicationCount == applicationCount) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            const DeepCollectionEquality()
                .equals(other.customQuestions, customQuestions) &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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
        const DeepCollectionEquality().hash(tags),
        applicationCount,
        viewCount,
        const DeepCollectionEquality().hash(customQuestions),
        resumeEnabled,
        resumeRequired,
        coverLetterEnabled,
        coverLetterRequired,
        referencesEnabled,
        referencesRequired,
        referencesCount,
        useExternalApply
      ]);

  @override
  String toString() {
    return 'Job(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, title: $title, organization: $organization, description: $description, jobType: $jobType, location: $location, locationType: $locationType, isPaid: $isPaid, salaryRange: $salaryRange, hourlyRate: $hourlyRate, requirements: $requirements, qualifications: $qualifications, contactEmail: $contactEmail, contactName: $contactName, contactPhone: $contactPhone, applicationUrl: $applicationUrl, applicationInstructions: $applicationInstructions, expiresAt: $expiresAt, status: $status, approvedAt: $approvedAt, approvedBy: $approvedBy, rejectionReason: $rejectionReason, submitterName: $submitterName, submitterEmail: $submitterEmail, submitterOrganization: $submitterOrganization, submitterPhone: $submitterPhone, slug: $slug, featured: $featured, tags: $tags, applicationCount: $applicationCount, viewCount: $viewCount, customQuestions: $customQuestions, resumeEnabled: $resumeEnabled, resumeRequired: $resumeRequired, coverLetterEnabled: $coverLetterEnabled, coverLetterRequired: $coverLetterRequired, referencesEnabled: $referencesEnabled, referencesRequired: $referencesRequired, referencesCount: $referencesCount, useExternalApply: $useExternalApply)';
  }
}

/// @nodoc
abstract mixin class $JobCopyWith<$Res> {
  factory $JobCopyWith(Job value, $Res Function(Job) _then) = _$JobCopyWithImpl;
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
      @JsonKey(name: 'is_paid') @SafeBoolConverter() bool isPaid,
      @JsonKey(name: 'salary_range') String? salaryRange,
      @JsonKey(name: 'hourly_rate') String? hourlyRate,
      String? requirements,
      String? qualifications,
      @JsonKey(name: 'contact_email') String contactEmail,
      @JsonKey(name: 'contact_name') String? contactName,
      @JsonKey(name: 'contact_phone') String? contactPhone,
      @JsonKey(name: 'application_url') String? applicationUrl,
      @JsonKey(name: 'application_instructions')
      String? applicationInstructions,
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
      @SafeBoolConverter() bool featured,
      List<String>? tags,
      @JsonKey(name: 'application_count') int applicationCount,
      @JsonKey(name: 'view_count') int viewCount,
      @JsonKey(
          name: 'custom_questions',
          fromJson: _customQuestionsFromJson,
          toJson: _customQuestionsToJson)
      List<CustomQuestion> customQuestions,
      @JsonKey(name: 'resume_enabled')
      @SafeNullableBoolConverter()
      bool? resumeEnabled,
      @JsonKey(name: 'resume_required')
      @SafeNullableBoolConverter()
      bool? resumeRequired,
      @JsonKey(name: 'cover_letter_enabled')
      @SafeNullableBoolConverter()
      bool? coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required')
      @SafeNullableBoolConverter()
      bool? coverLetterRequired,
      @JsonKey(name: 'references_enabled')
      @SafeBoolConverter()
      bool referencesEnabled,
      @JsonKey(name: 'references_required')
      @SafeBoolConverter()
      bool referencesRequired,
      @JsonKey(name: 'references_count') int referencesCount,
      @JsonKey(name: 'use_external_apply')
      @SafeBoolConverter()
      bool useExternalApply});
}

/// @nodoc
class _$JobCopyWithImpl<$Res> implements $JobCopyWith<$Res> {
  _$JobCopyWithImpl(this._self, this._then);

  final Job _self;
  final $Res Function(Job) _then;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      organization: null == organization
          ? _self.organization
          : organization // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      jobType: null == jobType
          ? _self.jobType
          : jobType // ignore: cast_nullable_to_non_nullable
              as String,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      locationType: freezed == locationType
          ? _self.locationType
          : locationType // ignore: cast_nullable_to_non_nullable
              as String?,
      isPaid: null == isPaid
          ? _self.isPaid
          : isPaid // ignore: cast_nullable_to_non_nullable
              as bool,
      salaryRange: freezed == salaryRange
          ? _self.salaryRange
          : salaryRange // ignore: cast_nullable_to_non_nullable
              as String?,
      hourlyRate: freezed == hourlyRate
          ? _self.hourlyRate
          : hourlyRate // ignore: cast_nullable_to_non_nullable
              as String?,
      requirements: freezed == requirements
          ? _self.requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as String?,
      qualifications: freezed == qualifications
          ? _self.qualifications
          : qualifications // ignore: cast_nullable_to_non_nullable
              as String?,
      contactEmail: null == contactEmail
          ? _self.contactEmail
          : contactEmail // ignore: cast_nullable_to_non_nullable
              as String,
      contactName: freezed == contactName
          ? _self.contactName
          : contactName // ignore: cast_nullable_to_non_nullable
              as String?,
      contactPhone: freezed == contactPhone
          ? _self.contactPhone
          : contactPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationUrl: freezed == applicationUrl
          ? _self.applicationUrl
          : applicationUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationInstructions: freezed == applicationInstructions
          ? _self.applicationInstructions
          : applicationInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      approvedAt: freezed == approvedAt
          ? _self.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      approvedBy: freezed == approvedBy
          ? _self.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      rejectionReason: freezed == rejectionReason
          ? _self.rejectionReason
          : rejectionReason // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterName: null == submitterName
          ? _self.submitterName
          : submitterName // ignore: cast_nullable_to_non_nullable
              as String,
      submitterEmail: null == submitterEmail
          ? _self.submitterEmail
          : submitterEmail // ignore: cast_nullable_to_non_nullable
              as String,
      submitterOrganization: freezed == submitterOrganization
          ? _self.submitterOrganization
          : submitterOrganization // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterPhone: freezed == submitterPhone
          ? _self.submitterPhone
          : submitterPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      slug: freezed == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      featured: null == featured
          ? _self.featured
          : featured // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: freezed == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      applicationCount: null == applicationCount
          ? _self.applicationCount
          : applicationCount // ignore: cast_nullable_to_non_nullable
              as int,
      viewCount: null == viewCount
          ? _self.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      customQuestions: null == customQuestions
          ? _self.customQuestions
          : customQuestions // ignore: cast_nullable_to_non_nullable
              as List<CustomQuestion>,
      resumeEnabled: freezed == resumeEnabled
          ? _self.resumeEnabled
          : resumeEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      resumeRequired: freezed == resumeRequired
          ? _self.resumeRequired
          : resumeRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterEnabled: freezed == coverLetterEnabled
          ? _self.coverLetterEnabled
          : coverLetterEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterRequired: freezed == coverLetterRequired
          ? _self.coverLetterRequired
          : coverLetterRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      referencesEnabled: null == referencesEnabled
          ? _self.referencesEnabled
          : referencesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesRequired: null == referencesRequired
          ? _self.referencesRequired
          : referencesRequired // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesCount: null == referencesCount
          ? _self.referencesCount
          : referencesCount // ignore: cast_nullable_to_non_nullable
              as int,
      useExternalApply: null == useExternalApply
          ? _self.useExternalApply
          : useExternalApply // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [Job].
extension JobPatterns on Job {
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
    TResult Function(_Job value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Job() when $default != null:
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
    TResult Function(_Job value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Job():
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
    TResult? Function(_Job value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Job() when $default != null:
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
            @JsonKey(name: 'updated_at') DateTime updatedAt,
            String title,
            String organization,
            String description,
            @JsonKey(name: 'job_type') String jobType,
            String? location,
            @JsonKey(name: 'location_type') String? locationType,
            @JsonKey(name: 'is_paid') @SafeBoolConverter() bool isPaid,
            @JsonKey(name: 'salary_range') String? salaryRange,
            @JsonKey(name: 'hourly_rate') String? hourlyRate,
            String? requirements,
            String? qualifications,
            @JsonKey(name: 'contact_email') String contactEmail,
            @JsonKey(name: 'contact_name') String? contactName,
            @JsonKey(name: 'contact_phone') String? contactPhone,
            @JsonKey(name: 'application_url') String? applicationUrl,
            @JsonKey(name: 'application_instructions')
            String? applicationInstructions,
            @JsonKey(name: 'expires_at') DateTime? expiresAt,
            String status,
            @JsonKey(name: 'approved_at') DateTime? approvedAt,
            @JsonKey(name: 'approved_by') String? approvedBy,
            @JsonKey(name: 'rejection_reason') String? rejectionReason,
            @JsonKey(name: 'submitter_name') String submitterName,
            @JsonKey(name: 'submitter_email') String submitterEmail,
            @JsonKey(name: 'submitter_organization')
            String? submitterOrganization,
            @JsonKey(name: 'submitter_phone') String? submitterPhone,
            String? slug,
            @SafeBoolConverter() bool featured,
            List<String>? tags,
            @JsonKey(name: 'application_count') int applicationCount,
            @JsonKey(name: 'view_count') int viewCount,
            @JsonKey(
                name: 'custom_questions',
                fromJson: _customQuestionsFromJson,
                toJson: _customQuestionsToJson)
            List<CustomQuestion> customQuestions,
            @JsonKey(name: 'resume_enabled')
            @SafeNullableBoolConverter()
            bool? resumeEnabled,
            @JsonKey(name: 'resume_required')
            @SafeNullableBoolConverter()
            bool? resumeRequired,
            @JsonKey(name: 'cover_letter_enabled')
            @SafeNullableBoolConverter()
            bool? coverLetterEnabled,
            @JsonKey(name: 'cover_letter_required')
            @SafeNullableBoolConverter()
            bool? coverLetterRequired,
            @JsonKey(name: 'references_enabled')
            @SafeBoolConverter()
            bool referencesEnabled,
            @JsonKey(name: 'references_required')
            @SafeBoolConverter()
            bool referencesRequired,
            @JsonKey(name: 'references_count') int referencesCount,
            @JsonKey(name: 'use_external_apply')
            @SafeBoolConverter()
            bool useExternalApply)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Job() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.title,
            _that.organization,
            _that.description,
            _that.jobType,
            _that.location,
            _that.locationType,
            _that.isPaid,
            _that.salaryRange,
            _that.hourlyRate,
            _that.requirements,
            _that.qualifications,
            _that.contactEmail,
            _that.contactName,
            _that.contactPhone,
            _that.applicationUrl,
            _that.applicationInstructions,
            _that.expiresAt,
            _that.status,
            _that.approvedAt,
            _that.approvedBy,
            _that.rejectionReason,
            _that.submitterName,
            _that.submitterEmail,
            _that.submitterOrganization,
            _that.submitterPhone,
            _that.slug,
            _that.featured,
            _that.tags,
            _that.applicationCount,
            _that.viewCount,
            _that.customQuestions,
            _that.resumeEnabled,
            _that.resumeRequired,
            _that.coverLetterEnabled,
            _that.coverLetterRequired,
            _that.referencesEnabled,
            _that.referencesRequired,
            _that.referencesCount,
            _that.useExternalApply);
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
            @JsonKey(name: 'updated_at') DateTime updatedAt,
            String title,
            String organization,
            String description,
            @JsonKey(name: 'job_type') String jobType,
            String? location,
            @JsonKey(name: 'location_type') String? locationType,
            @JsonKey(name: 'is_paid') @SafeBoolConverter() bool isPaid,
            @JsonKey(name: 'salary_range') String? salaryRange,
            @JsonKey(name: 'hourly_rate') String? hourlyRate,
            String? requirements,
            String? qualifications,
            @JsonKey(name: 'contact_email') String contactEmail,
            @JsonKey(name: 'contact_name') String? contactName,
            @JsonKey(name: 'contact_phone') String? contactPhone,
            @JsonKey(name: 'application_url') String? applicationUrl,
            @JsonKey(name: 'application_instructions')
            String? applicationInstructions,
            @JsonKey(name: 'expires_at') DateTime? expiresAt,
            String status,
            @JsonKey(name: 'approved_at') DateTime? approvedAt,
            @JsonKey(name: 'approved_by') String? approvedBy,
            @JsonKey(name: 'rejection_reason') String? rejectionReason,
            @JsonKey(name: 'submitter_name') String submitterName,
            @JsonKey(name: 'submitter_email') String submitterEmail,
            @JsonKey(name: 'submitter_organization')
            String? submitterOrganization,
            @JsonKey(name: 'submitter_phone') String? submitterPhone,
            String? slug,
            @SafeBoolConverter() bool featured,
            List<String>? tags,
            @JsonKey(name: 'application_count') int applicationCount,
            @JsonKey(name: 'view_count') int viewCount,
            @JsonKey(
                name: 'custom_questions',
                fromJson: _customQuestionsFromJson,
                toJson: _customQuestionsToJson)
            List<CustomQuestion> customQuestions,
            @JsonKey(name: 'resume_enabled')
            @SafeNullableBoolConverter()
            bool? resumeEnabled,
            @JsonKey(name: 'resume_required')
            @SafeNullableBoolConverter()
            bool? resumeRequired,
            @JsonKey(name: 'cover_letter_enabled')
            @SafeNullableBoolConverter()
            bool? coverLetterEnabled,
            @JsonKey(name: 'cover_letter_required')
            @SafeNullableBoolConverter()
            bool? coverLetterRequired,
            @JsonKey(name: 'references_enabled')
            @SafeBoolConverter()
            bool referencesEnabled,
            @JsonKey(name: 'references_required')
            @SafeBoolConverter()
            bool referencesRequired,
            @JsonKey(name: 'references_count') int referencesCount,
            @JsonKey(name: 'use_external_apply')
            @SafeBoolConverter()
            bool useExternalApply)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Job():
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.title,
            _that.organization,
            _that.description,
            _that.jobType,
            _that.location,
            _that.locationType,
            _that.isPaid,
            _that.salaryRange,
            _that.hourlyRate,
            _that.requirements,
            _that.qualifications,
            _that.contactEmail,
            _that.contactName,
            _that.contactPhone,
            _that.applicationUrl,
            _that.applicationInstructions,
            _that.expiresAt,
            _that.status,
            _that.approvedAt,
            _that.approvedBy,
            _that.rejectionReason,
            _that.submitterName,
            _that.submitterEmail,
            _that.submitterOrganization,
            _that.submitterPhone,
            _that.slug,
            _that.featured,
            _that.tags,
            _that.applicationCount,
            _that.viewCount,
            _that.customQuestions,
            _that.resumeEnabled,
            _that.resumeRequired,
            _that.coverLetterEnabled,
            _that.coverLetterRequired,
            _that.referencesEnabled,
            _that.referencesRequired,
            _that.referencesCount,
            _that.useExternalApply);
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
            @JsonKey(name: 'updated_at') DateTime updatedAt,
            String title,
            String organization,
            String description,
            @JsonKey(name: 'job_type') String jobType,
            String? location,
            @JsonKey(name: 'location_type') String? locationType,
            @JsonKey(name: 'is_paid') @SafeBoolConverter() bool isPaid,
            @JsonKey(name: 'salary_range') String? salaryRange,
            @JsonKey(name: 'hourly_rate') String? hourlyRate,
            String? requirements,
            String? qualifications,
            @JsonKey(name: 'contact_email') String contactEmail,
            @JsonKey(name: 'contact_name') String? contactName,
            @JsonKey(name: 'contact_phone') String? contactPhone,
            @JsonKey(name: 'application_url') String? applicationUrl,
            @JsonKey(name: 'application_instructions')
            String? applicationInstructions,
            @JsonKey(name: 'expires_at') DateTime? expiresAt,
            String status,
            @JsonKey(name: 'approved_at') DateTime? approvedAt,
            @JsonKey(name: 'approved_by') String? approvedBy,
            @JsonKey(name: 'rejection_reason') String? rejectionReason,
            @JsonKey(name: 'submitter_name') String submitterName,
            @JsonKey(name: 'submitter_email') String submitterEmail,
            @JsonKey(name: 'submitter_organization')
            String? submitterOrganization,
            @JsonKey(name: 'submitter_phone') String? submitterPhone,
            String? slug,
            @SafeBoolConverter() bool featured,
            List<String>? tags,
            @JsonKey(name: 'application_count') int applicationCount,
            @JsonKey(name: 'view_count') int viewCount,
            @JsonKey(
                name: 'custom_questions',
                fromJson: _customQuestionsFromJson,
                toJson: _customQuestionsToJson)
            List<CustomQuestion> customQuestions,
            @JsonKey(name: 'resume_enabled')
            @SafeNullableBoolConverter()
            bool? resumeEnabled,
            @JsonKey(name: 'resume_required')
            @SafeNullableBoolConverter()
            bool? resumeRequired,
            @JsonKey(name: 'cover_letter_enabled')
            @SafeNullableBoolConverter()
            bool? coverLetterEnabled,
            @JsonKey(name: 'cover_letter_required')
            @SafeNullableBoolConverter()
            bool? coverLetterRequired,
            @JsonKey(name: 'references_enabled')
            @SafeBoolConverter()
            bool referencesEnabled,
            @JsonKey(name: 'references_required')
            @SafeBoolConverter()
            bool referencesRequired,
            @JsonKey(name: 'references_count') int referencesCount,
            @JsonKey(name: 'use_external_apply')
            @SafeBoolConverter()
            bool useExternalApply)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Job() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.title,
            _that.organization,
            _that.description,
            _that.jobType,
            _that.location,
            _that.locationType,
            _that.isPaid,
            _that.salaryRange,
            _that.hourlyRate,
            _that.requirements,
            _that.qualifications,
            _that.contactEmail,
            _that.contactName,
            _that.contactPhone,
            _that.applicationUrl,
            _that.applicationInstructions,
            _that.expiresAt,
            _that.status,
            _that.approvedAt,
            _that.approvedBy,
            _that.rejectionReason,
            _that.submitterName,
            _that.submitterEmail,
            _that.submitterOrganization,
            _that.submitterPhone,
            _that.slug,
            _that.featured,
            _that.tags,
            _that.applicationCount,
            _that.viewCount,
            _that.customQuestions,
            _that.resumeEnabled,
            _that.resumeRequired,
            _that.coverLetterEnabled,
            _that.coverLetterRequired,
            _that.referencesEnabled,
            _that.referencesRequired,
            _that.referencesCount,
            _that.useExternalApply);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Job implements Job {
  const _Job(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      required this.title,
      required this.organization,
      required this.description,
      @JsonKey(name: 'job_type') required this.jobType,
      this.location,
      @JsonKey(name: 'location_type') this.locationType,
      @JsonKey(name: 'is_paid') @SafeBoolConverter() this.isPaid = false,
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
      @SafeBoolConverter() this.featured = false,
      final List<String>? tags,
      @JsonKey(name: 'application_count') this.applicationCount = 0,
      @JsonKey(name: 'view_count') this.viewCount = 0,
      @JsonKey(
          name: 'custom_questions',
          fromJson: _customQuestionsFromJson,
          toJson: _customQuestionsToJson)
      final List<CustomQuestion> customQuestions = const [],
      @JsonKey(name: 'resume_enabled')
      @SafeNullableBoolConverter()
      this.resumeEnabled,
      @JsonKey(name: 'resume_required')
      @SafeNullableBoolConverter()
      this.resumeRequired,
      @JsonKey(name: 'cover_letter_enabled')
      @SafeNullableBoolConverter()
      this.coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required')
      @SafeNullableBoolConverter()
      this.coverLetterRequired,
      @JsonKey(name: 'references_enabled')
      @SafeBoolConverter()
      this.referencesEnabled = false,
      @JsonKey(name: 'references_required')
      @SafeBoolConverter()
      this.referencesRequired = false,
      @JsonKey(name: 'references_count') this.referencesCount = 2,
      @JsonKey(name: 'use_external_apply')
      @SafeBoolConverter()
      this.useExternalApply = false})
      : _tags = tags,
        _customQuestions = customQuestions;
  factory _Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
// Job Information
  @override
  final String title;
  @override
  final String organization;
  @override
  final String description;
// Job Type & Location
  @override
  @JsonKey(name: 'job_type')
  final String jobType;
  @override
  final String? location;
  @override
  @JsonKey(name: 'location_type')
  final String? locationType;
// Compensation
  @override
  @JsonKey(name: 'is_paid')
  @SafeBoolConverter()
  final bool isPaid;
  @override
  @JsonKey(name: 'salary_range')
  final String? salaryRange;
  @override
  @JsonKey(name: 'hourly_rate')
  final String? hourlyRate;
// Requirements
  @override
  final String? requirements;
  @override
  final String? qualifications;
// Contact Information
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
// Metadata
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
// Submission Information
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
// SEO & Display
  @override
  final String? slug;
  @override
  @JsonKey()
  @SafeBoolConverter()
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

// Application Tracking
  @override
  @JsonKey(name: 'application_count')
  final int applicationCount;
  @override
  @JsonKey(name: 'view_count')
  final int viewCount;
// Custom Questions for Applications
  final List<CustomQuestion> _customQuestions;
// Custom Questions for Applications
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

// Resume & Cover Letter Options
  @override
  @JsonKey(name: 'resume_enabled')
  @SafeNullableBoolConverter()
  final bool? resumeEnabled;
  @override
  @JsonKey(name: 'resume_required')
  @SafeNullableBoolConverter()
  final bool? resumeRequired;
  @override
  @JsonKey(name: 'cover_letter_enabled')
  @SafeNullableBoolConverter()
  final bool? coverLetterEnabled;
  @override
  @JsonKey(name: 'cover_letter_required')
  @SafeNullableBoolConverter()
  final bool? coverLetterRequired;
// References Options
  @override
  @JsonKey(name: 'references_enabled')
  @SafeBoolConverter()
  final bool referencesEnabled;
  @override
  @JsonKey(name: 'references_required')
  @SafeBoolConverter()
  final bool referencesRequired;
  @override
  @JsonKey(name: 'references_count')
  final int referencesCount;
// External Application Option
  @override
  @JsonKey(name: 'use_external_apply')
  @SafeBoolConverter()
  final bool useExternalApply;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JobCopyWith<_Job> get copyWith =>
      __$JobCopyWithImpl<_Job>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JobToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Job &&
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
            (identical(
                    other.applicationInstructions, applicationInstructions) ||
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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
        useExternalApply
      ]);

  @override
  String toString() {
    return 'Job(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, title: $title, organization: $organization, description: $description, jobType: $jobType, location: $location, locationType: $locationType, isPaid: $isPaid, salaryRange: $salaryRange, hourlyRate: $hourlyRate, requirements: $requirements, qualifications: $qualifications, contactEmail: $contactEmail, contactName: $contactName, contactPhone: $contactPhone, applicationUrl: $applicationUrl, applicationInstructions: $applicationInstructions, expiresAt: $expiresAt, status: $status, approvedAt: $approvedAt, approvedBy: $approvedBy, rejectionReason: $rejectionReason, submitterName: $submitterName, submitterEmail: $submitterEmail, submitterOrganization: $submitterOrganization, submitterPhone: $submitterPhone, slug: $slug, featured: $featured, tags: $tags, applicationCount: $applicationCount, viewCount: $viewCount, customQuestions: $customQuestions, resumeEnabled: $resumeEnabled, resumeRequired: $resumeRequired, coverLetterEnabled: $coverLetterEnabled, coverLetterRequired: $coverLetterRequired, referencesEnabled: $referencesEnabled, referencesRequired: $referencesRequired, referencesCount: $referencesCount, useExternalApply: $useExternalApply)';
  }
}

/// @nodoc
abstract mixin class _$JobCopyWith<$Res> implements $JobCopyWith<$Res> {
  factory _$JobCopyWith(_Job value, $Res Function(_Job) _then) =
      __$JobCopyWithImpl;
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
      @JsonKey(name: 'is_paid') @SafeBoolConverter() bool isPaid,
      @JsonKey(name: 'salary_range') String? salaryRange,
      @JsonKey(name: 'hourly_rate') String? hourlyRate,
      String? requirements,
      String? qualifications,
      @JsonKey(name: 'contact_email') String contactEmail,
      @JsonKey(name: 'contact_name') String? contactName,
      @JsonKey(name: 'contact_phone') String? contactPhone,
      @JsonKey(name: 'application_url') String? applicationUrl,
      @JsonKey(name: 'application_instructions')
      String? applicationInstructions,
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
      @SafeBoolConverter() bool featured,
      List<String>? tags,
      @JsonKey(name: 'application_count') int applicationCount,
      @JsonKey(name: 'view_count') int viewCount,
      @JsonKey(
          name: 'custom_questions',
          fromJson: _customQuestionsFromJson,
          toJson: _customQuestionsToJson)
      List<CustomQuestion> customQuestions,
      @JsonKey(name: 'resume_enabled')
      @SafeNullableBoolConverter()
      bool? resumeEnabled,
      @JsonKey(name: 'resume_required')
      @SafeNullableBoolConverter()
      bool? resumeRequired,
      @JsonKey(name: 'cover_letter_enabled')
      @SafeNullableBoolConverter()
      bool? coverLetterEnabled,
      @JsonKey(name: 'cover_letter_required')
      @SafeNullableBoolConverter()
      bool? coverLetterRequired,
      @JsonKey(name: 'references_enabled')
      @SafeBoolConverter()
      bool referencesEnabled,
      @JsonKey(name: 'references_required')
      @SafeBoolConverter()
      bool referencesRequired,
      @JsonKey(name: 'references_count') int referencesCount,
      @JsonKey(name: 'use_external_apply')
      @SafeBoolConverter()
      bool useExternalApply});
}

/// @nodoc
class __$JobCopyWithImpl<$Res> implements _$JobCopyWith<$Res> {
  __$JobCopyWithImpl(this._self, this._then);

  final _Job _self;
  final $Res Function(_Job) _then;

  /// Create a copy of Job
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_Job(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      organization: null == organization
          ? _self.organization
          : organization // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      jobType: null == jobType
          ? _self.jobType
          : jobType // ignore: cast_nullable_to_non_nullable
              as String,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as String?,
      locationType: freezed == locationType
          ? _self.locationType
          : locationType // ignore: cast_nullable_to_non_nullable
              as String?,
      isPaid: null == isPaid
          ? _self.isPaid
          : isPaid // ignore: cast_nullable_to_non_nullable
              as bool,
      salaryRange: freezed == salaryRange
          ? _self.salaryRange
          : salaryRange // ignore: cast_nullable_to_non_nullable
              as String?,
      hourlyRate: freezed == hourlyRate
          ? _self.hourlyRate
          : hourlyRate // ignore: cast_nullable_to_non_nullable
              as String?,
      requirements: freezed == requirements
          ? _self.requirements
          : requirements // ignore: cast_nullable_to_non_nullable
              as String?,
      qualifications: freezed == qualifications
          ? _self.qualifications
          : qualifications // ignore: cast_nullable_to_non_nullable
              as String?,
      contactEmail: null == contactEmail
          ? _self.contactEmail
          : contactEmail // ignore: cast_nullable_to_non_nullable
              as String,
      contactName: freezed == contactName
          ? _self.contactName
          : contactName // ignore: cast_nullable_to_non_nullable
              as String?,
      contactPhone: freezed == contactPhone
          ? _self.contactPhone
          : contactPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationUrl: freezed == applicationUrl
          ? _self.applicationUrl
          : applicationUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      applicationInstructions: freezed == applicationInstructions
          ? _self.applicationInstructions
          : applicationInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _self.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      approvedAt: freezed == approvedAt
          ? _self.approvedAt
          : approvedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      approvedBy: freezed == approvedBy
          ? _self.approvedBy
          : approvedBy // ignore: cast_nullable_to_non_nullable
              as String?,
      rejectionReason: freezed == rejectionReason
          ? _self.rejectionReason
          : rejectionReason // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterName: null == submitterName
          ? _self.submitterName
          : submitterName // ignore: cast_nullable_to_non_nullable
              as String,
      submitterEmail: null == submitterEmail
          ? _self.submitterEmail
          : submitterEmail // ignore: cast_nullable_to_non_nullable
              as String,
      submitterOrganization: freezed == submitterOrganization
          ? _self.submitterOrganization
          : submitterOrganization // ignore: cast_nullable_to_non_nullable
              as String?,
      submitterPhone: freezed == submitterPhone
          ? _self.submitterPhone
          : submitterPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      slug: freezed == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      featured: null == featured
          ? _self.featured
          : featured // ignore: cast_nullable_to_non_nullable
              as bool,
      tags: freezed == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      applicationCount: null == applicationCount
          ? _self.applicationCount
          : applicationCount // ignore: cast_nullable_to_non_nullable
              as int,
      viewCount: null == viewCount
          ? _self.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      customQuestions: null == customQuestions
          ? _self._customQuestions
          : customQuestions // ignore: cast_nullable_to_non_nullable
              as List<CustomQuestion>,
      resumeEnabled: freezed == resumeEnabled
          ? _self.resumeEnabled
          : resumeEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      resumeRequired: freezed == resumeRequired
          ? _self.resumeRequired
          : resumeRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterEnabled: freezed == coverLetterEnabled
          ? _self.coverLetterEnabled
          : coverLetterEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      coverLetterRequired: freezed == coverLetterRequired
          ? _self.coverLetterRequired
          : coverLetterRequired // ignore: cast_nullable_to_non_nullable
              as bool?,
      referencesEnabled: null == referencesEnabled
          ? _self.referencesEnabled
          : referencesEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesRequired: null == referencesRequired
          ? _self.referencesRequired
          : referencesRequired // ignore: cast_nullable_to_non_nullable
              as bool,
      referencesCount: null == referencesCount
          ? _self.referencesCount
          : referencesCount // ignore: cast_nullable_to_non_nullable
              as int,
      useExternalApply: null == useExternalApply
          ? _self.useExternalApply
          : useExternalApply // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
