import 'package:flutter/foundation.dart';

/// An explicit assignment created by a staff member to direct another
/// member's attention to a candidate, bill, event, meeting, or freeform task.
///
/// Backed by `public.assignments` (migration 20260424_04). RLS lets the
/// assignee, the assigner, and any superadmin read/update; only assigners
/// (or superadmins) can delete; only staff can insert.
@immutable
class Assignment {
  final String id;
  final String assignedTo;       // auth.users.id
  final String? assignedBy;      // auth.users.id (nullable after assigner deletion)
  final String title;
  final String? note;
  final String? entityType;
  final String? entityId;
  final String? entityUrl;
  final String status;           // 'pending' | 'in_progress' | 'done' | 'cancelled'
  final String? priority;        // 'low' | 'medium' | 'high'
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Assignment({
    required this.id,
    required this.assignedTo,
    this.assignedBy,
    required this.title,
    this.note,
    this.entityType,
    this.entityId,
    this.entityUrl,
    this.status = 'pending',
    this.priority,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDone => status == 'done';
  bool get isOpen => status == 'pending' || status == 'in_progress';

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return Assignment(
      id: json['id'] as String,
      assignedTo: json['assigned_to'] as String,
      assignedBy: json['assigned_by'] as String?,
      title: json['title'] as String,
      note: json['note'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      entityUrl: json['entity_url'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      priority: json['priority'] as String?,
      dueDate: parseDate(json['due_date']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  /// Build the payload for an INSERT. Excludes server-managed fields
  /// (id, created_at, updated_at).
  Map<String, dynamic> toInsert() => {
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'title': title,
        'note': note,
        'entity_type': entityType,
        'entity_id': entityId,
        'entity_url': entityUrl,
        'status': status,
        'priority': priority,
        'due_date': dueDate?.toIso8601String().split('T').first,
      };

  /// Build the payload for an UPDATE.
  Map<String, dynamic> toUpdate() => {
        'title': title,
        'note': note,
        'entity_type': entityType,
        'entity_id': entityId,
        'entity_url': entityUrl,
        'status': status,
        'priority': priority,
        'due_date': dueDate?.toIso8601String().split('T').first,
      };

  Assignment copyWith({
    String? title,
    String? note,
    String? entityType,
    String? entityId,
    String? entityUrl,
    String? status,
    String? priority,
    DateTime? dueDate,
  }) {
    return Assignment(
      id: id,
      assignedTo: assignedTo,
      assignedBy: assignedBy,
      title: title ?? this.title,
      note: note ?? this.note,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entityUrl: entityUrl ?? this.entityUrl,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Auto-inferred assignments are read-only synthetic items derived from
/// other tables (candidates, member_profile_changes, etc). They surface
/// in the home screen alongside explicit assignments but cannot be
/// edited or completed inline — the user clicks through to the source.
@immutable
class AutoInferredAssignment {
  final String key;          // stable identifier (e.g. 'candidate:<uuid>')
  final String source;       // 'candidate' | 'profile_change' | 'event_pending' | 'bill_mention' | 'job_pending'
  final String title;
  final String? subtitle;
  final String entityUrl;    // in-app deep link
  final DateTime? at;        // when the underlying row was last updated
  final String? memberName;       // optional — name of the related member (e.g. profile-change subject)
  final String? memberAvatarUrl;  // optional — avatar URL for the related member

  const AutoInferredAssignment({
    required this.key,
    required this.source,
    required this.title,
    this.subtitle,
    required this.entityUrl,
    this.at,
    this.memberName,
    this.memberAvatarUrl,
  });
}
