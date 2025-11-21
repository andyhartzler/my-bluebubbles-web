import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/event.dart';

class Donor {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? memberId;
  final double? totalDonated;
  final bool? isRecurringDonor;
  final DateTime? createdAt;
  final Member? member;
  final List<Donation> donations;

  const Donor({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.memberId,
    this.totalDonated,
    this.isRecurringDonor,
    this.createdAt,
    this.member,
    this.donations = const [],
  });

  Donor copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? memberId,
    double? totalDonated,
    bool? isRecurringDonor,
    DateTime? createdAt,
    Member? member,
    List<Donation>? donations,
  }) {
    return Donor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      memberId: memberId ?? this.memberId,
      totalDonated: totalDonated ?? this.totalDonated,
      isRecurringDonor: isRecurringDonor ?? this.isRecurringDonor,
      createdAt: createdAt ?? this.createdAt,
      member: member ?? this.member,
      donations: donations ?? this.donations,
    );
  }

  factory Donor.fromJson(Map<String, dynamic> json) {
    Member? member;
    if (json['members'] is Map<String, dynamic>) {
      member = Member.fromJson(json['members'] as Map<String, dynamic>);
    }

    final donationsData = json['donations'] ?? json['donations:donations'];
    final donations = <Donation>[];
    if (donationsData is List) {
      for (final entry in donationsData) {
        if (entry is Map<String, dynamic>) {
          donations.add(Donation.fromJson(entry));
        }
      }
    }

    return Donor(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      memberId: json['member_id'] as String?,
      totalDonated: _parseDouble(json['total_donated']),
      isRecurringDonor: json['is_recurring_donor'] as bool?,
      createdAt: _parseDateTime(json['created_at']),
      member: member,
      donations: donations,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is DateTime) return value;
    return null;
  }
}

class Donation {
  final String id;
  final double? amount;
  final DateTime? donatedAt;
  final bool? recurring;
  final String? method;
  final String? status;
  final String? notes;
  final String? eventId;
  final String? eventName;
  final DateTime? eventDate;

  const Donation({
    required this.id,
    this.amount,
    this.donatedAt,
    this.recurring,
    this.method,
    this.status,
    this.notes,
    this.eventId,
    this.eventName,
    this.eventDate,
  });

  factory Donation.fromJson(Map<String, dynamic> json) {
    final eventData = json['events'] ?? json['event'];
    Event? event;
    if (eventData is Map<String, dynamic>) {
      event = Event.fromJson(eventData);
    }

    return Donation(
      id: json['id']?.toString() ?? '',
      amount: _parseDouble(json['amount'] ?? json['total']),
      donatedAt: _parseDate(json['donated_at'] ?? json['donation_date'] ?? json['created_at']),
      recurring: json['is_recurring'] as bool? ?? json['recurring'] as bool?,
      method: json['method'] as String? ?? json['payment_method'] as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      eventId: json['event_id'] as String? ?? event?.id,
      eventName: event?.name ?? json['event_name'] as String?,
      eventDate: event?.startsAt,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is DateTime) return value;
    return null;
  }
}
