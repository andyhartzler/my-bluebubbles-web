import 'package:freezed_annotation/freezed_annotation.dart';
import 'form_field_config.dart';

part 'voting_form.freezed.dart';
part 'voting_form.g.dart';

// VotingForm is actually stored in form_schemas table with form_type='vote'
// This is a convenience wrapper around the schema
@freezed
class VotingForm with _$VotingForm {
  const factory VotingForm({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'created_by') String? createdBy,

    required String title,
    String? description,

    // Schema contains the voting options and configuration
    required Map<String, dynamic> schema,

    // Settings for vote configuration
    @Default({}) Map<String, dynamic> settings,

    @Default('draft') String status,

    // Voting-specific fields from form_schemas
    @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
    @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
    @JsonKey(name: 'eligible_members') Map<String, dynamic>? eligibleMembers,
    @JsonKey(name: 'results_public') @Default(false) bool resultsPublic,
    @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,

    // Page management
    @JsonKey(name: 'page_count') @Default(1) int pageCount,

    // Custom URL slug
    String? slug,

    // Submission tracking
    @JsonKey(name: 'submission_count') @Default(0) int submissionCount,

    // Scheduling
    @JsonKey(name: 'opens_at') DateTime? opensAt,
    @JsonKey(name: 'closes_at') DateTime? closesAt,

    // Submission limits
    @JsonKey(name: 'max_submissions') int? maxSubmissions,

    // Access control
    @JsonKey(name: 'require_login') @Default(false) bool requireLogin,
    @JsonKey(name: 'one_submission_per_user') @Default(true) bool oneSubmissionPerUser,

    // Email settings
    @JsonKey(name: 'confirmation_email_template') String? confirmationEmailTemplate,
    @JsonKey(name: 'notification_emails') List<String>? notificationEmails,

    // Supporting documents (list of document metadata objects)
    @JsonKey(name: 'supporting_documents') List<Map<String, dynamic>>? supportingDocuments,

    // Executive Committee Only - restricts voting to executive committee members
    @JsonKey(name: 'executive_only') @Default(false) bool executiveOnly,
  }) = _VotingForm;

  factory VotingForm.fromJson(Map<String, dynamic> json) =>
      _$VotingFormFromJson(json);
}

// Voting option model for convenience in building vote forms
@freezed
class VotingOption with _$VotingOption {
  const factory VotingOption({
    required String id,
    required String label,
    String? description,
    @Default(0) int votes,
  }) = _VotingOption;

  factory VotingOption.fromJson(Map<String, dynamic> json) =>
      _$VotingOptionFromJson(json);
}

// Vote submission model
@freezed
class Vote with _$Vote {
  const factory Vote({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'voting_form_id') required String votingFormId,
    @JsonKey(name: 'member_id') required String memberId,
    @JsonKey(name: 'vote_data') required Map<String, dynamic> voteData,
  }) = _Vote;

  factory Vote.fromJson(Map<String, dynamic> json) => _$VoteFromJson(json);
}

// Extension to make working with VotingForm easier
extension VotingFormExtension on VotingForm {
  /// Check if this vote uses the new multi-question format
  bool get usesQuestions => schema['questions'] != null;

  /// Extract questions from the schema (new format)
  /// Falls back to converting old options to a single question
  List<Map<String, dynamic>> get questions {
    try {
      // New format: questions array
      final questionsData = schema['questions'] as List<dynamic>?;
      if (questionsData != null) {
        return questionsData.cast<Map<String, dynamic>>();
      }

      // Backwards compatibility: convert old fields to a single question
      final fields = schema['fields'] as List<dynamic>?;
      if (fields != null && fields.isNotEmpty) {
        return [
          {
            'id': 'default',
            'text': title, // Use vote title as question text
            'question_type': 'multiple_choice',
            'required': true,
            'options': fields,
          }
        ];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get question count
  int get questionCount => questions.length;

  /// Extract voting options from the schema (legacy support)
  List<VotingOption> get options {
    try {
      final fields = schema['fields'] as List<dynamic>?;
      if (fields == null) return [];

      return fields
          .map((field) => VotingOption.fromJson(field as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get option count (legacy - for old single-question votes)
  int get optionCount => options.length;

  /// Get total options across all questions
  int get totalOptionCount {
    int count = 0;
    for (final q in questions) {
      final opts = q['options'] as List<dynamic>?;
      if (opts != null) count += opts.length;
    }
    return count;
  }

  /// Check if voting is currently active
  bool get isVotingActive {
    if (status != 'active') return false;

    final now = DateTime.now();

    // Check start date
    if (votingStartsAt != null && now.isBefore(votingStartsAt!)) {
      return false;
    }

    // Check end date
    if (votingEndsAt != null && now.isAfter(votingEndsAt!)) {
      return false;
    }

    return true;
  }

  /// Check if voting has ended
  bool get hasEnded {
    if (votingEndsAt == null) return false;
    return DateTime.now().isAfter(votingEndsAt!);
  }

  /// Check if voting hasn't started yet
  bool get notStarted {
    if (votingStartsAt == null) return false;
    return DateTime.now().isBefore(votingStartsAt!);
  }
}
