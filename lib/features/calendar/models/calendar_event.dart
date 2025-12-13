/// Event status
enum EventStatus {
  confirmed,
  tentative,
  cancelled;

  static EventStatus fromString(String? value) {
    if (value == null) return EventStatus.confirmed;
    return EventStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventStatus.confirmed,
    );
  }
}

/// Model representing a calendar event - matches Supabase calendar_events table
class CalendarEvent {
  final String id;
  final String? googleEventId;
  final String? calendarId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? location;
  final String? meetingLink;
  final String? zoomMeetingId; // text in DB
  final String? eventType; // 'event' is default
  final String? committeeName;
  final String? colorId;
  final bool isRecurring;
  final String? recurrenceRule;
  final String? organizerEmail;
  final String? organizerName;
  final List<Map<String, dynamic>>? attendees;
  final EventStatus status;
  final String? createdBy; // uuid, nullable
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? syncedAt;

  const CalendarEvent({
    required this.id,
    this.googleEventId,
    this.calendarId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.location,
    this.meetingLink,
    this.zoomMeetingId,
    this.eventType,
    this.committeeName,
    this.colorId,
    this.isRecurring = false,
    this.recurrenceRule,
    this.organizerEmail,
    this.organizerName,
    this.attendees,
    this.status = EventStatus.confirmed,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.syncedAt,
  });

  /// Creates a CalendarEvent from JSON data (Supabase row)
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    // Parse attendees from JSONB
    List<Map<String, dynamic>>? attendeesList;
    if (json['attendees'] != null) {
      if (json['attendees'] is List) {
        attendeesList = (json['attendees'] as List)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
      } else if (json['attendees'] is String) {
        // Sometimes JSONB comes as a string
        try {
          final parsed = json['attendees'];
          if (parsed is List) {
            attendeesList = parsed.cast<Map<String, dynamic>>();
          }
        } catch (_) {
          attendeesList = null;
        }
      }
    }

    return CalendarEvent(
      id: json['id'] as String,
      googleEventId: json['google_event_id'] as String?,
      calendarId: json['calendar_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      isAllDay: json['is_all_day'] as bool? ?? false,
      location: json['location'] as String?,
      meetingLink: json['meeting_link'] as String?,
      zoomMeetingId: json['zoom_meeting_id'] as String?,
      eventType: json['event_type'] as String?,
      committeeName: json['committee_name'] as String?,
      colorId: json['color_id'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrenceRule: json['recurrence_rule'] as String?,
      organizerEmail: json['organizer_email'] as String?,
      organizerName: json['organizer_name'] as String?,
      attendees: attendeesList,
      status: EventStatus.fromString(json['status'] as String?),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }

  /// Converts the CalendarEvent to JSON for database insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (googleEventId != null) 'google_event_id': googleEventId,
      if (calendarId != null) 'calendar_id': calendarId,
      'title': title,
      if (description != null) 'description': description,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      if (location != null) 'location': location,
      if (meetingLink != null) 'meeting_link': meetingLink,
      if (zoomMeetingId != null) 'zoom_meeting_id': zoomMeetingId,
      if (eventType != null) 'event_type': eventType,
      if (committeeName != null) 'committee_name': committeeName,
      if (colorId != null) 'color_id': colorId,
      'is_recurring': isRecurring,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (organizerEmail != null) 'organizer_email': organizerEmail,
      if (organizerName != null) 'organizer_name': organizerName,
      if (attendees != null) 'attendees': attendees,
      'status': status.name,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  /// Creates a copy with updated fields
  CalendarEvent copyWith({
    String? id,
    String? googleEventId,
    String? calendarId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    String? meetingLink,
    String? zoomMeetingId,
    String? eventType,
    String? committeeName,
    String? colorId,
    bool? isRecurring,
    String? recurrenceRule,
    String? organizerEmail,
    String? organizerName,
    List<Map<String, dynamic>>? attendees,
    EventStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      googleEventId: googleEventId ?? this.googleEventId,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      meetingLink: meetingLink ?? this.meetingLink,
      zoomMeetingId: zoomMeetingId ?? this.zoomMeetingId,
      eventType: eventType ?? this.eventType,
      committeeName: committeeName ?? this.committeeName,
      colorId: colorId ?? this.colorId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      organizerName: organizerName ?? this.organizerName,
      attendees: attendees ?? this.attendees,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // Convenience getters

  /// Gets the duration of the event
  Duration get duration => endTime.difference(startTime);

  /// Formats the duration as a readable string
  String get formattedDuration {
    final d = duration;
    if (d.inDays > 0) {
      return '${d.inDays} day${d.inDays > 1 ? 's' : ''}';
    }
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60);
      if (minutes > 0) {
        return '${d.inHours}h ${minutes}m';
      }
      return '${d.inHours} hour${d.inHours > 1 ? 's' : ''}';
    }
    return '${d.inMinutes} minutes';
  }

  /// Whether the event is happening now
  bool get isHappeningNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Whether the event is in the past
  bool get isPast => endTime.isBefore(DateTime.now());

  /// Whether the event is in the future
  bool get isFuture => startTime.isAfter(DateTime.now());

  /// Whether this event has a Zoom meeting link
  bool get hasZoomMeeting =>
      zoomMeetingId != null ||
      (meetingLink != null && meetingLink!.contains('zoom'));

  /// Shorthand for allDay
  bool get allDay => isAllDay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
