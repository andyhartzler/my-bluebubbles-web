import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/campaign.dart';
import 'package:bluebubbles/models/crm/campaign_analytics.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/config/crm_config.dart';

class CampaignService {
  CampaignService({CRMSupabaseService? supabase})
      : _supabase = supabase ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  SupabaseClient? get _client =>
      CRMConfig.crmEnabled && _supabase.isInitialized ? _supabase.client : null;

  Future<List<Campaign>> fetchCampaigns() async {
    final SupabaseClient? client = _client;
    if (client == null) return const <Campaign>[];

    try {
      final dynamic response = await client
          .from('campaigns')
          .select('id, name, title, subject, description, status, created_at, sent_at')
          .order('created_at', ascending: false);
      return Campaign.fromList(response);
    } catch (error) {
      print('❌ Failed to load campaigns: $error');
      return const <Campaign>[];
    }
  }

  Future<Campaign?> fetchCampaign(String id) async {
    final SupabaseClient? client = _client;
    if (client == null) return null;

    try {
      final dynamic response = await client
          .from('campaigns')
          .select('id, name, title, subject, description, status, created_at, sent_at')
          .eq('id', id)
          .maybeSingle();
      return Campaign.fromMap(response);
    } catch (error) {
      print('❌ Failed to load campaign: $error');
      return null;
    }
  }

  Future<CampaignAnalytics> getAnalytics({String? campaignId}) async {
    final SupabaseClient? client = _client;
    if (client == null) return CampaignAnalytics.empty;

    try {
      final Future<dynamic> recipientsFuture = client
          .from('campaign_recipients')
          .select('id, campaign_id, recipient_id, status, created_at, delivered_at, opened_at, clicked_at')
          .maybeFilter('campaign_id', campaignId)
          .order('created_at');

      final Future<dynamic> linksFuture = client
          .from('campaign_links')
          .select('id, campaign_id, url, label, title')
          .maybeFilter('campaign_id', campaignId);

      final Future<dynamic> clicksFuture = client
          .from('campaign_clicks')
          .select('id, campaign_id, link_id, recipient_id, created_at')
          .maybeFilter('campaign_id', campaignId)
          .order('created_at');

      final Future<dynamic>? campaignFuture = campaignId == null
          ? null
          : client
              .from('campaigns')
              .select('id, name, title, subject, description, status, created_at, sent_at')
              .eq('id', campaignId)
              .maybeSingle();

      final dynamic recipientsRaw = await recipientsFuture;
      final dynamic linksRaw = await linksFuture;
      final dynamic clicksRaw = await clicksFuture;
      final Campaign? campaign = campaignFuture == null
          ? null
          : Campaign.fromMap(await campaignFuture);

      final List<Map<String, dynamic>> recipients = _normalizeList(recipientsRaw);
      final List<Map<String, dynamic>> links = _normalizeList(linksRaw);
      final List<Map<String, dynamic>> clicks = _normalizeList(clicksRaw);

      final Map<String, CampaignLinkAnalytics> linkLookup = {
        for (final Map<String, dynamic> link in links)
          if (link['id'] != null)
            link['id'].toString(): CampaignLinkAnalytics(
              id: link['id'].toString(),
              url: link['url']?.toString() ?? '',
              label: link['label']?.toString() ?? link['title']?.toString(),
              clicks: 0,
              uniqueClicks: 0,
            ),
      };

      int delivered = 0;
      int opened = 0;
      int clicked = 0;
      int bounced = 0;
      final List<DateTime> sendDates = <DateTime>[];
      final List<DateTime> openDates = <DateTime>[];
      final List<DateTime> clickDates = <DateTime>[];
      final Set<String> uniqueClickers = <String>{};
      final Map<String, Set<String>> linkClickers = <String, Set<String>>{};

      for (final Map<String, dynamic> recipient in recipients) {
        final String recipientId = recipient['recipient_id']?.toString() ??
            recipient['id']?.toString() ??
            '';
        final String status = recipient['status']?.toString().toLowerCase() ?? '';

        final DateTime? createdAt = _tryParseDate(recipient['created_at']);
        final DateTime? deliveredAt =
            _tryParseDate(recipient['delivered_at']);
        final DateTime? openedAt = _tryParseDate(recipient['opened_at']);
        final DateTime? clickedAt = _tryParseDate(recipient['clicked_at']);

        if (createdAt != null) sendDates.add(createdAt);
        if (deliveredAt != null) {
          delivered += 1;
          sendDates.add(deliveredAt);
        }
        if (openedAt != null) {
          opened += 1;
          openDates.add(openedAt);
        }
        if (clickedAt != null) {
          clicked += 1;
          clickDates.add(clickedAt);
          uniqueClickers.add(recipientId);
        }
        if (status.contains('bounce')) {
          bounced += 1;
        }
      }

      for (final Map<String, dynamic> click in clicks) {
        final String recipientId = click['recipient_id']?.toString() ?? '';
        final DateTime? createdAt = _tryParseDate(click['created_at']);
        if (createdAt != null) {
          clickDates.add(createdAt);
          uniqueClickers.add(recipientId);
        }

        final String linkId = click['link_id']?.toString() ?? '';
        final CampaignLinkAnalytics? existing = linkLookup[linkId];
        if (existing != null) {
          final Set<String> clickers =
              linkClickers.putIfAbsent(linkId, () => <String>{});
          final bool uniqueAdd =
              recipientId.isNotEmpty ? clickers.add(recipientId) : false;
          linkLookup[linkId] = CampaignLinkAnalytics(
            id: existing.id,
            url: existing.url,
            label: existing.label,
            clicks: existing.clicks + 1,
            uniqueClicks: existing.uniqueClicks + (uniqueAdd ? 1 : 0),
          );
        } else if (linkId.isNotEmpty) {
          linkLookup[linkId] = CampaignLinkAnalytics(
            id: linkId,
            url: '',
            clicks: 1,
            uniqueClicks: recipientId.isEmpty ? 0 : 1,
          );
        }
      }

      final List<CampaignLinkAnalytics> topLinks = linkLookup.values
          .sorted((a, b) => b.clicks.compareTo(a.clicks))
          .take(5)
          .toList();

      final int totalRecipients = recipients.length;

      return CampaignAnalytics(
        campaign: campaign,
        totalRecipients: totalRecipients,
        delivered: delivered,
        opened: opened,
        clicked: clicked,
        bounced: bounced,
        uniqueClickers: uniqueClickers.length,
        sendTimeline: TimeSeriesPoint.aggregateByDay(sendDates),
        openTimeline: TimeSeriesPoint.aggregateByDay(openDates),
        clickTimeline: TimeSeriesPoint.aggregateByDay(clickDates),
        topLinks: topLinks,
      );
    } catch (error) {
      print('❌ Failed to load campaign analytics: $error');
      return CampaignAnalytics.empty;
    }
  }

  List<Map<String, dynamic>> _normalizeList(dynamic value) {
    if (value is List<Map<String, dynamic>>) return value;
    if (value is Iterable) {
      return value
          .whereType<Map<String, dynamic>>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

extension _MaybeFilter on PostgrestFilterBuilder {
  PostgrestFilterBuilder maybeFilter(String column, String? value) {
    if (value == null || value.isEmpty) return this;
    return eq(column, value);
  }
}
