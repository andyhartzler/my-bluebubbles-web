import 'dart:collection';

import 'package:meta/meta.dart';

import 'email_message.dart';

@immutable
class EmailThread {
  EmailThread({
    required this.id,
    required List<EmailMessage> messages,
  }) : _messages = UnmodifiableListView(
          (List<EmailMessage>.from(messages)
            ..sort((a, b) => b.sentAt.compareTo(a.sentAt))),
        );

  final String id;
  final UnmodifiableListView<EmailMessage> _messages;

  List<EmailMessage> get messages => _messages;

  DateTime? get latestMessageAt =>
      _messages.isEmpty ? null : _messages.first.sentAt;

  bool get hasUnread => _messages.any((message) => !message.isRead);

  EmailThread copyWith({List<EmailMessage>? messages}) {
    return EmailThread(
      id: id,
      messages: messages ?? _messages,
    );
  }

  @override
  String toString() => 'EmailThread(id: $id, messages: ${_messages.length})';
}
