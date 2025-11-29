import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CampaignService {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

  Future<List<Campaign>> fetchCampaigns({String? searchQuery}) async {
    if (!isReady) return [];

    try {
      var query = _readClient.from('campaigns').select();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Campaign.fromJson)
          .toList();
    } catch (e, s) {
      Logger.error('Failed to fetch campaigns', error: e, trace: s);
      return [];
    }
  }

  Future<Campaign?> fetchCampaignById(String id) async {
    if (!isReady) return null;

    try {
      final data = await _readClient
          .from('campaigns')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return Campaign.fromJson(data as Map<String, dynamic>);
    } catch (e, s) {
      Logger.error('Failed to load campaign $id', error: e, trace: s);
      return null;
    }
  }

  Future<Campaign> saveCampaign(Campaign campaign) async {
    if (!isReady) {
      throw Exception('CRM Supabase is not configured');
    }

    final payload = campaign.toJson();
    final campaignId = campaign.id;

    try {
      if (campaignId == null) {
        final response = await _writeClient
            .from('campaigns')
            .insert(payload)
            .select()
            .single();
        return Campaign.fromJson(response as Map<String, dynamic>);
      }

      final response = await _writeClient
          .from('campaigns')
          .update(payload)
          .eq('id', campaignId)
          .select()
          .single();
      return Campaign.fromJson(response as Map<String, dynamic>);
    } catch (e, s) {
      Logger.error('Failed to save campaign', error: e, trace: s);
      rethrow;
    }
  }

  Future<Campaign> saveCampaignDesign({
    required String campaignId,
    required String htmlContent,
    required Map<String, dynamic> designJson,
  }) async {
    if (!isReady) {
      throw Exception('CRM Supabase is not configured');
    }

    try {
      final response = await _writeClient
          .from('campaigns')
          .update({
            'html_content': htmlContent,
            'design_json': designJson,
          })
          .eq('id', campaignId)
          .select()
          .single();

      return Campaign.fromJson(response as Map<String, dynamic>);
    } catch (e, s) {
      Logger.error('Failed to save campaign design', error: e, trace: s);
      rethrow;
    }
  }

  Future<Campaign> scheduleCampaign(
      String campaignId, DateTime scheduledAt) async {
    if (!isReady) {
      throw Exception('CRM Supabase is not configured');
    }

    try {
      final response = await _writeClient
          .from('campaigns')
          .update({
            'scheduled_at': scheduledAt.toIso8601String(),
            'status': CampaignStatus.scheduled.name,
          })
          .eq('id', campaignId)
          .select()
          .single();

      return Campaign.fromJson(response as Map<String, dynamic>);
    } catch (e, s) {
      Logger.error('Failed to schedule campaign', error: e, trace: s);
      rethrow;
    }
  }

  Future<void> sendCampaignNow(String campaignId) async {
    if (!isReady) {
      throw Exception('CRM Supabase is not configured');
    }

    try {
      if (_supabase.hasServiceRole) {
        await _writeClient
            .rpc('send_campaign_now', params: {'campaign_id': campaignId});
      }

      await _writeClient
          .from('campaigns')
          .update({'status': CampaignStatus.sending.name}).eq('id', campaignId);
    } catch (e, s) {
      Logger.error('Failed to trigger send', error: e, trace: s);
      rethrow;
    }
  }

  Future<List<CampaignRecipient>> previewRecipients(
      MessageFilter filter) async {
    if (!isReady) return [];

    try {
      if (_supabase.hasServiceRole) {
        final response = await _readClient.rpc('resolve_campaign_segment',
            params: _filterToParams(filter));
        return (response as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CampaignRecipient.fromJson)
            .toList();
      }
    } catch (e, s) {
      Logger.warn('Failed to resolve campaign recipients', error: e, trace: s);
    }

    return [];
  }

  Future<CampaignAnalytics> fetchAnalytics(String campaignId) async {
    if (!isReady) return const CampaignAnalytics();

    try {
      if (_supabase.hasServiceRole) {
        final response = await _readClient
            .rpc('campaign_analytics', params: {'campaign_id': campaignId});
        if (response is Map<String, dynamic>) {
          return CampaignAnalytics.fromJson(response);
        }
      }

      final data = await _readClient
          .from('campaign_metrics')
          .select()
          .eq('campaign_id', campaignId)
          .maybeSingle();
      if (data is Map<String, dynamic>) {
        return CampaignAnalytics.fromJson(data);
      }
    } catch (e, s) {
      Logger.warn('Failed to load analytics for campaign $campaignId',
          error: e, trace: s);
    }

    return const CampaignAnalytics();
  }

  Future<int> estimateRecipientCount(MessageFilter filter) async {
    if (!isReady) return 0;

    try {
      if (_supabase.hasServiceRole) {
        final response = await _readClient.rpc('count_campaign_segment',
            params: _filterToParams(filter));
        if (response is int) return response;
      }

      final response = await _readClient
          .from('members')
          .select('id')
          .match(_filterToSupabaseMatch(filter).cast<String, Object>())
          .count(CountOption.exact);

      final count = response.count;
      if (count != null) return count;
    } catch (e, s) {
      Logger.warn('Failed to estimate recipients', error: e, trace: s);
    }

    return 0;
  }

  Map<String, dynamic> _filterToParams(MessageFilter filter) {
    final map = _filterToSupabaseMatch(filter);
    map['exclude_opted_out'] = filter.excludeOptedOut;
    map['exclude_recently_contacted'] = filter.excludeRecentlyContacted;
    map['recent_contact_threshold_days'] =
        filter.recentContactThreshold?.inDays;
    return map..removeWhere((_, value) => value == null);
  }

  Map<String, dynamic> _filterToSupabaseMatch(MessageFilter filter) {
    return {
      if (filter.county != null && filter.county!.isNotEmpty)
        'county': filter.county,
      if (filter.congressionalDistrict != null &&
          filter.congressionalDistrict!.isNotEmpty)
        'congressional_district': filter.congressionalDistrict,
      if (filter.committees != null && filter.committees!.isNotEmpty)
        'committees': filter.committees,
      if (filter.highSchool != null && filter.highSchool!.isNotEmpty)
        'high_school': filter.highSchool,
      if (filter.college != null && filter.college!.isNotEmpty)
        'college': filter.college,
      if (filter.chapterName != null && filter.chapterName!.isNotEmpty)
        'chapter_name': filter.chapterName,
      if (filter.chapterStatus != null && filter.chapterStatus!.isNotEmpty)
        'chapter_status': filter.chapterStatus,
      if (filter.minAge != null) 'min_age': filter.minAge,
      if (filter.maxAge != null) 'max_age': filter.maxAge,
    };
  }

  // ============================================================================
  // DRAFT MANAGEMENT
  // ============================================================================

  /// Fetch all campaign drafts for the current user
  Future<List<Map<String, dynamic>>> fetchDrafts() async {
    if (!isReady) return [];

    try {
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await _readClient
          .from('campaign_drafts')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return (data as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e, s) {
      Logger.error('Failed to fetch drafts', error: e, trace: s);
      return [];
    }
  }

  /// Delete a campaign draft
  Future<void> deleteDraft(String draftId) async {
    if (!isReady) throw Exception('CRM Supabase is not configured');

    try {
      await _writeClient.from('campaign_drafts').delete().eq('id', draftId);
    } catch (e, s) {
      Logger.error('Failed to delete draft', error: e, trace: s);
      rethrow;
    }
  }

  /// Promote a draft to a full campaign
  Future<Campaign> promoteDraftToCampaign(String draftId) async {
    if (!isReady) throw Exception('CRM Supabase is not configured');

    try {
      // Fetch the draft
      final draftData = await _readClient
          .from('campaign_drafts')
          .select()
          .eq('id', draftId)
          .single();

      // Create campaign from draft
      final campaignPayload = {
        'name': draftData['campaign_name'] ?? 'Untitled Campaign',
        'subject_line': draftData['subject_line'],
        'preview_text': draftData['preview_text'],
        'from_email': draftData['from_email'],
        'html_content': draftData['html_content'],
        'design_json': draftData['design_json'],
        'segment_type': draftData['segment_type'],
        'segment_filters': draftData['segment_filters'],
        'selected_events': draftData['selected_events'],
        'status': 'draft',
      };

      final response = await _writeClient
          .from('campaigns')
          .insert(campaignPayload)
          .select()
          .single();

      // Optionally delete the draft
      await deleteDraft(draftId);

      return Campaign.fromJson(response as Map<String, dynamic>);
    } catch (e, s) {
      Logger.error('Failed to promote draft to campaign', error: e, trace: s);
      rethrow;
    }
  }
}
