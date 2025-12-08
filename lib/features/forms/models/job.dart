import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';
part 'job.g.dart';

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
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}
