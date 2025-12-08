import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import 'form_confirmation_service.dart';

class FormsService {
  final _supabase = Supabase.instance.client;

  Stream<List<FormSchema>> watchForms(String typeFilter) {
    if (typeFilter == 'all') {
      return _supabase
          .from('form_schemas')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => FormSchema.fromJson(json)).toList());
    } else {
      return _supabase
          .from('form_schemas')
          .stream(primaryKey: ['id'])
          .eq('form_type', typeFilter)
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => FormSchema.fromJson(json)).toList());
    }
  }

  Future<FormSchema> getForm(String id) async {
    final response = await _supabase
        .from('form_schemas')
        .select()
        .eq('id', id)
        .single();

    return FormSchema.fromJson(response);
  }

  Future<String> createForm({
    required String title,
    String? description,
    required String formType,
    required FormSchemaData schema,
    String status = 'draft',
    // Scheduling
    DateTime? opensAt,
    DateTime? closesAt,
    // Access control
    bool requireLogin = false,
    bool oneSubmissionPerUser = false,
    // Submission limits
    int? maxSubmissions,
    // Custom URL
    String? slug,
    // Email settings
    String? confirmationEmailTemplate,
    List<String>? notificationEmails,
    // Template reference
    String? templateId,
  }) async {
    final response = await _supabase
        .from('form_schemas')
        .insert({
          'title': title,
          'description': description,
          'form_type': formType,
          'schema': schema.toJson(),
          'status': status,
          'created_by': _supabase.auth.currentUser?.id,
          if (opensAt != null) 'opens_at': opensAt.toIso8601String(),
          if (closesAt != null) 'closes_at': closesAt.toIso8601String(),
          'require_login': requireLogin,
          'one_submission_per_user': oneSubmissionPerUser,
          if (maxSubmissions != null) 'max_submissions': maxSubmissions,
          if (slug != null) 'slug': slug,
          if (confirmationEmailTemplate != null) 'confirmation_email_template': confirmationEmailTemplate,
          if (notificationEmails != null) 'notification_emails': notificationEmails,
          if (templateId != null) 'template_id': templateId,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  Future<void> updateForm(
    String id, {
    String? title,
    String? description,
    FormSchemaData? schema,
    String? status,
    // Scheduling - use nullable wrappers to distinguish "not provided" from "set to null"
    DateTime? opensAt,
    bool clearOpensAt = false,
    DateTime? closesAt,
    bool clearClosesAt = false,
    // Access control
    bool? requireLogin,
    bool? oneSubmissionPerUser,
    // Submission limits
    int? maxSubmissions,
    bool clearMaxSubmissions = false,
    // Custom URL
    String? slug,
    bool clearSlug = false,
    // Email settings
    String? confirmationEmailTemplate,
    bool clearConfirmationEmailTemplate = false,
    List<String>? notificationEmails,
    bool clearNotificationEmails = false,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (schema != null) updates['schema'] = schema.toJson();
    if (status != null) updates['status'] = status;

    // Scheduling
    if (opensAt != null) {
      updates['opens_at'] = opensAt.toIso8601String();
    } else if (clearOpensAt) {
      updates['opens_at'] = null;
    }
    if (closesAt != null) {
      updates['closes_at'] = closesAt.toIso8601String();
    } else if (clearClosesAt) {
      updates['closes_at'] = null;
    }

    // Access control
    if (requireLogin != null) updates['require_login'] = requireLogin;
    if (oneSubmissionPerUser != null) updates['one_submission_per_user'] = oneSubmissionPerUser;

    // Submission limits
    if (maxSubmissions != null) {
      updates['max_submissions'] = maxSubmissions;
    } else if (clearMaxSubmissions) {
      updates['max_submissions'] = null;
    }

    // Custom URL
    if (slug != null) {
      updates['slug'] = slug;
    } else if (clearSlug) {
      updates['slug'] = null;
    }

    // Email settings
    if (confirmationEmailTemplate != null) {
      updates['confirmation_email_template'] = confirmationEmailTemplate;
    } else if (clearConfirmationEmailTemplate) {
      updates['confirmation_email_template'] = null;
    }
    if (notificationEmails != null) {
      updates['notification_emails'] = notificationEmails;
    } else if (clearNotificationEmails) {
      updates['notification_emails'] = null;
    }

    await _supabase
        .from('form_schemas')
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteForm(String id) async {
    await _supabase
        .from('form_schemas')
        .delete()
        .eq('id', id);
  }

  Future<void> publishForm(String id) async {
    await _supabase
        .from('form_schemas')
        .update({'status': 'active'})
        .eq('id', id);
  }

  Future<void> unpublishForm(String id) async {
    await _supabase
        .from('form_schemas')
        .update({'status': 'draft'})
        .eq('id', id);
  }

  Future<List<FormSubmission>> getSubmissions(String formId) async {
    final response = await _supabase
        .from('form_submissions')
        .select('*, members(*)')
        .eq('form_id', formId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => FormSubmission.fromJson(json))
        .toList();
  }

  Future<String> createSubmission({
    required String formId,
    required String memberId,
    required Map<String, dynamic> submissionData,
    String? submitterEmail,
    String? submitterName,
    String? submitterPhone,
    bool sendConfirmations = true,
  }) async {
    final response = await _supabase
        .from('form_submissions')
        .insert({
          'form_id': formId,
          'member_id': memberId,
          'data': submissionData,
          'submitter_email': submitterEmail,
          'submitter_name': submitterName,
          'submitter_phone': submitterPhone,
        })
        .select()
        .single();

    final submissionId = response['id'] as String;

    // Send confirmation messages and emails if enabled
    if (sendConfirmations) {
      try {
        final form = await getForm(formId);
        await FormConfirmationService().sendFormConfirmations(
          form: form,
          submitterEmail: submitterEmail,
          submitterPhone: submitterPhone,
          submitterName: submitterName,
          submissionData: submissionData,
        );
      } catch (e) {
        // Log but don't fail the submission if confirmations fail
        print('Warning: Failed to send form confirmations: $e');
      }
    }

    return submissionId;
  }
}
