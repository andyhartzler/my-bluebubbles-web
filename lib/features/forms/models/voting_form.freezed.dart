// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voting_form.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

VotingForm _$VotingFormFromJson(Map<String, dynamic> json) {
  return _VotingForm.fromJson(json);
}

/// @nodoc
mixin _$VotingForm {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String? get createdBy => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  Map<String, dynamic> get schema => throw _privateConstructorUsedError;
  Map<String, dynamic> get settings => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'voting_starts_at')
  DateTime? get votingStartsAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'voting_ends_at')
  DateTime? get votingEndsAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'eligible_members')
  Map<String, dynamic>? get eligibleMembers =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'results_public')
  bool get resultsPublic => throw _privateConstructorUsedError;
  @JsonKey(name: 'results_data')
  Map<String, dynamic>? get resultsData => throw _privateConstructorUsedError;
  @JsonKey(name: 'page_count')
  int get pageCount => throw _privateConstructorUsedError;
  String? get slug => throw _privateConstructorUsedError;
  @JsonKey(name: 'submission_count')
  int get submissionCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'opens_at')
  DateTime? get opensAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'closes_at')
  DateTime? get closesAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_submissions')
  int? get maxSubmissions => throw _privateConstructorUsedError;
  @JsonKey(name: 'require_login')
  bool get requireLogin => throw _privateConstructorUsedError;
  @JsonKey(name: 'one_submission_per_user')
  bool get oneSubmissionPerUser => throw _privateConstructorUsedError;
  @JsonKey(name: 'confirmation_email_template')
  String? get confirmationEmailTemplate => throw _privateConstructorUsedError;
  @JsonKey(name: 'notification_emails')
  List<String>? get notificationEmails => throw _privateConstructorUsedError;
  @JsonKey(name: 'supporting_documents')
  List<Map<String, dynamic>>? get supportingDocuments =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'executive_only')
  bool get executiveOnly => throw _privateConstructorUsedError;
  String? get committee => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VotingFormCopyWith<VotingForm> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VotingFormCopyWith<$Res> {
  factory $VotingFormCopyWith(
          VotingForm value, $Res Function(VotingForm) then) =
      _$VotingFormCopyWithImpl<$Res, VotingForm>;
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
      @JsonKey(name: 'results_public') bool resultsPublic,
      @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') int pageCount,
      String? slug,
      @JsonKey(name: 'submission_count') int submissionCount,
      @JsonKey(name: 'opens_at') DateTime? opensAt,
      @JsonKey(name: 'closes_at') DateTime? closesAt,
      @JsonKey(name: 'max_submissions') int? maxSubmissions,
      @JsonKey(name: 'require_login') bool requireLogin,
      @JsonKey(name: 'one_submission_per_user') bool oneSubmissionPerUser,
      @JsonKey(name: 'confirmation_email_template')
      String? confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails') List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only') bool executiveOnly,
      String? committee});
}

/// @nodoc
class _$VotingFormCopyWithImpl<$Res, $Val extends VotingForm>
    implements $VotingFormCopyWith<$Res> {
  _$VotingFormCopyWithImpl(this._value, this._then);

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
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      schema: null == schema
          ? _value.schema
          : schema // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      settings: null == settings
          ? _value.settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      votingStartsAt: freezed == votingStartsAt
          ? _value.votingStartsAt
          : votingStartsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      votingEndsAt: freezed == votingEndsAt
          ? _value.votingEndsAt
          : votingEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      eligibleMembers: freezed == eligibleMembers
          ? _value.eligibleMembers
          : eligibleMembers // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      resultsPublic: null == resultsPublic
          ? _value.resultsPublic
          : resultsPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      resultsData: freezed == resultsData
          ? _value.resultsData
          : resultsData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      pageCount: null == pageCount
          ? _value.pageCount
          : pageCount // ignore: cast_nullable_to_non_nullable
              as int,
      slug: freezed == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      submissionCount: null == submissionCount
          ? _value.submissionCount
          : submissionCount // ignore: cast_nullable_to_non_nullable
              as int,
      opensAt: freezed == opensAt
          ? _value.opensAt
          : opensAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      closesAt: freezed == closesAt
          ? _value.closesAt
          : closesAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxSubmissions: freezed == maxSubmissions
          ? _value.maxSubmissions
          : maxSubmissions // ignore: cast_nullable_to_non_nullable
              as int?,
      requireLogin: null == requireLogin
          ? _value.requireLogin
          : requireLogin // ignore: cast_nullable_to_non_nullable
              as bool,
      oneSubmissionPerUser: null == oneSubmissionPerUser
          ? _value.oneSubmissionPerUser
          : oneSubmissionPerUser // ignore: cast_nullable_to_non_nullable
              as bool,
      confirmationEmailTemplate: freezed == confirmationEmailTemplate
          ? _value.confirmationEmailTemplate
          : confirmationEmailTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      notificationEmails: freezed == notificationEmails
          ? _value.notificationEmails
          : notificationEmails // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      supportingDocuments: freezed == supportingDocuments
          ? _value.supportingDocuments
          : supportingDocuments // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>?,
      executiveOnly: null == executiveOnly
          ? _value.executiveOnly
          : executiveOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      committee: freezed == committee
          ? _value.committee
          : committee // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VotingFormImplCopyWith<$Res>
    implements $VotingFormCopyWith<$Res> {
  factory _$$VotingFormImplCopyWith(
          _$VotingFormImpl value, $Res Function(_$VotingFormImpl) then) =
      __$$VotingFormImplCopyWithImpl<$Res>;
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
      @JsonKey(name: 'results_public') bool resultsPublic,
      @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') int pageCount,
      String? slug,
      @JsonKey(name: 'submission_count') int submissionCount,
      @JsonKey(name: 'opens_at') DateTime? opensAt,
      @JsonKey(name: 'closes_at') DateTime? closesAt,
      @JsonKey(name: 'max_submissions') int? maxSubmissions,
      @JsonKey(name: 'require_login') bool requireLogin,
      @JsonKey(name: 'one_submission_per_user') bool oneSubmissionPerUser,
      @JsonKey(name: 'confirmation_email_template')
      String? confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails') List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only') bool executiveOnly,
      String? committee});
}

/// @nodoc
class __$$VotingFormImplCopyWithImpl<$Res>
    extends _$VotingFormCopyWithImpl<$Res, _$VotingFormImpl>
    implements _$$VotingFormImplCopyWith<$Res> {
  __$$VotingFormImplCopyWithImpl(
      _$VotingFormImpl _value, $Res Function(_$VotingFormImpl) _then)
      : super(_value, _then);

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
    return _then(_$VotingFormImpl(
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
      createdBy: freezed == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String?,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      schema: null == schema
          ? _value._schema
          : schema // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      settings: null == settings
          ? _value._settings
          : settings // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      votingStartsAt: freezed == votingStartsAt
          ? _value.votingStartsAt
          : votingStartsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      votingEndsAt: freezed == votingEndsAt
          ? _value.votingEndsAt
          : votingEndsAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      eligibleMembers: freezed == eligibleMembers
          ? _value._eligibleMembers
          : eligibleMembers // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      resultsPublic: null == resultsPublic
          ? _value.resultsPublic
          : resultsPublic // ignore: cast_nullable_to_non_nullable
              as bool,
      resultsData: freezed == resultsData
          ? _value._resultsData
          : resultsData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      pageCount: null == pageCount
          ? _value.pageCount
          : pageCount // ignore: cast_nullable_to_non_nullable
              as int,
      slug: freezed == slug
          ? _value.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String?,
      submissionCount: null == submissionCount
          ? _value.submissionCount
          : submissionCount // ignore: cast_nullable_to_non_nullable
              as int,
      opensAt: freezed == opensAt
          ? _value.opensAt
          : opensAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      closesAt: freezed == closesAt
          ? _value.closesAt
          : closesAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxSubmissions: freezed == maxSubmissions
          ? _value.maxSubmissions
          : maxSubmissions // ignore: cast_nullable_to_non_nullable
              as int?,
      requireLogin: null == requireLogin
          ? _value.requireLogin
          : requireLogin // ignore: cast_nullable_to_non_nullable
              as bool,
      oneSubmissionPerUser: null == oneSubmissionPerUser
          ? _value.oneSubmissionPerUser
          : oneSubmissionPerUser // ignore: cast_nullable_to_non_nullable
              as bool,
      confirmationEmailTemplate: freezed == confirmationEmailTemplate
          ? _value.confirmationEmailTemplate
          : confirmationEmailTemplate // ignore: cast_nullable_to_non_nullable
              as String?,
      notificationEmails: freezed == notificationEmails
          ? _value._notificationEmails
          : notificationEmails // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      supportingDocuments: freezed == supportingDocuments
          ? _value._supportingDocuments
          : supportingDocuments // ignore: cast_nullable_to_non_nullable
              as List<Map<String, dynamic>>?,
      executiveOnly: null == executiveOnly
          ? _value.executiveOnly
          : executiveOnly // ignore: cast_nullable_to_non_nullable
              as bool,
      committee: freezed == committee
          ? _value.committee
          : committee // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VotingFormImpl implements _VotingForm {
  const _$VotingFormImpl(
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
      @JsonKey(name: 'results_public') this.resultsPublic = false,
      @JsonKey(name: 'results_data') final Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') this.pageCount = 1,
      this.slug,
      @JsonKey(name: 'submission_count') this.submissionCount = 0,
      @JsonKey(name: 'opens_at') this.opensAt,
      @JsonKey(name: 'closes_at') this.closesAt,
      @JsonKey(name: 'max_submissions') this.maxSubmissions,
      @JsonKey(name: 'require_login') this.requireLogin = false,
      @JsonKey(name: 'one_submission_per_user') this.oneSubmissionPerUser = true,
      @JsonKey(name: 'confirmation_email_template')
      this.confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails') final List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      final List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only') this.executiveOnly = false,
      this.committee})
      : _schema = schema,
        _settings = settings,
        _eligibleMembers = eligibleMembers,
        _resultsData = resultsData,
        _notificationEmails = notificationEmails,
        _supportingDocuments = supportingDocuments;

  factory _$VotingFormImpl.fromJson(Map<String, dynamic> json) =>
      _$$VotingFormImplFromJson(json);

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
  final Map<String, dynamic> _schema;
  @override
  Map<String, dynamic> get schema {
    if (_schema is EqualUnmodifiableMapView) return _schema;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_schema);
  }

  final Map<String, dynamic> _settings;
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

  @override
  @JsonKey(name: 'page_count')
  final int pageCount;
  @override
  final String? slug;
  @override
  @JsonKey(name: 'submission_count')
  final int submissionCount;
  @override
  @JsonKey(name: 'opens_at')
  final DateTime? opensAt;
  @override
  @JsonKey(name: 'closes_at')
  final DateTime? closesAt;
  @override
  @JsonKey(name: 'max_submissions')
  final int? maxSubmissions;
  @override
  @JsonKey(name: 'require_login')
  final bool requireLogin;
  @override
  @JsonKey(name: 'one_submission_per_user')
  final bool oneSubmissionPerUser;
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

  final List<Map<String, dynamic>>? _supportingDocuments;
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

  @override
  @JsonKey(name: 'executive_only')
  final bool executiveOnly;
  @override
  final String? committee;

  @override
  String toString() {
    return 'VotingForm(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy, title: $title, description: $description, schema: $schema, settings: $settings, status: $status, votingStartsAt: $votingStartsAt, votingEndsAt: $votingEndsAt, eligibleMembers: $eligibleMembers, resultsPublic: $resultsPublic, resultsData: $resultsData, pageCount: $pageCount, slug: $slug, submissionCount: $submissionCount, opensAt: $opensAt, closesAt: $closesAt, maxSubmissions: $maxSubmissions, requireLogin: $requireLogin, oneSubmissionPerUser: $oneSubmissionPerUser, confirmationEmailTemplate: $confirmationEmailTemplate, notificationEmails: $notificationEmails, supportingDocuments: $supportingDocuments, executiveOnly: $executiveOnly, committee: $committee)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VotingFormImpl &&
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

  @JsonKey(ignore: true)
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

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VotingFormImplCopyWith<_$VotingFormImpl> get copyWith =>
      __$$VotingFormImplCopyWithImpl<_$VotingFormImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VotingFormImplToJson(
      this,
    );
  }
}

abstract class _VotingForm implements VotingForm {
  const factory _VotingForm(
      {required final String id,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'updated_at') required final DateTime updatedAt,
      @JsonKey(name: 'created_by') final String? createdBy,
      required final String title,
      final String? description,
      required final Map<String, dynamic> schema,
      final Map<String, dynamic> settings,
      final String status,
      @JsonKey(name: 'voting_starts_at') final DateTime? votingStartsAt,
      @JsonKey(name: 'voting_ends_at') final DateTime? votingEndsAt,
      @JsonKey(name: 'eligible_members')
      final Map<String, dynamic>? eligibleMembers,
      @JsonKey(name: 'results_public') final bool resultsPublic,
      @JsonKey(name: 'results_data') final Map<String, dynamic>? resultsData,
      @JsonKey(name: 'page_count') final int pageCount,
      final String? slug,
      @JsonKey(name: 'submission_count') final int submissionCount,
      @JsonKey(name: 'opens_at') final DateTime? opensAt,
      @JsonKey(name: 'closes_at') final DateTime? closesAt,
      @JsonKey(name: 'max_submissions') final int? maxSubmissions,
      @JsonKey(name: 'require_login') final bool requireLogin,
      @JsonKey(name: 'one_submission_per_user') final bool oneSubmissionPerUser,
      @JsonKey(name: 'confirmation_email_template')
      final String? confirmationEmailTemplate,
      @JsonKey(name: 'notification_emails') final List<String>? notificationEmails,
      @JsonKey(name: 'supporting_documents')
      final List<Map<String, dynamic>>? supportingDocuments,
      @JsonKey(name: 'executive_only') final bool executiveOnly,
      final String? committee}) = _$VotingFormImpl;

  factory _VotingForm.fromJson(Map<String, dynamic> json) =
      _$VotingFormImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'created_by')
  String? get createdBy;
  @override
  String get title;
  @override
  String? get description;
  @override
  Map<String, dynamic> get schema;
  @override
  Map<String, dynamic> get settings;
  @override
  String get status;
  @override
  @JsonKey(name: 'voting_starts_at')
  DateTime? get votingStartsAt;
  @override
  @JsonKey(name: 'voting_ends_at')
  DateTime? get votingEndsAt;
  @override
  @JsonKey(name: 'eligible_members')
  Map<String, dynamic>? get eligibleMembers;
  @override
  @JsonKey(name: 'results_public')
  bool get resultsPublic;
  @override
  @JsonKey(name: 'results_data')
  Map<String, dynamic>? get resultsData;
  @override
  @JsonKey(name: 'page_count')
  int get pageCount;
  @override
  String? get slug;
  @override
  @JsonKey(name: 'submission_count')
  int get submissionCount;
  @override
  @JsonKey(name: 'opens_at')
  DateTime? get opensAt;
  @override
  @JsonKey(name: 'closes_at')
  DateTime? get closesAt;
  @override
  @JsonKey(name: 'max_submissions')
  int? get maxSubmissions;
  @override
  @JsonKey(name: 'require_login')
  bool get requireLogin;
  @override
  @JsonKey(name: 'one_submission_per_user')
  bool get oneSubmissionPerUser;
  @override
  @JsonKey(name: 'confirmation_email_template')
  String? get confirmationEmailTemplate;
  @override
  @JsonKey(name: 'notification_emails')
  List<String>? get notificationEmails;
  @override
  @JsonKey(name: 'supporting_documents')
  List<Map<String, dynamic>>? get supportingDocuments;
  @override
  @JsonKey(name: 'executive_only')
  bool get executiveOnly;
  @override
  String? get committee;
  @override
  @JsonKey(ignore: true)
  _$$VotingFormImplCopyWith<_$VotingFormImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VotingOption _$VotingOptionFromJson(Map<String, dynamic> json) {
  return _VotingOption.fromJson(json);
}

/// @nodoc
mixin _$VotingOption {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  int get votes => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VotingOptionCopyWith<VotingOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VotingOptionCopyWith<$Res> {
  factory $VotingOptionCopyWith(
          VotingOption value, $Res Function(VotingOption) then) =
      _$VotingOptionCopyWithImpl<$Res, VotingOption>;
  @useResult
  $Res call({String id, String label, String? description, int votes});
}

/// @nodoc
class _$VotingOptionCopyWithImpl<$Res, $Val extends VotingOption>
    implements $VotingOptionCopyWith<$Res> {
  _$VotingOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? description = freezed,
    Object? votes = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      votes: null == votes
          ? _value.votes
          : votes // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VotingOptionImplCopyWith<$Res>
    implements $VotingOptionCopyWith<$Res> {
  factory _$$VotingOptionImplCopyWith(
          _$VotingOptionImpl value, $Res Function(_$VotingOptionImpl) then) =
      __$$VotingOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String label, String? description, int votes});
}

/// @nodoc
class __$$VotingOptionImplCopyWithImpl<$Res>
    extends _$VotingOptionCopyWithImpl<$Res, _$VotingOptionImpl>
    implements _$$VotingOptionImplCopyWith<$Res> {
  __$$VotingOptionImplCopyWithImpl(
      _$VotingOptionImpl _value, $Res Function(_$VotingOptionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? description = freezed,
    Object? votes = null,
  }) {
    return _then(_$VotingOptionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      votes: null == votes
          ? _value.votes
          : votes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VotingOptionImpl implements _VotingOption {
  const _$VotingOptionImpl(
      {required this.id,
      required this.label,
      this.description,
      this.votes = 0});

  factory _$VotingOptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$VotingOptionImplFromJson(json);

  @override
  final String id;
  @override
  final String label;
  @override
  final String? description;
  @override
  @JsonKey()
  final int votes;

  @override
  String toString() {
    return 'VotingOption(id: $id, label: $label, description: $description, votes: $votes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VotingOptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.votes, votes) || other.votes == votes));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, label, description, votes);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VotingOptionImplCopyWith<_$VotingOptionImpl> get copyWith =>
      __$$VotingOptionImplCopyWithImpl<_$VotingOptionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VotingOptionImplToJson(
      this,
    );
  }
}

abstract class _VotingOption implements VotingOption {
  const factory _VotingOption(
      {required final String id,
      required final String label,
      final String? description,
      final int votes}) = _$VotingOptionImpl;

  factory _VotingOption.fromJson(Map<String, dynamic> json) =
      _$VotingOptionImpl.fromJson;

  @override
  String get id;
  @override
  String get label;
  @override
  String? get description;
  @override
  int get votes;
  @override
  @JsonKey(ignore: true)
  _$$VotingOptionImplCopyWith<_$VotingOptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Vote _$VoteFromJson(Map<String, dynamic> json) {
  return _Vote.fromJson(json);
}

/// @nodoc
mixin _$Vote {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'voting_form_id')
  String get votingFormId => throw _privateConstructorUsedError;
  @JsonKey(name: 'member_id')
  String get memberId => throw _privateConstructorUsedError;
  @JsonKey(name: 'vote_data')
  Map<String, dynamic> get voteData => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $VoteCopyWith<Vote> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VoteCopyWith<$Res> {
  factory $VoteCopyWith(Vote value, $Res Function(Vote) then) =
      _$VoteCopyWithImpl<$Res, Vote>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'voting_form_id') String votingFormId,
      @JsonKey(name: 'member_id') String memberId,
      @JsonKey(name: 'vote_data') Map<String, dynamic> voteData});
}

/// @nodoc
class _$VoteCopyWithImpl<$Res, $Val extends Vote>
    implements $VoteCopyWith<$Res> {
  _$VoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? votingFormId = null,
    Object? memberId = null,
    Object? voteData = null,
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
      votingFormId: null == votingFormId
          ? _value.votingFormId
          : votingFormId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      voteData: null == voteData
          ? _value.voteData
          : voteData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VoteImplCopyWith<$Res> implements $VoteCopyWith<$Res> {
  factory _$$VoteImplCopyWith(
          _$VoteImpl value, $Res Function(_$VoteImpl) then) =
      __$$VoteImplCopyWithImpl<$Res>;
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
class __$$VoteImplCopyWithImpl<$Res>
    extends _$VoteCopyWithImpl<$Res, _$VoteImpl>
    implements _$$VoteImplCopyWith<$Res> {
  __$$VoteImplCopyWithImpl(_$VoteImpl _value, $Res Function(_$VoteImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? votingFormId = null,
    Object? memberId = null,
    Object? voteData = null,
  }) {
    return _then(_$VoteImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      votingFormId: null == votingFormId
          ? _value.votingFormId
          : votingFormId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      voteData: null == voteData
          ? _value._voteData
          : voteData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VoteImpl implements _Vote {
  const _$VoteImpl(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'voting_form_id') required this.votingFormId,
      @JsonKey(name: 'member_id') required this.memberId,
      @JsonKey(name: 'vote_data') required final Map<String, dynamic> voteData})
      : _voteData = voteData;

  factory _$VoteImpl.fromJson(Map<String, dynamic> json) =>
      _$$VoteImplFromJson(json);

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

  @override
  String toString() {
    return 'Vote(id: $id, createdAt: $createdAt, votingFormId: $votingFormId, memberId: $memberId, voteData: $voteData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VoteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.votingFormId, votingFormId) ||
                other.votingFormId == votingFormId) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId) &&
            const DeepCollectionEquality().equals(other._voteData, _voteData));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, votingFormId,
      memberId, const DeepCollectionEquality().hash(_voteData));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$VoteImplCopyWith<_$VoteImpl> get copyWith =>
      __$$VoteImplCopyWithImpl<_$VoteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VoteImplToJson(
      this,
    );
  }
}

abstract class _Vote implements Vote {
  const factory _Vote(
      {required final String id,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'voting_form_id') required final String votingFormId,
      @JsonKey(name: 'member_id') required final String memberId,
      @JsonKey(name: 'vote_data')
      required final Map<String, dynamic> voteData}) = _$VoteImpl;

  factory _Vote.fromJson(Map<String, dynamic> json) = _$VoteImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'voting_form_id')
  String get votingFormId;
  @override
  @JsonKey(name: 'member_id')
  String get memberId;
  @override
  @JsonKey(name: 'vote_data')
  Map<String, dynamic> get voteData;
  @override
  @JsonKey(ignore: true)
  _$$VoteImplCopyWith<_$VoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
