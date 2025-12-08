import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/form_schema.dart';
import '../models/form_submission.dart';

class FormsService {
  final _supabase = Supabase.instance.client;

  Stream<List<FormSchema>> watchForms(String typeFilter) {
    var query = _supabase
        .from('form_schemas')
        .stream(primaryKey: ['id']);

    if (typeFilter != 'all') {
      query = query.eq('form_type', typeFilter);
    }

    return query
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => FormSchema.fromJson(json)).toList());
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
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (schema != null) updates['schema'] = schema.toJson();
    if (status != null) updates['status'] = status;

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
}
