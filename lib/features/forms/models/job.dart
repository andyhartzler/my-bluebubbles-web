import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';
part 'job.g.dart';

/// Custom question types for job applications
enum CustomQuestionType {
  @JsonValue('text')
  text,
  @JsonValue('textarea')
  textarea,
  @JsonValue('select')
  select,
  @JsonValue('checkbox')
  checkbox,
  @JsonValue('radio')
  radio,
}

/// A custom question for job applications
@freezed
class CustomQuestion with _$CustomQuestion {
  const factory CustomQuestion({
    required String id,
    required String question,
    @Default(CustomQuestionType.text) CustomQuestionType type,
    @Default(false) bool required,
    @Default([]) List<String> options,
    @Default(0) int order,
  }) = _CustomQuestion;

  factory CustomQuestion.fromJson(Map<String, dynamic> json) =>
      _$CustomQuestionFromJson(json);
}

@freezed
class Job with _$Job {
  const factory Job({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,

    // Job Information
    required String title,
    required String organization,
    required String description,

    // Job Type & Location
    @JsonKey(name: 'job_type') required String jobType,
    String? location,
    @JsonKey(name: 'location_type') String? locationType,

    // Compensation
    @JsonKey(name: 'is_paid') @Default(false) bool isPaid,
    @JsonKey(name: 'salary_range') String? salaryRange,
    @JsonKey(name: 'hourly_rate') String? hourlyRate,

    // Requirements
    String? requirements,
    String? qualifications,

    // Contact Information
    @JsonKey(name: 'contact_email') required String contactEmail,
    @JsonKey(name: 'contact_name') String? contactName,
    @JsonKey(name: 'contact_phone') String? contactPhone,
    @JsonKey(name: 'application_url') String? applicationUrl,
    @JsonKey(name: 'application_instructions') String? applicationInstructions,

    // Metadata
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @Default('pending') String status,
    @JsonKey(name: 'approved_at') DateTime? approvedAt,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'rejection_reason') String? rejectionReason,

    // Submission Information
    @JsonKey(name: 'submitter_name') required String submitterName,
    @JsonKey(name: 'submitter_email') required String submitterEmail,
    @JsonKey(name: 'submitter_organization') String? submitterOrganization,
    @JsonKey(name: 'submitter_phone') String? submitterPhone,

    // SEO & Display
    String? slug,
    @Default(false) bool featured,
    List<String>? tags,

    // Application Tracking
    @JsonKey(name: 'application_count') @Default(0) int applicationCount,
    @JsonKey(name: 'view_count') @Default(0) int viewCount,

    // Custom Questions for Applications
    @JsonKey(name: 'custom_questions', fromJson: _customQuestionsFromJson, toJson: _customQuestionsToJson)
    @Default([]) List<CustomQuestion> customQuestions,

    // Resume & Cover Letter Options
    @JsonKey(name: 'resume_enabled') bool? resumeEnabled,
    @JsonKey(name: 'resume_required') bool? resumeRequired,
    @JsonKey(name: 'cover_letter_enabled') bool? coverLetterEnabled,
    @JsonKey(name: 'cover_letter_required') bool? coverLetterRequired,

    // References Options
    @JsonKey(name: 'references_enabled') @Default(false) bool referencesEnabled,
    @JsonKey(name: 'references_required') @Default(false) bool referencesRequired,
    @JsonKey(name: 'references_count') @Default(2) int referencesCount,

    // External Application Option
    @JsonKey(name: 'use_external_apply') @Default(false) bool useExternalApply,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}

/// Helper to parse custom questions from JSON (handles null and list)
List<CustomQuestion> _customQuestionsFromJson(dynamic json) {
  if (json == null) return [];
  if (json is List) {
    return json
        .map((e) => CustomQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return [];
}

/// Helper to convert custom questions to JSON
List<Map<String, dynamic>> _customQuestionsToJson(List<CustomQuestion> questions) {
  return questions.map((q) => q.toJson()).toList();
}
