import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Nested models
// ---------------------------------------------------------------------------

class ContributionRecord {
  final String? id;
  final String? profileId;
  final String? source;
  final String? contributorName;
  final double? amount;
  final DateTime? date;
  final String? committeeName;
  final String? committeeId;
  final String? paymentMethod;
  final String? employer;
  final String? occupation;
  final String? eventTitle;
  final bool? sentThankYou;

  const ContributionRecord({
    this.id,
    this.profileId,
    this.source,
    this.contributorName,
    this.amount,
    this.date,
    this.committeeName,
    this.committeeId,
    this.paymentMethod,
    this.employer,
    this.occupation,
    this.eventTitle,
    this.sentThankYou,
  });

  factory ContributionRecord.fromJson(Map<String, dynamic> json) {
    return ContributionRecord(
      id: json['source_id'] as String?,
      profileId: json['profile_id'] as String?,
      source: json['source'] as String?,
      contributorName: json['recipient_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      date: DonorProfile._parseDate(json['contribution_date']),
      paymentMethod: json['payment_method'] as String?,
    );
  }
}

class MoydDonation {
  final String? id;
  final String? profileId;
  final String? contributorName;
  final double? amount;
  final DateTime? date;
  final String? paymentMethod;
  final String? employer;
  final String? occupation;
  final String? eventTitle;
  final bool? sentThankYou;

  const MoydDonation({
    this.id,
    this.profileId,
    this.contributorName,
    this.amount,
    this.date,
    this.paymentMethod,
    this.employer,
    this.occupation,
    this.eventTitle,
    this.sentThankYou,
  });

  factory MoydDonation.fromJson(Map<String, dynamic> json) {
    return MoydDonation(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String?,
      contributorName: json['contributor_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      date: DonorProfile._parseDate(json['date']),
      paymentMethod: json['payment_method'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      eventTitle: json['event_title'] as String?,
      sentThankYou: json['sent_thank_you'] as bool?,
    );
  }
}

class MecContribution {
  final String? id;
  final String? contributorName;
  final String? committeeName;
  final String? committeeId;
  final double? amount;
  final DateTime? date;
  final String? employer;
  final String? occupation;

  const MecContribution({
    this.id,
    this.contributorName,
    this.committeeName,
    this.committeeId,
    this.amount,
    this.date,
    this.employer,
    this.occupation,
  });

  factory MecContribution.fromJson(Map<String, dynamic> json) {
    return MecContribution(
      id: json['id'] as String?,
      contributorName: json['contributor_name'] as String?,
      committeeName: json['committee_name'] as String?,
      committeeId: json['committee_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      date: DonorProfile._parseDate(json['date']),
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
    );
  }
}

class PropertyRecord {
  final String? id;
  final String? address;
  final String? city;
  final String? state;
  final String? zip;
  final String? propertyType;
  final int? yearBuilt;
  final double? assessedValue;
  final double? lotSizeSqft;
  final DateTime? lastSaleDate;
  final double? lastSalePrice;

  const PropertyRecord({
    this.id,
    this.address,
    this.city,
    this.state,
    this.zip,
    this.propertyType,
    this.yearBuilt,
    this.assessedValue,
    this.lotSizeSqft,
    this.lastSaleDate,
    this.lastSalePrice,
  });

  factory PropertyRecord.fromJson(Map<String, dynamic> json) {
    return PropertyRecord(
      id: json['id'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      propertyType: json['property_type'] as String?,
      yearBuilt: (json['year_built'] as num?)?.toInt(),
      assessedValue: (json['assessed_value'] as num?)?.toDouble(),
      lotSizeSqft: (json['lot_size_sqft'] as num?)?.toDouble(),
      lastSaleDate: DonorProfile._parseDate(json['last_sale_date']),
      lastSalePrice: (json['last_sale_price'] as num?)?.toDouble(),
    );
  }
}

class CasenetRecord {
  final String? id;
  final String? caseNumber;
  final String? caseType;
  final String? court;
  final DateTime? filingDate;
  final String? status;
  final String? parties;

  const CasenetRecord({
    this.id,
    this.caseNumber,
    this.caseType,
    this.court,
    this.filingDate,
    this.status,
    this.parties,
  });

  factory CasenetRecord.fromJson(Map<String, dynamic> json) {
    return CasenetRecord(
      id: json['id'] as String?,
      caseNumber: json['case_number'] as String?,
      caseType: json['case_type'] as String?,
      court: json['court'] as String?,
      filingDate: DonorProfile._parseDate(json['filing_date']),
      status: json['status'] as String?,
      parties: json['parties'] as String?,
    );
  }
}

class SecFiling {
  final String? id;
  final String? companyName;
  final String? formType;
  final DateTime? filingDate;
  final String? description;

  const SecFiling({
    this.id,
    this.companyName,
    this.formType,
    this.filingDate,
    this.description,
  });

  factory SecFiling.fromJson(Map<String, dynamic> json) {
    return SecFiling(
      id: json['id'] as String?,
      companyName: json['company_name'] as String?,
      formType: json['form_type'] as String?,
      filingDate: DonorProfile._parseDate(json['filing_date']),
      description: json['description'] as String?,
    );
  }
}

class BusinessEntity {
  final String? id;
  final String? entityName;
  final String? entityType;
  final String? status;
  final DateTime? formationDate;
  final String? agentName;

  const BusinessEntity({
    this.id,
    this.entityName,
    this.entityType,
    this.status,
    this.formationDate,
    this.agentName,
  });

  factory BusinessEntity.fromJson(Map<String, dynamic> json) {
    return BusinessEntity(
      id: json['id'] as String?,
      entityName: json['entity_name'] as String?,
      entityType: json['entity_type'] as String?,
      status: json['status'] as String?,
      formationDate: DonorProfile._parseDate(json['formation_date']),
      agentName: json['agent_name'] as String?,
    );
  }
}

class VanVoter {
  final String? vanId;
  final String? firstName;
  final String? lastName;
  final String? party;
  final DateTime? registrationDate;
  final String? precinct;
  final String? ward;
  final String? county;
  final String? congressionalDistrict;
  final String? stateSenate;
  final String? stateHouse;
  final String? cityCouncil;

  const VanVoter({
    this.vanId,
    this.firstName,
    this.lastName,
    this.party,
    this.registrationDate,
    this.precinct,
    this.ward,
    this.county,
    this.congressionalDistrict,
    this.stateSenate,
    this.stateHouse,
    this.cityCouncil,
  });

  factory VanVoter.fromJson(Map<String, dynamic> json) {
    return VanVoter(
      vanId: json['van_id'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      party: json['party'] as String?,
      registrationDate: DonorProfile._parseDate(json['registration_date']),
      precinct: json['precinct'] as String?,
      ward: json['ward'] as String?,
      county: json['county'] as String?,
      congressionalDistrict: json['congressional_district'] as String?,
      stateSenate: json['state_senate'] as String?,
      stateHouse: json['state_house'] as String?,
      cityCouncil: json['city_council'] as String?,
    );
  }
}

class VanVotingRecord {
  final DateTime? electionDate;
  final String? electionType;
  final bool? voted;

  const VanVotingRecord({
    this.electionDate,
    this.electionType,
    this.voted,
  });

  factory VanVotingRecord.fromJson(Map<String, dynamic> json) {
    return VanVotingRecord(
      electionDate: DonorProfile._parseDate(json['election_date']),
      electionType: json['election_type'] as String?,
      voted: json['voted'] as bool?,
    );
  }
}

class VanScore {
  final String? scoreName;
  final double? scoreValue;

  const VanScore({this.scoreName, this.scoreValue});

  factory VanScore.fromJson(Map<String, dynamic> json) {
    return VanScore(
      scoreName: json['score_name'] as String?,
      scoreValue: (json['score_value'] as num?)?.toDouble(),
    );
  }
}

class EnrichmentData {
  final String? fullName;
  final int? age;
  final String? gender;
  final String? education;
  final String? incomeRange;
  final String? netWorth;
  final String? politicalParty;
  final String? donorLikelihood;
  final List<String> socialProfiles;
  final List<String> phones;
  final List<String> emails;

  const EnrichmentData({
    this.fullName,
    this.age,
    this.gender,
    this.education,
    this.incomeRange,
    this.netWorth,
    this.politicalParty,
    this.donorLikelihood,
    this.socialProfiles = const [],
    this.phones = const [],
    this.emails = const [],
  });

  factory EnrichmentData.fromJson(Map<String, dynamic> json) {
    return EnrichmentData(
      fullName: json['full_name'] as String?,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      education: json['education'] as String?,
      incomeRange: json['income_range'] as String?,
      netWorth: json['net_worth'] as String?,
      politicalParty: json['political_party'] as String?,
      donorLikelihood: json['donor_likelihood'] as String?,
      socialProfiles: _parseStringList(json['social_profiles']),
      phones: _parseStringList(json['phones']),
      emails: _parseStringList(json['emails']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }

  /// Returns a count of how many fields are non-null / non-empty.
  int get populatedFieldCount {
    int count = 0;
    if (fullName != null) count++;
    if (age != null) count++;
    if (gender != null) count++;
    if (education != null) count++;
    if (incomeRange != null) count++;
    if (netWorth != null) count++;
    if (politicalParty != null) count++;
    if (donorLikelihood != null) count++;
    if (socialProfiles.isNotEmpty) count++;
    if (phones.isNotEmpty) count++;
    if (emails.isNotEmpty) count++;
    return count;
  }

  static const int totalFieldCount = 11;
}

class CensusData {
  final double? medianIncome;
  final double? medianHomeValue;
  final int? population;
  final Map<String, dynamic>? demographics;

  const CensusData({
    this.medianIncome,
    this.medianHomeValue,
    this.population,
    this.demographics,
  });

  factory CensusData.fromJson(Map<String, dynamic> json) {
    return CensusData(
      medianIncome: (json['median_income'] as num?)?.toDouble(),
      medianHomeValue: (json['median_home_value'] as num?)?.toDouble(),
      population: (json['population'] as num?)?.toInt(),
      demographics: json['demographics'] is Map<String, dynamic>
          ? json['demographics'] as Map<String, dynamic>
          : null,
    );
  }
}

class ZillowData {
  final double? zhvi;
  final double? zhviChangePct;
  final double? medianListingPrice;
  final double? medianRent;

  const ZillowData({
    this.zhvi,
    this.zhviChangePct,
    this.medianListingPrice,
    this.medianRent,
  });

  factory ZillowData.fromJson(Map<String, dynamic> json) {
    return ZillowData(
      zhvi: (json['zhvi'] as num?)?.toDouble(),
      zhviChangePct: (json['zhvi_change_pct'] as num?)?.toDouble(),
      medianListingPrice: (json['median_listing_price'] as num?)?.toDouble(),
      medianRent: (json['median_rent'] as num?)?.toDouble(),
    );
  }
}

class CallOutcome {
  final String? id;
  final String? profileId;
  final String? outcome;
  final double? pledgeAmount;
  final String? notes;
  final DateTime? calledAt;
  final String? calledBy;

  const CallOutcome({
    this.id,
    this.profileId,
    this.outcome,
    this.pledgeAmount,
    this.notes,
    this.calledAt,
    this.calledBy,
  });

  factory CallOutcome.fromJson(Map<String, dynamic> json) {
    return CallOutcome(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String?,
      outcome: json['outcome'] as String?,
      pledgeAmount: (json['pledge_amount'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      calledAt: DonorProfile._parseDate(json['called_at']),
      calledBy: json['called_by'] as String?,
    );
  }
}

class ActivityEntry {
  final String? id;
  final String? profileId;
  final String? activityType;
  final String? title;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final String? createdBy;

  const ActivityEntry({
    this.id,
    this.profileId,
    this.activityType,
    this.title,
    this.description,
    this.metadata,
    this.createdAt,
    this.createdBy,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: json['id'] as String?,
      profileId: json['profile_id'] as String?,
      activityType: json['activity_type'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      createdAt: DonorProfile._parseDate(json['created_at']),
      createdBy: json['created_by'] as String?,
    );
  }
}

class DonorTag {
  final String? id;
  final String? tagName;
  final DateTime? createdAt;
  final String? createdBy;

  const DonorTag({
    this.id,
    this.tagName,
    this.createdAt,
    this.createdBy,
  });

  factory DonorTag.fromJson(Map<String, dynamic> json) {
    return DonorTag(
      id: json['id'] as String?,
      tagName: json['tag_name'] as String?,
      createdAt: DonorProfile._parseDate(json['created_at']),
      createdBy: json['created_by'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Main DonorProfile model
// ---------------------------------------------------------------------------

class DonorProfile {
  // -- donor_profiles columns --
  final String? id;
  final String? donorId;
  final String? memberId;
  final String? vanId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? phoneE164;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? county;
  final String? congressionalDistrict;
  final String? employer;
  final String? occupation;
  final DateTime? dateOfBirth;
  final String? tier;
  final String? partyLean;
  final double? totalDonatedMoyd;
  final double? totalDonatedPolitical;
  final int? donationCountMoyd;
  final int? donationCountPolitical;
  final DateTime? firstDonationDate;
  final DateTime? lastDonationDate;
  final double? averageGift;
  final double? largestGift;
  final int? wealthScore;
  final int? engagementScore;
  final double? givingCapacity;
  final bool? isHomeowner;
  final bool? isBusinessOwner;
  final bool? isSecFiler;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // -- parsed JSONB sub-objects --
  final EnrichmentData? enrichmentData;
  final CensusData? censusData;
  final ZillowData? zillowData;

  // -- nested lists --
  final List<ContributionRecord> donations;
  final List<MecContribution> mecContributions;
  final List<PropertyRecord> propertyRecords;
  final List<CasenetRecord> casenetRecords;
  final List<SecFiling> secFilings;
  final List<BusinessEntity> businessEntities;
  final List<VanVotingRecord> vanVotingRecords;
  final List<VanScore> vanScores;
  final List<DonorTag> tags;
  final List<ActivityEntry> activityLog;
  final List<CallOutcome> callOutcomes;

  // -- nested single objects --
  final VanVoter? vanVoter;

  const DonorProfile({
    this.id,
    this.donorId,
    this.memberId,
    this.vanId,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.phoneE164,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.county,
    this.congressionalDistrict,
    this.employer,
    this.occupation,
    this.dateOfBirth,
    this.tier,
    this.partyLean,
    this.totalDonatedMoyd,
    this.totalDonatedPolitical,
    this.donationCountMoyd,
    this.donationCountPolitical,
    this.firstDonationDate,
    this.lastDonationDate,
    this.averageGift,
    this.largestGift,
    this.wealthScore,
    this.engagementScore,
    this.givingCapacity,
    this.isHomeowner,
    this.isBusinessOwner,
    this.isSecFiler,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.enrichmentData,
    this.censusData,
    this.zillowData,
    this.donations = const [],
    this.mecContributions = const [],
    this.propertyRecords = const [],
    this.casenetRecords = const [],
    this.secFilings = const [],
    this.businessEntities = const [],
    this.vanVotingRecords = const [],
    this.vanScores = const [],
    this.tags = const [],
    this.activityLog = const [],
    this.callOutcomes = const [],
    this.vanVoter,
  });

  // -------------------------------------------------------------------------
  // Factory
  // -------------------------------------------------------------------------

  factory DonorProfile.fromJson(Map<String, dynamic> json) {
    return DonorProfile(
      id: json['id'] as String?,
      donorId: json['donor_id'] as String?,
      memberId: json['member_id'] as String?,
      vanId: json['van_id'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      phoneE164: json['phone_e164'] as String? ?? json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      county: json['county'] as String?,
      congressionalDistrict: json['congressional_district'] as String?,
      employer: json['employer'] as String?,
      occupation: json['occupation'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      tier: json['tier'] as String?,
      partyLean: json['party_lean'] as String?,
      totalDonatedMoyd: (json['total_donated_moyd'] as num?)?.toDouble(),
      totalDonatedPolitical:
          (json['total_donated_political'] as num?)?.toDouble(),
      donationCountMoyd: (json['donation_count_moyd'] as num?)?.toInt(),
      donationCountPolitical:
          (json['donation_count_political'] as num?)?.toInt(),
      firstDonationDate: _parseDate(json['first_donation_date']),
      lastDonationDate: _parseDate(json['last_donation_date']),
      averageGift: (json['average_gift'] as num?)?.toDouble(),
      largestGift: (json['largest_gift'] as num?)?.toDouble(),
      wealthScore: (json['wealth_score'] as num?)?.toInt(),
      engagementScore: (json['engagement_score'] as num?)?.toInt(),
      givingCapacity: (json['giving_capacity'] as num?)?.toDouble(),
      isHomeowner: json['is_homeowner'] as bool?,
      isBusinessOwner: json['is_business_owner'] as bool?,
      isSecFiler: json['is_sec_filer'] as bool?,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      enrichmentData: json['enrichment_data'] is Map<String, dynamic>
          ? EnrichmentData.fromJson(json['enrichment_data'] as Map<String, dynamic>)
          : null,
      censusData: json['census_data'] is Map<String, dynamic>
          ? CensusData.fromJson(json['census_data'] as Map<String, dynamic>)
          : null,
      zillowData: json['zillow_data'] is Map<String, dynamic>
          ? ZillowData.fromJson(json['zillow_data'] as Map<String, dynamic>)
          : null,
      donations: _parseList(json['donations'], ContributionRecord.fromJson),
      mecContributions:
          _parseList(json['mec_contributions'], MecContribution.fromJson),
      propertyRecords:
          _parseList(json['property_records'], PropertyRecord.fromJson),
      casenetRecords:
          _parseList(json['casenet_records'], CasenetRecord.fromJson),
      secFilings: _parseList(json['sec_filings'], SecFiling.fromJson),
      businessEntities:
          _parseList(json['business_entities'], BusinessEntity.fromJson),
      vanVotingRecords:
          _parseList(json['van_voting_records'], VanVotingRecord.fromJson),
      vanScores: _parseList(json['van_scores'], VanScore.fromJson),
      tags: _parseList(json['tags'], DonorTag.fromJson),
      activityLog: _parseList(json['activity_log'], ActivityEntry.fromJson),
      callOutcomes: _parseList(json['call_outcomes'], CallOutcome.fromJson),
      vanVoter: json['van_voter'] is Map<String, dynamic>
          ? VanVoter.fromJson(json['van_voter'] as Map<String, dynamic>)
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------

  DonorProfile copyWith({
    String? id,
    String? donorId,
    String? memberId,
    String? vanId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? phoneE164,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? county,
    String? congressionalDistrict,
    String? employer,
    String? occupation,
    DateTime? dateOfBirth,
    String? tier,
    String? partyLean,
    double? totalDonatedMoyd,
    double? totalDonatedPolitical,
    int? donationCountMoyd,
    int? donationCountPolitical,
    DateTime? firstDonationDate,
    DateTime? lastDonationDate,
    double? averageGift,
    double? largestGift,
    int? wealthScore,
    int? engagementScore,
    double? givingCapacity,
    bool? isHomeowner,
    bool? isBusinessOwner,
    bool? isSecFiler,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    EnrichmentData? enrichmentData,
    CensusData? censusData,
    ZillowData? zillowData,
    List<ContributionRecord>? donations,
    List<MecContribution>? mecContributions,
    List<PropertyRecord>? propertyRecords,
    List<CasenetRecord>? casenetRecords,
    List<SecFiling>? secFilings,
    List<BusinessEntity>? businessEntities,
    List<VanVotingRecord>? vanVotingRecords,
    List<VanScore>? vanScores,
    List<DonorTag>? tags,
    List<ActivityEntry>? activityLog,
    List<CallOutcome>? callOutcomes,
    VanVoter? vanVoter,
  }) {
    return DonorProfile(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      memberId: memberId ?? this.memberId,
      vanId: vanId ?? this.vanId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneE164: phoneE164 ?? this.phoneE164,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      county: county ?? this.county,
      congressionalDistrict:
          congressionalDistrict ?? this.congressionalDistrict,
      employer: employer ?? this.employer,
      occupation: occupation ?? this.occupation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      tier: tier ?? this.tier,
      partyLean: partyLean ?? this.partyLean,
      totalDonatedMoyd: totalDonatedMoyd ?? this.totalDonatedMoyd,
      totalDonatedPolitical:
          totalDonatedPolitical ?? this.totalDonatedPolitical,
      donationCountMoyd: donationCountMoyd ?? this.donationCountMoyd,
      donationCountPolitical:
          donationCountPolitical ?? this.donationCountPolitical,
      firstDonationDate: firstDonationDate ?? this.firstDonationDate,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      averageGift: averageGift ?? this.averageGift,
      largestGift: largestGift ?? this.largestGift,
      wealthScore: wealthScore ?? this.wealthScore,
      engagementScore: engagementScore ?? this.engagementScore,
      givingCapacity: givingCapacity ?? this.givingCapacity,
      isHomeowner: isHomeowner ?? this.isHomeowner,
      isBusinessOwner: isBusinessOwner ?? this.isBusinessOwner,
      isSecFiler: isSecFiler ?? this.isSecFiler,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enrichmentData: enrichmentData ?? this.enrichmentData,
      censusData: censusData ?? this.censusData,
      zillowData: zillowData ?? this.zillowData,
      donations: donations ?? this.donations,
      mecContributions: mecContributions ?? this.mecContributions,
      propertyRecords: propertyRecords ?? this.propertyRecords,
      casenetRecords: casenetRecords ?? this.casenetRecords,
      secFilings: secFilings ?? this.secFilings,
      businessEntities: businessEntities ?? this.businessEntities,
      vanVotingRecords: vanVotingRecords ?? this.vanVotingRecords,
      vanScores: vanScores ?? this.vanScores,
      tags: tags ?? this.tags,
      activityLog: activityLog ?? this.activityLog,
      callOutcomes: callOutcomes ?? this.callOutcomes,
      vanVoter: vanVoter ?? this.vanVoter,
    );
  }

  // -------------------------------------------------------------------------
  // Computed getters
  // -------------------------------------------------------------------------

  String get fullName {
    final parts = [firstName, lastName].where((s) => s != null && s.isNotEmpty);
    return parts.join(' ');
  }

  double get totalDonatedAll =>
      (totalDonatedMoyd ?? 0.0) + (totalDonatedPolitical ?? 0.0);

  int get totalDonationCount =>
      (donationCountMoyd ?? 0) + (donationCountPolitical ?? 0);

  /// Compares giving in the last 12 months to the prior 12 months.
  /// Returns percentage change, or null if there is no prior-period giving.
  double? get donationTrend {
    final now = DateTime.now();
    final twelveMonthsAgo = DateTime(now.year - 1, now.month, now.day);
    final twentyFourMonthsAgo = DateTime(now.year - 2, now.month, now.day);

    double recent = 0;
    double prior = 0;

    for (final d in donations) {
      final date = d.date;
      final amount = d.amount;
      if (date == null || amount == null) continue;
      if (date.isAfter(twelveMonthsAgo)) {
        recent += amount;
      } else if (date.isAfter(twentyFourMonthsAgo)) {
        prior += amount;
      }
    }

    if (prior == 0) return null;
    return ((recent - prior) / prior) * 100.0;
  }

  /// Gave in the prior calendar year but not in the current calendar year.
  bool get isLybunt {
    final currentYear = DateTime.now().year;
    final priorYear = currentYear - 1;

    bool gaveCurrentYear = false;
    bool gavePriorYear = false;

    for (final d in donations) {
      final year = d.date?.year;
      if (year == null) continue;
      if (year == currentYear) gaveCurrentYear = true;
      if (year == priorYear) gavePriorYear = true;
    }

    return gavePriorYear && !gaveCurrentYear;
  }

  /// Gave some prior year but not last year and not this year.
  bool get isSybunt {
    final currentYear = DateTime.now().year;
    final priorYear = currentYear - 1;

    bool gaveCurrentYear = false;
    bool gavePriorYear = false;
    bool gaveAnyEarlier = false;

    for (final d in donations) {
      final year = d.date?.year;
      if (year == null) continue;
      if (year == currentYear) gaveCurrentYear = true;
      if (year == priorYear) gavePriorYear = true;
      if (year < priorYear) gaveAnyEarlier = true;
    }

    return gaveAnyEarlier && !gavePriorYear && !gaveCurrentYear;
  }

  int? get daysSinceLastGift {
    if (lastDonationDate == null) return null;
    return DateTime.now().difference(lastDonationDate!).inDays;
  }

  /// Suggested ask amount: max of (giving_capacity * 10%, average_gift * 1.2)
  /// rounded to the nearest $25.
  double get suggestedAskAmount {
    final capacityBased = (givingCapacity ?? 0.0) * 0.1;
    final avgBased = (averageGift ?? 0.0) * 1.2;
    final raw = capacityBased > avgBased ? capacityBased : avgBased;
    if (raw <= 0) return 25.0;
    return (raw / 25.0).round() * 25.0;
  }

  /// Percentage of enrichment fields that are non-null (0.0 to 1.0).
  double get enrichmentCompleteness {
    if (enrichmentData == null) return 0.0;
    return enrichmentData!.populatedFieldCount / EnrichmentData.totalFieldCount;
  }

  String get tierDisplay {
    if (tier == null || tier!.isEmpty) return 'Unknown';
    return '${tier![0].toUpperCase()}${tier!.substring(1)}';
  }

  Color get tierColor {
    switch (tier) {
      case 'major':
        return const Color(0xFFD4A017); // gold
      case 'mid':
        return const Color(0xFF1E88E5); // blue
      case 'small':
        return const Color(0xFF43A047); // green
      case 'prospect':
        return const Color(0xFF8E24AA); // purple
      case 'lapsed':
        return const Color(0xFFE53935); // red
      default:
        return const Color(0xFF757575); // grey
    }
  }

  String get partyLeanDisplay {
    switch (partyLean) {
      case 'strong_dem':
        return 'Strong Democrat';
      case 'lean_dem':
        return 'Lean Democrat';
      case 'independent':
        return 'Independent';
      case 'lean_rep':
        return 'Lean Republican';
      case 'strong_rep':
        return 'Strong Republican';
      case 'unknown':
        return 'Unknown';
      default:
        return partyLean ?? 'Unknown';
    }
  }

  List<String> get keyBadges {
    final badges = <String>[];
    if (isHomeowner == true) badges.add('Homeowner');
    if (isBusinessOwner == true) badges.add('Business Owner');
    if (isSecFiler == true) badges.add('SEC Filer');
    if (wealthScore != null && wealthScore! >= 80) badges.add('High Wealth');
    if (engagementScore != null && engagementScore! >= 80) {
      badges.add('Highly Engaged');
    }
    if (isLybunt) badges.add('LYBUNT');
    if (isSybunt) badges.add('SYBUNT');
    if (vanVoter != null) badges.add('VAN Match');
    if (enrichmentData != null) badges.add('Enriched');
    return badges;
  }

  /// Yearly giving totals from MOYD donations.
  Map<int, double> get yearlyGivingMoyd {
    final map = <int, double>{};
    for (final d in donations) {
      if (d.source != 'moyd') continue;
      final year = d.date?.year;
      final amount = d.amount;
      if (year == null || amount == null) continue;
      map[year] = (map[year] ?? 0.0) + amount;
    }
    return map;
  }

  /// Yearly giving totals from MEC contributions.
  Map<int, double> get yearlyGivingPolitical {
    final map = <int, double>{};
    for (final c in mecContributions) {
      final year = c.date?.year;
      final amount = c.amount;
      if (year == null || amount == null) continue;
      map[year] = (map[year] ?? 0.0) + amount;
    }
    return map;
  }

  /// Party distribution by committee name keywords from MEC contributions.
  Map<String, double> get partyDistribution {
    final map = <String, double>{};
    for (final c in mecContributions) {
      final amount = c.amount;
      if (amount == null) continue;
      final name = (c.committeeName ?? '').toLowerCase();
      String party;
      if (name.contains('democrat') ||
          name.contains('dem ') ||
          name.contains('democratic')) {
        party = 'Democrat';
      } else if (name.contains('republican') ||
          name.contains('gop') ||
          name.contains('rep ')) {
        party = 'Republican';
      } else {
        party = 'Other';
      }
      map[party] = (map[party] ?? 0.0) + amount;
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }
}

// ---------------------------------------------------------------------------
// DonorProfileSearchResult
// ---------------------------------------------------------------------------

class DonorProfileSearchResult {
  final String? id;
  final String? donorId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? city;
  final String? county;
  final String? tier;
  final String? partyLean;
  final double? totalDonatedMoyd;
  final double? totalDonatedPolitical;
  final int? wealthScore;
  final int? engagementScore;
  final DateTime? lastDonationDate;

  const DonorProfileSearchResult({
    this.id,
    this.donorId,
    this.firstName,
    this.lastName,
    this.email,
    this.city,
    this.county,
    this.tier,
    this.partyLean,
    this.totalDonatedMoyd,
    this.totalDonatedPolitical,
    this.wealthScore,
    this.engagementScore,
    this.lastDonationDate,
  });

  factory DonorProfileSearchResult.fromJson(Map<String, dynamic> json) {
    return DonorProfileSearchResult(
      id: json['id'] as String?,
      donorId: json['donor_id'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      tier: json['tier'] as String?,
      partyLean: json['party_lean'] as String?,
      totalDonatedMoyd: (json['total_donated_moyd'] as num?)?.toDouble(),
      totalDonatedPolitical:
          (json['total_donated_political'] as num?)?.toDouble(),
      wealthScore: (json['wealth_score'] as num?)?.toInt(),
      engagementScore: (json['engagement_score'] as num?)?.toInt(),
      lastDonationDate: DonorProfile._parseDate(json['last_donation_date']),
    );
  }

  String get fullName {
    final parts = [firstName, lastName].where((s) => s != null && s.isNotEmpty);
    return parts.join(' ');
  }
}

// ---------------------------------------------------------------------------
// DonorProfileStats
// ---------------------------------------------------------------------------

class DonorProfileStats {
  final int? totalProfiles;
  final double? totalRaisedMoyd;
  final double? totalRaisedPolitical;
  final double? averageGift;
  final int? prospectCount;

  const DonorProfileStats({
    this.totalProfiles,
    this.totalRaisedMoyd,
    this.totalRaisedPolitical,
    this.averageGift,
    this.prospectCount,
  });

  /// Returns an empty stats object with all fields null.
  factory DonorProfileStats.empty() => const DonorProfileStats();

  factory DonorProfileStats.fromJson(Map<String, dynamic> json) {
    return DonorProfileStats(
      totalProfiles: (json['total_profiles'] as num?)?.toInt(),
      totalRaisedMoyd: (json['total_raised_moyd'] as num?)?.toDouble(),
      totalRaisedPolitical:
          (json['total_raised_political'] as num?)?.toDouble(),
      averageGift: (json['average_gift'] as num?)?.toDouble(),
      prospectCount: (json['prospect_count'] as num?)?.toInt(),
    );
  }
}
