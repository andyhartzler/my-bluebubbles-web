import 'package:freezed_annotation/freezed_annotation.dart';
import 'form_field_config.dart';

part 'form_schema.freezed.dart';
part 'form_schema.g.dart';

@freezed
class FormSchema with _$FormSchema {
  const factory FormSchema({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'created_by') String? createdBy,

    // Form Metadata
    required String title,
    String? description,
    @JsonKey(name: 'form_type') required String formType,

    // Form Schema (JSON)
    required FormSchemaData schema,

    // Settings
    @Default({}) Map<String, dynamic> settings,

    // Status
    @Default('draft') String status,

    // Voting-specific fields (only used if form_type = 'vote')
    @JsonKey(name: 'voting_starts_at') DateTime? votingStartsAt,
    @JsonKey(name: 'voting_ends_at') DateTime? votingEndsAt,
    @JsonKey(name: 'eligible_members') Map<String, dynamic>? eligibleMembers,
    @JsonKey(name: 'results_public') @Default(false) bool resultsPublic,
    @JsonKey(name: 'results_data') Map<String, dynamic>? resultsData,
  }) = _FormSchema;

  factory FormSchema.fromJson(Map<String, dynamic> json) =>
      _$FormSchemaFromJson(json);
}

@freezed
class FormSchemaData with _$FormSchemaData {
  const factory FormSchemaData({
    required List<FormFieldConfig> fields,
    @Default({}) Map<String, dynamic> styling,
    @Default({}) Map<String, dynamic> confirmation,
  }) = _FormSchemaData;

  factory FormSchemaData.fromJson(Map<String, dynamic> json) =>
      _$FormSchemaDataFromJson(json);
}
