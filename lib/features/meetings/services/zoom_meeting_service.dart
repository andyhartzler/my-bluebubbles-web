import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/features/meetings/models/scheduled_meeting.dart';
import 'package:bluebubbles/features/meetings/models/meeting_invitee.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Exception thrown when Zoom meeting operations fail
class ZoomMeetingException implements Exception {
  final String message;
  final Object? cause;

  ZoomMeetingException(this.message, {this.cause});

  @override
  String toString() => 'ZoomMeetingException: $message';
}

/// Response from creating a Zoom meeting via the edge function
class ZoomMeetingResponse {
  final int zoomMeetingId;
  final String joinUrl;
  final String startUrl;
  final String password;
  final String hostEmail;
  final String? hostName;

  const ZoomMeetingResponse({
    required this.zoomMeetingId,
    required this.joinUrl,
    required this.startUrl,
    required this.password,
    required this.hostEmail,
    this.hostName,
  });

  factory ZoomMeetingResponse.fromJson(Map<String, dynamic> json) {
    return ZoomMeetingResponse(
      zoomMeetingId: (json['zoom_meeting_id'] as num).toInt(),
      joinUrl: json['join_url'] as String,
      startUrl: json['start_url'] as String,
      password: json['password'] as String,
      hostEmail: json['host_email'] as String,
      hostName: json['host_name'] as String?,
    );
  }
}

/// Service for managing Zoom meetings through Supabase edge functions
class ZoomMeetingService {
  static final ZoomMeetingService _instance = ZoomMeetingService._internal();
  factory ZoomMeetingService() => _instance;
  ZoomMeetingService._internal();

  final CRMSupabaseService _supabase = CRMSupabaseService();
  final Uuid _uuid = const Uuid();

  bool get isReady => _supabase.isInitialized;

  SupabaseClient get _client => _supabase.client;

  /// Creates a Zoom meeting via the edge function and saves it to the database
  Future<ScheduledMeeting> createMeeting({
    required String title,
    String? description,
    required DateTime meetingDate,
    required String startTime,
    int durationMinutes = 60,
    String timezone = 'America/Chicago',
    String? committeeId,
    String? committeeName,
    required String createdBy,
  }) async {
    await _ensureInitialized();

    // Step 1: Create the Zoom meeting via edge function
    final startDateTime = _buildIso8601DateTime(meetingDate, startTime);

    final zoomResponse = await _createZoomMeeting(
      title: title,
      description: description,
      startTime: startDateTime,
      duration: durationMinutes,
      timezone: timezone,
    );

    // Step 2: Save to scheduled_meetings table
    final meetingId = _uuid.v4();
    final now = DateTime.now();

    final meeting = ScheduledMeeting(
      id: meetingId,
      createdAt: now,
      createdBy: createdBy,
      title: title,
      description: description,
      meetingDate: meetingDate,
      startTime: startTime,
      durationMinutes: durationMinutes,
      timezone: timezone,
      zoomMeetingId: zoomResponse.zoomMeetingId,
      zoomJoinUrl: zoomResponse.joinUrl,
      zoomStartUrl: zoomResponse.startUrl,
      zoomPassword: zoomResponse.password,
      hostEmail: zoomResponse.hostEmail,
      hostName: zoomResponse.hostName,
      committeeId: committeeId,
      committeeName: committeeName,
      status: MeetingStatus.scheduled,
    );

    try {
      await _client.from('scheduled_meetings').insert(meeting.toJson());
    } catch (e) {
      // If database insert fails, try to delete the Zoom meeting
      try {
        await _deleteZoomMeeting(zoomResponse.zoomMeetingId);
      } catch (_) {
        // Ignore cleanup error
      }
      throw ZoomMeetingException('Failed to save meeting to database: $e', cause: e);
    }

    return meeting;
  }

  /// Updates an existing meeting
  Future<ScheduledMeeting> updateMeeting({
    required ScheduledMeeting meeting,
    String? title,
    String? description,
    DateTime? meetingDate,
    String? startTime,
    int? durationMinutes,
  }) async {
    await _ensureInitialized();

    final newTitle = title ?? meeting.title;
    final newDescription = description ?? meeting.description;
    final newMeetingDate = meetingDate ?? meeting.meetingDate;
    final newStartTime = startTime ?? meeting.startTime;
    final newDurationMinutes = durationMinutes ?? meeting.durationMinutes;

    // Update Zoom meeting if we have a Zoom meeting ID
    if (meeting.zoomMeetingId != null) {
      final startDateTime = _buildIso8601DateTime(newMeetingDate, newStartTime);
      await _updateZoomMeeting(
        zoomMeetingId: meeting.zoomMeetingId!,
        title: newTitle,
        description: newDescription,
        startTime: startDateTime,
        duration: newDurationMinutes,
        timezone: meeting.timezone,
      );
    }

    // Update in database
    final updatedMeeting = meeting.copyWith(
      title: newTitle,
      description: newDescription,
      meetingDate: newMeetingDate,
      startTime: newStartTime,
      durationMinutes: newDurationMinutes,
      updatedAt: DateTime.now(),
    );

    try {
      await _client
          .from('scheduled_meetings')
          .update({
            'title': updatedMeeting.title,
            'description': updatedMeeting.description,
            'meeting_date': _formatDate(updatedMeeting.meetingDate),
            'start_time': updatedMeeting.startTime,
            'duration_minutes': updatedMeeting.durationMinutes,
            'updated_at': updatedMeeting.updatedAt!.toUtc().toIso8601String(),
          })
          .eq('id', meeting.id);
    } catch (e) {
      throw ZoomMeetingException('Failed to update meeting in database: $e', cause: e);
    }

    return updatedMeeting;
  }

  /// Cancels a meeting
  Future<ScheduledMeeting> cancelMeeting(ScheduledMeeting meeting) async {
    await _ensureInitialized();

    // Delete from Zoom if we have a Zoom meeting ID
    if (meeting.zoomMeetingId != null) {
      await _deleteZoomMeeting(meeting.zoomMeetingId!);
    }

    // Update status in database
    final now = DateTime.now();
    final cancelledMeeting = meeting.copyWith(
      status: MeetingStatus.cancelled,
      cancelledAt: now,
      updatedAt: now,
    );

    try {
      await _client
          .from('scheduled_meetings')
          .update({
            'status': 'cancelled',
            'cancelled_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
          })
          .eq('id', meeting.id);
    } catch (e) {
      throw ZoomMeetingException('Failed to cancel meeting in database: $e', cause: e);
    }

    return cancelledMeeting;
  }

  /// Sends meeting invites to committee members
  Future<void> sendMeetingInvites({
    required String meetingId,
    required List<Member> members,
    bool sendEmail = true,
    bool sendSms = false,
  }) async {
    await _ensureInitialized();

    if (!sendEmail && !sendSms) {
      return; // Nothing to send
    }

    // Call the send-meeting-invites edge function
    try {
      final response = await _client.functions.invoke(
        'send-meeting-invites',
        body: {
          'meeting_id': meetingId,
          'send_email': sendEmail,
          'send_sms': sendSms,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null;
        final errorMessage = data?['error']?.toString() ?? 'Unknown error';
        throw ZoomMeetingException('Failed to send invites (HTTP $statusCode): $errorMessage');
      }
    } catch (e) {
      if (e is ZoomMeetingException) rethrow;
      throw ZoomMeetingException('Failed to send meeting invites: $e', cause: e);
    }
  }

  /// Gets upcoming meetings for a committee
  Future<List<ScheduledMeeting>> getUpcomingMeetings({
    String? committeeId,
    String? committeeName,
    int limit = 10,
  }) async {
    await _ensureInitialized();

    try {
      // Build query with filters first, then transforms
      var query = _client
          .from('scheduled_meetings')
          .select()
          .eq('status', 'scheduled')
          .gte('meeting_date', _formatDate(DateTime.now()));

      // Apply committee filter before transforms
      if (committeeId != null) {
        query = query.eq('committee_id', committeeId);
      } else if (committeeName != null) {
        query = query.eq('committee_name', committeeName);
      }

      // Now apply transforms (order, limit) and execute
      final data = await query
          .order('meeting_date', ascending: true)
          .order('start_time', ascending: true)
          .limit(limit);

      return (data as List<dynamic>)
          .map((item) => ScheduledMeeting.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ZoomMeetingException('Failed to fetch upcoming meetings: $e', cause: e);
    }
  }

  /// Gets all meetings for a committee (including past and cancelled)
  Future<List<ScheduledMeeting>> getAllMeetings({
    String? committeeId,
    String? committeeName,
    int limit = 50,
  }) async {
    await _ensureInitialized();

    try {
      // Build query with filters first
      var query = _client
          .from('scheduled_meetings')
          .select();

      // Apply committee filter before transforms
      if (committeeId != null) {
        query = query.eq('committee_id', committeeId);
      } else if (committeeName != null) {
        query = query.eq('committee_name', committeeName);
      }

      // Now apply transforms (order, limit) and execute
      final data = await query
          .order('meeting_date', ascending: false)
          .order('start_time', ascending: false)
          .limit(limit);

      return (data as List<dynamic>)
          .map((item) => ScheduledMeeting.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ZoomMeetingException('Failed to fetch meetings: $e', cause: e);
    }
  }

  /// Gets a single meeting by ID
  Future<ScheduledMeeting?> getMeetingById(String id) async {
    await _ensureInitialized();

    try {
      final data = await _client
          .from('scheduled_meetings')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (data == null) return null;
      return ScheduledMeeting.fromJson(data);
    } catch (e) {
      throw ZoomMeetingException('Failed to fetch meeting: $e', cause: e);
    }
  }

  /// Gets invitees for a meeting
  Future<List<MeetingInvitee>> getMeetingInvitees(String meetingId) async {
    await _ensureInitialized();

    try {
      final data = await _client
          .from('meeting_invitees')
          .select()
          .eq('meeting_id', meetingId)
          .order('name', ascending: true);

      return (data as List<dynamic>)
          .map((item) => MeetingInvitee.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ZoomMeetingException('Failed to fetch meeting invitees: $e', cause: e);
    }
  }

  // Private helper methods

  Future<void> _ensureInitialized() async {
    if (!_supabase.isInitialized) {
      try {
        await _supabase.initialize();
      } catch (e) {
        throw ZoomMeetingException('Failed to initialize Supabase: $e', cause: e);
      }
    }

    if (!_supabase.isInitialized) {
      throw ZoomMeetingException('Supabase is not configured');
    }
  }

  Future<ZoomMeetingResponse> _createZoomMeeting({
    required String title,
    String? description,
    required String startTime,
    required int duration,
    required String timezone,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'zoom-create-meeting',
        body: {
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          'start_time': startTime,
          'duration': duration,
          'timezone': timezone,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data;
        final errorMessage = data is Map ? (data['error']?.toString() ?? 'Unknown error') : 'Unknown error';
        throw ZoomMeetingException('Failed to create Zoom meeting (HTTP $statusCode): $errorMessage');
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : throw ZoomMeetingException('Unexpected response from zoom-create-meeting');
      return ZoomMeetingResponse.fromJson(data);
    } catch (e) {
      if (e is ZoomMeetingException) rethrow;
      throw ZoomMeetingException('Failed to create Zoom meeting: $e', cause: e);
    }
  }

  Future<void> _updateZoomMeeting({
    required int zoomMeetingId,
    required String title,
    String? description,
    required String startTime,
    required int duration,
    required String timezone,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'zoom-update-meeting',
        body: {
          'zoom_meeting_id': zoomMeetingId,
          'title': title,
          if (description != null) 'description': description,
          'start_time': startTime,
          'duration': duration,
          'timezone': timezone,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data;
        final errorMessage = data is Map ? (data['error']?.toString() ?? 'Unknown error') : 'Unknown error';
        throw ZoomMeetingException('Failed to update Zoom meeting (HTTP $statusCode): $errorMessage');
      }
    } catch (e) {
      if (e is ZoomMeetingException) rethrow;
      throw ZoomMeetingException('Failed to update Zoom meeting: $e', cause: e);
    }
  }

  Future<void> _deleteZoomMeeting(int zoomMeetingId) async {
    try {
      final response = await _client.functions.invoke(
        'zoom-delete-meeting',
        body: {
          'zoom_meeting_id': zoomMeetingId,
        },
      );

      final statusCode = response.status;
      if (statusCode != 200) {
        final data = response.data;
        final errorMessage = data is Map ? (data['error']?.toString() ?? 'Unknown error') : 'Unknown error';
        throw ZoomMeetingException('Failed to delete Zoom meeting (HTTP $statusCode): $errorMessage');
      }
    } catch (e) {
      if (e is ZoomMeetingException) rethrow;
      throw ZoomMeetingException('Failed to delete Zoom meeting: $e', cause: e);
    }
  }

  String _buildIso8601DateTime(DateTime date, String time) {
    final timeParts = time.split(':');
    final hour = timeParts[0].padLeft(2, '0');
    final minute = timeParts[1].padLeft(2, '0');
    final dateStr = _formatDate(date);
    return '${dateStr}T$hour:$minute:00';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
