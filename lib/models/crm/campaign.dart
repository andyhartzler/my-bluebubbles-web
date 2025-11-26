import 'package:collection/collection.dart';

class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    this.subject,
    this.description,
    this.status,
    this.createdAt,
    this.sentAt,
  });

  final String id;
  final String name;
  final String? subject;
  final String? description;
  final String? status;
  final DateTime? createdAt;
  final DateTime? sentAt;

  static Campaign? fromMap(dynamic value) {
    if (value == null || value is! Map<String, dynamic>) {
      return null;
    }

    final dynamic idValue = value['id'] ?? value['campaign_id'];
    final String? id = idValue?.toString();
    if (id == null || id.isEmpty) return null;

    final String name = value['name']?.toString() ??
        value['title']?.toString() ??
        'Campaign';

    DateTime? parseDate(dynamic date) {
      if (date == null) return null;
      if (date is DateTime) return date;
      return DateTime.tryParse(date.toString());
    }

    return Campaign(
      id: id,
      name: name,
      subject: value['subject']?.toString(),
      description: value['description']?.toString(),
      status: value['status']?.toString(),
      createdAt: parseDate(value['created_at']),
      sentAt: parseDate(value['sent_at'] ?? value['started_at']),
    );
  }

  Campaign copyWith({
    String? id,
    String? name,
    String? subject,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? sentAt,
  }) {
    return Campaign(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Campaign &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          subject == other.subject &&
          description == other.description &&
          status == other.status &&
          createdAt == other.createdAt &&
          sentAt == other.sentAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        subject,
        description,
        status,
        createdAt,
        sentAt,
      );

  static List<Campaign> fromList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((entry) => Campaign.fromMap(entry))
          .whereNotNull()
          .toList();
    }
    return const <Campaign>[];
  }
}
