// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_application.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JobApplication _$JobApplicationFromJson(Map<String, dynamic> json) =>
    _JobApplication(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      jobId: json['job_id'] as String,
      applicantName: json['applicant_name'] as String,
      applicantEmail: json['applicant_email'] as String,
      applicantPhone: json['applicant_phone'] as String?,
      applicantCity: json['applicant_city'] as String?,
      applicantZipCode: json['applicant_zip_code'] as String?,
      resumeUrl: json['resume_url'] as String?,
      coverLetter: json['cover_letter'] as String?,
      applicationData: json['application_data'] as Map<String, dynamic>?,
      customQuestionResponses:
          json['custom_question_responses'] as Map<String, dynamic>? ??
              const {},
      status: json['status'] as String? ?? 'submitted',
      memberId: json['member_id'] as String?,
    );

Map<String, dynamic> _$JobApplicationToJson(_JobApplication instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'job_id': instance.jobId,
      'applicant_name': instance.applicantName,
      'applicant_email': instance.applicantEmail,
      'applicant_phone': instance.applicantPhone,
      'applicant_city': instance.applicantCity,
      'applicant_zip_code': instance.applicantZipCode,
      'resume_url': instance.resumeUrl,
      'cover_letter': instance.coverLetter,
      'application_data': instance.applicationData,
      'custom_question_responses': instance.customQuestionResponses,
      'status': instance.status,
      'member_id': instance.memberId,
    };
