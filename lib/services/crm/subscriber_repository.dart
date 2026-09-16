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

  /// Attendance counts for a page of subscribers, in ONE grouped read.
  ///
  /// This used to slice `emails` into batches of 50 and fire one query per
  /// batch, but the query inside that loop never referenced the batch: it was
  /// an UNFILTERED read of `event_attendees` that PostgREST caps at 1000 rows,
  /// and the batch was only applied afterwards, in Dart, as a `contains`
  /// check. So every fetchSubscribers() call fired ceil(N/50) identical
  /// full-table reads and derived attendance from whichever 1000 attendee
  /// rows happened to come back. event_attendees holds 0 rows today, which is
  /// exactly why the truncation is invisible now and certain later.
  ///
  /// public.get_subscriber_event_counts() does the GROUP BY server-side for
  /// the whole page in one round trip. The `eventAttendeesOnly` filter in
  /// fetchSubscribers() reads these counts, so a wrong mapping would hide
  /// subscribers from that filter rather than fail loudly.
  Future<List<Subscriber>> _enrichWithEventCounts(
      List<Subscriber> subscribers) async {
    final emails = subscribers
        .map((s) => s.email)
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList();
    if (emails.isEmpty) return subscribers;

    try {
      final rows = await _readClient.rpc(
        'get_subscriber_event_counts',
        params: {'p_emails': emails},
      ) as List<dynamic>?;

      final counts = <String, int>{};
      for (final row in (rows ?? const <dynamic>[])) {
        if (row is! Map) continue;
        final email = row['email'] as String?;
        if (email == null || email.isEmpty) continue;
        counts[email] = (row['attendance_count'] as num?)?.toInt() ?? 0;
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
