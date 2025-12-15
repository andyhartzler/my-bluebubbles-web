import 'package:intl/intl.dart';

/// Represents the method used to send a thank you for a donation.
enum ThankYouMethod {
  mailed('mailed', 'Mailed', 'Mail'),
  call('call', 'Phone Call', 'Call'),
  text('text', 'Text Message', 'Text'),
  email('email', 'Email', 'Email'),
  inPerson('in_person', 'In Person', 'In Person');

  final String dbValue;
  final String displayName;
  final String shortName;

  const ThankYouMethod(this.dbValue, this.displayName, this.shortName);

  static ThankYouMethod fromString(String value) {
    return ThankYouMethod.values.firstWhere(
      (m) => m.dbValue == value,
      orElse: () => ThankYouMethod.email,
    );
  }
}

/// Represents a thank you record for a donation.
class DonationThankYou {
  final String id;
  final String donationId;
  final ThankYouMethod method;
  final DateTime sentDate;
  final String? notes;
  final DateTime? createdAt;

  const DonationThankYou({
    required this.id,
    required this.donationId,
    required this.method,
    required this.sentDate,
    this.notes,
    this.createdAt,
  });

  factory DonationThankYou.fromJson(Map<String, dynamic> json) {
    return DonationThankYou(
      id: json['id']?.toString() ?? '',
      donationId: json['donation_id']?.toString() ?? '',
      method: ThankYouMethod.fromString(json['method'] as String? ?? 'email'),
      sentDate: _parseDate(json['sent_date']) ?? DateTime.now(),
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'donation_id': donationId,
      'method': method.dbValue,
      'sent_date': sentDate.toUtc().toIso8601String(),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  String get formattedDate => DateFormat.yMMMd().format(sentDate);

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  DonationThankYou copyWith({
    String? id,
    String? donationId,
    ThankYouMethod? method,
    DateTime? sentDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return DonationThankYou(
      id: id ?? this.id,
      donationId: donationId ?? this.donationId,
      method: method ?? this.method,
      sentDate: sentDate ?? this.sentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
