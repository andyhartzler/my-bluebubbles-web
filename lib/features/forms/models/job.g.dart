// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CustomQuestionImpl _$$CustomQuestionImplFromJson(Map<String, dynamic> json) =>
    _$CustomQuestionImpl(
      id: json['id'] as String,
      question: json['question'] as String,
      type: $enumDecodeNullable(_$CustomQuestionTypeEnumMap, json['type']) ??
          CustomQuestionType.text,
      required: json['required'] == null
          ? false
          : const SafeBoolConverter().fromJson(json['required']),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      order: (json['order'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$CustomQuestionImplToJson(
        _$CustomQuestionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'type': _$CustomQuestionTypeEnumMap[instance.type]!,
      'required': const SafeBoolConverter().toJson(instance.required),
      'options': instance.options,
      'order': instance.order,
    };

const _$CustomQuestionTypeEnumMap = {
  CustomQuestionType.text: 'text',
  CustomQuestionType.textarea: 'textarea',
  CustomQuestionType.select: 'select',
  CustomQuestionType.checkbox: 'checkbox',
  CustomQuestionType.radio: 'radio',
};

_$JobImpl _$$JobImplFromJson(Map<String, dynamic> json) => _$JobImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      title: json['title'] as String,
      organization: json['organization'] as String,
      description: json['description'] as String,
      jobType: json['job_type'] as String,
      location: json['location'] as String?,
      locationType: json['location_type'] as String?,
      isPaid: json['is_paid'] == null
          ? false
          : const SafeBoolConverter().fromJson(json['is_paid']),
      salaryRange: json['salary_range'] as String?,
      hourlyRate: json['hourly_rate'] as String?,
      requirements: json['requirements'] as String?,
      qualifications: json['qualifications'] as String?,
      contactEmail: json['contact_email'] as String,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      applicationUrl: json['application_url'] as String?,
      applicationInstructions: json['application_instructions'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      status: json['status'] as String? ?? 'pending',
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      approvedBy: json['approved_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      submitterName: json['submitter_name'] as String,
      submitterEmail: json['submitter_email'] as String,
      submitterOrganization: json['submitter_organization'] as String?,
      submitterPhone: json['submitter_phone'] as String?,
      slug: json['slug'] as String?,
      featured: json['featured'] == null
          ? false
          : const SafeBoolConverter().fromJson(json['featured']),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      applicationCount: (json['application_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      customQuestions: json['custom_questions'] == null
          ? const []
          : _customQuestionsFromJson(json['custom_questions']),
      resumeEnabled:
          const SafeNullableBoolConverter().fromJson(json['resume_enabled']),
      resumeRequired:
          const SafeNullableBoolConverter().fromJson(json['resume_required']),
      coverLetterEnabled: const SafeNullableBoolConverter()
          .fromJson(json['cover_letter_enabled']),
      coverLetterRequired: const SafeNullableBoolConverter()
          .fromJson(json['cover_letter_required']),
      referencesEnabled: json['references_enabled'] == null
          ? false
          : const SafeBoolConverter().fromJson(json['references_enabled']),
      referencesRequired: json['references_required'] == null
          ? false
          : const SafeBoolConverter().fromJson(json['references_required']),
      referencesCount: (json['references_count'] as num?)?.toInt() ?? 2,
      useExternalApply: json['use_external_apply'] == null
          ? false
          : const SafeBoolConverter().fromJson(json['use_external_apply']),
    );

Map<String, dynamic> _$$JobImplToJson(_$JobImpl instance) => <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'title': instance.title,
      'organization': instance.organization,
      'description': instance.description,
      'job_type': instance.jobType,
      'location': instance.location,
      'location_type': instance.locationType,
      'is_paid': const SafeBoolConverter().toJson(instance.isPaid),
      'salary_range': instance.salaryRange,
      'hourly_rate': instance.hourlyRate,
      'requirements': instance.requirements,
      'qualifications': instance.qualifications,
      'contact_email': instance.contactEmail,
      'contact_name': instance.contactName,
      'contact_phone': instance.contactPhone,
      'application_url': instance.applicationUrl,
      'application_instructions': instance.applicationInstructions,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'status': instance.status,
      'approved_at': instance.approvedAt?.toIso8601String(),
      'approved_by': instance.approvedBy,
      'rejection_reason': instance.rejectionReason,
      'submitter_name': instance.submitterName,
      'submitter_email': instance.submitterEmail,
      'submitter_organization': instance.submitterOrganization,
      'submitter_phone': instance.submitterPhone,
      'slug': instance.slug,
      'featured': const SafeBoolConverter().toJson(instance.featured),
      'tags': instance.tags,
      'application_count': instance.applicationCount,
      'view_count': instance.viewCount,
      'custom_questions': _customQuestionsToJson(instance.customQuestions),
      'resume_enabled':
          const SafeNullableBoolConverter().toJson(instance.resumeEnabled),
      'resume_required':
          const SafeNullableBoolConverter().toJson(instance.resumeRequired),
      'cover_letter_enabled':
          const SafeNullableBoolConverter().toJson(instance.coverLetterEnabled),
      'cover_letter_required': const SafeNullableBoolConverter()
          .toJson(instance.coverLetterRequired),
      'references_enabled':
          const SafeBoolConverter().toJson(instance.referencesEnabled),
      'references_required':
          const SafeBoolConverter().toJson(instance.referencesRequired),
      'references_count': instance.referencesCount,
      'use_external_apply':
          const SafeBoolConverter().toJson(instance.useExternalApply),
    };
