import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class MeetingRepository {
  MeetingRepository._();

  static final MeetingRepository _instance = MeetingRepository._();

  factory MeetingRepository() => _instance;

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  Future<List<Meeting>> getMeetings({bool includeAttendance = true}) async {
    if (!_isReady) return [];

    try {
      final query = _supabase.client
          .from('meetings')
          .select(includeAttendance
              ? '*, host:members!meetings_meeting_host_fkey(*), attendance:meeting_attendance(*, member:members(*))'
              : '*, host:members!meetings_meeting_host_fkey(*)')
          .order('meeting_date', ascending: false);

      final response = await query;
      final meetings = (response as List<dynamic>)
          .map((raw) {
            final json = _coerceJsonMap(raw);
            if (json == null) {
              throw FormatException('Unexpected meeting payload: ${raw.runtimeType}');
            }
            return Meeting.fromJson(json, includeAttendance: includeAttendance);
          })
          .toList();
      meetings.sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
      return meetings;
    } catch (e) {
      print('❌ Error fetching meetings: $e');
      rethrow;
    }
  }

  Future<Meeting?> getMeetingById(String id, {bool includeAttendance = true}) async {
    if (!_isReady) return null;

    try {
      final response = await _supabase.client
          .from('meetings')
          .select(includeAttendance
              ? '*, host:members!meetings_meeting_host_fkey(*), attendance:meeting_attendance(*, member:members(*))'
              : '*, host:members!meetings_meeting_host_fkey(*)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final json = _coerceJsonMap(response);
      if (json == null) {
        throw const FormatException('Supabase returned an unexpected meeting payload');
      }
      return Meeting.fromJson(json, includeAttendance: includeAttendance);
    } catch (e) {
      print('❌ Error fetching meeting by id: $e');
      rethrow;
    }
  }

  Future<List<MeetingAttendance>> getAttendanceForMeeting(String meetingId) async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('meeting_attendance')
          .select('*, member:members(*), meeting:meetings(id, meeting_date, meeting_title, recording_url, recording_embed_url, duration_minutes, meeting_host)')
          .eq('meeting_id', meetingId)
          .order('first_join_time');

      return (response as List<dynamic>)
          .map((raw) {
            final json = _coerceJsonMap(raw);
            if (json == null) {
              throw FormatException('Unexpected meeting attendance payload: ${raw.runtimeType}');
            }
            return MeetingAttendance.fromJson(json);
          })
          .toList();
    } catch (e) {
      print('❌ Error fetching meeting attendance: $e');
      rethrow;
    }
  }

  Future<List<MeetingAttendance>> getAttendanceForMember(String memberId) async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('meeting_attendance')
          .select('*, member:members(*), meeting:meetings(id, meeting_date, meeting_title, recording_url, recording_embed_url, duration_minutes, meeting_host)')
          .eq('member_id', memberId);

      final attendance = (response as List<dynamic>)
          .map((raw) {
            final json = _coerceJsonMap(raw);
            if (json == null) {
              throw FormatException('Unexpected meeting attendance payload: ${raw.runtimeType}');
            }
            return MeetingAttendance.fromJson(json);
          })
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
}

Map<String, dynamic>? _coerceJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key.toString(), v));
  }
  return null;
}
