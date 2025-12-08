import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';
part 'job.g.dart';

@freezed
class Job with _$Job {
  const factory Job({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    required String title,
    required String organization,
    required String description,
    String? requirements,
    String? qualifications,
    String? location,
    @JsonKey(name: 'job_type') required String jobType,
    @JsonKey(name: 'location_type') String? locationType,
    @JsonKey(name: 'is_paid') @Default(false) bool isPaid,
    @JsonKey(name: 'contact_email') required String contactEmail,
    @JsonKey(name: 'submitter_name') required String submitterName,
    @JsonKey(name: 'submitter_email') required String submitterEmail,
    @JsonKey(name: 'submitter_organization') String? submitterOrganization,
    @Default('pending') String status,
    @JsonKey(name: 'approved_at') DateTime? approvedAt,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'rejection_reason') String? rejectionReason,
    @Default(false) bool featured,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}
