import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:postgrest/postgrest.dart' show PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';

class MeetingRepository {
  MeetingRepository._();

  static final MeetingRepository _instance = MeetingRepository._();

  factory MeetingRepository() => _instance;

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  Future<List<Meeting>> getMeetings({bool includeAttendance = true}) async {
    final results = await _fetchMeetings(includeAttendance: includeAttendance);
    return results;
  }

  Future<Meeting?> getMeetingById(String id, {bool includeAttendance = true}) async {
    final meetings = await _fetchMeetings(
      includeAttendance: includeAttendance,
      meetingId: id,
    );
    if (meetings.isEmpty) return null;
    return meetings.first;
  }

  Future<List<MeetingAttendance>> getAttendanceForMeeting(String meetingId) async {
    if (!_isReady) return [];

    try {
      final client = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

      final response = await client
          .from('meeting_attendance')
          .select('*, member:members(*), meeting:meetings(id, meeting_date, meeting_title, recording_url, recording_embed_url, duration_minutes, meeting_host)')
          .eq('meeting_id', meetingId)
          .order('first_join_time');

      return _coerceJsonList(response)
          .map(MeetingAttendance.fromJson)
          .toList();
    } catch (e) {
      print('❌ Error fetching meeting attendance: $e');
      rethrow;
    }
  }

  Future<List<Meeting>> _fetchMeetings({
    bool includeAttendance = true,
    String? meetingId,
  }) async {
    if (!_isReady) return [];

    try {
      final SupabaseClient client =
          _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

      var query = client.from('meetings').select('*');

      if (meetingId != null) {
        query = query.eq('id', meetingId);
      }

      final response = await query.order('meeting_date', ascending: false);
      final baseRows = _coerceJsonList(response);

      if (baseRows.isEmpty) {
        print(
            '⚠️ Supabase returned 0 meetings for ${meetingId != null ? 'id $meetingId' : 'the current query'}');
        return const [];
      }

      final meetings = <Meeting>[];
      final meetingMap = <String, Meeting>{};
      for (final row in baseRows) {
        final meeting = Meeting.fromJson(row, includeAttendance: false);
        meetings.add(meeting);
        meetingMap[meeting.id] = meeting;
      }

      await _hydrateHosts(client, meetingMap);

      if (includeAttendance) {
        await _hydrateAttendance(client, meetingMap);
      }

      final ordered = meetings
          .map((meeting) => meetingMap[meeting.id] ?? meeting)
          .toList(growable: false);
      ordered.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
      print('✅ Loaded ${ordered.length} meeting(s) from Supabase');
      return ordered;
    } catch (e) {
      print('❌ Error fetching meetings: $e');
      rethrow;
    }
  }

  Future<void> _hydrateHosts(SupabaseClient client, Map<String, Meeting> meetingMap) async {
    final hostIds = meetingMap.values
        .map((meeting) => meeting.meetingHostId)
        .whereType<String>()
        .toSet();

    if (hostIds.isEmpty) {
      return;
    }

    try {
      final response = await client
          .from('members')
          .select('*')
          .inFilter('id', hostIds.toList());

      final hostRows = _coerceJsonList(response);
      final hosts = <String, Member>{};
      for (final row in hostRows) {
        final member = Member.fromJson(row);
        hosts[member.id] = member;
      }

      for (final key in meetingMap.keys.toList()) {
        final meeting = meetingMap[key];
        if (meeting == null) continue;
        final hostId = meeting.meetingHostId;
        if (hostId == null) continue;
        final host = hosts[hostId];
        if (host != null) {
          meetingMap[key] = meeting.copyWith(host: host);
        }
      }
    } catch (e) {
      print('⚠️ Failed to hydrate meeting hosts: $e');
    }
  }

  Future<void> _hydrateAttendance(
    SupabaseClient client,
    Map<String, Meeting> meetingMap,
  ) async {
    if (meetingMap.isEmpty) {
      return;
    }

    try {
      final response = await client
          .from('meeting_attendance')
          .select('*, member:members!meeting_attendance_member_id_fkey(*)')
          .inFilter('meeting_id', meetingMap.keys.toList())
          .order('first_join_time');

      final rows = _coerceJsonList(response);
      final attendanceByMeeting = <String, List<MeetingAttendance>>{};

      for (final row in rows) {
        final attendance = MeetingAttendance.fromJson(row);
        final meetingId = attendance.meetingId;
        if (meetingId == null) {
          continue;
        }

        final meeting = meetingMap[meetingId];
        final enriched = meeting == null
            ? attendance
            : attendance.copyWith(
                meeting: meeting,
                meetingTitle: attendance.meetingTitle ?? meeting.meetingTitle,
                meetingDate: attendance.meetingDate ?? meeting.meetingDate,
                meetingRecordingUrl: attendance.meetingRecordingUrl ?? meeting.recordingUrl,
                meetingRecordingEmbedUrl:
                    attendance.meetingRecordingEmbedUrl ?? meeting.recordingEmbedUrl,
              );

        attendanceByMeeting.putIfAbsent(meetingId, () => <MeetingAttendance>[]).add(enriched);
      }

      for (final key in meetingMap.keys.toList()) {
        final meeting = meetingMap[key];
        if (meeting == null) continue;
        final records = attendanceByMeeting[key] ?? const <MeetingAttendance>[];
        meetingMap[key] = meeting.copyWith(attendance: records);
      }
    } catch (e) {
      print('⚠️ Failed to hydrate meeting attendance: $e');
    }
  }

  Future<List<MeetingAttendance>> getAttendanceForMember(String memberId) async {
    if (!_isReady) return [];

    try {
      final client = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

      final response = await client
          .from('meeting_attendance')
          .select('*, member:members(*), meeting:meetings(id, meeting_date, meeting_title, recording_url, recording_embed_url, duration_minutes, meeting_host)')
          .eq('member_id', memberId);

      final attendance = _coerceJsonList(response)
          .map(MeetingAttendance.fromJson)
          .toList();

      attendance.sort((a, b) {
        final aDate = a.meetingDate ?? a.meeting?.meetingDate;
        final bDate = b.meetingDate ?? b.meeting?.meetingDate;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return attendance;
    } catch (e) {
      print('❌ Error fetching member meeting attendance: $e');
      rethrow;
    }
  }

  Future<Meeting?> updateMeeting(
    String meetingId,
    Map<String, dynamic> updates, {
    bool includeAttendance = true,
  }) async {
    if (!_isReady || updates.isEmpty) return null;

    final payload = Map<String, dynamic>.from(updates);

    try {
      final response = await _supabase.privilegedClient
          .from('meetings')
          .update(payload)
          .eq('id', meetingId)
          .select(includeAttendance
              ? '*, host:members!meetings_meeting_host_fkey(*), attendance:meeting_attendance(*, member:members(*))'
              : '*, host:members!meetings_meeting_host_fkey(*)')
          .maybeSingle();

      if (response == null) return null;
      final json = _coerceJsonMap(response);
      if (json == null) {
        throw const FormatException('Supabase returned an unexpected meeting payload');
      }
      return Meeting.fromJson(json, includeAttendance: includeAttendance);
    } catch (e) {
      print('❌ Error updating meeting: $e');
      rethrow;
    }
  }

  Future<MeetingAttendance?> updateAttendance(
    String attendanceId,
    Map<String, dynamic> updates,
  ) async {
    if (!_isReady || updates.isEmpty) return null;

    final payload = Map<String, dynamic>.from(updates);

    try {
      final response = await _supabase.privilegedClient
          .from('meeting_attendance')
          .update(payload)
          .eq('id', attendanceId)
          .select('*, member:members(*), meeting:meetings(id, meeting_date, meeting_title, recording_url, recording_embed_url, duration_minutes, meeting_host)')
          .maybeSingle();

      if (response == null) return null;
      final json = _coerceJsonMap(response);
      if (json == null) {
        throw const FormatException('Supabase returned an unexpected meeting attendance payload');
      }
      return MeetingAttendance.fromJson(json);
    } catch (e) {
      print('❌ Error updating meeting attendance: $e');
      rethrow;
    }
  }
}

List<Map<String, dynamic>> _coerceJsonList(dynamic value) {
  if (value == null) return const [];
  if (value is PostgrestResponse) {
    return _coerceJsonList(value.data);
  }
  if (value is List) {
    return value
        .map(_coerceJsonMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
  if (value is Map && value.containsKey('data')) {
    return _coerceJsonList(value['data']);
  }
  throw FormatException('Unexpected Supabase payload type: ${value.runtimeType}');
}

Map<String, dynamic>? _coerceJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is PostgrestResponse) {
    return _coerceJsonMap(value.data);
  }
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key.toString(), v));
  }
  return null;
}
