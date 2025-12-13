/// Event types for categorization
enum EventType {
  general,
  committee,
  executive,
  social,
  deadline;

  static EventType fromString(String? value) {
    if (value == null) return EventType.general;
    return EventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventType.general,
    );
  }
}

/// Visibility levels for events
enum EventVisibility {
  public,
  organization,
  committee,
  private;

  static EventVisibility fromString(String? value) {
    if (value == null) return EventVisibility.organization;
    return EventVisibility.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventVisibility.organization,
    );
  }
}

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

/// Model representing a calendar event
class CalendarEvent {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Event details
  final String title;
  final String? description;
  final String? location;

  // Timing
  final DateTime startTime;
  final DateTime endTime;
  final bool allDay;
  final String timezone;

  // Recurrence
  final String? recurrenceRule;
  final DateTime? recurrenceEnd;
  final String? parentEventId;

  // Organization
  final EventType eventType;
  final String? committeeName;

  // Visibility
  final bool isPublic;
  final EventVisibility visibility;

  // Source tracking
  final String createdBy;
  final String? googleEventId;
  final int? zoomMeetingId;

  // Status
  final EventStatus status;

  const CalendarEvent({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    this.allDay = false,
    this.timezone = 'America/Chicago',
    this.recurrenceRule,
    this.recurrenceEnd,
    this.parentEventId,
    this.eventType = EventType.general,
    this.committeeName,
    this.isPublic = true,
    this.visibility = EventVisibility.organization,
    required this.createdBy,
    this.googleEventId,
    this.zoomMeetingId,
    this.status = EventStatus.confirmed,
  });

  /// Creates a CalendarEvent from JSON data
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      allDay: json['all_day'] as bool? ?? false,
      timezone: json['timezone'] as String? ?? 'America/Chicago',
      recurrenceRule: json['recurrence_rule'] as String?,
      recurrenceEnd: json['recurrence_end'] != null
          ? DateTime.parse(json['recurrence_end'] as String)
          : null,
      parentEventId: json['parent_event_id'] as String?,
      eventType: EventType.fromString(json['event_type'] as String?),
      committeeName: json['committee_name'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      visibility: EventVisibility.fromString(json['visibility'] as String?),
      createdBy: json['created_by'] as String,
      googleEventId: json['google_event_id'] as String?,
      zoomMeetingId: json['zoom_meeting_id'] != null
          ? (json['zoom_meeting_id'] as num).toInt()
          : null,
      status: EventStatus.fromString(json['status'] as String?),
    );
  }

  /// Converts the CalendarEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'all_day': allDay,
      'timezone': timezone,
      if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      if (recurrenceEnd != null)
        'recurrence_end': recurrenceEnd!.toUtc().toIso8601String(),
      if (parentEventId != null) 'parent_event_id': parentEventId,
      'event_type': eventType.name,
      if (committeeName != null) 'committee_name': committeeName,
      'is_public': isPublic,
      'visibility': visibility.name,
      'created_by': createdBy,
      if (googleEventId != null) 'google_event_id': googleEventId,
      if (zoomMeetingId != null) 'zoom_meeting_id': zoomMeetingId,
      'status': status.name,
    };
  }

  /// Creates a copy of this event with the given fields replaced
  CalendarEvent copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
    String? timezone,
    String? recurrenceRule,
    DateTime? recurrenceEnd,
    String? parentEventId,
    EventType? eventType,
    String? committeeName,
    bool? isPublic,
    EventVisibility? visibility,
    String? createdBy,
    String? googleEventId,
    int? zoomMeetingId,
    EventStatus? status,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allDay: allDay ?? this.allDay,
      timezone: timezone ?? this.timezone,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceEnd: recurrenceEnd ?? this.recurrenceEnd,
      parentEventId: parentEventId ?? this.parentEventId,
      eventType: eventType ?? this.eventType,
      committeeName: committeeName ?? this.committeeName,
      isPublic: isPublic ?? this.isPublic,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy ?? this.createdBy,
      googleEventId: googleEventId ?? this.googleEventId,
      zoomMeetingId: zoomMeetingId ?? this.zoomMeetingId,
      status: status ?? this.status,
    );
  }

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

  /// Whether this is a recurring event
  bool get isRecurring => recurrenceRule != null;

  /// Whether this is an instance of a recurring event
  bool get isRecurrenceInstance => parentEventId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
