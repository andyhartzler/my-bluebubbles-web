import 'package:postgrest/postgrest.dart' show CountOption, FetchOptions, PostgrestResponse;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/member_portal.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class MemberPortalRepository {
  MemberPortalRepository._();

  static final MemberPortalRepository _instance = MemberPortalRepository._();

  factory MemberPortalRepository() => _instance;

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient => _supabase.privilegedClient;

  Future<MemberPortalDashboardStats> fetchDashboardStats() async {
    if (!_isReady) return MemberPortalDashboardStats.empty;

    try {
      final responses = await Future.wait([
        _readClient
            .from('member_profile_changes')
            .select('id', const FetchOptions(count: CountOption.exact, head: true))
            .eq('status', 'pending'),
        _readClient
            .from('member_submitted_events')
            .select('id', const FetchOptions(count: CountOption.exact, head: true))
            .eq('approval_status', 'pending'),
        _readClient
            .from('member_portal_meetings')
            .select('id', const FetchOptions(count: CountOption.exact, head: true))
            .eq('is_published', true),
        _readClient
            .from('member_portal_resources')
            .select('id', const FetchOptions(count: CountOption.exact, head: true))
            .eq('is_visible', true),
      ]);

      return MemberPortalDashboardStats(
        pendingProfileChanges: responses[0].count ?? 0,
        pendingEventSubmissions: responses[1].count ?? 0,
        publishedMeetings: responses[2].count ?? 0,
        visibleResources: responses[3].count ?? 0,
      );
    } catch (e) {
      print('❌ Failed to load member portal dashboard stats: $e');
      rethrow;
    }
  }

  Future<List<MemberPortalMeeting>> fetchPortalMeetings({bool? isPublished}) async {
    if (!_isReady) return const [];

    try {
      var query = _readClient.from('member_portal_meetings').select(''',
            *,
            meetings(meeting_title, meeting_date, attendance_count)
          ''').order('created_at', ascending: false);

      if (isPublished != null) {
        query = query.eq('is_published', isPublished);
      }

      final response = await query;
      return _coerceJsonList(response)
          .map(MemberPortalMeeting.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('❌ Error loading portal meetings: $e');
      rethrow;
    }
  }

  Future<MemberPortalMeeting?> savePortalMeeting(MemberPortalMeeting meeting) async {
    if (!_isReady) return null;

    try {
      final response = await _writeClient
          .from('member_portal_meetings')
          .upsert(meeting.toJson())
          .select()
          .single();

      final json = _coerceJsonMap(response);
      if (json == null) return null;
      return MemberPortalMeeting.fromJson(json);
    } catch (e) {
      print('❌ Failed to save portal meeting: $e');
      rethrow;
    }
  }

  Future<MemberPortalMeeting?> publishPortalMeeting({
    required String meetingId,
    required bool publish,
    bool? visibleToAll,
    bool? visibleToAttendeesOnly,
    String? adminId,
  }) async {
    if (!_isReady) return null;

    try {
      final payload = <String, dynamic>{
        'is_published': publish,
        'published_at': publish ? DateTime.now().toIso8601String() : null,
        'published_by': publish ? adminId : null,
      };

      if (visibleToAll != null) payload['visible_to_all'] = visibleToAll;
      if (visibleToAttendeesOnly != null) {
        payload['visible_to_attendees_only'] = visibleToAttendeesOnly;
      }

      final response = await _writeClient
          .from('member_portal_meetings')
          .update(payload)
          .eq('id', meetingId)
          .select()
          .single();

      final json = _coerceJsonMap(response);
      if (json == null) return null;
      return MemberPortalMeeting.fromJson(json);
    } catch (e) {
      print('❌ Failed to update meeting publication: $e');
      rethrow;
    }
  }

  Future<List<MemberSubmittedEvent>> fetchMemberSubmittedEvents({String? status}) async {
    if (!_isReady) return const [];

    try {
      var query = _readClient.from('member_submitted_events').select('*').order('created_at', ascending: false);
      if (status != null) {
        query = query.eq('approval_status', status);
      }
      final response = await query;
      return _coerceJsonList(response)
          .map(MemberSubmittedEvent.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('❌ Error loading submitted events: $e');
      rethrow;
    }
  }

  Future<MemberSubmittedEvent?> approveSubmittedEvent({
    required String submissionId,
    String? adminId,
    Map<String, dynamic>? publicEventPayload,
  }) async {
    if (!_isReady) return null;

    try {
      String? publicEventId;
      if (publicEventPayload != null && publicEventPayload.isNotEmpty) {
        final eventResponse = await _writeClient
            .from('events')
            .insert(publicEventPayload..putIfAbsent('status', () => 'published'))
            .select('id')
            .single();

        publicEventId = _coerceJsonMap(eventResponse)?['id']?.toString();
      }

      final updatePayload = {
        'approval_status': 'approved',
        'approved_by': adminId,
        'approved_at': DateTime.now().toIso8601String(),
        if (publicEventId != null) 'public_event_id': publicEventId,
      };

      final response = await _writeClient
          .from('member_submitted_events')
          .update(updatePayload)
          .eq('id', submissionId)
          .select()
          .single();

      final json = _coerceJsonMap(response);
      return json == null ? null : MemberSubmittedEvent.fromJson(json);
    } catch (e) {
      print('❌ Failed to approve submitted event: $e');
      rethrow;
    }
  }

  Future<MemberSubmittedEvent?> rejectSubmittedEvent({
    required String submissionId,
    String? adminId,
    required String reason,
  }) async {
    if (!_isReady) return null;

    try {
      final response = await _writeClient
          .from('member_submitted_events')
          .update({
            'approval_status': 'rejected',
            'approved_by': adminId,
            'approved_at': DateTime.now().toIso8601String(),
            'rejection_reason': reason,
          })
          .eq('id', submissionId)
          .select()
          .single();

      final json = _coerceJsonMap(response);
      return json == null ? null : MemberSubmittedEvent.fromJson(json);
    } catch (e) {
      print('❌ Failed to reject submitted event: $e');
      rethrow;
    }
  }

  Future<MemberSubmittedEvent?> markSubmissionPending(String submissionId) async {
    if (!_isReady) return null;

    try {
      final response = await _writeClient
          .from('member_submitted_events')
          .update({'approval_status': 'pending', 'approved_by': null, 'approved_at': null, 'rejection_reason': null})
          .eq('id', submissionId)
          .select()
          .single();

      final json = _coerceJsonMap(response);
      return json == null ? null : MemberSubmittedEvent.fromJson(json);
    } catch (e) {
      print('❌ Failed to reset submission status: $e');
      rethrow;
    }
  }

  Future<List<MemberPortalResource>> fetchPortalResources({String? resourceType}) async {
    if (!_isReady) return const [];

    try {
      var query = _readClient
          .from('member_portal_resources')
          .select('*')
          .order('resource_type')
          .order('sort_order');

      if (resourceType != null) {
        query = query.eq('resource_type', resourceType);
      }

      final response = await query;
      return _coerceJsonList(response)
          .map(MemberPortalResource.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('❌ Error loading portal resources: $e');
      rethrow;
    }
  }

  Future<MemberPortalResource?> savePortalResource(MemberPortalResource resource) async {
    if (!_isReady) return null;

    try {
      final response = await _writeClient
          .from('member_portal_resources')
          .upsert(resource.toJson())
          .select()
          .single();

      final json = _coerceJsonMap(response);
      return json == null ? null : MemberPortalResource.fromJson(json);
    } catch (e) {
      print('❌ Failed to save portal resource: $e');
      rethrow;
    }
  }

  Future<void> bulkUpdateResourceVisibility(List<String> ids, bool isVisible) async {
    if (!_isReady || ids.isEmpty) return;

    try {
      await _writeClient
          .from('member_portal_resources')
          .update({'is_visible': isVisible})
          .inFilter('id', ids);
    } catch (e) {
      print('⚠️ Failed to update resource visibility: $e');
    }
  }

  Future<void> deletePortalResource(String id) async {
    if (!_isReady) return;

    try {
      await _writeClient.from('member_portal_resources').delete().eq('id', id);
    } catch (e) {
      print('⚠️ Failed to delete resource $id: $e');
    }
  }

  Future<List<MemberProfileChange>> fetchProfileChanges({String status = 'pending'}) async {
    if (!_isReady) return const [];

    try {
      final response = await _readClient
          .from('member_profile_changes')
          .select('*, member_portal_field_visibility(field_name, display_label, field_category)')
          .eq('status', status)
          .order('created_at', ascending: false);

      return _coerceJsonList(response)
          .map(MemberProfileChange.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('❌ Error loading profile changes: $e');
      rethrow;
    }
  }

  Future<void> approveProfileChange(String changeId, {String? adminId}) async {
    if (!_isReady) return;

    try {
      await _writeClient.rpc('apply_approved_profile_change', params: {'p_change_id': changeId});

      await _writeClient
          .from('member_profile_changes')
          .update({'reviewed_by': adminId})
          .eq('id', changeId);
    } catch (e) {
      print('❌ Failed to approve profile change: $e');
      rethrow;
    }
  }

  Future<void> rejectProfileChange(String changeId, {String? adminId, String? reason}) async {
    if (!_isReady) return;

    try {
      await _writeClient
          .from('member_profile_changes')
          .update({
            'status': 'rejected',
            'reviewed_by': adminId,
            'reviewed_at': DateTime.now().toIso8601String(),
            'rejection_reason': reason,
          })
          .eq('id', changeId);
    } catch (e) {
      print('❌ Failed to reject profile change: $e');
      rethrow;
    }
  }

  Future<List<MemberPortalFieldVisibility>> fetchFieldVisibility() async {
    if (!_isReady) return const [];

    try {
      final response = await _readClient
          .from('member_portal_field_visibility')
          .select('*')
          .order('field_category')
          .order('sort_order');

      return _coerceJsonList(response)
          .map(MemberPortalFieldVisibility.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('❌ Error loading field visibility: $e');
      rethrow;
    }
  }

  Future<MemberPortalFieldVisibility?> saveFieldVisibility(
    MemberPortalFieldVisibility visibility,
  ) async {
    if (!_isReady) return null;

    try {
      final response = await _writeClient
          .from('member_portal_field_visibility')
          .upsert(visibility.toJson())
          .select()
          .single();

      final json = _coerceJsonMap(response);
      return json == null ? null : MemberPortalFieldVisibility.fromJson(json);
    } catch (e) {
      print('❌ Failed to save field visibility: $e');
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
