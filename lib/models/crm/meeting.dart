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
  final String? recordingThumbnailUrl;
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
  final List<NonMemberAttendee> nonMemberAttendees;

  const Meeting({
    required this.id,
    required this.meetingDate,
    required this.meetingTitle,
    this.zoomMeetingId,
    this.durationMinutes,
    this.recordingUrl,
    this.recordingEmbedUrl,
    this.recordingThumbnailUrl,
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
    this.nonMemberAttendees = const [],
  });

  Meeting copyWith({
    String? id,
    DateTime? meetingDate,
    String? meetingTitle,
    String? zoomMeetingId,
    int? durationMinutes,
    String? recordingUrl,
    String? recordingEmbedUrl,
    String? recordingThumbnailUrl,
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
    List<NonMemberAttendee>? nonMemberAttendees,
  }) {
    return Meeting(
      id: id ?? this.id,
      meetingDate: meetingDate ?? this.meetingDate,
      meetingTitle: meetingTitle ?? this.meetingTitle,
      zoomMeetingId: zoomMeetingId ?? this.zoomMeetingId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      recordingEmbedUrl: recordingEmbedUrl ?? this.recordingEmbedUrl,
      recordingThumbnailUrl: recordingThumbnailUrl ?? this.recordingThumbnailUrl,
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
      nonMemberAttendees: nonMemberAttendees ?? this.nonMemberAttendees,
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
      'recording_thumbnail_url': recordingThumbnailUrl,
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
      if (includeAttendance)
        'non_member_attendees':
            nonMemberAttendees.map((attendee) => attendee.toJson(includeMeeting: false)).toList(),
    };
  }

  factory Meeting.fromJson(Map<String, dynamic> json, {bool includeAttendance = true}) {
    Member? host;
    final hostData = json['host'];
    if (hostData is Map<String, dynamic>) {
      host = Member.fromJson(hostData);
    }

    var meeting = Meeting(
      id: json['id'] as String,
      meetingDate: _parseDateTime(json['meeting_date'], isRequired: true, fieldName: 'meeting_date')!,
      meetingTitle: json['meeting_title'] as String,
      zoomMeetingId: json['zoom_meeting_id'] as String?,
      durationMinutes: _parseInt(json['duration_minutes']),
      recordingUrl: json['recording_url'] as String?,
      recordingEmbedUrl: json['recording_embed_url'] as String?,
      recordingThumbnailUrl: json['recording_thumbnail_url'] as String?,
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
      nonMemberAttendees: const [],
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
      meeting = meeting.copyWith(attendance: attendance);
    }

    final nonMemberData = json['non_member_attendees'];
    if (nonMemberData is List) {
      final guests = nonMemberData
          .whereType<Map<String, dynamic>>()
          .map((item) => NonMemberAttendee.fromJson(item, meeting: meeting))
          .toList();
      meeting = meeting.copyWith(nonMemberAttendees: guests);
    }

    return meeting;
  }

  String get formattedDate => '${meetingDate.month}/${meetingDate.day}/${meetingDate.year}';
  String get formattedTime {
    final hour = meetingDate.hour;
    final minute = meetingDate.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
  }

  String? get resolvedRecordingEmbedUrl {
    final candidate = (recordingEmbedUrl ?? recordingUrl)?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('drive.google.com')) {
      final id = _extractDriveIdFromUri(uri);
      if (id != null) {
        return 'https://drive.google.com/file/d/$id/preview';
      }
    }
    return uri.toString();
  }

  String? get resolvedRecordingThumbnailUrl {
    final provided = recordingThumbnailUrl?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final candidate = (recordingEmbedUrl ?? recordingUrl)?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    final uri = Uri.tryParse(candidate);
    if (uri == null) return null;
    final id = _extractDriveIdFromUri(uri);
    if (id == null) return null;
    return 'https://lh3.googleusercontent.com/d/$id=w1200-h675-n-k-no';
  }
}

class NonMemberAttendee {
  final String id;
  final String meetingId;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? pronouns;
  final int? totalDurationMinutes;
  final DateTime? firstJoinTime;
  final DateTime? lastLeaveTime;
  final int? numberOfJoins;
  final DateTime? createdAt;
  final Meeting? meeting;

  const NonMemberAttendee({
    required this.id,
    required this.meetingId,
    required this.displayName,
    this.email,
    this.phoneNumber,
    this.pronouns,
    this.totalDurationMinutes,
    this.firstJoinTime,
    this.lastLeaveTime,
    this.numberOfJoins,
    this.createdAt,
    this.meeting,
  });

  NonMemberAttendee copyWith({
    String? id,
    String? meetingId,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? pronouns,
    int? totalDurationMinutes,
    DateTime? firstJoinTime,
    DateTime? lastLeaveTime,
    int? numberOfJoins,
    DateTime? createdAt,
    Meeting? meeting,
  }) {
    return NonMemberAttendee(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pronouns: pronouns ?? this.pronouns,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      firstJoinTime: firstJoinTime ?? this.firstJoinTime,
      lastLeaveTime: lastLeaveTime ?? this.lastLeaveTime,
      numberOfJoins: numberOfJoins ?? this.numberOfJoins,
      createdAt: createdAt ?? this.createdAt,
      meeting: meeting ?? this.meeting,
    );
  }

  Map<String, dynamic> toJson({bool includeMeeting = true}) {
    return {
      'id': id,
      'meeting_id': meetingId,
      'display_name': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'pronouns': pronouns,
      'total_duration_minutes': totalDurationMinutes,
      'first_join_time': firstJoinTime?.toIso8601String(),
      'last_leave_time': lastLeaveTime?.toIso8601String(),
      'number_of_joins': numberOfJoins,
      'created_at': createdAt?.toIso8601String(),
      if (includeMeeting && meeting != null)
        'meeting': meeting!.toJson(includeAttendance: false),
    };
  }

  factory NonMemberAttendee.fromJson(Map<String, dynamic> json, {Meeting? meeting}) {
    Meeting? meetingRef = meeting;
    final meetingData = json['meeting'];
    if (meetingData is Map<String, dynamic>) {
      meetingRef = Meeting.fromJson(meetingData, includeAttendance: false);
    }

    return NonMemberAttendee(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      displayName: json['display_name'] as String? ?? 'Guest',
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      pronouns: json['pronouns'] as String?,
      totalDurationMinutes: _parseInt(json['total_duration_minutes']),
      firstJoinTime: _parseDateTime(json['first_join_time']),
      lastLeaveTime: _parseDateTime(json['last_leave_time']),
      numberOfJoins: _parseInt(json['number_of_joins']),
      createdAt: _parseDateTime(json['created_at']),
      meeting: meetingRef,
    );
  }

  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts.last[0]).toUpperCase();
  }

  String? get formattedJoinWindow {
    final start = firstJoinTime;
    final end = lastLeaveTime;
    if (start == null && end == null) return null;
    final buffer = StringBuffer();
    if (start != null) {
      buffer.write('${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}');
    }
    if (end != null) {
      if (buffer.isNotEmpty) buffer.write(' – ');
      buffer.write('${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}');
    }
    return buffer.toString();
  }
}

String? _extractDriveIdFromUri(Uri uri) {
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.length >= 3 && segments.first == 'file') {
    final dIndex = segments.indexOf('d');
    if (dIndex != -1 && segments.length > dIndex + 1) {
      final id = segments[dIndex + 1];
      if (id.isNotEmpty) {
        return id;
      }
    }
  }

  final queryId = uri.queryParameters['id'] ?? uri.queryParameters['fileId'];
  if (queryId != null && queryId.isNotEmpty) {
    return queryId;
  }

  return null;
}

class MeetingAttendance {
  final String id;
  final String? meetingId;
  final String? memberId;
  final String? guestName;
  final String? guestEmail;
  final String? guestPhone;
  final String? rsvpStatus;
  final int? guestCount;
  final String? notes;
  final bool? checkedIn;
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
    this.guestName,
    this.guestEmail,
    this.guestPhone,
    this.rsvpStatus,
    this.guestCount,
    this.notes,
    this.checkedIn,
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
    String? guestName,
    String? guestEmail,
    String? guestPhone,
    String? rsvpStatus,
    int? guestCount,
    String? notes,
    bool? checkedIn,
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
      guestName: guestName ?? this.guestName,
      guestEmail: guestEmail ?? this.guestEmail,
      guestPhone: guestPhone ?? this.guestPhone,
      rsvpStatus: rsvpStatus ?? this.rsvpStatus,
      guestCount: guestCount ?? this.guestCount,
      notes: notes ?? this.notes,
      checkedIn: checkedIn ?? this.checkedIn,
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
      'guest_name': guestName,
      'guest_email': guestEmail,
      'guest_phone': guestPhone,
      'rsvp_status': rsvpStatus,
      'guest_count': guestCount,
      'notes': notes,
      'checked_in': checkedIn,
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
    final guestCount = _parseInt(json['guest_count']);
    final rsvpStatus = json['rsvp_status'] as String?;
    final guestName = json['guest_name'] as String?;
    final guestEmail = json['guest_email'] as String?;
    final guestPhone = json['guest_phone'] as String?;
    final notes = json['notes'] as String?;
    final checkedIn = json['checked_in'] as bool?;
    final meetingId = json['meeting_id'] as String? ?? json['event_id'] as String?;

    return MeetingAttendance(
      id: json['id'] as String,
      meetingId: meetingId ?? meetingRef?.id,
      memberId: json['member_id'] as String?,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      rsvpStatus: rsvpStatus,
      guestCount: guestCount,
      notes: notes,
      checkedIn: checkedIn,
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

  String get participantName =>
      member?.name ?? zoomDisplayName ?? guestName ?? guestEmail ?? guestPhone ?? 'Unknown Participant';

  String get meetingLabel => meetingTitle ?? meeting?.meetingTitle ?? 'Meeting';

  String? get formattedMeetingDate {
    final date = meetingDate ?? meeting?.meetingDate;
    if (date == null) return null;
    return '${date.month}/${date.day}/${date.year}';
  }

  int? get meetingDurationMinutes => meeting?.durationMinutes;

  String get durationSummary {
    final attendeeMinutes = totalDurationMinutes;
    final meetingMinutes = meetingDurationMinutes;
    if (attendeeMinutes == null && meetingMinutes == null) {
      return 'Attendance duration unavailable';
    }
    if (meetingMinutes == null) {
      return '${attendeeMinutes ?? 0} min logged';
    }
    if (attendeeMinutes == null) {
      return '0 of $meetingMinutes min logged';
    }
    return '$attendeeMinutes of $meetingMinutes min';
  }

  String? get joinWindow {
    final start = firstJoinTime;
    final end = lastLeaveTime;
    if (start == null && end == null) return null;
    String format(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (start != null && end != null) {
      return '${format(start)} – ${format(end)}';
    }
    return start != null ? 'Joined at ${format(start)}' : 'Left at ${format(end!)}';
  }
}
