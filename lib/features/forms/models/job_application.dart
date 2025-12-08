import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_application.freezed.dart';
part 'job_application.g.dart';

@freezed
class JobApplication with _$JobApplication {
  const factory JobApplication({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,

    @JsonKey(name: 'job_id') required String jobId,

    // Applicant Information
    @JsonKey(name: 'applicant_name') required String applicantName,
    @JsonKey(name: 'applicant_email') required String applicantEmail,
    @JsonKey(name: 'applicant_phone') String? applicantPhone,
    @JsonKey(name: 'resume_url') String? resumeUrl,
    @JsonKey(name: 'cover_letter') String? coverLetter,

    // Application Data
    @JsonKey(name: 'application_data') Map<String, dynamic>? applicationData,

    // Status
    @Default('submitted') String status,

    // Link to member if applicable
    @JsonKey(name: 'member_id') String? memberId,
  }) = _JobApplication;

  factory JobApplication.fromJson(Map<String, dynamic> json) =>
      _$JobApplicationFromJson(json);
}
