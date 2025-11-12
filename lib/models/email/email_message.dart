import 'package:meta/meta.dart';

@immutable
class EmailMessage {
  const EmailMessage._({
    required this.id,
    required this.threadId,
    required this.sender,
    required this.recipients,
    this.subject,
    this.snippet,
    required this.sentAt,
    this.isRead = true,
    this.isOutgoing = false,
  });

  factory EmailMessage({
    required String id,
    required String threadId,
    required String sender,
    List<String> recipients = const <String>[],
    String? subject,
    String? snippet,
    required DateTime sentAt,
    bool isRead = true,
    bool isOutgoing = false,
  }) {
    return EmailMessage._(
      id: id,
      threadId: threadId,
      sender: sender,
      recipients: List.unmodifiable(recipients),
      subject: subject,
      snippet: snippet,
      sentAt: sentAt,
      isRead: isRead,
      isOutgoing: isOutgoing,
    );
  }

  final String id;
  final String threadId;
  final String sender;
  final List<String> recipients;
  final String? subject;
  final String? snippet;
  final DateTime sentAt;
  final bool isRead;
  final bool isOutgoing;

  EmailMessage copyWith({
    String? id,
    String? threadId,
    String? sender,
    List<String>? recipients,
    String? subject,
    String? snippet,
    DateTime? sentAt,
    bool? isRead,
    bool? isOutgoing,
  }) {
    return EmailMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      sender: sender ?? this.sender,
      recipients:
          recipients != null ? List.unmodifiable(recipients) : this.recipients,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }

  @override
  String toString() {
    return 'EmailMessage(id: $id, threadId: $threadId, sentAt: $sentAt)';
  }
}
