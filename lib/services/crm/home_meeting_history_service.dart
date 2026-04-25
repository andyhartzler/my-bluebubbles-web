import 'package:flutter/foundation.dart';
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

  /// Upcoming scheduled meetings the member is invited to.
  Future<List<Map<String, dynamic>>> fetchUpcomingInvited(String memberId,
      {int limit = 10}) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows = await client
          .from('meeting_invitees')
          .select(
              'meeting_id, scheduled_meetings(id, meeting_title, meeting_date, start_time, status, committee_id)')
          .eq('member_id', memberId)
          .order('meeting_id', ascending: true)
          .limit(limit * 3);
      final flattened = _flattenJoined(rows, joinKey: 'scheduled_meetings');
      // Filter for status == scheduled and meeting_date >= today
      return flattened
          .where((m) {
            final status = (m['status'] as String?) ?? '';
            final dateStr = m['meeting_date']?.toString() ?? '';
            return status == 'scheduled' && dateStr.compareTo(today) >= 0;
          })
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('[HomeMeetingHistoryService] fetchUpcomingInvited: $e');
      return const [];
    }
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
          .select('event_id, events:event_id(id, name, event_date, location, address)')
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
      final upcoming = await client
          .from('scheduled_meetings')
          .select('id, meeting_title, meeting_date, start_time, status, committee_id')
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
