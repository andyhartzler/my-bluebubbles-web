import 'package:collection/collection.dart';

class Donor {
  final String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? memberId;
  final double? totalDonated;
  final bool? isRecurringDonor;
  final DateTime? createdAt;
  final Map<String, dynamic> extra;

  const Donor({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.memberId,
    this.totalDonated,
    this.isRecurringDonor,
    this.createdAt,
    this.extra = const {},
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    return Donor(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      memberId: json['member_id'] as String?,
      totalDonated: (json['total_donated'] as num?)?.toDouble(),
      isRecurringDonor: json['is_recurring_donor'] as bool?,
      createdAt: _parseDate(json['created_at']),
      extra: Map<String, dynamic>.from(json),
    );
  }

  Donor copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? memberId,
    double? totalDonated,
    bool? isRecurringDonor,
    DateTime? createdAt,
    Map<String, dynamic>? extra,
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
      extra: extra ?? this.extra,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
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
