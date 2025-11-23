import 'dart:async';

import 'package:postgrest/postgrest.dart'
    show CountOption, FetchOptions, PostgrestFilterBuilder, PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/subscriber.dart';

import 'supabase_service.dart';

class SubscriberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  Future<SubscriberFetchResult> fetchSubscribers({
    String? searchQuery,
    String? subscriptionStatus,
    String? source,
    String? county,
    String? state,
    bool donorsOnly = false,
    bool eventAttendeesOnly = false,
    DateTime? optInStart,
    DateTime? optInEnd,
    int limit = 30,
    int offset = 0,
    bool fetchTotalCount = true,
  }) async {
    if (!isReady) {
      return const SubscriberFetchResult(subscribers: [], totalCount: 0);
    }

    final fetchOptions = FetchOptions(
      count: fetchTotalCount ? CountOption.exact : null,
    );

    var query = _readClient
        .from('subscribers')
        .select(
          '''
        *,
        donor:donor_id(id,total_donated,donation_count,last_donation_date)
      ''',
          fetchOptions: fetchOptions,
        )
        .filter('member_id', 'is', null)
        .order('created_at', ascending: false);

    query = _applyFilters(
      query,
      searchQuery: searchQuery,
      subscriptionStatus: subscriptionStatus,
      source: source,
      county: county,
      state: state,
      donorsOnly: donorsOnly,
      optInStart: optInStart,
      optInEnd: optInEnd,
    );

    if (limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    final PostgrestResponse response = await query;
    final data = response.data ?? [];

    final subscribers = _mapSubscribers(data);
    final withEvents = await _enrichWithEventCounts(subscribers);

    final filtered = eventAttendeesOnly
        ? withEvents.where((s) => s.eventAttendanceCount > 0).toList()
        : withEvents;

    return SubscriberFetchResult(
      subscribers: filtered,
      totalCount: eventAttendeesOnly
          ? filtered.length
          : (fetchTotalCount ? response.count : null),
    );
  }

  Future<SubscriberStats> fetchStats() async {
    if (!isReady) {
      return const SubscriberStats();
    }

    try {
      final results = await Future.wait([
        _countWhere({'subscription_status': 'subscribed', 'member_id': null}),
        _countWhere({'subscription_status': 'subscribed', 'member_id': null}),
        _countWhere({'subscription_status': 'unsubscribed', 'member_id': null}),
        _countWhere({'member_id': null}, notNullColumn: 'donor_id'),
        _countWhere({'member_id': null},
            orFilter: 'phone_e164.not.is.null,address.not.is.null'),
        _recentOptIns(),
        _sourceBreakdown(),
      ]);

      return SubscriberStats(
        totalSubscribers: results[0] as int,
        activeSubscribers: results[1] as int,
        unsubscribed: results[2] as int,
        donorCount: results[3] as int,
        contactInfoCount: results[4] as int,
        recentOptIns: results[5] as int,
        bySource: results[6] as Map<String, int>,
      );
    } catch (e) {
      print('❌ Error fetching subscriber stats: $e');
      return const SubscriberStats();
    }
  }

  PostgrestFilterBuilder<dynamic> _applyFilters(
    PostgrestFilterBuilder<dynamic> query, {
    String? searchQuery,
    String? subscriptionStatus,
    String? source,
    String? county,
    String? state,
    bool donorsOnly = false,
    DateTime? optInStart,
    DateTime? optInEnd,
  }) {
    if (subscriptionStatus != null && subscriptionStatus.isNotEmpty) {
      query = query.eq('subscription_status', subscriptionStatus);
    }

    if (source != null && source.isNotEmpty) {
      query = query.eq('source', source);
    }

    if (county != null && county.isNotEmpty) {
      query = query.eq('county', county);
    }

    if (state != null && state.isNotEmpty) {
      query = query.eq('state', state);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.textSearch('search_name', searchQuery.trim(), type: TextSearchType.websearch);
    }

    if (donorsOnly) {
      query = query.not('donor_id', 'is', null);
    }

    if (optInStart != null) {
      query = query.gte('optin_date', optInStart.toIso8601String());
    }

    if (optInEnd != null) {
      query = query.lte('optin_date', optInEnd.toIso8601String());
    }

    return query;
  }

  Future<int> _countWhere(Map<String, dynamic> filters,
      {String? notNullColumn, String? orFilter}) async {
    var query = _readClient.from('subscribers').select(
          'id',
          fetchOptions: const FetchOptions(head: true, count: CountOption.exact),
        ).filter('member_id', 'is', null);
    filters.forEach((key, value) => query = query.eq(key, value));
    if (notNullColumn != null) {
      query = query.not(notNullColumn, 'is', null);
    }
    if (orFilter != null) {
      query = query.or(orFilter);
    }
    final PostgrestResponse response = await query;
    return response.count ?? 0;
  }

  Future<Map<String, int>> _sourceBreakdown() async {
    final PostgrestResponse response = await _readClient
        .from('subscribers')
        .select('source, count:id')
        .filter('member_id', 'is', null)
        .group('source');

    final results = <String, int>{};
    for (final row in (response.data ?? []) as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final source = (map['source'] as String?)?.isNotEmpty == true ? map['source'] as String : 'unknown';
      final count = map['count'] as int? ?? 0;
      results[source] = count;
    }
    return results;
  }

  Future<int> _recentOptIns() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final PostgrestResponse response = await _readClient
        .from('subscribers')
        .select('id', fetchOptions: const FetchOptions(head: true, count: CountOption.exact))
        .filter('member_id', 'is', null)
        .eq('subscription_status', 'subscribed')
        .gte('optin_date', thirtyDaysAgo.toIso8601String())
        ;
    return response.count ?? 0;
  }

  Future<List<String>> fetchDistinctValues(String column) async {
    if (!isReady) return [];
    final PostgrestResponse response = await _readClient
        .from('subscribers')
        .select(column, fetchOptions: const FetchOptions(distinct: true))
        .filter('member_id', 'is', null)
        .order(column, ascending: true);

    return ((response.data ?? []) as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)[column] as String?)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));
  }

  Future<List<Subscriber>> _enrichWithEventCounts(List<Subscriber> subscribers) async {
    final emails = subscribers.map((s) => s.email).where((email) => email.isNotEmpty).toSet().toList();
    if (emails.isEmpty) return subscribers;

    try {
      final PostgrestResponse response = await _readClient
          .from('event_attendees')
          .select('email, count:id')
          .inFilter('email', emails)
          .group('email');

      final counts = <String, int>{};
      for (final row in (response.data ?? []) as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final email = map['email'] as String?;
        if (email == null) continue;
        counts[email] = map['count'] as int? ?? 0;
      }

      return subscribers
          .map((s) => s.copyWith(eventAttendanceCount: counts[s.email] ?? 0))
          .toList();
    } catch (e) {
      print('⚠️ Failed to load event attendance counts: $e');
      return subscribers;
    }
  }

  List<Subscriber> _mapSubscribers(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Subscriber.fromJson)
        .toList();
  }
}
