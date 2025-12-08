import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_submission.freezed.dart';
part 'form_submission.g.dart';

@freezed
class FormSubmission with _$FormSubmission {
  const factory FormSubmission({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'form_id') required String formId,
    @JsonKey(name: 'member_id') String? memberId,
    required Map<String, dynamic> data,
    @JsonKey(name: 'submitter_email') String? submitterEmail,
    @JsonKey(name: 'submitter_name') String? submitterName,
  }) = _FormSubmission;

  factory FormSubmission.fromJson(Map<String, dynamic> json) =>
      _$FormSubmissionFromJson(json);
}
