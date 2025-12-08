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
