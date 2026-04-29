// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voting_form.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VotingForm {
  String get id;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @JsonKey(name: 'created_by')
  String? get createdBy;
  String get title;
  String?
      get description; // Schema contains the voting options and configuration
  Map<String, dynamic> get schema; // Settings for vote configuration
  Map<String, dynamic> get settings;
  String get status; // Voting-specific fields from form_schemas
  @JsonKey(name: 'voting_starts_at')
  DateTime? get votingStartsAt;
  @JsonKey(name: 'voting_ends_at')
  DateTime? get votingEndsAt;
  @JsonKey(name: 'eligible_members')
  Map<String, dynamic>? get eligibleMembers;
  @JsonKey(name: 'results_public')
  @SafeBoolConverter()
  bool get resultsPublic;
  @JsonKey(name: 'results_data')
  Map<String, dynamic>? get resultsData; // Page management
  @JsonKey(name: 'page_count')
  int get pageCount; // Custom URL slug
  String? get slug; // Submission tracking
  @JsonKey(name: 'submission_count')
  int get submissionCount; // Scheduling
  @JsonKey(name: 'opens_at')
  DateTime? get opensAt;
  @JsonKey(name: 'closes_at')
  DateTime? get closesAt; // Submission limits
  @JsonKey(name: 'max_submissions')
  int? get maxSubmissions; // Access control
  @JsonKey(name: 'require_login')
  @SafeBoolConverter()
  bool get requireLogin;
  @JsonKey(name: 'one_submission_per_user')
  @SafeBoolTrueConverter()
  bool get oneSubmissionPerUser; // Email settings
  @JsonKey(name: 'confirmation_email_template')
  String? get confirmationEmailTemplate;
  @JsonKey(name: 'notification_emails')
  List<String>?
      get notificationEmails; // Supporting documents (list of document metadata objects)
  @JsonKey(name: 'supporting_documents')
  List<Map<String, dynamic>>?
      get supportingDocuments; // Executive Committee Only - restricts voting to executive committee members
  @JsonKey(name: 'executive_only')
  @SafeBoolConverter()
  bool
      get executiveOnly; // Committee association - ties vote to a specific committee
  String? get committee;

  /// Create a copy of VotingForm
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VotingFormCopyWith<VotingForm> get copyWith =>
      _$VotingFormCopyWithImpl<VotingForm>(this as VotingForm, _$identity);

  /// Serializes this VotingForm to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VotingForm &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other.schema, schema) &&
            const DeepCollectionEquality().equals(other.settings, settings) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.votingStartsAt, votingStartsAt) ||
                other.votingStartsAt == votingStartsAt) &&
            (identical(other.votingEndsAt, votingEndsAt) ||
                other.votingEndsAt == votingEndsAt) &&
            const DeepCollectionEquality()
                .equals(other.eligibleMembers, eligibleMembers) &&
            (identical(other.resultsPublic, resultsPublic) ||
                other.resultsPublic == resultsPublic) &&
            const DeepCollectionEquality()
                .equals(other.resultsData, resultsData) &&
            (identical(other.pageCount, pageCount) ||
                other.pageCount == pageCount) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.submissionCount, submissionCount) ||
                other.submissionCount == submissionCount) &&
            (identical(other.opensAt, opensAt) || other.opensAt == opensAt) &&
            (identical(other.closesAt, closesAt) ||
                other.closesAt == closesAt) &&
            (identical(other.maxSubmissions, maxSubmissions) ||
                other.maxSubmissions == maxSubmissions) &&
            (identical(other.requireLogin, requireLogin) ||
                other.requireLogin == requireLogin) &&
            (identical(other.oneSubmissionPerUser, oneSubmissionPerUser) ||
                other.oneSubmissionPerUser == oneSubmissionPerUser) &&
            (identical(other.confirmationEmailTemplate,
                    confirmationEmailTemplate) ||
                other.confirmationEmailTemplate == confirmationEmailTemplate) &&
            const DeepCollectionEquality()
                .equals(other.notificationEmails, notificationEmails) &&
            const DeepCollectionEquality()
                .equals(other.supportingDocuments, supportingDocuments) &&
            (identical(other.executiveOnly, executiveOnly) ||
                other.executiveOnly == executiveOnly) &&
            (identical(other.committee, committee) ||
                other.committee == committee));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        createdAt,
        updatedAt,
        createdBy,
        title,
        description,
        const DeepCollectionEquality().hash(schema),
        const DeepCollectionEquality().hash(settings),
        status,
        votingStartsAt,
        votingEndsAt,
        const DeepCollectionEquality().hash(eligibleMembers),
        resultsPublic,
        const DeepCollectionEquality().hash(resultsData),
        pageCount,
        slug,
        submissionCount,
        opensAt,
        closesAt,
        maxSubmissions,
        requireLogin,
        oneSubmissionPerUser,
        confirmationEmailTemplate,
        const DeepCollectionEquality().hash(notificationEmails),
        const DeepCollectionEquality().hash(supportingDocuments),
        executiveOnly,
        committee
      ]);

  @override
  String toString() {
    return 'VotingForm(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, title: $title, description: $description, schema: $schema, settings: $settings, status: $status, votingStartsAt: $votingStartsAt, votingEndsAt: $votingEndsAt, eligibleMembers: $eligibleMembers, resultsPublic: $resultsPublic, resultsData: $resultsData, pageCount: $pageCount, slug: $slug, submissionCount: $submissionCount, opensAt: $opensAt, closesAt: $closesAt, maxSubmissions: $maxSubmissions, requireLogin: $requireLogin, oneSubmissionPerUser: $oneSubmissionPerUser, confirmationEmailTemplate: $confirmationEmailTemplate, notificationEmails: $notificationEmails, supportingDocuments: $supportingDocuments, executiveOnly: $executiveOnly, committee: $committee)';
  }
}

/// @nodoc
abstract mixin class $VotingFormCopyWith<$Res> {
  factory $VotingFormCopyWith(
          VotingForm value, $Res Function(VotingForm) _then) =
      _$VotingFormCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      @JsonKey(name: 'created_by') String? createdBy,
      String title,
      String? description,
      Map<String, dynamic> schema,
      Map<String, dynamic> settings,
      String status,
      @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
      @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
      @JsonKey(name: 'eligible_members') Map<String, dynamic>? eligibleMembers,
      @JsonKey(name: 'results_public') @SafeBoolConverter() bool resultsPublic,
      @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') int pageCount,
      String? slug,
      @JsonKey(name: 'submission_count') int submissionCount,
      @JsonKey(name: 'opens_at') DateTime? opensAt,
      @JsonKey(name: 'closes_at') DateTime? closesAt,
      @JsonKey(name: 'max_submissions') int? maxSubmissions,
      @JsonKey(name: 'require_login') @SafeBoolConverter() bool requireLogin,
      @JsonKey(name: 'one_submission_per_user')
      @SafeBoolTrueConverter()
      bool oneSubmissionPerUser,
      @JsonKey(name: 'confirmation_email_template')
      String? confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails') List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only') @SafeBoolConverter() bool executiveOnly,
      String? committee});
}

/// @nodoc
class _$VotingFormCopyWithImpl<$Res> implements $VotingFormCopyWith<$Res> {
  _$VotingFormCopyWithImpl(this._self, this._then);

  final VotingForm _self;
  final $Res Function(VotingForm) _then;

  /// Create a copy of VotingForm
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? createdBy = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? schema = null,
    Object? settings = null,
    Object? status = null,
    Object? votingStartsAt = freezed,
    Object? votingEndsAt = freezed,
    Object? eligibleMembers = freezed,
    Object? resultsPublic = null,
    Object? resultsData = freezed,
    Object? pageCount = null,
    Object? slug = freezed,
    Object? submissionCount = null,
    Object? opensAt = freezed,
    Object? closesAt = freezed,
    Object? maxSubmissions = freezed,
    Object? requireLogin = null,
    Object? oneSubmissionPerUser = null,
    Object? confirmationEmailTemplate = freezed,
    Object? notificationEmails = freezed,
    Object? supportingDocuments = freezed,
    Object? executiveOnly = null,
    Object? committee = freezed,
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
      createdBy: freezed == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      schema: null == schema
          ? _self.schema
          : schema // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      settings: null == settings
          ? _self.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      votingStartsAt: freezed == votingStartsAt
          ? _self.votingStartsAt
          : votingStartsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      votingEndsAt: freezed == votingEndsAt
          ? _self.votingEndsAt
          : votingEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      eligibleMembers: freezed == eligibleMembers
          ? _self.eligibleMembers
          : eligibleMembers // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      resultsPublic: null == resultsPublic
          ? _self.resultsPublic
          : resultsPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      resultsData: freezed == resultsData
          ? _self.resultsData
          : resultsData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      pageCount: null == pageCount
          ? _self.pageCount
          : pageCount // ignore: cast_nullable_to_non_nullable
              as int,
      slug: freezed == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      submissionCount: null == submissionCount
          ? _self.submissionCount
          : submissionCount // ignore: cast_nullable_to_non_nullable
              as int,
      opensAt: freezed == opensAt
          ? _self.opensAt
          : opensAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      closesAt: freezed == closesAt
          ? _self.closesAt
          : closesAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxSubmissions: freezed == maxSubmissions
          ? _self.maxSubmissions
          : maxSubmissions // ignore: cast_nullable_to_non_nullable
              as int?,
      requireLogin: null == requireLogin
          ? _self.requireLogin
          : requireLogin // ignore: cast_nullable_to_non_nullable
              as bool,
      oneSubmissionPerUser: null == oneSubmissionPerUser
          ? _self.oneSubmissionPerUser
          : oneSubmissionPerUser // ignore: cast_nullable_to_non_nullable
              as bool,
      confirmationEmailTemplate: freezed == confirmationEmailTemplate
          ? _self.confirmationEmailTemplate
          : confirmationEmailTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      notificationEmails: freezed == notificationEmails
          ? _self.notificationEmails
          : notificationEmails // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      supportingDocuments: freezed == supportingDocuments
          ? _self.supportingDocuments
          : supportingDocuments // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>?,
      executiveOnly: null == executiveOnly
          ? _self.executiveOnly
          : executiveOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      committee: freezed == committee
          ? _self.committee
          : committee // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [VotingForm].
extension VotingFormPatterns on VotingForm {
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
    TResult Function(_VotingForm value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VotingForm() when $default != null:
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
    TResult Function(_VotingForm value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingForm():
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
    TResult? Function(_VotingForm value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingForm() when $default != null:
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
            @JsonKey(name: 'created_by') String? createdBy,
            String title,
            String? description,
            Map<String, dynamic> schema,
            Map<String, dynamic> settings,
            String status,
            @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
            @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
            @JsonKey(name: 'eligible_members')
            Map<String, dynamic>? eligibleMembers,
            @JsonKey(name: 'results_public')
            @SafeBoolConverter()
            bool resultsPublic,
            @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
            @JsonKey(name: 'page_count') int pageCount,
            String? slug,
            @JsonKey(name: 'submission_count') int submissionCount,
            @JsonKey(name: 'opens_at') DateTime? opensAt,
            @JsonKey(name: 'closes_at') DateTime? closesAt,
            @JsonKey(name: 'max_submissions') int? maxSubmissions,
            @JsonKey(name: 'require_login')
            @SafeBoolConverter()
            bool requireLogin,
            @JsonKey(name: 'one_submission_per_user')
            @SafeBoolTrueConverter()
            bool oneSubmissionPerUser,
            @JsonKey(name: 'confirmation_email_template')
            String? confirmationEmailTemplate,
            @JsonKey(name: 'notification_emails')
            List<String>? notificationEmails,
            @JsonKey(name: 'supporting_documents')
            List<Map<String, dynamic>>? supportingDocuments,
            @JsonKey(name: 'executive_only')
            @SafeBoolConverter()
            bool executiveOnly,
            String? committee)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VotingForm() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.createdBy,
            _that.title,
            _that.description,
            _that.schema,
            _that.settings,
            _that.status,
            _that.votingStartsAt,
            _that.votingEndsAt,
            _that.eligibleMembers,
            _that.resultsPublic,
            _that.resultsData,
            _that.pageCount,
            _that.slug,
            _that.submissionCount,
            _that.opensAt,
            _that.closesAt,
            _that.maxSubmissions,
            _that.requireLogin,
            _that.oneSubmissionPerUser,
            _that.confirmationEmailTemplate,
            _that.notificationEmails,
            _that.supportingDocuments,
            _that.executiveOnly,
            _that.committee);
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
            @JsonKey(name: 'created_by') String? createdBy,
            String title,
            String? description,
            Map<String, dynamic> schema,
            Map<String, dynamic> settings,
            String status,
            @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
            @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
            @JsonKey(name: 'eligible_members')
            Map<String, dynamic>? eligibleMembers,
            @JsonKey(name: 'results_public')
            @SafeBoolConverter()
            bool resultsPublic,
            @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
            @JsonKey(name: 'page_count') int pageCount,
            String? slug,
            @JsonKey(name: 'submission_count') int submissionCount,
            @JsonKey(name: 'opens_at') DateTime? opensAt,
            @JsonKey(name: 'closes_at') DateTime? closesAt,
            @JsonKey(name: 'max_submissions') int? maxSubmissions,
            @JsonKey(name: 'require_login')
            @SafeBoolConverter()
            bool requireLogin,
            @JsonKey(name: 'one_submission_per_user')
            @SafeBoolTrueConverter()
            bool oneSubmissionPerUser,
            @JsonKey(name: 'confirmation_email_template')
            String? confirmationEmailTemplate,
            @JsonKey(name: 'notification_emails')
            List<String>? notificationEmails,
            @JsonKey(name: 'supporting_documents')
            List<Map<String, dynamic>>? supportingDocuments,
            @JsonKey(name: 'executive_only')
            @SafeBoolConverter()
            bool executiveOnly,
            String? committee)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingForm():
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.createdBy,
            _that.title,
            _that.description,
            _that.schema,
            _that.settings,
            _that.status,
            _that.votingStartsAt,
            _that.votingEndsAt,
            _that.eligibleMembers,
            _that.resultsPublic,
            _that.resultsData,
            _that.pageCount,
            _that.slug,
            _that.submissionCount,
            _that.opensAt,
            _that.closesAt,
            _that.maxSubmissions,
            _that.requireLogin,
            _that.oneSubmissionPerUser,
            _that.confirmationEmailTemplate,
            _that.notificationEmails,
            _that.supportingDocuments,
            _that.executiveOnly,
            _that.committee);
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
            @JsonKey(name: 'created_by') String? createdBy,
            String title,
            String? description,
            Map<String, dynamic> schema,
            Map<String, dynamic> settings,
            String status,
            @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
            @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
            @JsonKey(name: 'eligible_members')
            Map<String, dynamic>? eligibleMembers,
            @JsonKey(name: 'results_public')
            @SafeBoolConverter()
            bool resultsPublic,
            @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
            @JsonKey(name: 'page_count') int pageCount,
            String? slug,
            @JsonKey(name: 'submission_count') int submissionCount,
            @JsonKey(name: 'opens_at') DateTime? opensAt,
            @JsonKey(name: 'closes_at') DateTime? closesAt,
            @JsonKey(name: 'max_submissions') int? maxSubmissions,
            @JsonKey(name: 'require_login')
            @SafeBoolConverter()
            bool requireLogin,
            @JsonKey(name: 'one_submission_per_user')
            @SafeBoolTrueConverter()
            bool oneSubmissionPerUser,
            @JsonKey(name: 'confirmation_email_template')
            String? confirmationEmailTemplate,
            @JsonKey(name: 'notification_emails')
            List<String>? notificationEmails,
            @JsonKey(name: 'supporting_documents')
            List<Map<String, dynamic>>? supportingDocuments,
            @JsonKey(name: 'executive_only')
            @SafeBoolConverter()
            bool executiveOnly,
            String? committee)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingForm() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.createdBy,
            _that.title,
            _that.description,
            _that.schema,
            _that.settings,
            _that.status,
            _that.votingStartsAt,
            _that.votingEndsAt,
            _that.eligibleMembers,
            _that.resultsPublic,
            _that.resultsData,
            _that.pageCount,
            _that.slug,
            _that.submissionCount,
            _that.opensAt,
            _that.closesAt,
            _that.maxSubmissions,
            _that.requireLogin,
            _that.oneSubmissionPerUser,
            _that.confirmationEmailTemplate,
            _that.notificationEmails,
            _that.supportingDocuments,
            _that.executiveOnly,
            _that.committee);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VotingForm implements VotingForm {
  const _VotingForm(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt,
      @JsonKey(name: 'created_by') this.createdBy,
      required this.title,
      this.description,
      required final Map<String, dynamic> schema,
      final Map<String, dynamic> settings = const {},
      this.status = 'draft',
      @JsonKey(name: 'voting_starts_at') this.votingStartsAt,
      @JsonKey(name: 'voting_ends_at') this.votingEndsAt,
      @JsonKey(name: 'eligible_members')
      final Map<String, dynamic>? eligibleMembers,
      @JsonKey(name: 'results_public')
      @SafeBoolConverter()
      this.resultsPublic = false,
      @JsonKey(name: 'results_data') final Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') this.pageCount = 1,
      this.slug,
      @JsonKey(name: 'submission_count') this.submissionCount = 0,
      @JsonKey(name: 'opens_at') this.opensAt,
      @JsonKey(name: 'closes_at') this.closesAt,
      @JsonKey(name: 'max_submissions') this.maxSubmissions,
      @JsonKey(name: 'require_login')
      @SafeBoolConverter()
      this.requireLogin = false,
      @JsonKey(name: 'one_submission_per_user')
      @SafeBoolTrueConverter()
      this.oneSubmissionPerUser = true,
      @JsonKey(name: 'confirmation_email_template')
      this.confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails')
      final List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      final List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only')
      @SafeBoolConverter()
      this.executiveOnly = false,
      this.committee})
      : _schema = schema,
        _settings = settings,
        _eligibleMembers = eligibleMembers,
        _resultsData = resultsData,
        _notificationEmails = notificationEmails,
        _supportingDocuments = supportingDocuments;
  factory _VotingForm.fromJson(Map<String, dynamic> json) =>
      _$VotingFormFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @override
  final String title;
  @override
  final String? description;
// Schema contains the voting options and configuration
  final Map<String, dynamic> _schema;
// Schema contains the voting options and configuration
  @override
  Map<String, dynamic> get schema {
    if (_schema is EqualUnmodifiableMapView) return _schema;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_schema);
  }

// Settings for vote configuration
  final Map<String, dynamic> _settings;
// Settings for vote configuration
  @override
  @JsonKey()
  Map<String, dynamic> get settings {
    if (_settings is EqualUnmodifiableMapView) return _settings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_settings);
  }

  @override
  @JsonKey()
  final String status;
// Voting-specific fields from form_schemas
  @override
  @JsonKey(name: 'voting_starts_at')
  final DateTime? votingStartsAt;
  @override
  @JsonKey(name: 'voting_ends_at')
  final DateTime? votingEndsAt;
  final Map<String, dynamic>? _eligibleMembers;
  @override
  @JsonKey(name: 'eligible_members')
  Map<String, dynamic>? get eligibleMembers {
    final value = _eligibleMembers;
    if (value == null) return null;
    if (_eligibleMembers is EqualUnmodifiableMapView) return _eligibleMembers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'results_public')
  @SafeBoolConverter()
  final bool resultsPublic;
  final Map<String, dynamic>? _resultsData;
  @override
  @JsonKey(name: 'results_data')
  Map<String, dynamic>? get resultsData {
    final value = _resultsData;
    if (value == null) return null;
    if (_resultsData is EqualUnmodifiableMapView) return _resultsData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// Page management
  @override
  @JsonKey(name: 'page_count')
  final int pageCount;
// Custom URL slug
  @override
  final String? slug;
// Submission tracking
  @override
  @JsonKey(name: 'submission_count')
  final int submissionCount;
// Scheduling
  @override
  @JsonKey(name: 'opens_at')
  final DateTime? opensAt;
  @override
  @JsonKey(name: 'closes_at')
  final DateTime? closesAt;
// Submission limits
  @override
  @JsonKey(name: 'max_submissions')
  final int? maxSubmissions;
// Access control
  @override
  @JsonKey(name: 'require_login')
  @SafeBoolConverter()
  final bool requireLogin;
  @override
  @JsonKey(name: 'one_submission_per_user')
  @SafeBoolTrueConverter()
  final bool oneSubmissionPerUser;
// Email settings
  @override
  @JsonKey(name: 'confirmation_email_template')
  final String? confirmationEmailTemplate;
  final List<String>? _notificationEmails;
  @override
  @JsonKey(name: 'notification_emails')
  List<String>? get notificationEmails {
    final value = _notificationEmails;
    if (value == null) return null;
    if (_notificationEmails is EqualUnmodifiableListView)
      return _notificationEmails;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// Supporting documents (list of document metadata objects)
  final List<Map<String, dynamic>>? _supportingDocuments;
// Supporting documents (list of document metadata objects)
  @override
  @JsonKey(name: 'supporting_documents')
  List<Map<String, dynamic>>? get supportingDocuments {
    final value = _supportingDocuments;
    if (value == null) return null;
    if (_supportingDocuments is EqualUnmodifiableListView)
      return _supportingDocuments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// Executive Committee Only - restricts voting to executive committee members
  @override
  @JsonKey(name: 'executive_only')
  @SafeBoolConverter()
  final bool executiveOnly;
// Committee association - ties vote to a specific committee
  @override
  final String? committee;

  /// Create a copy of VotingForm
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VotingFormCopyWith<_VotingForm> get copyWith =>
      __$VotingFormCopyWithImpl<_VotingForm>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VotingFormToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VotingForm &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._schema, _schema) &&
            const DeepCollectionEquality().equals(other._settings, _settings) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.votingStartsAt, votingStartsAt) ||
                other.votingStartsAt == votingStartsAt) &&
            (identical(other.votingEndsAt, votingEndsAt) ||
                other.votingEndsAt == votingEndsAt) &&
            const DeepCollectionEquality()
                .equals(other._eligibleMembers, _eligibleMembers) &&
            (identical(other.resultsPublic, resultsPublic) ||
                other.resultsPublic == resultsPublic) &&
            const DeepCollectionEquality()
                .equals(other._resultsData, _resultsData) &&
            (identical(other.pageCount, pageCount) ||
                other.pageCount == pageCount) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.submissionCount, submissionCount) ||
                other.submissionCount == submissionCount) &&
            (identical(other.opensAt, opensAt) || other.opensAt == opensAt) &&
            (identical(other.closesAt, closesAt) ||
                other.closesAt == closesAt) &&
            (identical(other.maxSubmissions, maxSubmissions) ||
                other.maxSubmissions == maxSubmissions) &&
            (identical(other.requireLogin, requireLogin) ||
                other.requireLogin == requireLogin) &&
            (identical(other.oneSubmissionPerUser, oneSubmissionPerUser) ||
                other.oneSubmissionPerUser == oneSubmissionPerUser) &&
            (identical(other.confirmationEmailTemplate,
                    confirmationEmailTemplate) ||
                other.confirmationEmailTemplate == confirmationEmailTemplate) &&
            const DeepCollectionEquality()
                .equals(other._notificationEmails, _notificationEmails) &&
            const DeepCollectionEquality()
                .equals(other._supportingDocuments, _supportingDocuments) &&
            (identical(other.executiveOnly, executiveOnly) ||
                other.executiveOnly == executiveOnly) &&
            (identical(other.committee, committee) ||
                other.committee == committee));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        createdAt,
        updatedAt,
        createdBy,
        title,
        description,
        const DeepCollectionEquality().hash(_schema),
        const DeepCollectionEquality().hash(_settings),
        status,
        votingStartsAt,
        votingEndsAt,
        const DeepCollectionEquality().hash(_eligibleMembers),
        resultsPublic,
        const DeepCollectionEquality().hash(_resultsData),
        pageCount,
        slug,
        submissionCount,
        opensAt,
        closesAt,
        maxSubmissions,
        requireLogin,
        oneSubmissionPerUser,
        confirmationEmailTemplate,
        const DeepCollectionEquality().hash(_notificationEmails),
        const DeepCollectionEquality().hash(_supportingDocuments),
        executiveOnly,
        committee
      ]);

  @override
  String toString() {
    return 'VotingForm(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, title: $title, description: $description, schema: $schema, settings: $settings, status: $status, votingStartsAt: $votingStartsAt, votingEndsAt: $votingEndsAt, eligibleMembers: $eligibleMembers, resultsPublic: $resultsPublic, resultsData: $resultsData, pageCount: $pageCount, slug: $slug, submissionCount: $submissionCount, opensAt: $opensAt, closesAt: $closesAt, maxSubmissions: $maxSubmissions, requireLogin: $requireLogin, oneSubmissionPerUser: $oneSubmissionPerUser, confirmationEmailTemplate: $confirmationEmailTemplate, notificationEmails: $notificationEmails, supportingDocuments: $supportingDocuments, executiveOnly: $executiveOnly, committee: $committee)';
  }
}

/// @nodoc
abstract mixin class _$VotingFormCopyWith<$Res>
    implements $VotingFormCopyWith<$Res> {
  factory _$VotingFormCopyWith(
          _VotingForm value, $Res Function(_VotingForm) _then) =
      __$VotingFormCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt,
      @JsonKey(name: 'created_by') String? createdBy,
      String title,
      String? description,
      Map<String, dynamic> schema,
      Map<String, dynamic> settings,
      String status,
      @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
      @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
      @JsonKey(name: 'eligible_members') Map<String, dynamic>? eligibleMembers,
      @JsonKey(name: 'results_public') @SafeBoolConverter() bool resultsPublic,
      @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') int pageCount,
      String? slug,
      @JsonKey(name: 'submission_count') int submissionCount,
      @JsonKey(name: 'opens_at') DateTime? opensAt,
      @JsonKey(name: 'closes_at') DateTime? closesAt,
      @JsonKey(name: 'max_submissions') int? maxSubmissions,
      @JsonKey(name: 'require_login') @SafeBoolConverter() bool requireLogin,
      @JsonKey(name: 'one_submission_per_user')
      @SafeBoolTrueConverter()
      bool oneSubmissionPerUser,
      @JsonKey(name: 'confirmation_email_template')
      String? confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails') List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only') @SafeBoolConverter() bool executiveOnly,
      String? committee});
}

/// @nodoc
class __$VotingFormCopyWithImpl<$Res> implements _$VotingFormCopyWith<$Res> {
  __$VotingFormCopyWithImpl(this._self, this._then);

  final _VotingForm _self;
  final $Res Function(_VotingForm) _then;

  /// Create a copy of VotingForm
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? createdBy = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? schema = null,
    Object? settings = null,
    Object? status = null,
    Object? votingStartsAt = freezed,
    Object? votingEndsAt = freezed,
    Object? eligibleMembers = freezed,
    Object? resultsPublic = null,
    Object? resultsData = freezed,
    Object? pageCount = null,
    Object? slug = freezed,
    Object? submissionCount = null,
    Object? opensAt = freezed,
    Object? closesAt = freezed,
    Object? maxSubmissions = freezed,
    Object? requireLogin = null,
    Object? oneSubmissionPerUser = null,
    Object? confirmationEmailTemplate = freezed,
    Object? notificationEmails = freezed,
    Object? supportingDocuments = freezed,
    Object? executiveOnly = null,
    Object? committee = freezed,
  }) {
    return _then(_VotingForm(
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
      createdBy: freezed == createdBy
          ? _self.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      schema: null == schema
          ? _self._schema
          : schema // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      settings: null == settings
          ? _self._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      votingStartsAt: freezed == votingStartsAt
          ? _self.votingStartsAt
          : votingStartsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      votingEndsAt: freezed == votingEndsAt
          ? _self.votingEndsAt
          : votingEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      eligibleMembers: freezed == eligibleMembers
          ? _self._eligibleMembers
          : eligibleMembers // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      resultsPublic: null == resultsPublic
          ? _self.resultsPublic
          : resultsPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      resultsData: freezed == resultsData
          ? _self._resultsData
          : resultsData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      pageCount: null == pageCount
          ? _self.pageCount
          : pageCount // ignore: cast_nullable_to_non_nullable
              as int,
      slug: freezed == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      submissionCount: null == submissionCount
          ? _self.submissionCount
          : submissionCount // ignore: cast_nullable_to_non_nullable
              as int,
      opensAt: freezed == opensAt
          ? _self.opensAt
          : opensAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      closesAt: freezed == closesAt
          ? _self.closesAt
          : closesAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxSubmissions: freezed == maxSubmissions
          ? _self.maxSubmissions
          : maxSubmissions // ignore: cast_nullable_to_non_nullable
              as int?,
      requireLogin: null == requireLogin
          ? _self.requireLogin
          : requireLogin // ignore: cast_nullable_to_non_nullable
              as bool,
      oneSubmissionPerUser: null == oneSubmissionPerUser
          ? _self.oneSubmissionPerUser
          : oneSubmissionPerUser // ignore: cast_nullable_to_non_nullable
              as bool,
      confirmationEmailTemplate: freezed == confirmationEmailTemplate
          ? _self.confirmationEmailTemplate
          : confirmationEmailTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      notificationEmails: freezed == notificationEmails
          ? _self._notificationEmails
          : notificationEmails // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      supportingDocuments: freezed == supportingDocuments
          ? _self._supportingDocuments
          : supportingDocuments // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>?,
      executiveOnly: null == executiveOnly
          ? _self.executiveOnly
          : executiveOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      committee: freezed == committee
          ? _self.committee
          : committee // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$VotingOption {
  String get id;
  String get label;
  String? get description;
  int get votes;

  /// Create a copy of VotingOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VotingOptionCopyWith<VotingOption> get copyWith =>
      _$VotingOptionCopyWithImpl<VotingOption>(
          this as VotingOption, _$identity);

  /// Serializes this VotingOption to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VotingOption &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.votes, votes) || other.votes == votes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, label, description, votes);

  @override
  String toString() {
    return 'VotingOption(id: $id, label: $label, description: $description, votes: $votes)';
  }
}

/// @nodoc
abstract mixin class $VotingOptionCopyWith<$Res> {
  factory $VotingOptionCopyWith(
          VotingOption value, $Res Function(VotingOption) _then) =
      _$VotingOptionCopyWithImpl;
  @useResult
  $Res call({String id, String label, String? description, int votes});
}

/// @nodoc
class _$VotingOptionCopyWithImpl<$Res> implements $VotingOptionCopyWith<$Res> {
  _$VotingOptionCopyWithImpl(this._self, this._then);

  final VotingOption _self;
  final $Res Function(VotingOption) _then;

  /// Create a copy of VotingOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? description = freezed,
    Object? votes = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      votes: null == votes
          ? _self.votes
          : votes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [VotingOption].
extension VotingOptionPatterns on VotingOption {
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
    TResult Function(_VotingOption value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VotingOption() when $default != null:
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
    TResult Function(_VotingOption value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingOption():
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
    TResult? Function(_VotingOption value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingOption() when $default != null:
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
    TResult Function(String id, String label, String? description, int votes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VotingOption() when $default != null:
        return $default(_that.id, _that.label, _that.description, _that.votes);
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
    TResult Function(String id, String label, String? description, int votes)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingOption():
        return $default(_that.id, _that.label, _that.description, _that.votes);
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
    TResult? Function(String id, String label, String? description, int votes)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VotingOption() when $default != null:
        return $default(_that.id, _that.label, _that.description, _that.votes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _VotingOption implements VotingOption {
  const _VotingOption(
      {required this.id,
      required this.label,
      this.description,
      this.votes = 0});
  factory _VotingOption.fromJson(Map<String, dynamic> json) =>
      _$VotingOptionFromJson(json);

  @override
  final String id;
  @override
  final String label;
  @override
  final String? description;
  @override
  @JsonKey()
  final int votes;

  /// Create a copy of VotingOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VotingOptionCopyWith<_VotingOption> get copyWith =>
      __$VotingOptionCopyWithImpl<_VotingOption>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VotingOptionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VotingOption &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.votes, votes) || other.votes == votes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, label, description, votes);

  @override
  String toString() {
    return 'VotingOption(id: $id, label: $label, description: $description, votes: $votes)';
  }
}

/// @nodoc
abstract mixin class _$VotingOptionCopyWith<$Res>
    implements $VotingOptionCopyWith<$Res> {
  factory _$VotingOptionCopyWith(
          _VotingOption value, $Res Function(_VotingOption) _then) =
      __$VotingOptionCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String label, String? description, int votes});
}

/// @nodoc
class __$VotingOptionCopyWithImpl<$Res>
    implements _$VotingOptionCopyWith<$Res> {
  __$VotingOptionCopyWithImpl(this._self, this._then);

  final _VotingOption _self;
  final $Res Function(_VotingOption) _then;

  /// Create a copy of VotingOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? description = freezed,
    Object? votes = null,
  }) {
    return _then(_VotingOption(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      votes: null == votes
          ? _self.votes
          : votes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$Vote {
  String get id;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'voting_form_id')
  String get votingFormId;
  @JsonKey(name: 'member_id')
  String get memberId;
  @JsonKey(name: 'vote_data')
  Map<String, dynamic> get voteData;

  /// Create a copy of Vote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VoteCopyWith<Vote> get copyWith =>
      _$VoteCopyWithImpl<Vote>(this as Vote, _$identity);

  /// Serializes this Vote to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Vote &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.votingFormId, votingFormId) ||
                other.votingFormId == votingFormId) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId) &&
            const DeepCollectionEquality().equals(other.voteData, voteData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, votingFormId,
      memberId, const DeepCollectionEquality().hash(voteData));

  @override
  String toString() {
    return 'Vote(id: $id, createdAt: $createdAt, votingFormId: $votingFormId, memberId: $memberId, voteData: $voteData)';
  }
}

/// @nodoc
abstract mixin class $VoteCopyWith<$Res> {
  factory $VoteCopyWith(Vote value, $Res Function(Vote) _then) =
      _$VoteCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'voting_form_id') String votingFormId,
      @JsonKey(name: 'member_id') String memberId,
      @JsonKey(name: 'vote_data') Map<String, dynamic> voteData});
}

/// @nodoc
class _$VoteCopyWithImpl<$Res> implements $VoteCopyWith<$Res> {
  _$VoteCopyWithImpl(this._self, this._then);

  final Vote _self;
  final $Res Function(Vote) _then;

  /// Create a copy of Vote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? votingFormId = null,
    Object? memberId = null,
    Object? voteData = null,
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
      votingFormId: null == votingFormId
          ? _self.votingFormId
          : votingFormId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      voteData: null == voteData
          ? _self.voteData
          : voteData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// Adds pattern-matching-related methods to [Vote].
extension VotePatterns on Vote {
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
    TResult Function(_Vote value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Vote() when $default != null:
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
    TResult Function(_Vote value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vote():
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
    TResult? Function(_Vote value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vote() when $default != null:
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
            @JsonKey(name: 'voting_form_id') String votingFormId,
            @JsonKey(name: 'member_id') String memberId,
            @JsonKey(name: 'vote_data') Map<String, dynamic> voteData)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Vote() when $default != null:
        return $default(_that.id, _that.createdAt, _that.votingFormId,
            _that.memberId, _that.voteData);
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
            @JsonKey(name: 'voting_form_id') String votingFormId,
            @JsonKey(name: 'member_id') String memberId,
            @JsonKey(name: 'vote_data') Map<String, dynamic> voteData)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vote():
        return $default(_that.id, _that.createdAt, _that.votingFormId,
            _that.memberId, _that.voteData);
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
            @JsonKey(name: 'voting_form_id') String votingFormId,
            @JsonKey(name: 'member_id') String memberId,
            @JsonKey(name: 'vote_data') Map<String, dynamic> voteData)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vote() when $default != null:
        return $default(_that.id, _that.createdAt, _that.votingFormId,
            _that.memberId, _that.voteData);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Vote implements Vote {
  const _Vote(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'voting_form_id') required this.votingFormId,
      @JsonKey(name: 'member_id') required this.memberId,
      @JsonKey(name: 'vote_data') required final Map<String, dynamic> voteData})
      : _voteData = voteData;
  factory _Vote.fromJson(Map<String, dynamic> json) => _$VoteFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'voting_form_id')
  final String votingFormId;
  @override
  @JsonKey(name: 'member_id')
  final String memberId;
  final Map<String, dynamic> _voteData;
  @override
  @JsonKey(name: 'vote_data')
  Map<String, dynamic> get voteData {
    if (_voteData is EqualUnmodifiableMapView) return _voteData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_voteData);
  }

  /// Create a copy of Vote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VoteCopyWith<_Vote> get copyWith =>
      __$VoteCopyWithImpl<_Vote>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$VoteToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Vote &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.votingFormId, votingFormId) ||
                other.votingFormId == votingFormId) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId) &&
            const DeepCollectionEquality().equals(other._voteData, _voteData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, votingFormId,
      memberId, const DeepCollectionEquality().hash(_voteData));

  @override
  String toString() {
    return 'Vote(id: $id, createdAt: $createdAt, votingFormId: $votingFormId, memberId: $memberId, voteData: $voteData)';
  }
}

/// @nodoc
abstract mixin class _$VoteCopyWith<$Res> implements $VoteCopyWith<$Res> {
  factory _$VoteCopyWith(_Vote value, $Res Function(_Vote) _then) =
      __$VoteCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'voting_form_id') String votingFormId,
      @JsonKey(name: 'member_id') String memberId,
      @JsonKey(name: 'vote_data') Map<String, dynamic> voteData});
}

/// @nodoc
class __$VoteCopyWithImpl<$Res> implements _$VoteCopyWith<$Res> {
  __$VoteCopyWithImpl(this._self, this._then);

  final _Vote _self;
  final $Res Function(_Vote) _then;

  /// Create a copy of Vote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? votingFormId = null,
    Object? memberId = null,
    Object? voteData = null,
  }) {
    return _then(_Vote(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      votingFormId: null == votingFormId
          ? _self.votingFormId
          : votingFormId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      voteData: null == voteData
          ? _self._voteData
          : voteData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

// dart format on
