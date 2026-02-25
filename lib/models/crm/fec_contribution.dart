import 'package:intl/intl.dart';

/// FecContribution model - maps to Supabase 'public.fec_contributions' table
/// Actual DB columns: cmte_id, committee_name, contributor_name, city, state, zip,
/// employer, occupation, transaction_date, transaction_amount, cycle, entity_tp, donor_id
class FecContribution {
  final int id;
  final String? cmteId;
  final String? committeeName;
  final String? contributorName;
  final String? city;
  final String? state;
  final String? zip;
  final String? employer;
  final String? occupation;
  final DateTime? transactionDate;
  final double? transactionAmount;
  final int? cycle;
  final String? entityType;
  final int? donorId;

  const FecContribution({
    required this.id,
    this.cmteId,
    this.committeeName,
    this.contributorName,
    this.city,
    this.state,
    this.zip,
    this.employer,
    this.occupation,
    this.transactionDate,
    this.transactionAmount,
    this.cycle,
    this.entityType,
    this.donorId,
  });

  factory FecContribution.fromJson(Map<String, dynamic> json) {
    return FecContribution(
      id: json['id'] as int,
      cmteId: json['cmte_id'] as String?,
      committeeName: json['committee_name'] as String?,
      contributorName: json['contributor_name'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      transactionDate: _parseDate(json['transaction_date']),
      transactionAmount: (json['transaction_amount'] as num?)?.toDouble(),
      cycle: json['cycle'] as int?,
      entityType: json['entity_tp'] as String?,
      donorId: json['donor_id'] as int?,
    );
  }

  String get formattedDate {
    if (transactionDate == null) return 'Date unknown';
    return DateFormat.yMMMd().format(transactionDate!);
  }

  String get formattedAmount {
    if (transactionAmount == null) return '\$0.00';
    return NumberFormat.simpleCurrency().format(transactionAmount);
  }

  String get displayName => contributorName ?? 'Unknown';

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
