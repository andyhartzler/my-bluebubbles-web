import 'package:bluebubbles/models/crm/member.dart';

DateTime? _parseDateTime(dynamic value, {bool isRequired = false, String? fieldName}) {
  if (value == null) {
    if (isRequired) {
      throw FormatException('Missing required ${fieldName ?? 'DateTime'} value');
    }
    return null;
  }

  if (value is DateTime) {
    return value.toLocal();
  }

  if (value is String) {
    if (value.isEmpty) {
      if (isRequired) {
        throw FormatException('Empty string provided for ${fieldName ?? 'DateTime'}');
      }
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }

  if (isRequired) {
    throw FormatException('Could not parse ${fieldName ?? 'DateTime'} value: $value');
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class Meeting {
  final String id;
  final DateTime meetingDate;
  final String meetingTitle;
  final String? zoomMeetingId;
  final int? durationMinutes;
  final String? recordingUrl;
  final String? recordingEmbedUrl;
  final String? transcriptFilePath;
  final String? actionItems;
  final String? executiveRecap;
  final String? agendaReviewed;
  final String? discussionHighlights;
  final String? decisionsRationales;
  final String? risksOpenQuestions;
  final int? attendanceCount;
  final String? processingStatus;
  final String? processingError;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? meetingHostId;
  final Member? host;
  final List<MeetingAttendance> attendance;

  const Meeting({
    required this.id,
    required this.meetingDate,
    required this.meetingTitle,
    this.zoomMeetingId,
    this.durationMinutes,
    this.recordingUrl,
    this.recordingEmbedUrl,
    this.transcriptFilePath,
    this.actionItems,
    this.executiveRecap,
    this.agendaReviewed,
    this.discussionHighlights,
    this.decisionsRationales,
    this.risksOpenQuestions,
    this.attendanceCount,
    this.processingStatus,
    this.processingError,
    this.createdAt,
    this.updatedAt,
    this.meetingHostId,
    this.host,
    this.attendance = const [],
  });

  Meeting copyWith({
    String? id,
    DateTime? meetingDate,
    String? meetingTitle,
    String? zoomMeetingId,
    int? durationMinutes,
    String? recordingUrl,
    String? recordingEmbedUrl,
    String? transcriptFilePath,
    String? actionItems,
    String? executiveRecap,
    String? agendaReviewed,
    String? discussionHighlights,
    String? decisionsRationales,
    String? risksOpenQuestions,
    int? attendanceCount,
    String? processingStatus,
    String? processingError,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? meetingHostId,
    Member? host,
    List<MeetingAttendance>? attendance,
  }) {
    return Meeting(
      id: id ?? this.id,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingTitle: meetingTitle ?? this.meetingTitle,
      zoomMeetingId: zoomMeetingId ?? this.zoomMeetingId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      recordingEmbedUrl: recordingEmbedUrl ?? this.recordingEmbedUrl,
      transcriptFilePath: transcriptFilePath ?? this.transcriptFilePath,
      actionItems: actionItems ?? this.actionItems,
      executiveRecap: executiveRecap ?? this.executiveRecap,
      agendaReviewed: agendaReviewed ?? this.agendaReviewed,
      discussionHighlights: discussionHighlights ?? this.discussionHighlights,
      decisionsRationales: decisionsRationales ?? this.decisionsRationales,
      risksOpenQuestions: risksOpenQuestions ?? this.risksOpenQuestions,
      attendanceCount: attendanceCount ?? this.attendanceCount,
      processingStatus: processingStatus ?? this.processingStatus,
      processingError: processingError ?? this.processingError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      meetingHostId: meetingHostId ?? this.meetingHostId,
      host: host ?? this.host,
      attendance: attendance ?? this.attendance,
    );
  }

  Map<String, dynamic> toJson({bool includeAttendance = true}) {
    return {
      'id': id,
      'meeting_date': meetingDate.toUtc().toIso8601String(),
      'meeting_title': meetingTitle,
      'zoom_meeting_id': zoomMeetingId,
      'duration_minutes': durationMinutes,
      'recording_url': recordingUrl,
      'recording_embed_url': recordingEmbedUrl,
      'transcript_file_path': transcriptFilePath,
      'action_items': actionItems,
      'executive_recap': executiveRecap,
      'agenda_reviewed': agendaReviewed,
      'discussion_highlights': discussionHighlights,
      'decisions_rationales': decisionsRationales,
      'risks_open_questions': risksOpenQuestions,
      'attendance_count': attendanceCount,
      'processing_status': processingStatus,
      'processing_error': processingError,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'meeting_host': meetingHostId,
      if (host != null) 'host': host!.toJson(),
      if (includeAttendance)
        'attendance': attendance.map((record) => record.toJson(includeMeeting: false)).toList(),
    };
  }

  factory Meeting.fromJson(Map<String, dynamic> json, {bool includeAttendance = true}) {
    Member? host;
    final hostData = json['host'];
    if (hostData is Map<String, dynamic>) {
      host = Member.fromJson(hostData);
    }

    final meeting = Meeting(
      id: json['id'] as String,
      meetingDate: _parseDateTime(json['meeting_date'], isRequired: true, fieldName: 'meeting_date')!,
      meetingTitle: json['meeting_title'] as String,
      zoomMeetingId: json['zoom_meeting_id'] as String?,
      durationMinutes: _parseInt(json['duration_minutes']),
      recordingUrl: json['recording_url'] as String?,
      recordingEmbedUrl: json['recording_embed_url'] as String?,
      transcriptFilePath: json['transcript_file_path'] as String?,
      actionItems: json['action_items'] as String?,
      executiveRecap: json['executive_recap'] as String?,
      agendaReviewed: json['agenda_reviewed'] as String?,
      discussionHighlights: json['discussion_highlights'] as String?,
      decisionsRationales: json['decisions_rationales'] as String?,
      risksOpenQuestions: json['risks_open_questions'] as String?,
      attendanceCount: _parseInt(json['attendance_count']),
      processingStatus: json['processing_status'] as String?,
      processingError: json['processing_error'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      meetingHostId: json['meeting_host'] as String?,
      host: host,
      attendance: const [],
    );

    if (!includeAttendance) {
      return meeting;
    }

    final attendanceData = json['attendance'];
    if (attendanceData is List) {
      final attendance = attendanceData
          .whereType<Map<String, dynamic>>()
          .map((item) => MeetingAttendance.fromJson(item, meeting: meeting))
          .toList();
      return meeting.copyWith(attendance: attendance);
    }

    return meeting;
  }

  String get formattedDate => '${meetingDate.month}/${meetingDate.day}/${meetingDate.year}';
  String get formattedTime => '${meetingDate.hour.toString().padLeft(2, '0')}:${meetingDate.minute.toString().padLeft(2, '0')}';
}

class MeetingAttendance {
  final String id;
  final String? meetingId;
  final String? memberId;
  final int? totalDurationMinutes;
  final DateTime? firstJoinTime;
  final DateTime? lastLeaveTime;
  final int? numberOfJoins;
  final String? zoomDisplayName;
  final String? zoomEmail;
  final String? matchedBy;
  final DateTime? createdAt;
  final bool? isHost;
  final Member? member;
  final Meeting? meeting;
  final String? meetingTitle;
  final DateTime? meetingDate;
  final String? meetingRecordingUrl;
  final String? meetingRecordingEmbedUrl;

  const MeetingAttendance({
    required this.id,
    this.meetingId,
    this.memberId,
    this.totalDurationMinutes,
    this.firstJoinTime,
    this.lastLeaveTime,
    this.numberOfJoins,
    this.zoomDisplayName,
    this.zoomEmail,
    this.matchedBy,
    this.createdAt,
    this.isHost,
    this.member,
    this.meeting,
    this.meetingTitle,
    this.meetingDate,
    this.meetingRecordingUrl,
    this.meetingRecordingEmbedUrl,
  });

  MeetingAttendance copyWith({
    String? id,
    String? meetingId,
    String? memberId,
    int? totalDurationMinutes,
    DateTime? firstJoinTime,
    DateTime? lastLeaveTime,
    int? numberOfJoins,
    String? zoomDisplayName,
    String? zoomEmail,
    String? matchedBy,
    DateTime? createdAt,
    bool? isHost,
    Member? member,
    Meeting? meeting,
    String? meetingTitle,
    DateTime? meetingDate,
    String? meetingRecordingUrl,
    String? meetingRecordingEmbedUrl,
  }) {
    return MeetingAttendance(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      memberId: memberId ?? this.memberId,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      firstJoinTime: firstJoinTime ?? this.firstJoinTime,
      lastLeaveTime: lastLeaveTime ?? this.lastLeaveTime,
      numberOfJoins: numberOfJoins ?? this.numberOfJoins,
      zoomDisplayName: zoomDisplayName ?? this.zoomDisplayName,
      zoomEmail: zoomEmail ?? this.zoomEmail,
      matchedBy: matchedBy ?? this.matchedBy,
      createdAt: createdAt ?? this.createdAt,
      isHost: isHost ?? this.isHost,
      member: member ?? this.member,
      meeting: meeting ?? this.meeting,
      meetingTitle: meetingTitle ?? this.meetingTitle,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingRecordingUrl: meetingRecordingUrl ?? this.meetingRecordingUrl,
      meetingRecordingEmbedUrl: meetingRecordingEmbedUrl ?? this.meetingRecordingEmbedUrl,
    );
  }

  Map<String, dynamic> toJson({bool includeMeeting = true, bool includeMember = true}) {
    return {
      'id': id,
      'meeting_id': meetingId,
      'member_id': memberId,
      'total_duration_minutes': totalDurationMinutes,
      'first_join_time': firstJoinTime?.toIso8601String(),
      'last_leave_time': lastLeaveTime?.toIso8601String(),
      'number_of_joins': numberOfJoins,
      'zoom_display_name': zoomDisplayName,
      'zoom_email': zoomEmail,
      'matched_by': matchedBy,
      'created_at': createdAt?.toIso8601String(),
      'is_host': isHost,
      if (includeMember && member != null) 'member': member!.toJson(),
      if (includeMeeting && meeting != null) 'meeting': meeting!.toJson(includeAttendance: false),
      'meeting_title': meetingTitle,
      'meeting_date': meetingDate?.toIso8601String(),
      'recording_url': meetingRecordingUrl,
      'recording_embed_url': meetingRecordingEmbedUrl,
    };
  }

  factory MeetingAttendance.fromJson(Map<String, dynamic> json, {Meeting? meeting}) {
    Member? member;
    final memberData = json['member'] ?? json['members'];
    if (memberData is Map<String, dynamic>) {
      member = Member.fromJson(memberData);
    }

    Meeting? meetingRef = meeting;
    final meetingData = json['meeting'];
    if (meetingData is Map<String, dynamic>) {
      meetingRef = Meeting.fromJson(meetingData, includeAttendance: false);
    }

    final meetingTitle = json['meeting_title'] as String? ?? meetingRef?.meetingTitle;
    final meetingDate = _parseDateTime(json['meeting_date']) ?? meetingRef?.meetingDate;

    return MeetingAttendance(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String? ?? meetingRef?.id,
      memberId: json['member_id'] as String?,
      totalDurationMinutes: _parseInt(json['total_duration_minutes']),
      firstJoinTime: _parseDateTime(json['first_join_time']),
      lastLeaveTime: _parseDateTime(json['last_leave_time']),
      numberOfJoins: _parseInt(json['number_of_joins']),
      zoomDisplayName: json['zoom_display_name'] as String?,
      zoomEmail: json['zoom_email'] as String?,
      matchedBy: json['matched_by'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      isHost: json['is_host'] as bool?,
      member: member,
      meeting: meetingRef,
      meetingTitle: meetingTitle,
      meetingDate: meetingDate,
      meetingRecordingUrl: json['recording_url'] as String? ?? meetingRef?.recordingUrl,
      meetingRecordingEmbedUrl: json['recording_embed_url'] as String? ?? meetingRef?.recordingEmbedUrl,
    );
  }

  String get participantName => member?.name ?? zoomDisplayName ?? 'Unknown Participant';

  String get meetingLabel => meetingTitle ?? meeting?.meetingTitle ?? 'Meeting';

  String? get formattedMeetingDate {
    final date = meetingDate ?? meeting?.meetingDate;
    if (date == null) return null;
    return '${date.month}/${date.day}/${date.year}';
  }
}
