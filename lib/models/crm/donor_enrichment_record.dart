/// DonorEnrichmentRecord — the columns from `public.donor_enrichment`
/// that are actually populated in production (see 2026-04-21 audit).
///
/// The table has 100+ columns, most of them null-only. This model only
/// maps the fields that the UI should surface. Unpopulated fields are
/// filtered out by `populatedFields` so we can skip rendering when nothing
/// useful is available.
class DonorEnrichmentRecord {
  final String? id;
  final String? fullName;

  // Identity
  final String? gender; // ~92% populated
  final int? ageEstimate;

  // Politics
  final String? partyLean; // ~84% populated
  final num? partyLeanConfidence;

  // Geography (current residence per voter file)
  final String? currentCity;
  final String? currentZip;
  final String? currentCounty;
  final String? congressionalDistrict;

  // Giving history (100% populated)
  final double? totalPoliticalDonations;
  final int? donationCount;
  final double? avgDonation;
  final String? donationFrequency;

  // Wealth / household
  final bool? isHomeowner;
  final num? wealthScore;

  // Linkage
  final String? moVoterFileId;

  const DonorEnrichmentRecord({
    this.id,
    this.fullName,
    this.gender,
    this.ageEstimate,
    this.partyLean,
    this.partyLeanConfidence,
    this.currentCity,
    this.currentZip,
    this.currentCounty,
    this.congressionalDistrict,
    this.totalPoliticalDonations,
    this.donationCount,
    this.avgDonation,
    this.donationFrequency,
    this.isHomeowner,
    this.wealthScore,
    this.moVoterFileId,
  });

  factory DonorEnrichmentRecord.fromJson(Map<String, dynamic> json) {
    return DonorEnrichmentRecord(
      id: json['id']?.toString(),
      fullName: json['full_name'] as String?,
      gender: json['gender'] as String?,
      ageEstimate: (json['age_estimate'] as num?)?.toInt(),
      partyLean: json['party_lean'] as String?,
      partyLeanConfidence: json['party_lean_confidence'] as num?,
      currentCity: json['current_city'] as String?,
      currentZip: json['current_zip'] as String?,
      currentCounty: json['current_county'] as String?,
      congressionalDistrict: json['congressional_district'] as String?,
      totalPoliticalDonations:
          (json['total_political_donations'] as num?)?.toDouble(),
      donationCount: (json['donation_count'] as num?)?.toInt(),
      avgDonation: (json['avg_donation'] as num?)?.toDouble(),
      donationFrequency: json['donation_frequency'] as String?,
      isHomeowner: json['is_homeowner'] as bool?,
      wealthScore: json['wealth_score'] as num?,
      moVoterFileId: json['mo_voter_file_id'] as String?,
    );
  }

  /// List of `(label, value)` pairs for every populated field.
  /// Used by DonorEnrichmentCard — if the list is empty, don't render
  /// the card at all.
  List<({String label, String value})> get populatedFields {
    final out = <({String label, String value})>[];

    String? fmtMoney(double? v) {
      if (v == null) return null;
      return '\$${v.toStringAsFixed(v >= 1000 ? 0 : 2)}';
    }

    String? s(String? v) => (v != null && v.isNotEmpty) ? v : null;

    void add(String label, String? value) {
      if (value != null) out.add((label: label, value: value));
    }

    add('Gender', s(gender));
    if (ageEstimate != null) add('Age (est.)', '$ageEstimate');
    add('Party Lean', s(partyLean));
    if (partyLeanConfidence != null) {
      add('Lean Confidence', '${(partyLeanConfidence!.toDouble() * 100).toStringAsFixed(0)}%');
    }
    add('Current City', s(currentCity));
    add('Current Zip', s(currentZip));
    add('Current County', s(currentCounty));
    add('Congressional District', s(congressionalDistrict));
    add('Total Political Giving', fmtMoney(totalPoliticalDonations));
    if (donationCount != null) add('Gift Count', '$donationCount');
    add('Average Gift', fmtMoney(avgDonation));
    add('Giving Frequency', s(donationFrequency));
    if (isHomeowner != null) {
      add('Homeowner', isHomeowner! ? 'Yes' : 'No');
    }
    if (wealthScore != null) {
      add('Wealth Score', wealthScore!.toStringAsFixed(0));
    }

    return out;
  }

  bool get hasData => populatedFields.isNotEmpty;
}
