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
  final String? generation;
  final String? ethnicity;

  // Politics
  final String? partyLean; // ~84% populated
  final num? partyLeanConfidence;

  // Geography (current residence per voter file)
  final String? currentAddressLine1;
  final String? currentAddressLine2;
  final String? currentCity;
  final String? currentState;
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
  final num? engagementScore;
  final double? givingCapacityEstimate;
  final String? estimatedIncomeRange;

  // Contact
  final String? phoneMobile;
  final String? phoneHome;
  final String? emailPersonal;
  final int? socialProfileCount;

  // Employment
  final String? currentEmployer;
  final String? currentJobTitle;

  // Linkage
  final String? moVoterFileId;

  const DonorEnrichmentRecord({
    this.id,
    this.fullName,
    this.gender,
    this.ageEstimate,
    this.generation,
    this.ethnicity,
    this.partyLean,
    this.partyLeanConfidence,
    this.currentAddressLine1,
    this.currentAddressLine2,
    this.currentCity,
    this.currentState,
    this.currentZip,
    this.currentCounty,
    this.congressionalDistrict,
    this.totalPoliticalDonations,
    this.donationCount,
    this.avgDonation,
    this.donationFrequency,
    this.isHomeowner,
    this.wealthScore,
    this.engagementScore,
    this.givingCapacityEstimate,
    this.estimatedIncomeRange,
    this.phoneMobile,
    this.phoneHome,
    this.emailPersonal,
    this.socialProfileCount,
    this.currentEmployer,
    this.currentJobTitle,
    this.moVoterFileId,
  });

  factory DonorEnrichmentRecord.fromJson(Map<String, dynamic> json) {
    return DonorEnrichmentRecord(
      id: json['id']?.toString(),
      fullName: json['full_name'] as String?,
      gender: json['gender'] as String?,
      ageEstimate: (json['age_estimate'] as num?)?.toInt(),
      generation: json['generation'] as String?,
      ethnicity: json['ethnicity'] as String?,
      partyLean: json['party_lean'] as String?,
      partyLeanConfidence: json['party_lean_confidence'] as num?,
      currentAddressLine1: json['current_address_line1'] as String?,
      currentAddressLine2: json['current_address_line2'] as String?,
      currentCity: json['current_city'] as String?,
      currentState: json['current_state'] as String?,
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
      engagementScore: json['engagement_score'] as num?,
      givingCapacityEstimate:
          (json['giving_capacity_estimate'] as num?)?.toDouble(),
      estimatedIncomeRange: json['estimated_income_range'] as String?,
      phoneMobile: json['phone_mobile'] as String?,
      phoneHome: json['phone_home'] as String?,
      emailPersonal: json['email_personal'] as String?,
      socialProfileCount: (json['social_profile_count'] as num?)?.toInt(),
      currentEmployer: json['current_employer'] as String?,
      currentJobTitle: json['current_job_title'] as String?,
      moVoterFileId: json['mo_voter_file_id'] as String?,
    );
  }

  /// Merge a `donor_enrichment` row (may be null) with a raw `donors` row
  /// (may be null), preferring enrichment values but falling back to the
  /// donor row's schema (`city`, `state`, `zip_code`, `address`, `employer`,
  /// `occupation`).
  ///
  /// Used by `MecResearchTab`, which has both data sources at hand.
  factory DonorEnrichmentRecord.fromRawMap(
    Map<String, dynamic>? enrichment, {
    Map<String, dynamic>? donorRow,
  }) {
    String? str(String key) =>
        (enrichment?[key] as String?) ?? (donorRow?[key] as String?);
    num? numv(String key) =>
        (enrichment?[key] as num?) ?? (donorRow?[key] as num?);
    bool? boolv(String key) =>
        (enrichment?[key] as bool?) ?? (donorRow?[key] as bool?);

    // Address: enrichment uses `current_address_line1`, donors row uses
    // `address` / `city` / `state` / `zip_code`.
    final addrLine1 = (enrichment?['current_address_line1'] as String?) ??
        (donorRow?['address_line_1'] as String?) ??
        (donorRow?['address'] as String?);
    final addrLine2 = (enrichment?['current_address_line2'] as String?) ??
        (donorRow?['address_line_2'] as String?);
    final city = (enrichment?['current_city'] as String?) ??
        (donorRow?['city'] as String?);
    final stateVal = (enrichment?['current_state'] as String?) ??
        (donorRow?['state'] as String?);
    final zip = (enrichment?['current_zip'] as String?) ??
        (donorRow?['zip_code'] as String?) ??
        (donorRow?['zip'] as String?);
    final employer = (enrichment?['current_employer'] as String?) ??
        (donorRow?['current_employer'] as String?) ??
        (donorRow?['employer'] as String?);
    final jobTitle = (enrichment?['current_job_title'] as String?) ??
        (donorRow?['current_job_title'] as String?) ??
        (donorRow?['occupation'] as String?);

    return DonorEnrichmentRecord(
      id: (enrichment?['id'] ?? donorRow?['id'])?.toString(),
      fullName: str('full_name'),
      gender: str('gender'),
      ageEstimate: numv('age_estimate')?.toInt(),
      generation: enrichment?['generation'] as String?,
      ethnicity: str('ethnicity'),
      partyLean: str('party_lean'),
      partyLeanConfidence: numv('party_lean_confidence'),
      currentAddressLine1: addrLine1,
      currentAddressLine2: addrLine2,
      currentCity: city,
      currentState: stateVal,
      currentZip: zip,
      currentCounty: str('current_county') ?? (donorRow?['county'] as String?),
      congressionalDistrict: str('congressional_district'),
      totalPoliticalDonations: numv('total_political_donations')?.toDouble(),
      donationCount: numv('donation_count')?.toInt(),
      avgDonation: numv('avg_donation')?.toDouble(),
      donationFrequency: str('donation_frequency'),
      isHomeowner: boolv('is_homeowner'),
      wealthScore: numv('wealth_score'),
      engagementScore: numv('engagement_score'),
      givingCapacityEstimate: numv('giving_capacity_estimate')?.toDouble(),
      estimatedIncomeRange: str('estimated_income_range'),
      phoneMobile: str('phone_mobile'),
      phoneHome: str('phone_home'),
      emailPersonal: str('email_personal'),
      socialProfileCount: numv('social_profile_count')?.toInt(),
      currentEmployer: employer,
      currentJobTitle: jobTitle,
      moVoterFileId: str('mo_voter_file_id'),
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

    // Identity
    add('Gender', s(gender));
    if (ageEstimate != null) add('Age (est.)', '$ageEstimate');
    add('Generation', s(generation));
    add('Ethnicity', s(ethnicity));

    // Politics
    add('Party Lean', s(partyLean));
    if (partyLeanConfidence != null) {
      add('Lean Confidence', '${(partyLeanConfidence!.toDouble() * 100).toStringAsFixed(0)}%');
    }

    // Geography
    add('Street', s(currentAddressLine1));
    add('Street 2', s(currentAddressLine2));
    add('Current City', s(currentCity));
    add('Current State', s(currentState));
    add('Current Zip', s(currentZip));
    add('Current County', s(currentCounty));
    add('Congressional District', s(congressionalDistrict));

    // Contact
    add('Mobile', s(phoneMobile));
    add('Home Phone', s(phoneHome));
    add('Email', s(emailPersonal));
    if (socialProfileCount != null && socialProfileCount! > 0) {
      add('Social Profiles', '$socialProfileCount found');
    }

    // Employment
    add('Employer', s(currentEmployer));
    add('Job Title', s(currentJobTitle));
    add('Est. Income', s(estimatedIncomeRange));

    // Giving
    add('Total Political Giving', fmtMoney(totalPoliticalDonations));
    if (donationCount != null) add('Gift Count', '$donationCount');
    add('Average Gift', fmtMoney(avgDonation));
    add('Giving Frequency', s(donationFrequency));
    add('Giving Capacity', fmtMoney(givingCapacityEstimate));

    // Wealth / household
    if (isHomeowner != null) {
      add('Homeowner', isHomeowner! ? 'Yes' : 'No');
    }
    if (wealthScore != null) {
      add('Wealth Score', wealthScore!.toStringAsFixed(0));
    }
    if (engagementScore != null) {
      add('Engagement Score', engagementScore!.toStringAsFixed(0));
    }

    return out;
  }

  bool get hasData => populatedFields.isNotEmpty;
}
