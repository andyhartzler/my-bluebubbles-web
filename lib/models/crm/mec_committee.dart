/// MecCommittee model - maps to Supabase 'public.mec_committees' table
/// Missouri Ethics Commission committee records
class MecCommittee {
  final int id;
  final String? mecId;
  final String? committeeName;
  final String? committeeType;
  final String? committeeStatus;
  final DateTime? terminatedDate;
  final String? committeeAddress;
  final String? committeePhone;
  final String? candidateName;
  final String? candidateAddress;
  final String? candidatePhone;
  final String? partyAffiliation;
  final String? treasurerName;
  final String? treasurerAddress;
  final String? treasurerPhone;
  final dynamic electionHistory;
  final DateTime? scrapedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MecCommittee({
    required this.id,
    this.mecId,
    this.committeeName,
    this.committeeType,
    this.committeeStatus,
    this.terminatedDate,
    this.committeeAddress,
    this.committeePhone,
    this.candidateName,
    this.candidateAddress,
    this.candidatePhone,
    this.partyAffiliation,
    this.treasurerName,
    this.treasurerAddress,
    this.treasurerPhone,
    this.electionHistory,
    this.scrapedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory MecCommittee.fromJson(Map<String, dynamic> json) {
    return MecCommittee(
      id: json['id'] as int,
      mecId: json['mec_id'] as String?,
      committeeName: json['committee_name'] as String?,
      committeeType: json['committee_type'] as String?,
      committeeStatus: json['committee_status'] as String?,
      terminatedDate: _parseDate(json['terminated_date']),
      committeeAddress: json['committee_address'] as String?,
      committeePhone: json['committee_phone'] as String?,
      candidateName: json['candidate_name'] as String?,
      candidateAddress: json['candidate_address'] as String?,
      candidatePhone: json['candidate_phone'] as String?,
      partyAffiliation: json['party_affiliation'] as String?,
      treasurerName: json['treasurer_name'] as String?,
      treasurerAddress: json['treasurer_address'] as String?,
      treasurerPhone: json['treasurer_phone'] as String?,
      electionHistory: json['election_history'],
      scrapedAt: _parseDate(json['scraped_at']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  bool get isDemocrat {
    final party = partyAffiliation?.trim().toLowerCase() ?? '';
    return party == 'democrat' || party == 'democratic' || party == 'dem';
  }

  bool get isRepublican {
    final party = partyAffiliation?.trim().toLowerCase() ?? '';
    return party == 'republican' || party == 'rep' || party == 'gop';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
