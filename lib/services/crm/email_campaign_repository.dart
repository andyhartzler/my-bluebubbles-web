import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart' as postgrest;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/email_campaign.dart';

import 'supabase_service.dart';

class EmailCampaignRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Fetch paginated list of email campaigns with optional filters
  Future<EmailCampaignFetchResult> fetchCampaigns({
    String? searchQuery,
    String? source,
    DateTime? sentAfter,
    DateTime? sentBefore,
    bool? hasSentAt,
    int limit = 30,
    int offset = 0,
    bool fetchTotalCount = true,
  }) async {
    if (!isReady) {
      return const EmailCampaignFetchResult(campaigns: [], totalCount: 0);
    }

    try {
      postgrest.PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _readClient.from('email_campaigns').select('*');

      // Apply filters
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = '%${searchQuery.trim()}%';
        query = query.or('name.ilike.$search,subject.ilike.$search');
      }

      if (source != null && source.isNotEmpty) {
        query = query.eq('source', source);
      }

      if (sentAfter != null) {
        query = query.gte('sent_at', sentAfter.toIso8601String());
      }

      if (sentBefore != null) {
        query = query.lte('sent_at', sentBefore.toIso8601String());
      }

      if (hasSentAt == true) {
        query = query.not('sent_at', 'is', null);
      } else if (hasSentAt == false) {
        query = query.filter('sent_at', 'is', null);
      }

      // Order by sent_at descending (nulls last for drafts)
      final orderedQuery = query.order('sent_at', ascending: false, nullsFirst: false);

      final finalQuery = limit > 0
          ? orderedQuery.range(offset, offset + limit - 1)
          : orderedQuery;

      final postgrest.PostgrestResponse response = fetchTotalCount
          ? await finalQuery.count(postgrest.CountOption.exact)
          : postgrest.PostgrestResponse(
              data: await finalQuery,
              count: 0,
            );

      final data = response.data ?? [];
      final campaigns = _mapCampaigns(data);

      return EmailCampaignFetchResult(
        campaigns: campaigns,
        totalCount: fetchTotalCount ? response.count : null,
      );
    } catch (e) {
      debugPrint('❌ Error fetching email campaigns: $e');
      return const EmailCampaignFetchResult(campaigns: [], totalCount: 0);
    }
  }

  /// Fetch a single campaign by ID
  Future<EmailCampaign?> fetchCampaignById(String id) async {
    if (!isReady) return null;

    try {
      final response = await _readClient
          .from('email_campaigns')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return EmailCampaign.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching campaign by ID: $e');
      return null;
    }
  }

  /// Fetch aggregate statistics for all campaigns
  Future<EmailCampaignStats> fetchStats() async {
    if (!isReady) return const EmailCampaignStats();

    try {
      final results = await Future.wait([
        _countCampaigns(),
        _countSentCampaigns(),
        _aggregateStats(),
        _sourceBreakdown(),
      ]);

      final totalCampaigns = results[0] as int;
      final sentCampaigns = results[1] as int;
      final aggregates = results[2] as Map<String, dynamic>;
      final bySource = results[3] as Map<String, int>;

      return EmailCampaignStats(
        totalCampaigns: totalCampaigns,
        sentCampaigns: sentCampaigns,
        totalRecipients: aggregates['total_recipients'] as int? ?? 0,
        totalOpens: aggregates['total_opens'] as int? ?? 0,
        totalClicks: aggregates['total_clicks'] as int? ?? 0,
        totalBounces: aggregates['total_bounces'] as int? ?? 0,
        totalUnsubscribes: aggregates['total_unsubscribes'] as int? ?? 0,
        averageOpenRate: (aggregates['avg_open_rate'] as num?)?.toDouble() ?? 0,
        averageClickRate: (aggregates['avg_click_rate'] as num?)?.toDouble() ?? 0,
        bySource: bySource,
      );
    } catch (e) {
      debugPrint('❌ Error fetching campaign stats: $e');
      return const EmailCampaignStats();
    }
  }

  /// Fetch recipients for a specific campaign with optional engagement filters
  Future<List<EmailCampaignRecipient>> fetchCampaignRecipients({
    required String campaignId,
    RecipientFilter filter = RecipientFilter.all,
    String? searchQuery,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    try {
      postgrest.PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _readClient
              .from('email_campaign_recipients')
              .select('*, subscriber:subscriber_id(*)')
              .eq('campaign_id', campaignId);

      // Apply engagement filter
      switch (filter) {
        case RecipientFilter.opened:
          query = query.eq('opened', true);
          break;
        case RecipientFilter.clicked:
          query = query.eq('clicked', true);
          break;
        case RecipientFilter.bounced:
          query = query.eq('bounced', true);
          break;
        case RecipientFilter.unsubscribed:
          query = query.eq('unsubscribed', true);
          break;
        case RecipientFilter.complained:
          query = query.eq('complained', true);
          break;
        case RecipientFilter.delivered:
          query = query.not('delivered_at', 'is', null);
          break;
        case RecipientFilter.failed:
          query = query.eq('failed', true);
          break;
        case RecipientFilter.all:
          // No additional filter
          break;
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = '%${searchQuery.trim()}%';
        query = query.or('email.ilike.$search,full_name.ilike.$search');
      }

      query.order('sent_at', ascending: false, nullsFirst: false);

      if (limit > 0) {
        query.range(offset, offset + limit - 1);
      }

      final data = await query;
      return _mapRecipients(data);
    } catch (e) {
      debugPrint('❌ Error fetching campaign recipients: $e');
      return [];
    }
  }

  /// Count recipients by filter type for a campaign
  Future<Map<RecipientFilter, int>> fetchRecipientCounts(String campaignId) async {
    if (!isReady) return {};

    try {
      final results = await Future.wait([
        _countRecipients(campaignId, null),
        _countRecipients(campaignId, 'opened'),
        _countRecipients(campaignId, 'clicked'),
        _countRecipients(campaignId, 'bounced'),
        _countRecipients(campaignId, 'unsubscribed'),
        _countRecipients(campaignId, 'complained'),
        _countRecipients(campaignId, 'failed'),
      ]);

      return {
        RecipientFilter.all: results[0],
        RecipientFilter.opened: results[1],
        RecipientFilter.clicked: results[2],
        RecipientFilter.bounced: results[3],
        RecipientFilter.unsubscribed: results[4],
        RecipientFilter.complained: results[5],
        RecipientFilter.failed: results[6],
      };
    } catch (e) {
      debugPrint('❌ Error fetching recipient counts: $e');
      return {};
    }
  }

  /// Fetch links for a specific campaign
  Future<List<EmailCampaignLink>> fetchCampaignLinks(String campaignId) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('email_campaign_links')
          .select('*')
          .eq('campaign_id', campaignId)
          .order('total_clicks', ascending: false);

      return _mapLinks(data);
    } catch (e) {
      debugPrint('❌ Error fetching campaign links: $e');
      return [];
    }
  }

  /// Fetch click events for a specific link
  Future<List<EmailCampaignLinkClick>> fetchLinkClicks({
    required String linkId,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('email_campaign_link_clicks')
          .select('*, subscriber:subscriber_id(*)')
          .eq('link_id', linkId)
          .order('clicked_at', ascending: false)
          .range(offset, offset + limit - 1);

      return _mapLinkClicks(data);
    } catch (e) {
      debugPrint('❌ Error fetching link clicks: $e');
      return [];
    }
  }

  /// Fetch campaign engagement history for a specific subscriber
  Future<List<EmailCampaignRecipient>> fetchSubscriberCampaigns({
    required String subscriberId,
    int limit = 20,
  }) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('email_campaign_recipients')
          .select('*, campaign:campaign_id(*)')
          .eq('subscriber_id', subscriberId)
          .order('sent_at', ascending: false, nullsFirst: false)
          .limit(limit);

      return _mapRecipients(data);
    } catch (e) {
      debugPrint('❌ Error fetching subscriber campaigns: $e');
      return [];
    }
  }

  /// Fetch campaign engagement history by email address
  Future<List<EmailCampaignRecipient>> fetchSubscriberCampaignsByEmail({
    required String email,
    int limit = 20,
  }) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('email_campaign_recipients')
          .select('*, campaign:campaign_id(*)')
          .eq('email', email.toLowerCase())
          .order('sent_at', ascending: false, nullsFirst: false)
          .limit(limit);

      return _mapRecipients(data);
    } catch (e) {
      debugPrint('❌ Error fetching subscriber campaigns by email: $e');
      return [];
    }
  }

  /// Fetch distinct sources for filter dropdown
  Future<List<String>> fetchDistinctSources() async {
    if (!isReady) return [];

    try {
      final response = await _readClient
          .from('email_campaigns')
          .select('source')
          .order('source', ascending: true);

      return ((response as List<dynamic>?) ?? [])
          .map((row) => (row as Map<String, dynamic>)['source'] as String?)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.compareTo(b));
    } catch (e) {
      debugPrint('❌ Error fetching distinct sources: $e');
      return [];
    }
  }

  // Private helper methods

  Future<int> _countCampaigns() async {
    final postgrest.PostgrestResponse response = await _readClient
        .from('email_campaigns')
        .select('id')
        .count(postgrest.CountOption.exact);
    return response.count;
  }

  Future<int> _countSentCampaigns() async {
    final postgrest.PostgrestResponse response = await _readClient
        .from('email_campaigns')
        .select('id')
        .not('sent_at', 'is', null)
        .count(postgrest.CountOption.exact);
    return response.count;
  }

  Future<Map<String, dynamic>> _aggregateStats() async {
    try {
      // Sum up all campaign stats
      final data = await _readClient.from('email_campaigns').select(
            'total_recipients, unique_opens, unique_clicks, total_bounces, total_unsubscribes, open_rate, click_rate',
          );

      if (data == null || (data as List).isEmpty) {
        return {
          'total_recipients': 0,
          'total_opens': 0,
          'total_clicks': 0,
          'total_bounces': 0,
          'total_unsubscribes': 0,
          'avg_open_rate': 0.0,
          'avg_click_rate': 0.0,
        };
      }

      int totalRecipients = 0;
      int totalOpens = 0;
      int totalClicks = 0;
      int totalBounces = 0;
      int totalUnsubscribes = 0;
      double sumOpenRate = 0;
      double sumClickRate = 0;
      int rateCount = 0;

      for (final row in data) {
        totalRecipients += (row['total_recipients'] as int?) ?? 0;
        totalOpens += (row['unique_opens'] as int?) ?? 0;
        totalClicks += (row['unique_clicks'] as int?) ?? 0;
        totalBounces += (row['total_bounces'] as int?) ?? 0;
        totalUnsubscribes += (row['total_unsubscribes'] as int?) ?? 0;

        final openRate = row['open_rate'];
        final clickRate = row['click_rate'];
        if (openRate != null) {
          sumOpenRate += (openRate as num).toDouble();
          rateCount++;
        }
        if (clickRate != null) {
          sumClickRate += (clickRate as num).toDouble();
        }
      }

      return {
        'total_recipients': totalRecipients,
        'total_opens': totalOpens,
        'total_clicks': totalClicks,
        'total_bounces': totalBounces,
        'total_unsubscribes': totalUnsubscribes,
        'avg_open_rate': rateCount > 0 ? sumOpenRate / rateCount : 0.0,
        'avg_click_rate': rateCount > 0 ? sumClickRate / rateCount : 0.0,
      };
    } catch (e) {
      debugPrint('❌ Error aggregating stats: $e');
      return {
        'total_recipients': 0,
        'total_opens': 0,
        'total_clicks': 0,
        'total_bounces': 0,
        'total_unsubscribes': 0,
        'avg_open_rate': 0.0,
        'avg_click_rate': 0.0,
      };
    }
  }

  Future<Map<String, int>> _sourceBreakdown() async {
    try {
      final data = await _readClient.from('email_campaigns').select('source');

      final results = <String, int>{};
      for (final row in (data as List<dynamic>?) ?? []) {
        final map = row as Map<String, dynamic>;
        final source =
            (map['source'] as String?)?.isNotEmpty == true ? map['source'] as String : 'unknown';
        results[source] = (results[source] ?? 0) + 1;
      }
      return results;
    } catch (e) {
      debugPrint('❌ Error fetching source breakdown: $e');
      return {};
    }
  }

  Future<int> _countRecipients(String campaignId, String? filterColumn) async {
    try {
      var query = _readClient
          .from('email_campaign_recipients')
          .select('id')
          .eq('campaign_id', campaignId);

      if (filterColumn != null) {
        query = query.eq(filterColumn, true);
      }

      final postgrest.PostgrestResponse response =
          await query.count(postgrest.CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('❌ Error counting recipients: $e');
      return 0;
    }
  }

  List<EmailCampaign> _mapCampaigns(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmailCampaign.fromJson)
        .toList();
  }

  List<EmailCampaignRecipient> _mapRecipients(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmailCampaignRecipient.fromJson)
        .toList();
  }

  List<EmailCampaignLink> _mapLinks(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmailCampaignLink.fromJson)
        .toList();
  }

  List<EmailCampaignLinkClick> _mapLinkClicks(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmailCampaignLinkClick.fromJson)
        .toList();
  }
}
