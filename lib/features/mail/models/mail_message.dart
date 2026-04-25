import 'package:flutter/foundation.dart';

@immutable
class MailMessage {
  final String id;
  final String threadId;
  final String from;
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String snippet;
  final DateTime internalDate;
  final List<String> labels;

  const MailMessage({
    required this.id,
    required this.threadId,
    required this.from,
    required this.to,
    required this.cc,
    required this.subject,
    required this.snippet,
    required this.internalDate,
    required this.labels,
  });

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    return MailMessage(
      id: json['id'] as String,
      threadId: (json['threadId'] ?? json['thread_id']) as String,
      from: (json['from'] as String?) ?? '',
      to: ((json['to'] as List?) ?? const [])
          .map((s) => s.toString())
          .toList(),
      cc: ((json['cc'] as List?) ?? const [])
          .map((s) => s.toString())
          .toList(),
      subject: (json['subject'] as String?) ?? '',
      snippet: (json['snippet'] as String?) ?? '',
      internalDate: _parseDate(json['internalDate']),
      labels: ((json['labels'] as List?) ?? const [])
          .map((s) => s.toString())
          .toList(),
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final asInt = int.tryParse(v.toString());
    if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    return DateTime.tryParse(v.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool get isUnread => labels.contains('UNREAD');

  /// Best-effort sender display name — extracts everything before the
  /// angle bracket, falling back to the address if the header is bare.
  String get fromDisplay {
    final v = from.trim();
    final lt = v.indexOf('<');
    if (lt > 0) return v.substring(0, lt).replaceAll('"', '').trim();
    return v;
  }

  String get fromAddress {
    final m = RegExp(r'<\s*([^<>\s]+@[^<>\s]+)\s*>').firstMatch(from);
    if (m != null) return m.group(1)!.toLowerCase();
    return from.trim().toLowerCase();
  }
}
