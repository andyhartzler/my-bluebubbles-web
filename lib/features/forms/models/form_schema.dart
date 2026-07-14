import 'dart:convert';
import 'form_field_config.dart';
import 'identity_config.dart';

/// Helper to safely coerce values to bool (handles Supabase returning int for bool)
bool _coerceBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

/// FormSchema model - manually implemented to handle flexible schema parsing
class FormSchema {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  // Form Metadata
  final String title;
  final String? description;
  final String formType;

  // Form Schema - typed as FormSchemaData for proper field access
  final FormSchemaData schema;

  // Settings
  final Map<String, dynamic> settings;

  // Status
  final String status;

  // Voting-specific fields (only used if form_type = 'vote')
  final DateTime? votingStartsAt;
  final DateTime? votingEndsAt;
  final Map<String, dynamic>? eligibleMembers;
  final bool resultsPublic;
  final Map<String, dynamic>? resultsData;

  // Page management
  final int pageCount;

  // Template reference
  final String? templateId;

  // Custom URL slug
  final String? slug;

  // Submission tracking (auto-calculated via trigger)
  final int submissionCount;

  // Scheduling
  final DateTime? opensAt;
  final DateTime? closesAt;

  // Submission limits
  final int? maxSubmissions;

  // Access control
  final bool requireLogin;
  final bool oneSubmissionPerUser;

  // Email settings
  final String? confirmationEmailTemplate;
  final List<String>? notificationEmails;

  // Supporting documents (list of document metadata objects)
  final List<Map<String, dynamic>>? supportingDocuments;

  // Public form - if true, show preview on Forms homepage
  final bool publicForm;

  // Preview text - used for preview tiles and social share text
  final String? previewText;

  const FormSchema({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    required this.title,
    this.description,
    required this.formType,
    required this.schema,
    this.settings = const {},
    this.status = 'draft',
    this.votingStartsAt,
    this.votingEndsAt,
    this.eligibleMembers,
    this.resultsPublic = false,
    this.resultsData,
    this.pageCount = 1,
    this.templateId,
    this.slug,
    this.submissionCount = 0,
    this.opensAt,
    this.closesAt,
    this.maxSubmissions,
    this.requireLogin = false,
    this.oneSubmissionPerUser = false,
    this.confirmationEmailTemplate,
    this.notificationEmails,
    this.supportingDocuments,
    this.publicForm = false,
    this.previewText,
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    // Handle schema field - can be a Map or a JSON string
    Map<String, dynamic> schemaMap;
    final rawSchema = json['schema'];
    if (rawSchema is String) {
      try {
        schemaMap = jsonDecode(rawSchema) as Map<String, dynamic>;
      } catch (e) {
        schemaMap = {};
      }
    } else if (rawSchema is Map<String, dynamic>) {
      schemaMap = rawSchema;
    } else {
      schemaMap = {};
    }

    // Parse schema into FormSchemaData
    final schemaData = FormSchemaData.fromJson(schemaMap);

    // Handle notification_emails - can be null or a list
    List<String>? notificationEmails;
    final rawEmails = json['notification_emails'];
    if (rawEmails is List) {
      notificationEmails = rawEmails.map((e) => e.toString()).toList();
    }

    // Handle supporting_documents - can be null or a list
    List<Map<String, dynamic>>? supportingDocuments;
    final rawDocs = json['supporting_documents'];
    if (rawDocs is List) {
      supportingDocuments = rawDocs
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return FormSchema(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      formType: json['form_type'] as String,
      schema: schemaData,
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      status: (json['status'] as String?) ?? 'draft',
      votingStartsAt: json['voting_starts_at'] == null
          ? null
          : DateTime.parse(json['voting_starts_at'] as String),
      votingEndsAt: json['voting_ends_at'] == null
          ? null
          : DateTime.parse(json['voting_ends_at'] as String),
      eligibleMembers: json['eligible_members'] as Map<String, dynamic>?,
      resultsPublic: _coerceBool(json['results_public']),
      resultsData: json['results_data'] as Map<String, dynamic>?,
      pageCount: (json['page_count'] as num?)?.toInt() ?? 1,
      templateId: json['template_id'] as String?,
      slug: json['slug'] as String?,
      submissionCount: (json['submission_count'] as num?)?.toInt() ?? 0,
      opensAt: json['opens_at'] == null
          ? null
          : DateTime.parse(json['opens_at'] as String),
      closesAt: json['closes_at'] == null
          ? null
          : DateTime.parse(json['closes_at'] as String),
      maxSubmissions: (json['max_submissions'] as num?)?.toInt(),
      requireLogin: _coerceBool(json['require_login']),
      oneSubmissionPerUser: _coerceBool(json['one_submission_per_user']),
      confirmationEmailTemplate: json['confirmation_email_template'] as String?,
      notificationEmails: notificationEmails,
      supportingDocuments: supportingDocuments,
      publicForm: _coerceBool(json['public_form']),
      previewText: json['preview_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
    'title': title,
    'description': description,
    'form_type': formType,
    'schema': schema.toJson(),
    'settings': settings,
    'status': status,
    'voting_starts_at': votingStartsAt?.toIso8601String(),
    'voting_ends_at': votingEndsAt?.toIso8601String(),
    'eligible_members': eligibleMembers,
    'results_public': resultsPublic,
    'results_data': resultsData,
    'page_count': pageCount,
    'template_id': templateId,
    'slug': slug,
    'submission_count': submissionCount,
    'opens_at': opensAt?.toIso8601String(),
    'closes_at': closesAt?.toIso8601String(),
    'max_submissions': maxSubmissions,
    'require_login': requireLogin,
    'one_submission_per_user': oneSubmissionPerUser,
    'confirmation_email_template': confirmationEmailTemplate,
    'notification_emails': notificationEmails,
    'supporting_documents': supportingDocuments,
    'public_form': publicForm,
    'preview_text': previewText,
  };

  FormSchema copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? title,
    String? description,
    String? formType,
    FormSchemaData? schema,
    Map<String, dynamic>? settings,
    String? status,
    DateTime? votingStartsAt,
    DateTime? votingEndsAt,
    Map<String, dynamic>? eligibleMembers,
    bool? resultsPublic,
    Map<String, dynamic>? resultsData,
    int? pageCount,
    String? templateId,
    String? slug,
    int? submissionCount,
    DateTime? opensAt,
    DateTime? closesAt,
    int? maxSubmissions,
    bool? requireLogin,
    bool? oneSubmissionPerUser,
    String? confirmationEmailTemplate,
    List<String>? notificationEmails,
    List<Map<String, dynamic>>? supportingDocuments,
    bool? publicForm,
    String? previewText,
  }) {
    return FormSchema(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      formType: formType ?? this.formType,
      schema: schema ?? this.schema,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      votingStartsAt: votingStartsAt ?? this.votingStartsAt,
      votingEndsAt: votingEndsAt ?? this.votingEndsAt,
      eligibleMembers: eligibleMembers ?? this.eligibleMembers,
      resultsPublic: resultsPublic ?? this.resultsPublic,
      resultsData: resultsData ?? this.resultsData,
      pageCount: pageCount ?? this.pageCount,
      templateId: templateId ?? this.templateId,
      slug: slug ?? this.slug,
      submissionCount: submissionCount ?? this.submissionCount,
      opensAt: opensAt ?? this.opensAt,
      closesAt: closesAt ?? this.closesAt,
      maxSubmissions: maxSubmissions ?? this.maxSubmissions,
      requireLogin: requireLogin ?? this.requireLogin,
      oneSubmissionPerUser: oneSubmissionPerUser ?? this.oneSubmissionPerUser,
      confirmationEmailTemplate: confirmationEmailTemplate ?? this.confirmationEmailTemplate,
      notificationEmails: notificationEmails ?? this.notificationEmails,
      supportingDocuments: supportingDocuments ?? this.supportingDocuments,
      publicForm: publicForm ?? this.publicForm,
      previewText: previewText ?? this.previewText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormSchema && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// FormSchemaData - helper class for building form schemas
/// Used when creating/updating forms via the form builder
class FormSchemaData {
  final List<FormFieldConfig> fields;
  final Map<String, dynamic> styling;
  final Map<String, dynamic> confirmation;
  /// Identity configuration for automatic person tracking
  /// If null, defaults to standard identity config
  final IdentityConfig? identityConfig;

  /// Optional alignment-scoring config (`schema.scoring`). Shape:
  /// `{ note: String, fields: { <fieldId>: { <answerValue>: weight0..1 } } }`.
  /// Preserved verbatim so [SubmissionReviewModel] can compute alignment.
  final Map<String, dynamic>? scoring;

  const FormSchemaData({
    required this.fields,
    this.styling = const {},
    this.confirmation = const {},
    this.identityConfig,
    this.scoring,
  });

  factory FormSchemaData.fromJson(Map<String, dynamic> json) {
    // Handle fields - can be under 'fields' or 'questions' key
    List<FormFieldConfig> parsedFields = [];
    final fieldsData = json['fields'] ?? json['questions'];
    if (fieldsData is List) {
      parsedFields = fieldsData
          .whereType<Map<String, dynamic>>()
          .map((e) => FormFieldConfig.fromJson(e))
          .toList();
    }

    // Handle identity_config
    IdentityConfig? identityConfig;
    final identityData = json['identity_config'];
    if (identityData is Map<String, dynamic>) {
      identityConfig = IdentityConfig.fromJson(identityData);
    }

    return FormSchemaData(
      fields: parsedFields,
      styling: (json['styling'] as Map<String, dynamic>?) ?? {},
      confirmation: (json['confirmation'] as Map<String, dynamic>?) ?? {},
      identityConfig: identityConfig,
      scoring: json['scoring'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'fields': fields.map((f) => f.toJson()).toList(),
    'styling': styling,
    'confirmation': confirmation,
    if (identityConfig != null) 'identity_config': identityConfig!.toJson(),
    if (scoring != null) 'scoring': scoring,
  };

  /// Get the effective identity config (defaults to standard if not set)
  IdentityConfig get effectiveIdentityConfig =>
      identityConfig ?? IdentityConfig.standard();

  /// Check if a field key conflicts with identity field keys
  bool isKeyReserved(String key) => ReservedFieldKeys.isReserved(key);

  FormSchemaData copyWith({
    List<FormFieldConfig>? fields,
    Map<String, dynamic>? styling,
    Map<String, dynamic>? confirmation,
    IdentityConfig? identityConfig,
    Map<String, dynamic>? scoring,
  }) {
    return FormSchemaData(
      fields: fields ?? this.fields,
      styling: styling ?? this.styling,
      confirmation: confirmation ?? this.confirmation,
      identityConfig: identityConfig ?? this.identityConfig,
      scoring: scoring ?? this.scoring,
    );
  }
}
