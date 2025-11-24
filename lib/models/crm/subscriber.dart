import 'package:bluebubbles/models/crm/donor.dart';

class Subscriber {
  final String id;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String email;
  final String name;
  final String? phone;
  final String? phoneE164;
  final DateTime? dateOfBirth;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? county;
  final String? congressionalDistrict;
  final String? houseDistrict;
  final String? senateDistrict;
  final String? employer;
  final DateTime? optinDate;
  final String? tags;
  final String? subscriptionStatus;
  final bool? subscribed;
  final String? memberId;
  final String? donorId;
  final String? source;
  final String? notes;
  final DateTime? lastSyncedAt;
  final Donor? donor;
  final int eventAttendanceCount;

  const Subscriber({
    required this.id,
    required this.email,
    required this.name,
    this.createdAt,
    this.updatedAt,
    this.phone,
    this.phoneE164,
    this.dateOfBirth,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.county,
    this.congressionalDistrict,
    this.houseDistrict,
    this.senateDistrict,
    this.employer,
    this.optinDate,
    this.tags,
    this.subscriptionStatus,
    this.subscribed,
    this.memberId,
    this.donorId,
    this.source,
    this.notes,
    this.lastSyncedAt,
    this.donor,
    this.eventAttendanceCount = 0,
  });

  factory Subscriber.fromJson(Map<String, dynamic> json) {
    return Subscriber(
      id: json['id'] as String,
      email: json['email'] as String,
      name: (json['name'] as String?)?.trim() ?? 'N/A',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      phone: json['phone'] as String?,
      phoneE164: json['phone_e164'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      county: json['county'] as String?,
      congressionalDistrict: json['congressional_district'] as String?,
      houseDistrict: json['house_district'] as String?,
      senateDistrict: json['senate_district'] as String?,
      employer: json['employer'] as String?,
      optinDate: _parseDate(json['optin_date']),
      tags: json['tags'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      subscribed: json['subscribed'] as bool?,
      memberId: json['member_id'] as String?,
      donorId: json['donor_id'] as String?,
      source: json['source'] as String?,
      notes: json['notes'] as String?,
      lastSyncedAt: _parseDate(json['last_synced_at']),
      donor: json['donor'] == null
          ? null
          : Donor.fromJson(json['donor'] as Map<String, dynamic>),
      eventAttendanceCount: json['event_attendance_count'] as int? ?? 0,
    );
  }

  Subscriber copyWith({int? eventAttendanceCount, Donor? donor, bool? subscribedStatus}) {
    return Subscriber(
      id: id,
      email: email,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      phone: phone,
      phoneE164: phoneE164,
      dateOfBirth: dateOfBirth,
      address: address,
      city: city,
      state: state,
      zipCode: zipCode,
      county: county,
      congressionalDistrict: congressionalDistrict,
      houseDistrict: houseDistrict,
      senateDistrict: senateDistrict,
      employer: employer,
      optinDate: optinDate,
      tags: tags,
      subscriptionStatus: subscriptionStatus,
      subscribed: subscribedStatus ?? subscribed,
      memberId: memberId,
      donorId: donorId,
      source: source,
      notes: notes,
      lastSyncedAt: lastSyncedAt,
      donor: donor ?? this.donor,
      eventAttendanceCount: eventAttendanceCount ?? this.eventAttendanceCount,
    );
  }

  List<String> get tagList {
    final raw = tags ?? '';
    return raw
        .split(RegExp(r'[;,]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.tryParse(value as String);
    } catch (_) {
      return null;
    }
  }
}

class SubscriberStats {
  final int totalSubscribers;
  final int activeSubscribers;
  final int unsubscribed;
  final int donorCount;
  final int contactInfoCount;
  final Map<String, int> bySource;
  final int recentOptIns;

  const SubscriberStats({
    this.totalSubscribers = 0,
    this.activeSubscribers = 0,
    this.unsubscribed = 0,
    this.donorCount = 0,
    this.contactInfoCount = 0,
    this.bySource = const {},
    this.recentOptIns = 0,
  });

  SubscriberStats copyWith({
    int? totalSubscribers,
    int? activeSubscribers,
    int? unsubscribed,
    int? donorCount,
    int? contactInfoCount,
    Map<String, int>? bySource,
    int? recentOptIns,
  }) {
    return SubscriberStats(
      totalSubscribers: totalSubscribers ?? this.totalSubscribers,
      activeSubscribers: activeSubscribers ?? this.activeSubscribers,
      unsubscribed: unsubscribed ?? this.unsubscribed,
      donorCount: donorCount ?? this.donorCount,
      contactInfoCount: contactInfoCount ?? this.contactInfoCount,
      bySource: bySource ?? this.bySource,
      recentOptIns: recentOptIns ?? this.recentOptIns,
    );
  }
}

class SubscriberFetchResult {
  final List<Subscriber> subscribers;
  final int? totalCount;
  final SubscriberStats? stats;

  const SubscriberFetchResult({
    required this.subscribers,
    this.totalCount,
    this.stats,
  });
}
