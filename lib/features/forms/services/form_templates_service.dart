import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/form_template_db.dart';
import '../../../services/crm/supabase_service.dart';

/// Service for managing form templates in the database
class FormTemplatesService {
  final _supabase = Supabase.instance.client;
  final _crmService = CRMSupabaseService();

  /// Get privileged client for write operations
  SupabaseClient get _writeClient =>
      _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

  /// Get privileged client for read operations
  SupabaseClient get _readClient =>
      _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

  /// Watch all templates (real-time stream) with fallback to one-time fetch on error
  Stream<List<FormTemplateDb>> watchTemplates({String? category}) async* {
    try {
      // First, yield immediate data from a one-time fetch
      final initialData = await fetchTemplates(category: category);
      yield initialData;

      // Then try to set up realtime subscription
      final realtimeStream = _supabase
          .from('form_templates')
          .stream(primaryKey: ['id'])
          .order('use_count', ascending: false)
          .order('name', ascending: true);

      await for (final data in realtimeStream) {
        var templates = data.map((json) => FormTemplateDb.fromJson(json)).toList();
        if (category != null && category.isNotEmpty) {
          templates = templates.where((t) => t.category == category).toList();
        }
        yield templates;
      }
    } catch (e) {
      // On realtime subscription error, yield data from one-time fetch
      print('FormTemplatesService.watchTemplates: Realtime subscription failed, using fallback: $e');
      final fallbackData = await fetchTemplates(category: category);
      yield fallbackData;
    }
  }

  /// Fetch all templates (one-time)
  Future<List<FormTemplateDb>> fetchTemplates({String? category}) async {
    var query = _readClient
        .from('form_templates')
        .select()
        .order('use_count', ascending: false)
        .order('name', ascending: true);

    if (category != null && category.isNotEmpty) {
      query = _readClient
          .from('form_templates')
          .select()
          .eq('category', category)
          .order('use_count', ascending: false)
          .order('name', ascending: true);
    }

    final response = await query;
    return (response as List)
        .map((json) => FormTemplateDb.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single template by ID
  Future<FormTemplateDb?> getTemplate(String id) async {
    final response = await _readClient
        .from('form_templates')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return FormTemplateDb.fromJson(response);
  }

  /// Create a new template
  Future<String> createTemplate({
    required String name,
    String? description,
    String? category,
    String? icon,
    required Map<String, dynamic> schema,
    Map<String, dynamic>? settings,
    bool isPublic = false,
  }) async {
    final response = await _writeClient
        .from('form_templates')
        .insert({
          'name': name,
          'description': description,
          'category': category,
          'icon': icon,
          'schema': schema,
          'settings': settings ?? {},
          'is_public': isPublic,
          'is_system': false,
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update an existing template
  Future<void> updateTemplate(
    String id, {
    String? name,
    String? description,
    String? category,
    String? icon,
    Map<String, dynamic>? schema,
    Map<String, dynamic>? settings,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (category != null) updates['category'] = category;
    if (icon != null) updates['icon'] = icon;
    if (schema != null) updates['schema'] = schema;
    if (settings != null) updates['settings'] = settings;
    if (isPublic != null) updates['is_public'] = isPublic;

    if (updates.isEmpty) return;

    await _writeClient
        .from('form_templates')
        .update(updates)
        .eq('id', id);
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    await _writeClient
        .from('form_templates')
        .delete()
        .eq('id', id);
  }

  /// Increment use count when a template is used
  Future<void> incrementUseCount(String id) async {
    await _writeClient.rpc('increment_template_use_count', params: {'template_id': id});
  }

  /// Duplicate a template
  Future<String> duplicateTemplate(String id, {String? newName}) async {
    final template = await getTemplate(id);
    if (template == null) {
      throw Exception('Template not found');
    }

    return createTemplate(
      name: newName ?? '${template.name} (Copy)',
      description: template.description,
      category: template.category,
      icon: template.icon,
      schema: template.schema,
      settings: template.settings,
      isPublic: false, // Always private for duplicates
    );
  }

  /// Get unique categories from all templates
  Future<List<String>> getCategories() async {
    final templates = await fetchTemplates();
    final categories = <String>{};
    for (final template in templates) {
      if (template.category != null && template.category!.isNotEmpty) {
        categories.add(template.category!);
      }
    }
    return categories.toList()..sort();
  }

  /// Search templates by name or description
  Future<List<FormTemplateDb>> searchTemplates(String query) async {
    final response = await _readClient
        .from('form_templates')
        .select()
        .or('name.ilike.%$query%,description.ilike.%$query%')
        .order('use_count', ascending: false)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => FormTemplateDb.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
