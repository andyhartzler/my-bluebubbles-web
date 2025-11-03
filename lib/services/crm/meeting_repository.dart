import 'package:bluebubbles/models/crm/meeting.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((json) => Meeting.fromJson(json, includeAttendance: includeAttendance))
          .toList();
    } catch (e) {
      print('❌ Error fetching meetings: $e');
      return [];
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
      return Meeting.fromJson(response as Map<String, dynamic>, includeAttendance: includeAttendance);
    } catch (e) {
      print('❌ Error fetching meeting by id: $e');
      return null;
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
          .whereType<Map<String, dynamic>>()
          .map((json) => MeetingAttendance.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching meeting attendance: $e');
      return [];
    }
  }

  Future<List<MeetingAttendance>> getAttendanceForMember(String memberId) async {
    if (!_isReady) return [];

    try {
      final PostgrestTransformBuilder<dynamic> query = _supabase.client
          .from('meeting_attendance')
          .select('*, member:members(*), meeting:meetings(id, meeting_date, meeting_title, recording_url, recording_embed_url, duration_minutes, meeting_host)')
          .eq('member_id', memberId)
          .order('meeting_date', ascending: false, foreignTable: 'meeting');

      final response = await query;
      return (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((json) => MeetingAttendance.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching member meeting attendance: $e');
      return [];
    }
  }
}
