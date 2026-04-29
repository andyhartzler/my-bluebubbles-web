import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_application.freezed.dart';
part 'job_application.g.dart';

@freezed
abstract class JobApplication with _$JobApplication {
  const factory JobApplication({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,

    @JsonKey(name: 'job_id') required String jobId,

    // Applicant Information
    @JsonKey(name: 'applicant_name') required String applicantName,
    @JsonKey(name: 'applicant_email') required String applicantEmail,
    @JsonKey(name: 'applicant_phone') String? applicantPhone,
    @JsonKey(name: 'applicant_city') String? applicantCity,
    @JsonKey(name: 'applicant_zip_code') String? applicantZipCode,
    @JsonKey(name: 'resume_url') String? resumeUrl,
    @JsonKey(name: 'cover_letter') String? coverLetter,

    // Application Data
    @JsonKey(name: 'application_data') Map<String, dynamic>? applicationData,

    // Custom Question Responses: { "question_id": "response_value" }
    // response_value can be string, array (for checkbox), or boolean
    @JsonKey(name: 'custom_question_responses')
    @Default({}) Map<String, dynamic> customQuestionResponses,

    // Status: submitted, reviewed, shortlisted, rejected, accepted
    @Default('submitted') String status,

    // Link to member if applicable
    @JsonKey(name: 'member_id') String? memberId,
  }) = _JobApplication;

  const JobApplication._();

  factory JobApplication.fromJson(Map<String, dynamic> json) =>
      _$JobApplicationFromJson(json);

  /// Get a color for the application status
  static int statusColor(String status) {
    switch (status) {
      case 'submitted':
        return 0xFF2196F3; // Blue
      case 'reviewed':
        return 0xFFFF9800; // Orange
      case 'shortlisted':
        return 0xFF9C27B0; // Purple
      case 'rejected':
        return 0xFFF44336; // Red
      case 'accepted':
        return 0xFF4CAF50; // Green
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Get a display label for the status
  static String statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'reviewed':
        return 'Reviewed';
      case 'shortlisted':
        return 'Shortlisted';
      case 'rejected':
        return 'Rejected';
      case 'accepted':
        return 'Accepted';
      default:
        return status;
    }
  }

  /// Check if cover letter is an uploaded file
  bool get hasCoverLetterFile =>
      coverLetter != null && coverLetter!.startsWith('[Uploaded:');

  /// Get the cover letter file path if it's a file
  String? get coverLetterFilePath {
    if (!hasCoverLetterFile) return null;
    final match = RegExp(r'\[Uploaded: (.+)\]').firstMatch(coverLetter!);
    return match?.group(1);
  }
}
