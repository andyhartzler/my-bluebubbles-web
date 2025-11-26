import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class UnlayerService {
  UnlayerService({CRMSupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? CRMSupabaseService();

  final CRMSupabaseService _supabaseService;

  static const String _templateTable = 'campaign_templates';

  bool get isReady => CRMConfig.crmEnabled && _supabaseService.isInitialized;

  SupabaseClient get _client {
    if (!isReady) {
      throw StateError('CRM Supabase is not configured for Unlayer templates.');
    }
    return _supabaseService.client;
  }

  Future<List<Map<String, dynamic>>> fetchTemplates({bool onlyActive = true}) async {
    if (!isReady) return const [];

    var query = _client.from(_templateTable).select();
    if (onlyActive) {
      query = query.eq('active', true);
    }

    final response = await query.order('updated_at', ascending: false);
    if (response is! List) return const [];

    return response
        .whereType<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> fetchTemplateById(String templateId) async {
    if (!isReady) return null;

    final response = await _client
        .from(_templateTable)
        .select()
        .eq('id', templateId)
        .maybeSingle();

    if (response == null || response is! Map<String, dynamic>) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> fetchTemplateByKey(String templateKey) async {
    if (!isReady) return null;

    final response = await _client
        .from(_templateTable)
        .select()
        .eq('template_key', templateKey)
        .maybeSingle();

    if (response == null || response is! Map<String, dynamic>) return null;
    return Map<String, dynamic>.from(response);
  }
}
