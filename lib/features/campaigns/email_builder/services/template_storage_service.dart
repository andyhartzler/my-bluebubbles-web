import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/email_document.dart';
import '../models/email_document_extensions.dart';
import '../models/email_template.dart';

class TemplateStorageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<EmailTemplate>> fetchTemplates() async {
    try {
      final response = await _client
          .from('email_templates')
          .select<List<Map<String, dynamic>>>()
          .order('updated_at', ascending: false);

      return response.map((row) => EmailTemplate.fromMap(row)).toList();
    } catch (_) {
      // Return empty list if storage is not configured yet.
      return [];
    }
  }

  Future<EmailTemplate?> saveTemplate({
    required String name,
    required String description,
    required EmailDocument document,
    String? accentColor,
  }) async {
    final template = EmailTemplate.newTemplate(
      name: name,
      description: description,
      designJson: document.toJson(),
      htmlContent: document.toHtml(),
      accentColor: accentColor,
    );

    try {
      await _client.from('email_templates').upsert(template.toMap());
      return template;
    } catch (_) {
      return null;
    }
  }
}
