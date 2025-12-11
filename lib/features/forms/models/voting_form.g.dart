// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voting_form.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VotingFormImpl _$$VotingFormImplFromJson(Map<String, dynamic> json) =>
    _$VotingFormImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      schema: json['schema'] as Map<String, dynamic>,
      settings: json['settings'] as Map<String, dynamic>? ?? const {},
      status: json['status'] as String? ?? 'draft',
      votingStartsAt: json['voting_starts_at'] == null
          ? null
          : DateTime.parse(json['voting_starts_at'] as String),
      votingEndsAt: json['voting_ends_at'] == null
          ? null
          : DateTime.parse(json['voting_ends_at'] as String),
      eligibleMembers: json['eligible_members'] as Map<String, dynamic>?,
      resultsPublic: json['results_public'] as bool? ?? false,
      resultsData: json['results_data'] as Map<String, dynamic>?,
      pageCount: (json['page_count'] as num?)?.toInt() ?? 1,
      slug: json['slug'] as String?,
      submissionCount: (json['submission_count'] as num?)?.toInt() ?? 0,
      opensAt: json['opens_at'] == null
          ? null
          : DateTime.parse(json['opens_at'] as String),
      closesAt: json['closes_at'] == null
          ? null
          : DateTime.parse(json['closes_at'] as String),
      maxSubmissions: (json['max_submissions'] as num?)?.toInt(),
      requireLogin: json['require_login'] as bool? ?? false,
      oneSubmissionPerUser: json['one_submission_per_user'] as bool? ?? true,
      confirmationEmailTemplate:
          json['confirmation_email_template'] as String?,
      notificationEmails: (json['notification_emails'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      supportingDocuments: (json['supporting_documents'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      executiveOnly: json['executive_only'] as bool? ?? false,
      committee: json['committee'] as String?,
    );

Map<String, dynamic> _$$VotingFormImplToJson(_$VotingFormImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'created_by': instance.createdBy,
      'title': instance.title,
      'description': instance.description,
      'schema': instance.schema,
      'settings': instance.settings,
      'status': instance.status,
      'voting_starts_at': instance.votingStartsAt?.toIso8601String(),
      'voting_ends_at': instance.votingEndsAt?.toIso8601String(),
      'eligible_members': instance.eligibleMembers,
      'results_public': instance.resultsPublic,
      'results_data': instance.resultsData,
      'page_count': instance.pageCount,
      'slug': instance.slug,
      'submission_count': instance.submissionCount,
      'opens_at': instance.opensAt?.toIso8601String(),
      'closes_at': instance.closesAt?.toIso8601String(),
      'max_submissions': instance.maxSubmissions,
      'require_login': instance.requireLogin,
      'one_submission_per_user': instance.oneSubmissionPerUser,
      'confirmation_email_template': instance.confirmationEmailTemplate,
      'notification_emails': instance.notificationEmails,
      'supporting_documents': instance.supportingDocuments,
      'executive_only': instance.executiveOnly,
      'committee': instance.committee,
    };

_$VotingOptionImpl _$$VotingOptionImplFromJson(Map<String, dynamic> json) =>
    _$VotingOptionImpl(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      votes: (json['votes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$VotingOptionImplToJson(_$VotingOptionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'description': instance.description,
      'votes': instance.votes,
    };

_$VoteImpl _$$VoteImplFromJson(Map<String, dynamic> json) => _$VoteImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      votingFormId: json['voting_form_id'] as String,
      memberId: json['member_id'] as String,
      voteData: json['vote_data'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$$VoteImplToJson(_$VoteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'voting_form_id': instance.votingFormId,
      'member_id': instance.memberId,
      'vote_data': instance.voteData,
    };
