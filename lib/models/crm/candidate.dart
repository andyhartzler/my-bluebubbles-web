/// Candidate model — maps to Supabase `listmonk.candidates` table
class Candidate {
  final String id;
  final String name;
  final String office;
  final String party;
  final String? address;
  final String? filingDate;
  final String? filingTime;
  final String? district;
  final String? officeLevel;
  final int youngDemScore;
  final int? estimatedAge;
  final bool isYoungDem;
  final String? voterMatchId;
  final int? mecDonorId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? campaignWebsite;
  final String? socialTwitter;
  final String? socialInstagram;
  final String? socialFacebook;
  final String? socialLinkedin;
  final String? ballotpediaUrl;
  final String? photoUrl;
  final String? occupation;
  final String? education;
  final String? bio;
  final String? campaignIssues;
  final String? endorsements;

  const Candidate({
    required this.id,
    required this.name,
    required this.office,
    required this.party,
    this.address,
    this.filingDate,
    this.filingTime,
    this.district,
    this.officeLevel,
    this.youngDemScore = 0,
    this.estimatedAge,
    this.isYoungDem = false,
    this.voterMatchId,
    this.mecDonorId,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.campaignWebsite,
    this.socialTwitter,
    this.socialInstagram,
    this.socialFacebook,
    this.socialLinkedin,
    this.ballotpediaUrl,
    this.photoUrl,
    this.occupation,
    this.education,
    this.bio,
    this.campaignIssues,
    this.endorsements,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      office: json['office'] as String? ?? '',
      party: json['party'] as String? ?? '',
      address: json['address'] as String?,
      filingDate: json['filing_date'] as String?,
      filingTime: json['filing_time'] as String?,
      district: json['district'] as String?,
      officeLevel: json['office_level'] as String?,
      youngDemScore: (json['young_dem_score'] as num?)?.toInt() ?? 0,
      estimatedAge: (json['estimated_age'] as num?)?.toInt(),
      isYoungDem: json['is_young_dem'] as bool? ?? false,
      voterMatchId: json['voter_match_id'] as String?,
      mecDonorId: (json['mec_donor_id'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      campaignWebsite: json['campaign_website'] as String?,
      socialTwitter: json['social_twitter'] as String?,
      socialInstagram: json['social_instagram'] as String?,
      socialFacebook: json['social_facebook'] as String?,
      socialLinkedin: json['social_linkedin'] as String?,
      ballotpediaUrl: json['ballotpedia_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      occupation: json['occupation'] as String?,
      education: json['education'] as String?,
      bio: json['bio'] as String?,
      campaignIssues: json['campaign_issues'] as String?,
      endorsements: json['endorsements'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'office': office,
        'party': party,
        'address': address,
        'filing_date': filingDate,
        'filing_time': filingTime,
        'district': district,
        'office_level': officeLevel,
        'young_dem_score': youngDemScore,
        'estimated_age': estimatedAge,
        'is_young_dem': isYoungDem,
        'voter_match_id': voterMatchId,
        'mec_donor_id': mecDonorId,
        'notes': notes,
        'campaign_website': campaignWebsite,
        'social_twitter': socialTwitter,
        'social_instagram': socialInstagram,
        'social_facebook': socialFacebook,
        'social_linkedin': socialLinkedin,
        'ballotpedia_url': ballotpediaUrl,
        'photo_url': photoUrl,
        'occupation': occupation,
        'education': education,
        'bio': bio,
        'campaign_issues': campaignIssues,
        'endorsements': endorsements,
      };

  /// Short party label for badges
  String get partyShort {
    switch (party.toLowerCase()) {
      case 'democratic':
        return 'D';
      case 'republican':
        return 'R';
      case 'libertarian':
        return 'L';
      default:
        return party.isNotEmpty ? party[0] : '?';
    }
  }

  /// Whether this candidate is a Democrat
  bool get isDemocrat => party.toLowerCase() == 'democratic';

  /// Whether this candidate is a Republican
  bool get isRepublican => party.toLowerCase() == 'republican';

  /// Display string for office + district
  String get officeDisplay {
    if (district != null && district!.isNotEmpty) {
      return '$office — District $district';
    }
    return office;
  }

  /// Initials for avatar fallback
  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  /// Whether this candidate has any social media links
  bool get hasSocialLinks =>
      (socialTwitter?.isNotEmpty ?? false) ||
      (socialInstagram?.isNotEmpty ?? false) ||
      (socialFacebook?.isNotEmpty ?? false) ||
      (socialLinkedin?.isNotEmpty ?? false) ||
      (campaignWebsite?.isNotEmpty ?? false);
}
