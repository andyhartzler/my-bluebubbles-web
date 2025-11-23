import 'package:collection/collection.dart';

import 'donation.dart';

class Donor {
  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? phoneE164;
  final String? memberId;
  final double? totalDonated;
  final bool? isRecurringDonor;
  final DateTime? firstDonationDate;
  final DateTime? lastDonationDate;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? employer;
  final String? occupation;
  final String? donorType;
  final String? notes;
  final DateTime? dateOfBirth;
  final String? congressionalDistrict;
  final String? county;
  final DateTime? createdAt;
  final List<Donation> donations;
  final Map<String, dynamic> extra;

  const Donor({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.phoneE164,
    this.memberId,
    this.totalDonated,
    this.isRecurringDonor,
    this.firstDonationDate,
    this.lastDonationDate,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.employer,
    this.occupation,
    this.donorType,
    this.notes,
    this.dateOfBirth,
    this.congressionalDistrict,
    this.county,
    this.createdAt,
    this.donations = const [],
    this.extra = const {},
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    return Donor(
      id: json['id'] as String?,
      name: _normalizeName(json['name'] as String?),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      phoneE164: json['phone_e164'] as String? ?? json['phone'] as String?,
      memberId: json['member_id'] as String?,
      totalDonated: (json['total_donated'] as num?)?.toDouble(),
      isRecurringDonor: _inferRecurring(json['is_recurring_donor'], json['donations']),
      firstDonationDate: _parseDate(
          json['first_donation_date'] ?? json['first_donation_at']),
      lastDonationDate:
          _parseDate(json['last_donation_date'] ?? json['last_donation_at']),
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      donorType: json['donor_type'] as String?,
      notes: json['notes'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth'])?.toLocal(),
      congressionalDistrict: json['congressional_district'] as String?,
      county: json['county'] as String?,
      createdAt: _parseDate(json['created_at']),
      donations: _parseDonations(json['donations']),
      extra: Map<String, dynamic>.from(json),
    );
  }

  Donor copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? phoneE164,
    String? memberId,
    double? totalDonated,
    bool? isRecurringDonor,
    DateTime? firstDonationDate,
    DateTime? lastDonationDate,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? employer,
    String? occupation,
    String? donorType,
    String? notes,
    DateTime? dateOfBirth,
    String? congressionalDistrict,
    String? county,
    DateTime? createdAt,
    List<Donation>? donations,
    Map<String, dynamic>? extra,
  }) {
    return Donor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneE164: phoneE164 ?? this.phoneE164,
      memberId: memberId ?? this.memberId,
      totalDonated: totalDonated ?? this.totalDonated,
      isRecurringDonor: isRecurringDonor ?? this.isRecurringDonor,
      firstDonationDate: firstDonationDate ?? this.firstDonationDate,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      employer: employer ?? this.employer,
      occupation: occupation ?? this.occupation,
      donorType: donorType ?? this.donorType,
      notes: notes ?? this.notes,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      county: county ?? this.county,
      createdAt: createdAt ?? this.createdAt,
      donations: donations ?? this.donations,
      extra: extra ?? this.extra,
    );
  }

  int get donationCount => (extra['donation_count'] as num?)?.toInt() ?? donations.length;

  static List<Donation> _parseDonations(dynamic value) {
    final list = (value as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Donation.fromJson)
        .toList();
    list.sort((a, b) {
      final aDate = a.donationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.donationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _normalizeName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static bool? _inferRecurring(dynamic recurringFlag, dynamic donationsJson) {
    final donations = _parseDonations(donationsJson);
    final inferred = _hasRecurringPattern(donations);
    if (recurringFlag is bool) {
      return recurringFlag || inferred;
    }
    return inferred;
  }

  static bool inferRecurringFromDonations(List<Donation> donations) {
    return _hasRecurringPattern(donations);
  }

  static bool _hasRecurringPattern(List<Donation> donations) {
    if (donations.length < 3) return false;
    final groups = <double, List<DateTime>>{};
    for (final donation in donations) {
      final amount = donation.amount;
      final date = donation.donationDate;
      if (amount == null || date == null) continue;
      final key = double.parse(amount.toStringAsFixed(2));
      groups.putIfAbsent(key, () => []).add(date);
    }

    for (final entries in groups.entries) {
      final dates = entries.value..sort();
      if (dates.length < 3) continue;
      final intervals = <int>[];
      for (var i = 1; i < dates.length; i++) {
        intervals.add(dates[i].difference(dates[i - 1]).inDays.abs());
      }
      if (intervals.isEmpty) continue;
      final mode = _mode(intervals);
      if (mode == null || mode == 0) continue;
      final consistentIntervals = intervals.where((d) => (d - mode).abs() <= 3).length;
      if (consistentIntervals >= 2) return true;
    }
    return false;
  }

  static int? _mode(List<int> values) {
    final counts = <int, int>{};
    for (final value in values) {
      counts.update(value, (c) => c + 1, ifAbsent: () => 1);
    }
    int? best;
    int bestCount = 0;
    counts.forEach((value, count) {
      if (count > bestCount) {
        bestCount = count;
        best = value;
      }
    });
    return best;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Donor && const DeepCollectionEquality().equals(other.extra, extra);
  }

  @override
  int get hashCode => const DeepCollectionEquality().hash(extra);
}

class DonorFetchResult {
  final List<Donor> donors;
  final int? totalCount;

  const DonorFetchResult({required this.donors, this.totalCount});
}
