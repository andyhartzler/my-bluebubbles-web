import 'package:intl/intl.dart';

class Donation {
  final String id;
  final String? donorId;
  final double? amount;
  final DateTime? donationDate;
  final String? paymentMethod;
  final String? checkNumber;
  final String? notes;
  final bool sentThankYou;
  final String? eventId;
  final String? eventName;
  final String? donorName;
  final String? donorEmail;
  final String? donorPhone;

  const Donation({
    required this.id,
    this.donorId,
    this.amount,
    this.donationDate,
    this.paymentMethod,
    this.checkNumber,
    this.notes,
    this.sentThankYou = false,
    this.eventId,
    this.eventName,
    this.donorName,
    this.donorEmail,
    this.donorPhone,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    final donor = json['donor'] ?? json['donors'];
    String? donorName;
    String? donorEmail;
    String? donorPhone;
    if (donor is Map<String, dynamic>) {
      donorName = donor['name'] as String?;
      donorEmail = donor['email'] as String?;
      donorPhone = donor['phone'] as String?;
    }

    return Donation(
      id: json['id']?.toString() ?? '',
      donorId: json['donor_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      donationDate: _parseDate(json['donation_date'] ?? json['created_at']),
      paymentMethod: json['payment_method'] as String?,
      checkNumber: json['check_number'] as String?,
      notes: json['notes'] as String?,
      sentThankYou: json['sent_thank_you'] == true,
      eventId: json['event_id'] as String?,
      eventName: json['event_name'] as String? ??
          (json['events'] is Map<String, dynamic> ? json['events']['title'] as String? : null),
      donorName: donorName,
      donorEmail: donorEmail,
      donorPhone: donorPhone,
    );
  }

  String get formattedDate {
    if (donationDate == null) return 'Date unknown';
    return DateFormat.yMMMd().format(donationDate!);
  }

  Donation copyWith({
    bool? sentThankYou,
  }) {
    return Donation(
      id: id,
      donorId: donorId,
      amount: amount,
      donationDate: donationDate,
      paymentMethod: paymentMethod,
      checkNumber: checkNumber,
      notes: notes,
      sentThankYou: sentThankYou ?? this.sentThankYou,
      eventId: eventId,
      eventName: eventName,
      donorName: donorName,
      donorEmail: donorEmail,
      donorPhone: donorPhone,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
