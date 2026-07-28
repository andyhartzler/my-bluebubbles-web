import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart' show CountOption, PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Three lightweight queries that power the Meeting History panel on the
/// Personalized Home Screen. Queried by member id (members.id, NOT auth uid)
/// because attendance/invitee tables key off members.id.
///
/// Returns simple maps rather than the heavy Meeting model so the home
/// screen can render quickly. Detail views still use MeetingRepository.
class HomeMeetingHistoryService {
  HomeMeetingHistoryService({CRMSupabaseService? supabaseService})
      : _supabase = supabaseService ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  SupabaseClient? get _client {
    if (_supabase.isInitialized) return _supabase.client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Past meetings the member attended (joined via meeting_attendance).
  Future<List<Map<String, dynamic>>> fetchPastAttended(String memberId,
      {int limit = 10}) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('meeting_attendance')
          .select('meeting_id, meetings(id, meeting_title, meeting_date, committee)')
          .eq('member_id', memberId)
          .order('meeting_id', ascending: false)
          .limit(limit);
      return _flattenJoined(rows, joinKey: 'meetings');
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchPastAttended: $e');
      return const [];
    }
  }

  /// Today in ISO date form, the comparison basis for "upcoming".
  static String get _today => DateTime.now().toIso8601String().split('T').first;

  /// The scheduled_meetings ids this member is invited to.
  Future<List<String>> _invitedMeetingIds(
      SupabaseClient client, String memberId) async {
    final rows = await client
        .from('meeting_invitees')
        .select('meeting_id')
        .eq('member_id', memberId);
    return <String>{
      for (final r in (rows as List).whereType<Map>())
        if (r['meeting_id'] != null) r['meeting_id'].toString(),
    }.toList();
  }

  /// Upcoming scheduled meetings the member is invited to.
  ///
  /// TWO BUGS LIVED HERE, and they cancelled out into a permanent "Upcoming
  /// (0)" that never once threw a visible error:
  ///
  ///  1. The embedded select asked scheduled_meetings for `meeting_title`.
  ///     That column does not exist on that table (it is `title`;
  ///     public.meetings is the one with `meeting_title`, which is why the
  ///     attended query works). PostgREST answered 42703, the catch swallowed
  ///     it to debugPrint, and the panel rendered the empty list as "No
  ///     upcoming meetings".
  ///  2. The filtering was client-side over a page ordered by `meeting_id`, a
  ///     uuid. Sorting meetings by a random identifier and then keeping the
  ///     first 30 drops genuinely upcoming meetings for no reason a reader
  ///     could ever see.
  ///
  /// Both are now server-side, against the real column names, ordered by the
  /// date the tab claims to sort by. The `meeting_title:title` alias keeps the
  /// key the panel reads (see MeetingHistoryPanel) unchanged.
  Future<List<Map<String, dynamic>>> fetchUpcomingInvited(String memberId,
      {int limit = 10}) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final ids = await _invitedMeetingIds(client, memberId);
      if (ids.isEmpty) return const [];
      final rows = await client
          .from('scheduled_meetings')
          .select(
              'id, meeting_title:title, meeting_date, start_time, status, committee_id')
          .inFilter('id', ids)
          .eq('status', 'scheduled')
          .gte('meeting_date', _today)
          .order('meeting_date', ascending: true)
          .limit(limit);
      return (rows as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchUpcomingInvited: $e');
      return const [];
    }
  }

  /// Exact number of upcoming invited meetings, independent of the page size
  /// [fetchUpcomingInvited] renders. The tab badges are counts, and a count
  /// that silently saturates at the limit is not one.
  Future<int> countUpcomingInvited(String memberId) async {
    final client = _client;
    if (client == null) return 0;
    try {
      final ids = await _invitedMeetingIds(client, memberId);
      if (ids.isEmpty) return 0;
      final PostgrestResponse res = await client
          .from('scheduled_meetings')
          .select('id')
          .inFilter('id', ids)
          .eq('status', 'scheduled')
          .gte('meeting_date', _today)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] countUpcomingInvited: $e');
      return 0;
    }
  }

  /// Exact number of past meetings this member attended.
  Future<int> countPastAttended(String memberId) async {
    final client = _client;
    if (client == null) return 0;
    try {
      final PostgrestResponse res = await client
          .from('meeting_attendance')
          .select('meeting_id')
          .eq('member_id', memberId)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] countPastAttended: $e');
      return 0;
    }
  }

  /// Exact number of meetings this member hosts: past hosted plus upcoming
  /// created. The chair hosts 17 and the list pages at 10, so the badge read
  /// "Hosted (10)".
  Future<int> countHosted({
    required String memberId,
    required String authUserId,
  }) async {
    final client = _client;
    if (client == null) return 0;
    var total = 0;
    try {
      final PostgrestResponse past = await client
          .from('meetings')
          .select('id')
          .eq('meeting_host', memberId)
          .count(CountOption.exact);
      total += past.count;
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] countHosted past: $e');
    }
    try {
      final PostgrestResponse upcoming = await client
          .from('scheduled_meetings')
          .select('id')
          .eq('created_by', authUserId)
          .count(CountOption.exact);
      total += upcoming.count;
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] countHosted upcoming: $e');
    }
    return total;
  }

  /// Past meetings the member EITHER attended OR hosted, merged and
  /// deduped by meeting id. Sorted newest first. Used by the home
  /// "Activity" panel — Andrew's requested merge of attended + hosted.
  Future<List<Map<String, dynamic>>> fetchAttendedOrHosted(
    String memberId, {
    int limit = 20,
  }) async {
    final attended = await fetchPastAttended(memberId, limit: limit);
    final client = _client;
    if (client == null) return attended;
    List<Map<String, dynamic>> hosted = const [];
    try {
      final rows = await client
          .from('meetings')
          .select('id, meeting_title, meeting_date, committee')
          .eq('meeting_host', memberId)
          .order('meeting_date', ascending: false)
          .limit(limit);
      hosted = (rows as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchAttendedOrHosted hosted: $e');
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final m in [...attended, ...hosted]) {
      final id = m['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byId.putIfAbsent(id, () => m);
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final da = DateTime.tryParse(a['meeting_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['meeting_date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    if (merged.length > limit) return merged.sublist(0, limit);
    return merged;
  }

  /// Events the member attended (via `event_attendees` joined to
  /// `events`). Sorted newest first.
  Future<List<Map<String, dynamic>>> fetchAttendedEvents(
    String memberId, {
    int limit = 20,
  }) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('event_attendees')
          .select(
              'event_id, events:event_id(id, title, event_date, location, location_address)')
          .eq('member_id', memberId)
          .limit(limit * 2);
      final events = _flattenJoined(rows, joinKey: 'events');
      events.sort((a, b) {
        final da = DateTime.tryParse(a['event_date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['event_date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      if (events.length > limit) return events.sublist(0, limit);
      return events;
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchAttendedEvents: $e');
      return const [];
    }
  }

  /// One complete event row by id, for opening the detail screen from the
  /// Events tab. [fetchAttendedEvents] deliberately selects only the columns
  /// the list renders, which is not enough to edit and save an event safely.
  Future<Map<String, dynamic>?> fetchEventById(String eventId) async {
    final client = _client;
    if (client == null) return null;
    final row =
        await client.from('events').select().eq('id', eventId).maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  /// Meetings the member hosts: past hosted + upcoming created.
  /// authUserId is required for the upcoming half because
  /// scheduled_meetings.created_by references auth.users.id.
  Future<List<Map<String, dynamic>>> fetchHosted({
    required String memberId,
    required String authUserId,
    int limit = 10,
  }) async {
    final client = _client;
    if (client == null) return const [];
    final results = <Map<String, dynamic>>[];
    try {
      final past = await client
          .from('meetings')
          .select('id, meeting_title, meeting_date, committee')
          .eq('meeting_host', memberId)
          .order('meeting_date', ascending: false)
          .limit(limit);
      for (final r in (past as List).whereType<Map>()) {
        results.add({...Map<String, dynamic>.from(r), '_source': 'past_hosted'});
      }
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchHosted past: $e');
    }
    try {
      // `meeting_title:title` for the same reason as fetchUpcomingInvited:
      // scheduled_meetings has no meeting_title column, so this half of the
      // Hosted tab was answering 42703 and silently contributing nothing.
      final upcoming = await client
          .from('scheduled_meetings')
          .select(
              'id, meeting_title:title, meeting_date, start_time, status, committee_id')
          .eq('created_by', authUserId)
          .order('meeting_date', ascending: true)
          .limit(limit);
      for (final r in (upcoming as List).whereType<Map>()) {
        results.add({...Map<String, dynamic>.from(r), '_source': 'upcoming_hosted'});
      }
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchHosted upcoming: $e');
    }
    return results;
  }

  /// Flattens `[{meeting_id: ..., joinKey: {...}}, ...]` into
  /// `[{...}, ...]` (the inner join records). Handles both shapes
  /// PostgREST may return for the embedded resource — a single map
  /// (one-to-one) or a single-element list (the supabase-dart client
  /// occasionally surfaces nested resources as lists).
  List<Map<String, dynamic>> _flattenJoined(dynamic rows,
      {required String joinKey}) {
    if (rows is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final r in rows.whereType<Map>()) {
      final inner = r[joinKey];
      if (inner is Map) {
        out.add(Map<String, dynamic>.from(inner));
      } else if (inner is List && inner.isNotEmpty && inner.first is Map) {
        out.add(Map<String, dynamic>.from(inner.first as Map));
      }
    }
    return out;
  }
}
