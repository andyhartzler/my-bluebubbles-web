import 'package:bluebubbles/models/crm/member.dart';

DateTime? _parseDateTime(dynamic value, {bool required = false, String? fieldName}) {
  if (value == null) {
    if (required) {
      throw FormatException('Missing required ${fieldName ?? 'date'}');
    }
    return null;
  }

  if (value is DateTime) {
    return value.toLocal();
  }

  if (value is String) {
    if (value.isEmpty) {
      if (required) {
        throw FormatException('Empty string for ${fieldName ?? 'date'}');
      }
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }

  if (required) {
    throw FormatException('Invalid ${fieldName ?? 'date'} value: $value');
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class Event {
  final String? id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final String? location;
  final String? locationAddress;
  final String? eventType;
  final bool rsvpEnabled;
  final DateTime? rsvpDeadline;
  final int? maxAttendees;
  final bool checkinEnabled;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Member? createdByMember;

  const Event({
    required this.title,
    required this.eventDate,
    required this.status,
    this.id,
    this.description,
    this.eventEndDate,
    this.location,
    this.locationAddress,
    this.eventType,
    this.rsvpEnabled = true,
    this.rsvpDeadline,
    this.maxAttendees,
    this.checkinEnabled = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.createdByMember,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventDate,
    DateTime? eventEndDate,
    String? location,
    String? locationAddress,
    String? eventType,
    bool? rsvpEnabled,
    DateTime? rsvpDeadline,
    int? maxAttendees,
    bool? checkinEnabled,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Member? createdByMember,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      eventType: eventType ?? this.eventType,
      rsvpEnabled: rsvpEnabled ?? this.rsvpEnabled,
      rsvpDeadline: rsvpDeadline ?? this.rsvpDeadline,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      checkinEnabled: checkinEnabled ?? this.checkinEnabled,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByMember: createdByMember ?? this.createdByMember,
    );
  }

  Map<String, dynamic> toInsertPayload() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toUtc().toIso8601String(),
      'event_end_date': eventEndDate?.toUtc().toIso8601String(),
      'location': location,
      'location_address': locationAddress,
      'event_type': eventType,
      'rsvp_enabled': rsvpEnabled,
      'rsvp_deadline': rsvpDeadline?.toUtc().toIso8601String(),
      'max_attendees': maxAttendees,
      'checkin_enabled': checkinEnabled,
      'status': status,
      'created_by': createdBy,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toUtc().toIso8601String(),
      'event_end_date': eventEndDate?.toUtc().toIso8601String(),
      'location': location,
      'location_address': locationAddress,
      'event_type': eventType,
      'rsvp_enabled': rsvpEnabled,
      'rsvp_deadline': rsvpDeadline?.toUtc().toIso8601String(),
      'max_attendees': maxAttendees,
      'checkin_enabled': checkinEnabled,
      'status': status,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    Member? createdByMember;
    final creatorJson = json['created_by_member'];
    if (creatorJson is Map<String, dynamic>) {
      createdByMember = Member.fromJson(creatorJson);
    }

    return Event(
      id: json['id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventDate: _parseDateTime(json['event_date'], required: true, fieldName: 'event_date')!,
      eventEndDate: _parseDateTime(json['event_end_date'], fieldName: 'event_end_date'),
      location: json['location'] as String?,
      locationAddress: json['location_address'] as String?,
      eventType: json['event_type'] as String?,
      rsvpEnabled: json['rsvp_enabled'] as bool? ?? true,
      rsvpDeadline: _parseDateTime(json['rsvp_deadline'], fieldName: 'rsvp_deadline'),
      maxAttendees: _parseInt(json['max_attendees']),
      checkinEnabled: json['checkin_enabled'] as bool? ?? false,
      status: json['status'] as String? ?? 'draft',
      createdBy: json['created_by'] as String?,
      createdAt: _parseDateTime(json['created_at'], fieldName: 'created_at'),
      updatedAt: _parseDateTime(json['updated_at'], fieldName: 'updated_at'),
      createdByMember: createdByMember,
    );
  }
}

class EventStats {
  final int totalRsvps;
  final int checkedIn;
  final int members;
  final int guests;

  const EventStats({
    required this.totalRsvps,
    required this.checkedIn,
    required this.members,
    required this.guests,
  });

  double get attendanceRate => totalRsvps == 0 ? 0 : (checkedIn / totalRsvps) * 100;

  factory EventStats.fromAttendees(List<EventAttendee> attendees) {
    final totalRsvps = attendees.where((a) => a.rsvpStatus == 'attending').fold<int>(0, (sum, a) => sum + (a.guestCount ?? 0) + 1);
    final checkedIn = attendees.where((a) => a.checkedIn).length;
    final members = attendees.where((a) => a.memberId != null).length;
    final guests = attendees.where((a) => a.memberId == null).length;
    return EventStats(
      totalRsvps: totalRsvps,
      checkedIn: checkedIn,
      members: members,
      guests: guests,
    );
  }
}

class EventAttendee {
  final String id;
  final String eventId;
  final String? memberId;
  final String? guestName;
  final String? guestEmail;
  final String? guestPhone;
  final String rsvpStatus;
  final int? guestCount;
  final String? notes;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final DateTime rsvpAt;
  final DateTime updatedAt;
  final Member? member;
  final double? totalDonated;
  final bool? isRecurringDonor;

  const EventAttendee({
    required this.id,
    required this.eventId,
    required this.rsvpStatus,
    required this.checkedIn,
    required this.rsvpAt,
    required this.updatedAt,
    this.memberId,
    this.guestName,
    this.guestEmail,
    this.guestPhone,
    this.guestCount,
    this.notes,
    this.checkedInAt,
    this.checkedInBy,
    this.member,
    this.totalDonated,
    this.isRecurringDonor,
  });

  String get displayName => member?.name ?? guestName ?? 'Unknown attendee';

  EventAttendee copyWith({
    bool? checkedIn,
    DateTime? checkedInAt,
    String? checkedInBy,
    double? totalDonated,
    bool? isRecurringDonor,
  }) {
    return EventAttendee(
      id: id,
      eventId: eventId,
      rsvpStatus: rsvpStatus,
      checkedIn: checkedIn ?? this.checkedIn,
      rsvpAt: rsvpAt,
      updatedAt: updatedAt,
      memberId: memberId,
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      guestCount: guestCount,
      notes: notes,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedInBy: checkedInBy ?? this.checkedInBy,
      member: member,
      totalDonated: totalDonated ?? this.totalDonated,
      isRecurringDonor: isRecurringDonor ?? this.isRecurringDonor,
    );
  }

  factory EventAttendee.fromJson(Map<String, dynamic> json) {
    Member? member;
    final memberJson = json['members'] ?? json['member'];
    if (memberJson is Map<String, dynamic>) {
      member = Member.fromJson(memberJson);
    }

    return EventAttendee(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      memberId: json['member_id'] as String?,
      guestName: json['guest_name'] as String?,
      guestEmail: json['guest_email'] as String?,
      guestPhone: json['guest_phone'] as String?,
      rsvpStatus: json['rsvp_status'] as String? ?? 'attending',
      guestCount: _parseInt(json['guest_count']),
      notes: json['notes'] as String?,
      checkedIn: json['checked_in'] as bool? ?? false,
      checkedInAt: _parseDateTime(json['checked_in_at'], fieldName: 'checked_in_at'),
      checkedInBy: json['checked_in_by'] as String?,
      rsvpAt: _parseDateTime(json['rsvp_at'], required: true, fieldName: 'rsvp_at')!,
      updatedAt: _parseDateTime(json['updated_at'], required: true, fieldName: 'updated_at')!,
      member: member,
      totalDonated: _parseDouble(json['total_donated']),
      isRecurringDonor: json['is_recurring_donor'] as bool?,
    );
  }
}
