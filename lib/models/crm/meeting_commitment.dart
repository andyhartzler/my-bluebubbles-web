/// One thing a meeting committed somebody to, as a row rather than a sentence
/// inside `meetings.action_items`.
///
/// The split that matters is between the derived fields, which a re-run of the
/// summariser may refresh, and [status] / [progressNote], which only a person
/// ever writes. That rule is enforced by a trigger on the table, not here; see
/// supabase/migrations/20260824_01_meeting_commitments.sql. This class must not
/// be the only thing standing between automation and somebody's work, because a
/// Dart guard protects one screen and the table has other writers.
enum CommitmentKind { region, task, decision }

enum CommitmentStatus { open, inProgress, done, deferred, dropped }

extension CommitmentKindX on CommitmentKind {
  static CommitmentKind parse(String? raw) {
    switch (raw) {
      case 'region':
        return CommitmentKind.region;
      case 'decision':
        return CommitmentKind.decision;
      default:
        return CommitmentKind.task;
    }
  }

  String get wire {
    switch (this) {
      case CommitmentKind.region:
        return 'region';
      case CommitmentKind.decision:
        return 'decision';
      case CommitmentKind.task:
        return 'task';
    }
  }

  String get heading {
    switch (this) {
      case CommitmentKind.region:
        return 'Who has which part of the state';
      case CommitmentKind.decision:
        return 'Decisions and open problems';
      case CommitmentKind.task:
        return 'Work people took on';
    }
  }
}

extension CommitmentStatusX on CommitmentStatus {
  static CommitmentStatus parse(String? raw) {
    switch (raw) {
      case 'in_progress':
        return CommitmentStatus.inProgress;
      case 'done':
        return CommitmentStatus.done;
      case 'deferred':
        return CommitmentStatus.deferred;
      case 'dropped':
        return CommitmentStatus.dropped;
      default:
        return CommitmentStatus.open;
    }
  }

  String get wire {
    switch (this) {
      case CommitmentStatus.inProgress:
        return 'in_progress';
      case CommitmentStatus.done:
        return 'done';
      case CommitmentStatus.deferred:
        return 'deferred';
      case CommitmentStatus.dropped:
        return 'dropped';
      case CommitmentStatus.open:
        return 'open';
    }
  }

  String get label {
    switch (this) {
      case CommitmentStatus.inProgress:
        return 'In progress';
      case CommitmentStatus.done:
        return 'Done';
      case CommitmentStatus.deferred:
        return 'Deferred';
      case CommitmentStatus.dropped:
        return 'Dropped';
      case CommitmentStatus.open:
        return 'Open';
    }
  }

  bool get isClosed =>
      this == CommitmentStatus.done ||
      this == CommitmentStatus.deferred ||
      this == CommitmentStatus.dropped;
}

class MeetingCommitment {
  const MeetingCommitment({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.ownerLabel,
    required this.commitment,
    required this.counties,
    required this.status,
    required this.needsConfirmation,
    required this.humanEditedFields,
    this.ownerMemberId,
    this.dueOn,
    this.evidence,
    this.progressNote,
    this.statusSetAt,
  });

  final String id;
  final String meetingId;
  final CommitmentKind kind;

  // Derived from the transcript. Automation may refresh these until a person
  // edits one, after which the field's name appears in [humanEditedFields] and
  // the trigger stops automation writing it.
  final String? ownerMemberId;
  final String ownerLabel;
  final String commitment;
  final List<String> counties;
  final DateTime? dueOn;
  final String? evidence;
  final bool needsConfirmation;

  // Only ever written by a signed-in person.
  final CommitmentStatus status;
  final String? progressNote;
  final DateTime? statusSetAt;

  final List<String> humanEditedFields;

  bool get isOverdue {
    final due = dueOn;
    if (due == null || status.isClosed) return false;
    final today = DateTime.now();
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get isUnowned => ownerMemberId == null;

  MeetingCommitment copyWith({
    CommitmentStatus? status,
    String? progressNote,
    bool clearProgressNote = false,
    DateTime? statusSetAt,
    List<String>? humanEditedFields,
  }) {
    return MeetingCommitment(
      id: id,
      meetingId: meetingId,
      kind: kind,
      ownerMemberId: ownerMemberId,
      ownerLabel: ownerLabel,
      commitment: commitment,
      counties: counties,
      dueOn: dueOn,
      evidence: evidence,
      needsConfirmation: needsConfirmation,
      status: status ?? this.status,
      progressNote: clearProgressNote ? null : (progressNote ?? this.progressNote),
      statusSetAt: statusSetAt ?? this.statusSetAt,
      humanEditedFields: humanEditedFields ?? this.humanEditedFields,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static DateTime? _date(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  factory MeetingCommitment.fromJson(Map<String, dynamic> json) {
    return MeetingCommitment(
      id: json['id'].toString(),
      meetingId: json['meeting_id'].toString(),
      kind: CommitmentKindX.parse(json['kind'] as String?),
      ownerMemberId: json['owner_member_id']?.toString(),
      ownerLabel: (json['owner_label'] ?? 'Unassigned').toString(),
      commitment: (json['commitment'] ?? '').toString(),
      counties: _stringList(json['counties']),
      dueOn: _date(json['due_on']),
      evidence: json['evidence']?.toString(),
      needsConfirmation: json['needs_confirmation'] == true,
      status: CommitmentStatusX.parse(json['status'] as String?),
      progressNote: json['progress_note']?.toString(),
      statusSetAt: _date(json['status_set_at']),
      humanEditedFields: _stringList(json['human_edited_fields']),
    );
  }
}

/// A county, how many members MOYD has in it, and who if anyone has taken
/// responsibility for it. Read from the `exec_region_coverage` view.
class RegionCoverage {
  const RegionCoverage({
    required this.county,
    required this.memberCount,
    required this.phoneCount,
    required this.ownerLabels,
    required this.ownerMemberIds,
    required this.hasOwner,
    required this.anyUnconfirmed,
  });

  final String county;

  /// Members with this county on file. Counts ONLY membership_eligible members,
  /// because that is exactly what the members list shows when you tap through.
  /// A count that changes when you tap it is worse than no count at all.
  final int memberCount;

  /// How many of [memberCount] have a phone number we could dial. This is the
  /// number that changes a decision rather than reporting one: Clay at 23 of 25
  /// is a calling job, Cape Girardeau at 5 of 18 is not one.
  final int phoneCount;

  /// Free text, straight from the meeting. One of the real values is the
  /// literal 'Nobody'. Display only.
  final List<String> ownerLabels;

  /// members.id values. Match ownership on THESE, never on [ownerLabels].
  final List<String> ownerMemberIds;

  final bool hasOwner;
  final bool anyUnconfirmed;

  bool isOwnedBy(String memberId) => ownerMemberIds.contains(memberId);

  factory RegionCoverage.fromJson(Map<String, dynamic> json) {
    return RegionCoverage(
      county: (json['county'] ?? '').toString(),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      phoneCount: (json['phone_count'] as num?)?.toInt() ?? 0,
      ownerLabels: MeetingCommitment._stringList(json['owner_labels']),
      ownerMemberIds: MeetingCommitment._stringList(json['owner_member_ids']),
      hasOwner: json['has_owner'] == true,
      anyUnconfirmed: json['any_unconfirmed'] == true,
    );
  }
}
