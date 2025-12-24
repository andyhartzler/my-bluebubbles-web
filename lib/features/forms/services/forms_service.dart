import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';
import 'form_confirmation_service.dart';
import '../../../services/crm/supabase_service.dart';

class FormsService {
  final _supabase = Supabase.instance.client;
  final _crmService = CRMSupabaseService();

  /// Get privileged client for bypassing RLS when reading submissions
  SupabaseClient get _readClient =>
      _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

  /// Watch forms with realtime updates, with fallback to one-time fetch on error
  Stream<List<FormSchema>> watchForms(String typeFilter) async* {
    try {
      // First, yield immediate data from a one-time fetch
      final initialData = await fetchForms(typeFilter);
      yield initialData;

      // Then try to set up realtime subscription
      Stream<List<Map<String, dynamic>>> realtimeStream;
      if (typeFilter == 'all') {
        realtimeStream = _supabase
            .from('form_schemas')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false);
      } else {
        realtimeStream = _supabase
            .from('form_schemas')
            .stream(primaryKey: ['id'])
            .eq('form_type', typeFilter)
            .order('created_at', ascending: false);
      }

      await for (final data in realtimeStream) {
        List<FormSchema> forms;
        if (typeFilter == 'all') {
          forms = data
              .where((json) => json['form_type'] != 'vote')
              .map((json) => FormSchema.fromJson(json))
              .toList();
        } else {
          forms = data.map((json) => FormSchema.fromJson(json)).toList();
        }
        yield forms;
      }
    } catch (e) {
      // On realtime subscription error, yield data from one-time fetch
      print('FormsService.watchForms: Realtime subscription failed, using fallback: $e');
      final fallbackData = await fetchForms(typeFilter);
      yield fallbackData;
    }
  }

  /// Fetch forms once (non-realtime)
  Future<List<FormSchema>> fetchForms(String typeFilter) async {
    try {
      List<dynamic> response;
      if (typeFilter == 'all') {
        response = await _supabase
            .from('form_schemas')
            .select()
            .neq('form_type', 'vote')
            .order('created_at', ascending: false);
      } else {
        response = await _supabase
            .from('form_schemas')
            .select()
            .eq('form_type', typeFilter)
            .order('created_at', ascending: false);
      }
      return response.map((json) => FormSchema.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('FormsService.fetchForms: Error fetching forms: $e');
      rethrow;
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
    // Public form - display preview on Forms homepage
    bool publicForm = false,
    // Preview text - used for preview tiles and social share text
    String? previewText,
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
          'public_form': publicForm,
          if (previewText != null) 'preview_text': previewText,
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
    // Public form - display preview on Forms homepage
    bool? publicForm,
    // Preview text - used for preview tiles and social share text
    String? previewText,
    bool clearPreviewText = false,
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

    // Public form
    if (publicForm != null) updates['public_form'] = publicForm;

    // Preview text
    if (previewText != null) {
      updates['preview_text'] = previewText;
    } else if (clearPreviewText) {
      updates['preview_text'] = null;
    }

    await _supabase
        .from('form_schemas')
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteForm(String id) async {
    try {
      // Use privileged client to bypass RLS for deletion
      final client = _readClient;

      // First delete any submissions for this form to avoid FK constraint errors
      await client
          .from('form_submissions')
          .delete()
          .eq('form_id', id);

      // Then delete the form
      await client
          .from('form_schemas')
          .delete()
          .eq('id', id);

      print('FormsService.deleteForm: Successfully deleted form $id');
    } catch (e) {
      print('FormsService.deleteForm: Error deleting form $id: $e');
      rethrow;
    }
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

  /// Get a single submission by ID
  Future<FormSubmission?> getSubmission(String submissionId) async {
    try {
      final response = await _readClient
          .from('form_submissions')
          .select()
          .eq('id', submissionId)
          .maybeSingle();

      if (response == null) return null;
      return FormSubmission.fromJson(response);
    } catch (e) {
      print('FormsService.getSubmission: Error fetching submission: $e');
      return null;
    }
  }

  Future<List<FormSubmission>> getSubmissions(String formId) async {
    try {
      // Use privileged client to bypass RLS for reading submissions
      // Join with members table to get member details for display
      final response = await _readClient
          .from('form_submissions')
          .select('''
            *,
            members:member_id (
              id,
              name,
              email,
              phone,
              phone_e164,
              profile_pictures
            ),
            subscribers:subscriber_id (
              id,
              name,
              email,
              phone,
              phone_e164
            )
          ''')
          .eq('form_id', formId)
          .order('created_at', ascending: false);

      final data = response as List;
      print('FormsService.getSubmissions: Found ${data.length} submissions for form $formId (using ${_crmService.hasServiceRole ? "service role" : "anon"} client)');

      return data.map((json) {
        try {
          return FormSubmission.fromJson(json as Map<String, dynamic>);
        } catch (e) {
          print('FormsService.getSubmissions: Error parsing submission: $e');
          print('FormsService.getSubmissions: Raw JSON: $json');
          rethrow;
        }
      }).toList();
    } catch (e) {
      print('FormsService.getSubmissions: Error fetching submissions: $e');
      rethrow;
    }
  }

  /// Get all submissions by a specific subscriber
  Future<List<FormSubmission>> getSubmissionsBySubscriberId(String subscriberId) async {
    try {
      final response = await _readClient
          .from('form_submissions')
          .select()
          .eq('subscriber_id', subscriberId)
          .order('created_at', ascending: false);

      final data = response as List;
      return data.map((json) {
        return FormSubmission.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('FormsService.getSubmissionsBySubscriberId: Error fetching submissions: $e');
      return [];
    }
  }

  /// Get all submissions by a specific member
  Future<List<FormSubmission>> getSubmissionsByMemberId(String memberId) async {
    try {
      final response = await _readClient
          .from('form_submissions')
          .select()
          .eq('member_id', memberId)
          .order('created_at', ascending: false);

      final data = response as List;
      return data.map((json) {
        return FormSubmission.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('FormsService.getSubmissionsByMemberId: Error fetching submissions: $e');
      return [];
    }
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
