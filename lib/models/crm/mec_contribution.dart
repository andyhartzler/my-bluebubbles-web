import 'package:intl/intl.dart';

/// MecContribution model - maps to Supabase 'public.mec_contributions' table
/// Missouri Ethics Commission campaign finance contribution records
class MecContribution {
  final int id;
  final String? mecId;
  final String? committeeName;
  final String? report;
  final String? contributorCommittee;
  final String? contributorCompany;
  final String? contributorLastName;
  final String? contributorFirstName;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? zip;
  final String? employer;
  final String? occupation;
  final DateTime? contributionDate;
  final double? contributionAmount;
  final String? monetaryOrInkind;
  final bool? isCommitteeContributor;
  final String? reportType;
  final int? filingYear;
  final DateTime? createdAt;

  const MecContribution({
    required this.id,
    this.mecId,
    this.committeeName,
    this.report,
    this.contributorCommittee,
    this.contributorCompany,
    this.contributorLastName,
    this.contributorFirstName,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.zip,
    this.employer,
    this.occupation,
    this.contributionDate,
    this.contributionAmount,
    this.monetaryOrInkind,
    this.isCommitteeContributor,
    this.reportType,
    this.filingYear,
    this.createdAt,
  });

  factory MecContribution.fromJson(Map<String, dynamic> json) {
    return MecContribution(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mecId: json['mec_id'] as String?,
      committeeName: json['committee_name'] as String?,
      report: json['report'] as String?,
      contributorCommittee: json['contributor_committee'] as String?,
      contributorCompany: json['contributor_company'] as String?,
      contributorLastName: json['contributor_last_name'] as String?,
      contributorFirstName: json['contributor_first_name'] as String?,
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      contributionDate: _parseDate(json['contribution_date']),
      contributionAmount: (json['contribution_amount'] as num?)?.toDouble(),
      monetaryOrInkind: json['monetary_or_inkind'] as String?,
      isCommitteeContributor: json['is_committee_contributor'] as bool?,
      reportType: json['report_type'] as String?,
      filingYear: json['filing_year'] as int?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  /// Display name logic: committee name > company > "First Last" > "Unknown"
  String get contributorDisplayName {
    if (isCommitteeContributor == true &&
        contributorCommittee != null &&
        contributorCommittee!.isNotEmpty) {
      return contributorCommittee!;
    }
    if (contributorCompany != null && contributorCompany!.isNotEmpty) {
      return contributorCompany!;
    }
    final first = contributorFirstName?.trim() ?? '';
    final last = contributorLastName?.trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      return '$first $last'.trim();
    }
    return 'Unknown';
  }

  String get formattedDate {
    if (contributionDate == null) return 'Date unknown';
    return DateFormat.yMMMd().format(contributionDate!);
  }

  String get formattedAmount {
    if (contributionAmount == null) return '\$0.00';
    return NumberFormat.simpleCurrency().format(contributionAmount);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
