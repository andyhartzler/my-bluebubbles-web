import 'package:freezed_annotation/freezed_annotation.dart';

part 'voting_form.freezed.dart';
part 'voting_form.g.dart';

@freezed
class VotingForm with _$VotingForm {
  const factory VotingForm({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'created_by') String? createdBy,
    required String title,
    String? description,
    @JsonKey(name: 'voting_type') required String votingType, // 'single', 'multiple', 'ranked'
    required List<VotingOption> options,
    @JsonKey(name: 'start_date') DateTime? startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @Default('draft') String status,
    @JsonKey(name: 'allow_multiple') @Default(false) bool allowMultiple,
    @JsonKey(name: 'max_choices') int? maxChoices,
    @JsonKey(name: 'require_member') @Default(true) bool requireMember,
  }) = _VotingForm;

  factory VotingForm.fromJson(Map<String, dynamic> json) =>
      _$VotingFormFromJson(json);
}

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
