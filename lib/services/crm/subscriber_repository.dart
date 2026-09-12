import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:postgrest/postgrest.dart' as postgrest;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/subscriber.dart';

import 'supabase_service.dart';

class SubscriberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _readClient => _supabase.client;

  SupabaseClient get _writeClient => _supabase.client;

  /// Page size and hard page cap for the two client-side facets below.
  ///
  /// PostgREST silently caps an unranged select at 1000 rows, and `subscribers`
  /// holds roughly 73k of them, so both facets used to be computed from the
  /// first 1000 rows: the source breakdown was wrong by about 98 percent, and
  /// the county/state filter dropdowns silently omitted most of their options,
  /// which makes a member in an unlisted county unfindable. There is no grouped
  /// RPC for either facet on the legacy path, so they page explicitly.
  ///
  /// The cap exists so a table that grows unexpectedly cannot turn one stats
  /// load into an unbounded scan on an exec's phone: we stop, say so, and
  /// return what we have rather than hang. 200 pages is 200k rows, which is
  /// ample headroom over today's 73k.
  static const int _facetPageSize = 1000;
  static const int _facetMaxPages = 200;

  Future<SubscriberFetchResult> fetchSubscribers({
    String? searchQuery,
    bool? subscribed,
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

    postgrest.PostgrestFilterBuilder<List<Map<String, dynamic>>> filterQuery =
        _readClient
            .from('subscribers')
            .select('''
        *,
        donor:donor_id(id,total_donated,donation_count,last_donation_date)
      ''')
          ..filter('member_id', 'is', null);

    filterQuery = _applyFilters(
      filterQuery,
      searchQuery: searchQuery,
      subscribed: subscribed,
      source: source,
      county: county,
      state: state,
      donorsOnly: donorsOnly,
      optInStart: optInStart,
      optInEnd: optInEnd,
    );

    // PostgREST's fluent builder is NOT mutate-in-place; `.order()` / `.range()`
    // return a new builder (and promote the type from Filter → Transform).
    // Previously the returned builders were dropped on the floor, so every
    // subscriber fetch ran UNSORTED and UNPAGINATED against the full table.
    // `id` is the tie-break, and it is not decorative. created_at is unique for
    // almost every row, but the largest tie is 281 subscribers sharing one
    // timestamp, so a page boundary landing inside that block would repeat some
    // of them and skip others. A sort key that is only usually unique is not a
    // sort key for paging.
    postgrest.PostgrestTransformBuilder<List<Map<String, dynamic>>> query =
        filterQuery
            .order('created_at', ascending: false)
            .order('id', ascending: true);

    if (limit > 0) {
      query = query.range(offset, offset + limit - 1);
    }

    // Use an estimated count for the list total: subscribers is a large table
    // (~73k rows) and an exact count forces a second full RLS-filtered scan per
    // request. This total only gates infinite-scroll ("has more"); the exact
    // headline figure comes from fetchStats(). PostgREST returns an exact count
    // for narrow (filtered/searched) result sets and the planner estimate only
    // for the broad unfiltered scan, where the freshly-ANALYZEd reltuples is
    // effectively exact.
    final postgrest.PostgrestResponse response = fetchTotalCount
        ? await query.count(postgrest.CountOption.estimated)
        : postgrest.PostgrestResponse(
            data: await query,
            count: 0,
          );
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

    // Preferred path: a single grouped RPC (public.get_subscriber_stats) that
    // computes all seven overview stats in one server-side scan instead of the
    // seven parallel exact-count / full-column round-trips the legacy path
    // fired. Mirrors fetchStats()'s shape and both status fallbacks exactly.
    try {
      final result = await _readClient.rpc('get_subscriber_stats');
      return _statsFromRpc(result);
    } on postgrest.PostgrestException catch (e) {
      // Only fall back when the function is genuinely missing (e.g. app deployed
      // ahead of the DB migration). Any other DB error (permissions, timeout)
      // should surface as empty stats rather than silently re-running the slow
      // legacy scan, matching the previous catch-all behaviour.
      if (_isFunctionNotFound(e)) {
        debugPrint(
            'ℹ️ get_subscriber_stats() unavailable, using legacy stats path: ${e.message}');
        return _fetchStatsLegacy();
      }
      debugPrint('❌ Error fetching subscriber stats: ${e.message}');
      return const SubscriberStats();
    } catch (e) {
      debugPrint('❌ Error fetching subscriber stats: $e');
      return const SubscriberStats();
    }
  }

  /// Maps the jsonb payload returned by public.get_subscriber_stats() onto the
  /// widget-facing [SubscriberStats] model.
  SubscriberStats _statsFromRpc(dynamic payload) {
    if (payload is! Map) {
      return const SubscriberStats();
    }
    int asInt(dynamic value) => (value as num?)?.toInt() ?? 0;

    final bySource = <String, int>{};
    final rawSource = payload['by_source'];
    if (rawSource is Map) {
      rawSource.forEach((key, value) {
        bySource[key.toString()] = (value as num?)?.toInt() ?? 0;
      });
    }

    return SubscriberStats(
      totalSubscribers: asInt(payload['total_subscribers']),
      activeSubscribers: asInt(payload['active_subscribers']),
      unsubscribed: asInt(payload['unsubscribed']),
      donorCount: asInt(payload['donor_count']),
      contactInfoCount: asInt(payload['contact_info_count']),
      recentOptIns: asInt(payload['recent_opt_ins']),
      bySource: bySource,
    );
  }

  /// True when [e] indicates the RPC does not exist yet (stale deploy): PostgREST
  /// reports PGRST202 when a function is absent from its schema cache; Postgres
  /// raises 42883 (undefined_function).
  bool _isFunctionNotFound(postgrest.PostgrestException e) {
    final code = e.code ?? '';
    if (code == 'PGRST202' || code == '42883') {
      return true;
    }
    final message = e.message.toLowerCase();
    return message.contains('could not find the function') ||
        message.contains('does not exist');
  }

  /// Legacy seven-round-trip stats path. Retained only as a fallback for when
  /// get_subscriber_stats() is not yet deployed, so the stats screen never
  /// blanks out against an older database.
  Future<SubscriberStats> _fetchStatsLegacy() async {
    try {
      final results = await Future.wait([
        _countWhere(const {}),
        _countWhere({'subscribed': true}),
        _countWhere({'subscribed': false}),
        _countWhere(const {}, notNullColumn: 'donor_id'),
        _countWhere(const {}, orFilter: 'phone_e164.not.is.null,address.not.is.null'),
        _recentOptIns(),
        _sourceBreakdown(),
      ]);

      var totalSubscribers = results[0] as int;
      var activeSubscribers = results[1] as int;
      var unsubscribed = results[2] as int;

      if (activeSubscribers == 0 && unsubscribed == 0) {
        activeSubscribers = await _countWhere({'subscription_status': 'subscribed'});
        unsubscribed = await _countWhere({'subscription_status': 'unsubscribed'});
      }

      if (unsubscribed == 0 && totalSubscribers > activeSubscribers) {
        unsubscribed = totalSubscribers - activeSubscribers;
      }

      return SubscriberStats(
        totalSubscribers: totalSubscribers,
        activeSubscribers: activeSubscribers,
        unsubscribed: unsubscribed,
        donorCount: results[3] as int,
        contactInfoCount: results[4] as int,
        recentOptIns: results[5] as int,
        bySource: results[6] as Map<String, int>,
      );
    } catch (e) {
      debugPrint('❌ Error fetching subscriber stats (legacy): $e');
      return const SubscriberStats();
    }
  }

  postgrest.PostgrestFilterBuilder<T> _applyFilters<T>(
    postgrest.PostgrestFilterBuilder<T> query, {
    String? searchQuery,
    bool? subscribed,
    String? source,
    String? county,
    String? state,
    bool donorsOnly = false,
    DateTime? optInStart,
    DateTime? optInEnd,
  }) {
    if (subscribed != null) {
      query = query.eq('subscribed', subscribed);
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
    postgrest.PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _readClient
        .from('subscribers')
        .select('id')
      ..filter('member_id', 'is', null);
    filters.forEach((key, value) => query = query.eq(key, value));
    if (notNullColumn != null) {
      query = query.not(notNullColumn, 'is', null);
    }
    if (orFilter != null) {
      query = query.or(orFilter);
    }
    final postgrest.PostgrestResponse response =
        await query.count(postgrest.CountOption.exact);
    return response.count;
  }

  Future<Map<String, int>> _sourceBreakdown() async {
    final results = <String, int>{};

    for (var page = 0; page < _facetMaxPages; page++) {
      final from = page * _facetPageSize;
      // Ordered by a stable key on purpose: `.range()` without an ORDER BY
      // gives PostgREST no defined row order, so pages could overlap or skip
      // and the tally would be quietly wrong rather than obviously broken.
      final data = await _readClient
          .from('subscribers')
          .select('source')
          .filter('member_id', 'is', null)
          .order('id', ascending: true)
          .range(from, from + _facetPageSize - 1);

      final rows = (data as List<dynamic>?) ?? const <dynamic>[];
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final source = (map['source'] as String?)?.isNotEmpty == true ? map['source'] as String : 'unknown';
        results[source] = (results[source] ?? 0) + 1;
      }

      // A short page is the last page.
      if (rows.length < _facetPageSize) return results;
    }

    debugPrint(
        '⚠️ Source breakdown stopped at the $_facetMaxPages page cap; these counts are a floor, not a total.');
    return results;
  }

  Future<int> _recentOptIns() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final postgrest.PostgrestResponse response = await _readClient
        .from('subscribers')
        .select('id')
        .filter('member_id', 'is', null)
        .eq('subscribed', true)
        .gte('optin_date', thirtyDaysAgo.toIso8601String())
        .count(postgrest.CountOption.exact);
    return response.count;
  }

  /// Distinct values for one filter dropdown on the subscribers screen.
  ///
  /// Served by the public.get_subscriber_facets() RPC in ONE round trip.
  ///
  /// This used to select the whole column and take the distinct values in the
  /// client. PostgREST caps an unranged select at 1000 rows, so with ~73,100
  /// subscribers the county and state dropdowns were built from the first 1.4
  /// percent of the table and quietly omitted most of their options: a member in
  /// an unlisted county simply could not be filtered to. Paging it client side
  /// fixed the correctness and cost 74 round trips per column, 222 per screen
  /// open, with OFFSET paging degrading quadratically (the last page alone
  /// measures 285 ms and 73,674 buffers). The database has to touch those rows
  /// either way, so the DISTINCT belongs there.
  ///
  /// Returns an empty list on failure rather than throwing, because all three
  /// callers in subscribers_screen.dart await this inside a bare Future.wait
  /// with no handler, and a throw would strand the whole screen. The failure is
  /// logged so it is not silent.
  Future<List<String>> fetchDistinctValues(String column) async {
    if (!isReady) return [];

    try {
      final rows = await _readClient.rpc('get_subscriber_facets') as List<dynamic>?;
      final values = <String>{};
      for (final row in (rows ?? const <dynamic>[])) {
        final map = row as Map<String, dynamic>;
        if (map['facet'] == column) {
          final value = map['value'] as String?;
          if (value != null && value.trim().isNotEmpty) values.add(value);
        }
      }
      return values.toList()..sort((a, b) => a.compareTo(b));
    } catch (e) {
      debugPrint('Failed to load $column filter options: $e');
      return [];
    }
  }

  /// Fetch a single subscriber by ID
  Future<Subscriber?> fetchSubscriberById(String id) async {
    if (!isReady) return null;

    try {
      final response = await _readClient
          .from('subscribers')
          .select('''
            *,
            donor:donor_id(id,total_donated,donation_count,last_donation_date)
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Subscriber.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching subscriber by ID: $e');
      return null;
    }
  }

  Future<Subscriber> updateSubscriber(
    String id, {
    required Map<String, dynamic> data,
  }) async {
    // Previously short-circuited with "Insufficient permissions" when the
    // service-role client was missing. That blocked the supported path where
    // an authenticated user (or the public-update RLS policy) can write
    // directly. Let the update run and let Postgres raise a real RLS error
    // if the caller isn't entitled.
    final payload = Map<String, dynamic>.from(data)
      ..removeWhere((_, value) => value == null);

    final response = await _writeClient
        .from('subscribers')
        .update(payload)
        .eq('id', id)
        .select('*')
        .maybeSingle();

    if (response == null) {
      throw Exception('Subscriber not found');
    }

    return Subscriber.fromJson(response);
  }

  Future<List<Subscriber>> _enrichWithEventCounts(List<Subscriber> subscribers) async {
    final emails = subscribers.map((s) => s.email).where((email) => email.isNotEmpty).toSet().toList();
    if (emails.isEmpty) return subscribers;

    try {
      // Use the standard Supabase client (not service role) to avoid web auth issues
      // This query works with authenticated RLS policies
      final client = _supabase.isInitialized ? _supabase.client : _readClient;

      // Batch emails to avoid URL length limits (max ~50 emails per query)
      const batchSize = 50;
      final counts = <String, int>{};

      for (var i = 0; i < emails.length; i += batchSize) {
        final batch = emails.sublist(
          i,
          i + batchSize > emails.length ? emails.length : i + batchSize,
        );

        // Query event_attendees joined with members to get email
        // event_attendees has member_id, not email directly
        final response = await client
            .from('event_attendees')
            .select('member:members!member_id(email)')
            .not('member_id', 'is', null);

        for (final row in (response as List<dynamic>?) ?? []) {
          final map = row as Map<String, dynamic>;
          final member = map['member'] as Map<String, dynamic>?;
          final email = member?['email'] as String?;
          if (email == null || !batch.contains(email)) continue;
          counts[email] = (counts[email] ?? 0) + 1;
        }
      }

      return subscribers
          .map((s) => s.copyWith(eventAttendanceCount: counts[s.email] ?? 0))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to load event attendance counts: $e');
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
