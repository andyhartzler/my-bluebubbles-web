/// Model for a scheduled Zoom meeting
class ScheduledMeeting {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String title;
  final String? description;
  final DateTime meetingDate;
  final String startTime;
  final int durationMinutes;
  final String timezone;
  final int? zoomMeetingId;
  final String? zoomJoinUrl;
  final String? zoomStartUrl;
  final String? zoomPassword;
  final String hostEmail;
  final String? hostName;
  final String? committeeId;
  final String? committeeName;
  final bool emailSent;
  final DateTime? emailSentAt;
  final bool smsSent;
  final DateTime? smsSentAt;
  final MeetingStatus status;
  final DateTime? cancelledAt;

  const ScheduledMeeting({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.title,
    this.description,
    required this.meetingDate,
    required this.startTime,
    this.durationMinutes = 60,
    this.timezone = 'America/Chicago',
    this.zoomMeetingId,
    this.zoomJoinUrl,
    this.zoomStartUrl,
    this.zoomPassword,
    required this.hostEmail,
    this.hostName,
    this.committeeId,
    this.committeeName,
    this.emailSent = false,
    this.emailSentAt,
    this.smsSent = false,
    this.smsSentAt,
    this.status = MeetingStatus.scheduled,
    this.cancelledAt,
  });

  /// Creates a ScheduledMeeting from JSON data
  factory ScheduledMeeting.fromJson(Map<String, dynamic> json) {
    return ScheduledMeeting(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      meetingDate: DateTime.parse(json['meeting_date'] as String).toLocal(),
      startTime: json['start_time'] as String,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      timezone: json['timezone'] as String? ?? 'America/Chicago',
      zoomMeetingId: json['zoom_meeting_id'] != null
          ? (json['zoom_meeting_id'] as num).toInt()
          : null,
      zoomJoinUrl: json['zoom_join_url'] as String?,
      zoomStartUrl: json['zoom_start_url'] as String?,
      zoomPassword: json['zoom_password'] as String?,
      hostEmail: json['host_email'] as String,
      hostName: json['host_name'] as String?,
      committeeId: json['committee_id'] as String?,
      committeeName: json['committee_name'] as String?,
      emailSent: json['email_sent'] as bool? ?? false,
      emailSentAt: json['email_sent_at'] != null
          ? DateTime.parse(json['email_sent_at'] as String).toLocal()
          : null,
      smsSent: json['sms_sent'] as bool? ?? false,
      smsSentAt: json['sms_sent_at'] != null
          ? DateTime.parse(json['sms_sent_at'] as String).toLocal()
          : null,
      status: MeetingStatus.fromString(json['status'] as String? ?? 'scheduled'),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String).toLocal()
          : null,
    );
  }

  /// Converts this ScheduledMeeting to JSON for database insertion
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      'created_by': createdBy,
      'title': title,
      if (description != null) 'description': description,
      'meeting_date': _formatDate(meetingDate),
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'timezone': timezone,
      if (zoomMeetingId != null) 'zoom_meeting_id': zoomMeetingId,
      if (zoomJoinUrl != null) 'zoom_join_url': zoomJoinUrl,
      if (zoomStartUrl != null) 'zoom_start_url': zoomStartUrl,
      if (zoomPassword != null) 'zoom_password': zoomPassword,
      'host_email': hostEmail,
      if (hostName != null) 'host_name': hostName,
      if (committeeId != null) 'committee_id': committeeId,
      if (committeeName != null) 'committee_name': committeeName,
      'email_sent': emailSent,
      if (emailSentAt != null) 'email_sent_at': emailSentAt!.toUtc().toIso8601String(),
      'sms_sent': smsSent,
      if (smsSentAt != null) 'sms_sent_at': smsSentAt!.toUtc().toIso8601String(),
      'status': status.value,
      if (cancelledAt != null) 'cancelled_at': cancelledAt!.toUtc().toIso8601String(),
    };
  }

  /// Creates a copy of this meeting with the given fields replaced
  ScheduledMeeting copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? title,
    String? description,
    DateTime? meetingDate,
    String? startTime,
    int? durationMinutes,
    String? timezone,
    int? zoomMeetingId,
    String? zoomJoinUrl,
    String? zoomStartUrl,
    String? zoomPassword,
    String? hostEmail,
    String? hostName,
    String? committeeId,
    String? committeeName,
    bool? emailSent,
    DateTime? emailSentAt,
    bool? smsSent,
    DateTime? smsSentAt,
    MeetingStatus? status,
    DateTime? cancelledAt,
  }) {
    return ScheduledMeeting(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      meetingDate: meetingDate ?? this.meetingDate,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      timezone: timezone ?? this.timezone,
      zoomMeetingId: zoomMeetingId ?? this.zoomMeetingId,
      zoomJoinUrl: zoomJoinUrl ?? this.zoomJoinUrl,
      zoomStartUrl: zoomStartUrl ?? this.zoomStartUrl,
      zoomPassword: zoomPassword ?? this.zoomPassword,
      hostEmail: hostEmail ?? this.hostEmail,
      hostName: hostName ?? this.hostName,
      committeeId: committeeId ?? this.committeeId,
      committeeName: committeeName ?? this.committeeName,
      emailSent: emailSent ?? this.emailSent,
      emailSentAt: emailSentAt ?? this.emailSentAt,
      smsSent: smsSent ?? this.smsSent,
      smsSentAt: smsSentAt ?? this.smsSentAt,
      status: status ?? this.status,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  /// Returns a DateTime combining meetingDate and startTime
  DateTime get startDateTime {
    final timeParts = startTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    return DateTime(
      meetingDate.year,
      meetingDate.month,
      meetingDate.day,
      hour,
      minute,
    );
  }

  /// Returns the formatted date string (e.g., "December 20, 2024")
  String get formattedDate {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[meetingDate.month - 1]} ${meetingDate.day}, ${meetingDate.year}';
  }

  /// Returns the formatted time string (e.g., "2:00 PM")
  String get formattedTime {
    final timeParts = startTime.split(':');
    var hour = int.parse(timeParts[0]);
    final minute = timeParts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$minute $period';
  }

  /// Returns a formatted duration string (e.g., "1 hour", "30 minutes")
  String get formattedDuration {
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      if (mins == 0) {
        return hours == 1 ? '1 hour' : '$hours hours';
      }
      return '$hours hr ${mins} min';
    }
    return '$durationMinutes minutes';
  }

  /// Returns true if the meeting is in the past
  bool get isPast => startDateTime.isBefore(DateTime.now());

  /// Returns true if the meeting is today
  bool get isToday {
    final now = DateTime.now();
    return meetingDate.year == now.year &&
        meetingDate.month == now.month &&
        meetingDate.day == now.day;
  }

  /// Helper to format date as YYYY-MM-DD for database
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Available duration options in minutes
  static const List<int> durationOptions = [15, 30, 45, 60, 90, 120];

  /// Returns a display label for a duration value
  static String durationLabel(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return hours == 1 ? '1 hour' : '$hours hours';
      }
      return '$hours hr ${mins} min';
    }
    return '$minutes minutes';
  }
}

/// Status of a scheduled meeting
enum MeetingStatus {
  scheduled('scheduled'),
  completed('completed'),
  cancelled('cancelled');

  const MeetingStatus(this.value);
  final String value;

  static MeetingStatus fromString(String value) {
    return MeetingStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => MeetingStatus.scheduled,
    );
  }
}
