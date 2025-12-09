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
    @JsonKey(name: 'submitter_phone') String? submitterPhone,
    @JsonKey(name: 'ip_address') String? ipAddress,
    @JsonKey(name: 'user_agent') String? userAgent,
    @JsonKey(name: 'file_urls') List<String>? fileUrls,
    @JsonKey(name: 'page_data') Map<String, dynamic>? pageData,
    @JsonKey(name: 'subscriber_id') String? subscriberId,
    @Default('submitted') String status,
    // Joined member data (if available)
    Map<String, dynamic>? members,
  }) = _FormSubmission;

  factory FormSubmission.fromJson(Map<String, dynamic> json) =>
      _$FormSubmissionFromJson(json);
}

/// Extension to get display name from submission
extension FormSubmissionDisplay on FormSubmission {
  String get displayName {
    // Try submitter name first
    if (submitterName != null && submitterName!.isNotEmpty) {
      return submitterName!;
    }
    // Try member name from joined data
    if (members != null) {
      final firstName = members!['first_name'] as String?;
      final lastName = members!['last_name'] as String?;
      if (firstName != null || lastName != null) {
        return [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
      }
    }
    // Try email
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail!;
    }
    // Fallback
    return 'Anonymous';
  }

  String? get displayEmail {
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail;
    }
    if (members != null) {
      return members!['email'] as String?;
    }
    return null;
  }

  String get displayInitial {
    final name = displayName;
    if (name.isNotEmpty && name != 'Anonymous') {
      return name[0].toUpperCase();
    }
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail![0].toUpperCase();
    }
    return '?';
  }
}
