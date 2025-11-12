import 'package:collection/collection.dart';

/// Represents a participant in an email thread. Typically a person or
/// organization.
class EmailParticipant {
  const EmailParticipant({
    required this.address,
    this.displayName,
  });

  /// The raw email address.
  final String address;

  /// Optional display name provided by the remote service.
  final String? displayName;

  /// Returns the name that should be shown in the UI.
  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : address;

  @override
  int get hashCode => Object.hash(address.toLowerCase(), displayName);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmailParticipant &&
        address.toLowerCase() == other.address.toLowerCase() &&
        other.displayName == displayName;
  }
}

/// Represents an individual email message.
class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.sentAt,
    required this.sender,
    this.to = const [],
    this.cc = const [],
    this.subject,
    this.plainTextBody,
    this.htmlBody,
    this.isOutgoing = false,
  });

  final String id;
  final DateTime sentAt;
  final EmailParticipant sender;
  final List<EmailParticipant> to;
  final List<EmailParticipant> cc;
  final String? subject;
  final String? plainTextBody;
  final String? htmlBody;
  final bool isOutgoing;

  /// Provides text that can be shown in summaries if HTML is unavailable.
  String get displayBody => plainTextBody ?? htmlBody ?? '';
}

/// A group of related email messages.
class EmailThread {
  const EmailThread({
    required this.id,
    required this.subject,
    required this.updatedAt,
    this.snippet,
    this.unreadCount = 0,
    this.messages = const [],
    this.participants = const [],
    this.isArchived = false,
  });

  final String id;
  final String subject;
  final DateTime updatedAt;
  final String? snippet;
  final int unreadCount;
  final List<EmailMessage> messages;
  final List<EmailParticipant> participants;
  final bool isArchived;

  EmailMessage? get latestMessage => messages.isEmpty ? null : messages.last;

  /// Participants minus the current user. Duplicate addresses are removed.
  List<EmailParticipant> get uniqueParticipants {
    final seen = <String>{};
    return participants
        .where((participant) =>
            seen.add(participant.address.trim().toLowerCase()))
        .toList(growable: false);
  }

  EmailThread copyWith({
    String? id,
    String? subject,
    DateTime? updatedAt,
    String? snippet,
    int? unreadCount,
    List<EmailMessage>? messages,
    List<EmailParticipant>? participants,
    bool? isArchived,
  }) {
    return EmailThread(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      updatedAt: updatedAt ?? this.updatedAt,
      snippet: snippet ?? this.snippet,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
      participants: participants ?? this.participants,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

/// Helper that formats a list of participants into a display string.
String formatParticipants(List<EmailParticipant> participants) {
  return participants
      .map((participant) => participant.label)
      .where((label) => label.trim().isNotEmpty)
      .toSet()
      .join(', ');
}

/// Finds the first message that contains HTML content.
EmailMessage? firstHtmlMessage(List<EmailMessage> messages) {
  return messages.firstWhereOrNull((message) =>
      message.htmlBody != null && message.htmlBody!.trim().isNotEmpty);
}
