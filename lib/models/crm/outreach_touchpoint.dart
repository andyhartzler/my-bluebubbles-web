import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/bulk_send_result.dart';

// ═══════════════════════════════════════════════════════════════
//  MOBILIZE DESK touchpoints. Maps to public.outreach_touchpoints.
//  One bulk contact at two points in its life: the resumable draft an
//  exec is still writing, and the record of what was actually sent.
//  Pure data + display maps. No I/O; TouchpointRepository owns Supabase.
// ═══════════════════════════════════════════════════════════════

/// Presentation for the `status` and `channel` check-in-lists, so the desk
/// rail, the region sections and the result card render a label plus a color
/// or icon without each widget re-deciding. Keys are the exact stored values.
class TouchpointDisplay {
  TouchpointDisplay._();

  /// Contrast against white, computed (WCAG relative luminance), because a
  /// wrong guarantee shipped here once: draft 4.83:1, sending 5.02:1,
  /// sent 5.13:1, partial 5.18:1, failed 6.47:1, discarded 7.73:1. Every one
  /// clears 4.5:1 as a chip fill with white text, matching OutreachDisplay.
  ///
  /// 'sending' reads as "Interrupted" on purpose. A row is only ever loaded
  /// into a list after the tab that owned the send has gone, so a persisted
  /// 'sending' means the browser closed mid-send (3.5), never "in flight".
  static const Map<String, ({String label, Color color})> statuses =
      <String, ({String label, Color color})>{
    'draft': (label: 'Draft', color: Color(0xFF6B7280)),
    'sending': (label: 'Interrupted', color: Color(0xFFB45309)),
    'sent': (label: 'Sent', color: Color(0xFF2E7D32)),
    'partial': (label: 'Partly sent', color: Color(0xFFC2410C)),
    'failed': (label: 'Failed', color: Color(0xFFB91C1C)),
    'discarded': (label: 'Discarded', color: Color(0xFF52525B)),
  };

  static const Map<String, ({String label, IconData icon})> channels =
      <String, ({String label, IconData icon})>{
    'sms': (label: 'Text', icon: Icons.sms_outlined),
    'email': (label: 'Email', icon: Icons.mail_outline),
  };

  static String statusLabel(String status) => statuses[status]?.label ?? status;
  static Color statusColor(String status) =>
      statuses[status]?.color ?? const Color(0xFF6B7280);
  static String channelLabel(String channel) =>
      channels[channel]?.label ?? channel;
  static IconData channelIcon(String channel) =>
      channels[channel]?.icon ?? Icons.send_outlined;
}

/// One bulk contact, as stored. Geometry-free in the same way an activity is:
/// the four district arrays carry bare-digit district numbers and [counties]
/// carries county names, matching the map's own region keys.
class OutreachTouchpoint {
  OutreachTouchpoint({
    required this.id,
    required this.channel,
    this.status = 'draft',
    this.subject,
    this.bodyText,
    this.bodyHtml,
    this.recipientMemberIds = const <String>[],
    this.attemptedCount = 0,
    this.deliveredCount = 0,
    this.failedMemberIds = const <String>[],
    this.errorDetail,
    required this.actorMemberId,
    required this.actorUserId,
    this.counties = const <String>[],
    this.congressionalDistricts = const <String>[],
    this.senateDistricts = const <String>[],
    this.houseDistricts = const <String>[],
    this.candidateIds = const <String>[],
    this.activityId,
    this.retryOf,
    this.createdAt,
    this.lastEditedAt,
    this.sentAt,
  });

  final String id;

  /// 'sms' or 'email'.
  final String channel;
  final String status;

  /// Email only.
  final String? subject;

  /// The sms body, or the email plain-text part.
  final String? bodyText;

  /// Email only.
  final String? bodyHtml;

  /// members.id values in the order the exec selected them.
  final List<String> recipientMemberIds;

  final int attemptedCount;
  final int deliveredCount;
  final List<String> failedMemberIds;
  final String? errorDetail;

  /// members.id of the acting exec. NOT an auth.users.id (spec 4.1).
  final String actorMemberId;

  /// auth.users.id of the acting exec. NOT a members.id (spec 4.1).
  final String actorUserId;

  final List<String> counties;
  final List<String> congressionalDistricts;
  final List<String> senateDistricts;
  final List<String> houseDistricts;
  final List<String> candidateIds;

  /// Set once this touchpoint has been promoted into an activity.
  final String? activityId;

  /// The touchpoint whose failures this one retries.
  final String? retryOf;

  final DateTime? createdAt;
  final DateTime? lastEditedAt;
  final DateTime? sentAt;

  String get statusLabel => TouchpointDisplay.statusLabel(status);
  Color get statusColor => TouchpointDisplay.statusColor(status);
  String get channelLabel => TouchpointDisplay.channelLabel(channel);
  IconData get channelIcon => TouchpointDisplay.channelIcon(channel);

  bool get isDraft => status == 'draft';

  /// A send that never resolved: the tab closed between the compare-and-set and
  /// the outcome write. Needs a human decision, never an automatic resend.
  bool get isInterrupted => status == 'sending';

  bool get isResolved =>
      status == 'sent' || status == 'partial' || status == 'failed';

  /// Whether "Retry the N that failed" applies.
  bool get hasFailures => failedMemberIds.isNotEmpty;

  bool get isPromoted => activityId != null;

  /// The rail row's one-line body preview. Collapses newlines so a multi-line
  /// draft cannot blow out a fixed-height row.
  String get preview {
    final raw = (bodyText ?? subject ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.length <= 60) return raw;
    return '${raw.substring(0, 59)}…';
  }

  /// The outcome, said plainly. "38 of 39" for a partial, "Sent to 39" for a
  /// clean send, "Failed" when nothing landed.
  String get outcomeSummary {
    switch (status) {
      case 'sent':
        return 'Sent to $deliveredCount';
      case 'partial':
        return '$deliveredCount of $attemptedCount';
      case 'failed':
        return 'Failed';
      default:
        return statusLabel;
    }
  }

  static List<String> _stringList(dynamic value) => value == null
      ? const <String>[]
      : (value as List).map((e) => e.toString()).toList();

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory OutreachTouchpoint.fromJson(Map<String, dynamic> json) {
    return OutreachTouchpoint(
      id: json['id'] as String,
      channel: json['channel'] as String,
      status: (json['status'] as String?) ?? 'draft',
      subject: json['subject'] as String?,
      bodyText: json['body_text'] as String?,
      bodyHtml: json['body_html'] as String?,
      recipientMemberIds: _stringList(json['recipient_member_ids']),
      attemptedCount: (json['attempted_count'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
      failedMemberIds: _stringList(json['failed_member_ids']),
      errorDetail: json['error_detail'] as String?,
      actorMemberId: json['actor_member_id'] as String,
      actorUserId: json['actor_user_id'] as String,
      counties: _stringList(json['counties']),
      congressionalDistricts: _stringList(json['congressional_districts']),
      senateDistricts: _stringList(json['senate_districts']),
      houseDistricts: _stringList(json['house_districts']),
      candidateIds: _stringList(json['candidate_ids']),
      activityId: json['activity_id'] as String?,
      retryOf: json['retry_of'] as String?,
      createdAt: _date(json['created_at']),
      lastEditedAt: _date(json['last_edited_at']),
      sentAt: _date(json['sent_at']),
    );
  }
}

/// The composer state the Desk writes, on first save and on every debounce.
/// Deliberately not the same class as [OutreachTouchpoint]: a draft has no id,
/// no outcome and no timestamps, and the outcome columns are written only by
/// [TouchpointSendOutcome] so a debounced save can never clobber them.
///
/// Attachments are absent on purpose. PlatformFile bytes live only in the
/// browser tab, so the composer tells the exec to re-attach rather than
/// pretending a draft carries them (spec 4.3).
class TouchpointDraft {
  const TouchpointDraft({
    required this.channel,
    required this.actorMemberId,
    required this.actorUserId,
    this.subject,
    this.bodyText,
    this.bodyHtml,
    this.recipientMemberIds = const <String>[],
    this.candidateIds = const <String>[],
    this.counties = const <String>[],
    this.congressionalDistricts = const <String>[],
    this.senateDistricts = const <String>[],
    this.houseDistricts = const <String>[],
    this.retryOf,
  });

  /// 'sms' or 'email'. That is exactly `BulkSendChannel.name`, and the column
  /// has a CHECK on those two values, so pass the enum's name rather than a
  /// hand-written label.
  final String channel;

  /// members.id of the acting exec. NOT an auth.users.id (spec 4.1).
  final String actorMemberId;

  /// auth.users.id of the acting exec. NOT a members.id (spec 4.1).
  final String actorUserId;

  final String? subject;
  final String? bodyText;
  final String? bodyHtml;

  /// In selection order. Order is preserved; duplicates are dropped.
  final List<String> recipientMemberIds;

  final List<String> candidateIds;
  final List<String> counties;
  final List<String> congressionalDistricts;
  final List<String> senateDistricts;
  final List<String> houseDistricts;

  /// The touchpoint whose failures this draft retries. Insert-only.
  final String? retryOf;

  /// A geo array past this size describes a statewide send, and an unbounded
  /// array is what stops the GIN index doing any work for the region sections
  /// (spec 3.4).
  static const int maxGeoValues = 25;

  /// Distinct, order-preserving, and capped for the geo arrays.
  static List<String> _distinct(List<String> values, {int? cap}) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      out.add(trimmed);
      if (cap != null && out.length == cap) break;
    }
    return out;
  }

  /// Everything an exec can still change while a draft is open. Excluded from
  /// the update path: the two actor ids and retry_of, which are set once at
  /// insert and are the record's provenance.
  Map<String, dynamic> toUpdateJson() => <String, dynamic>{
        'channel': channel,
        'subject': subject,
        'body_text': bodyText,
        'body_html': bodyHtml,
        'recipient_member_ids': _distinct(recipientMemberIds),
        'candidate_ids': _distinct(candidateIds),
        'counties': _distinct(counties, cap: maxGeoValues),
        'congressional_districts':
            _distinct(congressionalDistricts, cap: maxGeoValues),
        'senate_districts': _distinct(senateDistricts, cap: maxGeoValues),
        'house_districts': _distinct(houseDistricts, cap: maxGeoValues),
        'last_edited_at': DateTime.now().toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => <String, dynamic>{
        ...toUpdateJson(),
        'status': 'draft',
        'actor_member_id': actorMemberId,
        'actor_user_id': actorUserId,
        'retry_of': retryOf,
      };
}

/// The result of the compare-and-set that guards a send (spec 3.5).
enum TouchpointClaim {
  /// This caller owns the send. Nobody else can claim the same row.
  claimed,

  /// Another tab, a double-tap or a retried request got there first. Do not
  /// send: reload the row and show its outcome.
  alreadyClaimed,

  /// The CRM is not configured or not initialized, so nothing was claimed and
  /// nothing was written. Distinct from [alreadyClaimed] because the caller
  /// must not report a send that another tab supposedly made.
  unavailable,
}

/// What actually happened, written once when a send resolves (spec 3.6). The
/// two channels fail differently and this records the difference rather than
/// flattening it to a boolean: sms reports per recipient and so can be
/// genuinely partial, email is one batched call and so is all or nothing.
///
/// Those rules live in [BulkSendResult], which is what both bulk screens and
/// the inline composer produce. This type exists only to turn that outcome into
/// the row update, so there is one place the rules can be wrong rather than two.
class TouchpointSendOutcome {
  const TouchpointSendOutcome._({
    required this.status,
    required this.attemptedCount,
    required this.deliveredCount,
    required this.failedMemberIds,
    this.errorDetail,
  });

  /// A send that resolved. An empty recipient set is recorded as failed, not
  /// sent: a send to nobody is a broken send path, and writing 'sent' with a
  /// delivered count of zero would make the record lie about it.
  factory TouchpointSendOutcome.fromBulkResult(BulkSendResult result) {
    if (result.attemptedCount == 0) {
      return const TouchpointSendOutcome._(
        status: 'failed',
        attemptedCount: 0,
        deliveredCount: 0,
        failedMemberIds: <String>[],
        errorDetail: 'The send resolved with no recipients.',
      );
    }

    return TouchpointSendOutcome._(
      status: result.status,
      attemptedCount: result.attemptedCount,
      deliveredCount: result.deliveredCount,
      failedMemberIds: result.failedMemberIds,
      errorDetail: _truncate(result.errorDetail),
    );
  }

  /// An INTERRUPTED send closed out by hand (3.5). The tab that owned the send
  /// went away before it could write an outcome, so nothing in the system
  /// knows what the provider did and nothing ever will. The exec says, and the
  /// row records that a human said it.
  ///
  /// This lives beside [fromBulkResult] rather than in the repository so the
  /// outcome columns still have exactly ONE place that decides what goes in
  /// them. It is not a send: it writes no delivery the send path observed, and
  /// [errorDetail] always names it as a hand entry so a later reader cannot
  /// mistake it for a reported result.
  factory TouchpointSendOutcome.recordedByHand({
    required bool reached,
    required List<String> recipientMemberIds,
  }) {
    final attempted = recipientMemberIds.length;
    return TouchpointSendOutcome._(
      status: reached ? 'sent' : 'failed',
      attemptedCount: attempted,
      deliveredCount: reached ? attempted : 0,
      // Not reached means every recipient is still owed the message, which is
      // what makes "Retry the N that failed" work on the closed-out row.
      failedMemberIds:
          reached ? const <String>[] : List<String>.of(recipientMemberIds),
      errorDetail: reached
          ? 'This send was interrupted and closed out by hand: an exec '
              'confirmed it went out. No per-recipient result was ever '
              'reported.'
          : 'This send was interrupted and closed out by hand: an exec '
              'confirmed it did not go out.',
    );
  }

  final String status;
  final int attemptedCount;
  final int deliveredCount;
  final List<String> failedMemberIds;
  final String? errorDetail;

  /// error_detail is a text column an exec reads in a card, not a log sink.
  /// BulkSendResult already bounds its own message; this covers the composer
  /// path, which passes a raw provider string.
  static String? _truncate(String? detail) {
    if (detail == null) return null;
    final trimmed = detail.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= 500 ? trimmed : trimmed.substring(0, 500);
  }

  Map<String, dynamic> toUpdateJson() => <String, dynamic>{
        'status': status,
        'attempted_count': attemptedCount,
        'delivered_count': deliveredCount,
        'failed_member_ids': failedMemberIds,
        'error_detail': errorDetail,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      };
}
