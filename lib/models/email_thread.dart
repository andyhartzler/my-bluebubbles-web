import 'dart:collection';

import 'package:collection/collection.dart';

import 'member_email.dart';

/// Immutable representation of an email conversation thread pulled from the CRM
/// data warehouse. Supports data originating from both Supabase (snake_case)
/// and API responses (camelCase).
class EmailThread {
  /// Key used when grouping recipients without an associated member id.
  static const String unassignedMemberKey = '';

  EmailThread({
    required this.id,
    this.subject,
    this.snippet,
    this.lastMessageAt,
    this.messageCount = 0,
    List<MemberEmail> to = const [],
    List<MemberEmail> cc = const [],
    List<MemberEmail> bcc = const [],
    Map<String, dynamic>? metadata,
  })  : to = List<MemberEmail>.unmodifiable(to),
        cc = List<MemberEmail>.unmodifiable(cc),
        bcc = List<MemberEmail>.unmodifiable(bcc),
        metadata = metadata == null
            ? const {}
            : Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(metadata));

  /// Identifier for the email thread.
  final String id;

  /// Optional subject line of the thread.
  final String? subject;

  /// Preview of the latest message or snippet extracted from the thread.
  final String? snippet;

  /// Timestamp representing the most recent message or activity.
  final DateTime? lastMessageAt;

  /// Number of messages contained in the thread.
  final int messageCount;

  /// Primary recipients for the thread.
  final List<MemberEmail> to;

  /// Carbon copy recipients.
  final List<MemberEmail> cc;

  /// Blind carbon copy recipients.
  final List<MemberEmail> bcc;

  /// Arbitrary metadata returned alongside the thread.
  final Map<String, dynamic> metadata;

  /// Whether the thread has at least one CC recipient.
  bool get hasCc => cc.isNotEmpty;

  /// Whether the thread has at least one BCC recipient.
  bool get hasBcc => bcc.isNotEmpty;

  /// Whether a subject line is present.
  bool get hasSubject => subject != null && subject!.trim().isNotEmpty;

  /// Whether a snippet/preview is present.
  bool get hasSnippet => snippet != null && snippet!.trim().isNotEmpty;

  /// Total number of recipients across To/Cc/Bcc.
  int get totalRecipientCount => to.length + cc.length + bcc.length;

  /// Distinct number of member ids represented in the thread.
  int get uniqueRecipientCount => groupRecipientsByMemberId().length;

  /// Returns true when more than one message exists in the thread.
  bool get hasReplies => messageCount > 1;

  /// Returns all recipients, preserving the order of To -> Cc -> Bcc.
  List<MemberEmail> get allRecipients => List<MemberEmail>.unmodifiable(
        <MemberEmail>[...to, ...cc, ...bcc],
      );

  /// Returns the first primary recipient if available.
  MemberEmail? get primaryRecipient {
    return allRecipients.firstWhereOrNull((email) => email.isPrimary) ??
        (to.isNotEmpty ? to.first : (allRecipients.isNotEmpty ? allRecipients.first : null));
  }

  /// Returns recipients flagged as verified.
  List<MemberEmail> get verifiedRecipients =>
      List<MemberEmail>.unmodifiable(allRecipients.where((email) => email.isVerified));

  /// Returns recipients that are not verified.
  List<MemberEmail> get unverifiedRecipients =>
      List<MemberEmail>.unmodifiable(allRecipients.where((email) => !email.isVerified));

  /// Returns recipients that are not linked to a CRM member record.
  List<MemberEmail> get unassignedRecipients =>
      List<MemberEmail>.unmodifiable(allRecipients.where((email) => !email.hasMember));

  /// Whether any recipients are missing a member linkage.
  bool get hasUnassignedRecipients => unassignedRecipients.isNotEmpty;

  /// Manual entry recipients convenience getter.
  List<MemberEmail> get manualRecipients => recipientsForSource(EmailSource.manual);

  /// Member profile recipients convenience getter.
  List<MemberEmail> get memberProfileRecipients =>
      recipientsForSource(EmailSource.memberProfile);

  /// School record recipients convenience getter.
  List<MemberEmail> get schoolRecipients => recipientsForSource(EmailSource.school);

  /// Organization recipients convenience getter.
  List<MemberEmail> get organizationRecipients =>
      recipientsForSource(EmailSource.organization);

  /// Campaign/import recipients convenience getter.
  List<MemberEmail> get campaignRecipients => recipientsForSource(EmailSource.campaign);

  /// Returns a human-friendly subject or falls back to the snippet when absent.
  String? get displaySubject {
    if (hasSubject) return subject!.trim();
    if (hasSnippet) return snippet!.trim();
    return null;
  }

  /// Returns the duration since the last recorded message.
  Duration? get timeSinceLastMessage {
    final last = lastMessageAt;
    if (last == null) return null;
    return DateTime.now().toUtc().difference(last.toUtc());
  }

  /// Whether metadata is present on the thread.
  bool get hasMetadata => metadata.isNotEmpty;

  /// Retrieves a typed metadata value when present.
  T? metadataValue<T>(String key) {
    final value = metadata[key];
    if (value is T) return value;
    return null;
  }

  /// Convenience helper that returns true when the provided email is part of
  /// the thread (case-insensitive).
  bool containsEmail(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        allRecipients.any((email) => email.normalizedEmail == normalized);
  }

  /// Returns the first [MemberEmail] matching the provided email address.
  MemberEmail? findRecipient(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return allRecipients.firstWhereOrNull(
      (email) => email.normalizedEmail == normalized,
    );
  }

  /// Groups recipients by their [EmailSource].
  Map<EmailSource, List<MemberEmail>> groupRecipientsBySource({
    bool includeTo = true,
    bool includeCc = true,
    bool includeBcc = true,
  }) {
    final grouped = LinkedHashMap<EmailSource, List<MemberEmail>>();
    for (final email in _collectRecipients(
      includeTo: includeTo,
      includeCc: includeCc,
      includeBcc: includeBcc,
    )) {
      grouped.putIfAbsent(email.source, () => <MemberEmail>[]).add(email);
    }
    return grouped.map(
      (key, value) => MapEntry(key, List<MemberEmail>.unmodifiable(value)),
    );
  }

  /// Returns the list of recipients matching the requested [source].
  List<MemberEmail> recipientsForSource(
    EmailSource source, {
    bool includeTo = true,
    bool includeCc = true,
    bool includeBcc = true,
  }) {
    final grouped = groupRecipientsBySource(
      includeTo: includeTo,
      includeCc: includeCc,
      includeBcc: includeBcc,
    );
    return List<MemberEmail>.unmodifiable(
      grouped[source] ?? const <MemberEmail>[],
    );
  }

  /// Groups recipients by member id. Empty keys represent emails without a
  /// linked member when [includeUnassigned] is true.
  Map<String, List<MemberEmail>> groupRecipientsByMemberId({
    bool includeTo = true,
    bool includeCc = true,
    bool includeBcc = true,
    bool includeUnassigned = false,
  }) {
    final grouped = LinkedHashMap<String, List<MemberEmail>>();
    for (final email in _collectRecipients(
      includeTo: includeTo,
      includeCc: includeCc,
      includeBcc: includeBcc,
    )) {
      final key = email.memberId?.trim();
      if (key == null || key.isEmpty) {
        if (!includeUnassigned) continue;
        grouped.putIfAbsent(unassignedMemberKey, () => <MemberEmail>[]).add(email);
      } else {
        grouped.putIfAbsent(key, () => <MemberEmail>[]).add(email);
      }
    }
    return grouped.map(
      (key, value) => MapEntry(key, List<MemberEmail>.unmodifiable(value)),
    );
  }

  /// Retrieves recipients belonging to a specific member id.
  List<MemberEmail> recipientsForMember(
    String memberId, {
    bool includeTo = true,
    bool includeCc = true,
    bool includeBcc = true,
  }) {
    final key = memberId.trim();
    final includeUnassigned = key.isEmpty;
    final grouped = groupRecipientsByMemberId(
      includeTo: includeTo,
      includeCc: includeCc,
      includeBcc: includeBcc,
      includeUnassigned: includeUnassigned,
    );
    final lookupKey = includeUnassigned ? unassignedMemberKey : key;
    return List<MemberEmail>.unmodifiable(
      grouped[lookupKey] ?? const <MemberEmail>[],
    );
  }

  /// Creates a copy of the thread with selectively replaced properties.
  EmailThread copyWith({
    String? id,
    String? subject,
    String? snippet,
    DateTime? lastMessageAt,
    int? messageCount,
    List<MemberEmail>? to,
    List<MemberEmail>? cc,
    List<MemberEmail>? bcc,
    Map<String, dynamic>? metadata,
  }) {
    return EmailThread(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messageCount: messageCount ?? this.messageCount,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Parses a thread from a heterogeneous JSON payload.
  factory EmailThread.fromJson(Map<String, dynamic> json) {
    final id = _readString(json, const ['id', 'thread_id', 'threadId']);
    if (id == null || id.isEmpty) {
      throw const FormatException('EmailThread is missing a valid identifier.');
    }

    final recipients = json['recipients'];

    final toRecipients = MemberEmail.listFromJson(
      json['to'] ?? json['to_addresses'] ?? json['toAddresses'] ??
          (recipients is Map ? (recipients['to'] ?? recipients['primary']) : null),
    );
    final ccRecipients = MemberEmail.listFromJson(
      json['cc'] ?? json['cc_addresses'] ?? json['ccAddresses'] ??
          (recipients is Map ? (recipients['cc'] ?? recipients['carbon']) : null),
    );
    final bccRecipients = MemberEmail.listFromJson(
      json['bcc'] ?? json['bcc_addresses'] ?? json['bccAddresses'] ??
          (recipients is Map ? (recipients['bcc'] ?? recipients['blind']) : null),
    );

    final metadataValue = json['metadata'] ?? json['meta'] ?? json['details'];

    final messageCount = _readInt(json, const ['message_count', 'messageCount']) ??
        _coerceInt(json['messages']) ??
        (metadataValue is Map ? _coerceInt(metadataValue['message_count']) : null) ??
        0;

    return EmailThread(
      id: id,
      subject: _readString(json, const ['subject', 'title']),
      snippet: _readString(
        json,
        const ['snippet', 'preview', 'last_message_preview', 'summary'],
      ),
      lastMessageAt: _readDate(
        json,
        const ['last_message_at', 'lastMessageAt', 'updated_at', 'updatedAt'],
      ),
      messageCount: messageCount,
      to: toRecipients,
      cc: ccRecipients,
      bcc: bccRecipients,
      metadata: metadataValue is Map
          ? Map<String, dynamic>.from(
              metadataValue.map((key, value) => MapEntry(key.toString(), value)),
            )
          : null,
    );
  }

  /// Serializes the thread using camelCase keys (API contract).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (subject != null) 'subject': subject,
      if (snippet != null) 'snippet': snippet,
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
      'messageCount': messageCount,
      'to': to.map((email) => email.toJson()).toList(),
      if (cc.isNotEmpty) 'cc': cc.map((email) => email.toJson()).toList(),
      if (bcc.isNotEmpty) 'bcc': bcc.map((email) => email.toJson()).toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Serializes the thread using snake_case keys (database contract).
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      if (subject != null) 'subject': subject,
      if (snippet != null) 'snippet': snippet,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt!.toIso8601String(),
      'message_count': messageCount,
      'to': to.map((email) => email.toDatabaseMap()).toList(),
      if (cc.isNotEmpty) 'cc': cc.map((email) => email.toDatabaseMap()).toList(),
      if (bcc.isNotEmpty) 'bcc': bcc.map((email) => email.toDatabaseMap()).toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  List<MemberEmail> _collectRecipients({
    bool includeTo = true,
    bool includeCc = true,
    bool includeBcc = true,
  }) {
    final recipients = <MemberEmail>[];
    if (includeTo) {
      recipients.addAll(to);
    }
    if (includeCc) {
      recipients.addAll(cc);
    }
    if (includeBcc) {
      recipients.addAll(bcc);
    }
    return recipients;
  }

  static String? _readString(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) {
        continue;
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      } else if (value is num || value is bool) {
        return value.toString();
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final result = _coerceInt(json[key]);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is Iterable) return value.length;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  static DateTime? _readDate(Map<String, dynamic> json, Iterable<String> keys) {
    for (final key in keys) {
      final result = _coerceDate(json[key]);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  static DateTime? _coerceDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    if (value is int) {
      if (value.abs() > 9999999999999) {
        return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
      }
      if (value.abs() > 9999999999) {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).round(), isUtc: true);
    }
    return null;
  }

  @override
  String toString() {
    return 'EmailThread(id: $id, subject: ${subject ?? 'null'}, messages: $messageCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EmailThread) return false;
    final equality = const DeepCollectionEquality();
    return other.id == id &&
        other.subject == subject &&
        other.snippet == snippet &&
        other.lastMessageAt == lastMessageAt &&
        other.messageCount == messageCount &&
        equality.equals(other.to, to) &&
        equality.equals(other.cc, cc) &&
        equality.equals(other.bcc, bcc) &&
        equality.equals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    final equality = const DeepCollectionEquality();
    return Object.hash(
      id,
      subject,
      snippet,
      lastMessageAt,
      messageCount,
      equality.hash(to),
      equality.hash(cc),
      equality.hash(bcc),
      equality.hash(metadata),
    );
  }
}
