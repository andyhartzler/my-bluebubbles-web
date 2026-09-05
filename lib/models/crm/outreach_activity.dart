import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
//  OUTREACH TRACKING models. Maps to public.outreach_activities and
//  public.outreach_participants (Layer 2 of Candidate Volunteers).
//  Pure data + display maps. No I/O; the repository owns Supabase.
// ═══════════════════════════════════════════════════════════════

/// Presentation for the `kind` and `status` check-in-lists, so the sheet and
/// the detail sections render a label plus an icon or color without each
/// widget re-deciding. Keys are the exact stored string values.
class OutreachDisplay {
  OutreachDisplay._();

  /// One entry per allowed `kind`. Order is the order to show in a picker.
  static const Map<String, ({String label, IconData icon})> kinds =
      <String, ({String label, IconData icon})>{
    'canvass': (label: 'Canvass', icon: Icons.door_front_door_outlined),
    'phone_bank': (label: 'Phone bank', icon: Icons.phone_outlined),
    'text_bank': (label: 'Text bank', icon: Icons.sms_outlined),
    'email_blast': (label: 'Email blast', icon: Icons.mail_outline),
    'social_blitz': (label: 'Social blitz', icon: Icons.campaign_outlined),
    'day_of_action': (label: 'Day of action', icon: Icons.event_outlined),
    'volunteer_day': (label: 'Volunteer day', icon: Icons.groups_outlined),
    'other': (label: 'Other', icon: Icons.more_horiz),
  };

  /// One entry per allowed `status`. Colors clear 4.5:1 as chip fills with
  /// white text in both themes (no gold: in_progress is a deep amber).
  static const Map<String, ({String label, Color color})> statuses =
      <String, ({String label, Color color})>{
    'planned': (label: 'Planned', color: Color(0xFF1565C0)),
    'in_progress': (label: 'In progress', color: Color(0xFFB45309)),
    'completed': (label: 'Completed', color: Color(0xFF2E7D32)),
    'cancelled': (label: 'Cancelled', color: Color(0xFF6B7280)),
  };

  static String kindLabel(String kind) => kinds[kind]?.label ?? kind;
  static IconData kindIcon(String kind) => kinds[kind]?.icon ?? Icons.more_horiz;
  static String statusLabel(String status) => statuses[status]?.label ?? status;
  static Color statusColor(String status) =>
      statuses[status]?.color ?? const Color(0xFF6B7280);
}

/// Sentinel for [OutreachActivity.copyWith]: tells "not passed" apart from
/// "set to null" so a nullable field can be cleared rather than only replaced.
/// Its own private type, not a bare Object(), because const Object() instances
/// are canonicalized and would compare identical to a caller's.
class _Unchanged {
  const _Unchanged();
}

const _Unchanged _unchanged = _Unchanged();

/// One field outreach activity. Geometry-free: the four district arrays carry
/// bare-digit district numbers and [counties] carries county names, matching
/// the map's own region keys.
class OutreachActivity {
  OutreachActivity({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    this.status = 'planned',
    this.channel,
    this.scheduledOn,
    this.completedAt,
    this.counties = const <String>[],
    this.congressionalDistricts = const <String>[],
    this.senateDistricts = const <String>[],
    this.houseDistricts = const <String>[],
    this.organizerMemberId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String kind;
  final String title;
  final String? description;
  final String status;
  final String? channel;
  final DateTime? scheduledOn;
  final DateTime? completedAt;
  final List<String> counties;
  final List<String> congressionalDistricts;
  final List<String> senateDistricts;
  final List<String> houseDistricts;
  final String? organizerMemberId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get kindLabel => OutreachDisplay.kindLabel(kind);
  IconData get kindIcon => OutreachDisplay.kindIcon(kind);
  String get statusLabel => OutreachDisplay.statusLabel(status);
  Color get statusColor => OutreachDisplay.statusColor(status);

  static List<String> _stringList(dynamic value) => value == null
      ? const <String>[]
      : (value as List).map((e) => e.toString()).toList();

  static DateTime? _date(dynamic value) => value == null
      ? null
      : DateTime.tryParse(value.toString());

  factory OutreachActivity.fromJson(Map<String, dynamic> json) {
    return OutreachActivity(
      id: json['id'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: (json['status'] as String?) ?? 'planned',
      channel: json['channel'] as String?,
      scheduledOn: _date(json['scheduled_on']),
      completedAt: _date(json['completed_at']),
      counties: _stringList(json['counties']),
      congressionalDistricts: _stringList(json['congressional_districts']),
      senateDistricts: _stringList(json['senate_districts']),
      houseDistricts: _stringList(json['house_districts']),
      organizerMemberId: json['organizer_member_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  /// Full round-trip form, including server-managed columns.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        ...toInsertJson(),
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  /// Writable columns only. Omits id/created_at/updated_at so the database
  /// defaults them; the repository overwrites created_by and
  /// organizer_member_id with the acting exec's two ids.
  Map<String, dynamic> toInsertJson() => <String, dynamic>{
        'kind': kind,
        'title': title,
        'description': description,
        'status': status,
        'channel': channel,
        'scheduled_on': scheduledOn?.toIso8601String().split('T').first,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'counties': counties,
        'congressional_districts': congressionalDistricts,
        'senate_districts': senateDistricts,
        'house_districts': houseDistricts,
        'organizer_member_id': organizerMemberId,
        'created_by': createdBy,
      };

  /// Every editable field, including the ones that can be CLEARED. Passing a
  /// literal null to a [_unchanged]-defaulted parameter sets that field to
  /// null; omitting the parameter leaves it alone. Without that distinction an
  /// edit could only ever replace a date or a description, never remove one,
  /// and `copyWith(status: 'planned', completedAt: null)` would silently keep a
  /// stale completion timestamp on the reopened activity.
  ///
  /// id, created_by, created_at and updated_at are not editable and are carried
  /// through unchanged: created_by is never rewritable and the other three are
  /// the database's to set.
  OutreachActivity copyWith({
    String? kind,
    String? title,
    Object? description = _unchanged,
    String? status,
    Object? channel = _unchanged,
    Object? scheduledOn = _unchanged,
    Object? completedAt = _unchanged,
    List<String>? counties,
    List<String>? congressionalDistricts,
    List<String>? senateDistricts,
    List<String>? houseDistricts,
    Object? organizerMemberId = _unchanged,
  }) {
    return OutreachActivity(
      id: id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: identical(description, _unchanged)
          ? this.description
          : description as String?,
      status: status ?? this.status,
      channel: identical(channel, _unchanged) ? this.channel : channel as String?,
      scheduledOn: identical(scheduledOn, _unchanged)
          ? this.scheduledOn
          : scheduledOn as DateTime?,
      completedAt: identical(completedAt, _unchanged)
          ? this.completedAt
          : completedAt as DateTime?,
      counties: counties ?? this.counties,
      congressionalDistricts:
          congressionalDistricts ?? this.congressionalDistricts,
      senateDistricts: senateDistricts ?? this.senateDistricts,
      houseDistricts: houseDistricts ?? this.houseDistricts,
      organizerMemberId: identical(organizerMemberId, _unchanged)
          ? this.organizerMemberId
          : organizerMemberId as String?,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// One member's participation in an activity, as stored.
class OutreachParticipant {
  OutreachParticipant({
    required this.id,
    required this.activityId,
    required this.memberId,
    this.role = 'volunteer',
    this.attended,
    this.createdAt,
  });

  final String id;
  final String activityId;
  final String memberId;
  final String role;

  /// null means attendance has not been recorded yet, distinct from false.
  final bool? attended;
  final DateTime? createdAt;

  factory OutreachParticipant.fromJson(Map<String, dynamic> json) {
    return OutreachParticipant(
      id: json['id'] as String,
      activityId: json['activity_id'] as String,
      memberId: json['member_id'] as String,
      role: (json['role'] as String?) ?? 'volunteer',
      attended: json['attended'] as bool?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'activity_id': activityId,
        'member_id': memberId,
        'role': role,
        'attended': attended,
      };
}

/// The fields the UI supplies when adding a participant. activity_id is
/// stamped by create_outreach_activity for a new activity, and by the
/// repository for one that already exists.
class OutreachParticipantInput {
  const OutreachParticipantInput({
    required this.memberId,
    this.role = 'volunteer',
    this.attended,
  });

  final String memberId;
  final String role;
  final bool? attended;

  /// One entry of create_outreach_activity's p_participants array. The RPC
  /// stamps activity_id from the row it just inserted, so it is absent here.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'member_id': memberId,
        'role': role,
        'attended': attended,
      };

  /// One insert row for public.outreach_participants under [activityId], for
  /// the add-to-an-existing-activity path that already has the id.
  Map<String, dynamic> toRow(String activityId) => <String, dynamic>{
        'activity_id': activityId,
        ...toJson(),
      };
}
