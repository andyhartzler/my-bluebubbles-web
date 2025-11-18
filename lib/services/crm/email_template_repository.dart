import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/email_template.dart';

import 'supabase_service.dart';

class EmailTemplateRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  Future<List<EmailTemplate>> getActiveTemplates({String? audience}) async {
    if (!_isReady) {
      return const [];
    }

    try {
      var query = _readClient.from('email_templates').select().eq('active', true);

      if (audience != null && audience.isNotEmpty) {
        query = query.eq('audience', audience);
      }

      final response = await query.order('template_name', ascending: true);
      if (response is! List) {
        return const [];
      }

      return response
          .whereType<Map<String, dynamic>>()
          .map(EmailTemplate.fromJson)
          .toList(growable: false);
    } catch (error) {
      rethrow;
    }
  }

  Future<EmailTemplate?> getTemplateByKey(String templateKey) async {
    if (!_isReady) return null;

    try {
      final response = await _readClient
          .from('email_templates')
          .select()
          .eq('template_key', templateKey)
          .eq('active', true)
          .maybeSingle();

      if (response == null) return null;
      return EmailTemplate.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
