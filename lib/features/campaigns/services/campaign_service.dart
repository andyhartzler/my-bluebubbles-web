import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import '../models/campaign.dart';
import '../models/campaign_analytics.dart';
import '../models/campaign_recipient.dart';

class CampaignService {
  CampaignService({CRMSupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? CRMSupabaseService();

  final CRMSupabaseService _supabaseService;

  bool get isReady => CRMConfig.crmEnabled && _supabaseService.isInitialized;

  SupabaseClient get _client {
    if (!isReady) {
      throw StateError('CRM Supabase is not configured for campaigns.');
    }
    return _supabaseService.client;
  }

  SupabaseClient get _functionClient =>
      _supabaseService.hasServiceRole ? _supabaseService.privilegedClient : _client;

  Future<List<Campaign>> fetchCampaigns({bool includeAnalytics = true}) async {
    if (!isReady) return const [];

    final response = await _client
        .from('campaigns')
        .select(includeAnalytics ? '*, campaign_analytics(*)' : '*')
        .order('created_at', ascending: false);

    if (response is! List) return const [];

    return response
        .whereType<Map<String, dynamic>>()
        .map(_mapCampaign)
        .toList(growable: false);
  }

  Future<Campaign?> fetchCampaignById(String campaignId,
      {bool includeAnalytics = true}) async {
    if (!isReady) return null;

    final response = await _client
        .from('campaigns')
        .select(includeAnalytics ? '*, campaign_analytics(*)' : '*')
        .eq('id', campaignId)
        .maybeSingle();

    if (response == null || response is! Map<String, dynamic>) return null;
    return _mapCampaign(response);
  }

  Future<List<CampaignRecipient>> fetchRecipients(String campaignId) async {
    if (!isReady) return const [];

    final response = await _client
        .from('campaign_recipients')
        .select()
        .eq('campaign_id', campaignId)
        .order('queued_at', ascending: true);

    if (response is! List) return const [];

    return response
        .whereType<Map<String, dynamic>>()
        .map((row) => CampaignRecipient.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<CampaignAnalytics?> fetchAnalytics(String campaignId) async {
    if (!isReady) return null;

    final response = await _client
        .from('campaign_analytics')
        .select()
        .eq('campaign_id', campaignId)
        .maybeSingle();

    if (response == null || response is! Map<String, dynamic>) return null;
    return CampaignAnalytics.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> processCampaignSegment({
    required String campaignId,
    Map<String, dynamic>? segment,
  }) async {
    final payload = <String, dynamic>{'campaign_id': campaignId};
    if (segment != null) {
      payload['segment'] = segment;
    }

    await _functionClient.functions.invoke(
      'process-campaign-segment',
      body: payload,
    );
  }

  Future<void> sendCampaign(String campaignId) async {
    await _functionClient.functions.invoke(
      'send-campaign',
      body: <String, dynamic>{'campaign_id': campaignId},
    );
  }

  Campaign _mapCampaign(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    final analyticsPayload = normalized.remove('campaign_analytics');
    final campaign = Campaign.fromJson(normalized);
    final analytics = _parseAnalytics(analyticsPayload);
    return analytics == null ? campaign : campaign.copyWith(analytics: analytics);
  }

  CampaignAnalytics? _parseAnalytics(dynamic payload) {
    if (payload == null) return null;
    if (payload is Map<String, dynamic>) {
      return CampaignAnalytics.fromJson(Map<String, dynamic>.from(payload));
    }
    if (payload is List && payload.isNotEmpty && payload.first is Map<String, dynamic>) {
      return CampaignAnalytics.fromJson(
          Map<String, dynamic>.from(payload.first as Map<String, dynamic>));
    }
    return null;
  }
}
