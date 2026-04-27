import 'package:flutter/material.dart';

/// Candidate model — maps to Supabase `public.candidates` table
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
  final String? moVoterFileId;
  final int? birthYear;
  final String? dobSource;
  final num? matchConfidence;
  final String? matchMethod;
  final int? mecDonorId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? campaignWebsite;
  final String? socialTwitter;
  final String? socialInstagram;
  final String? socialFacebook;
  final String? socialLinkedin;
  final String? socialTiktok;
  final String? ballotpediaUrl;
  final String? photoUrl;
  final String? occupation;
  final String? education;
  final String? bio;
  final String? campaignIssues;
  final String? endorsements;
  final String? email;
  final String? phone;
  final String? fecCandidateId;
  final List<String> mecCommitteeIds;
  final bool isEndorsed;
  final bool isContacted;
  final String? assignedTo;
  final String? endorsementStatus;
  final DateTime? lastContactDate;
  final String? contactMethod;

  // Member + DOB linkage
  final String? memberId;
  final DateTime? dateOfBirth;

  // Location + demographics (round-trip through the form edit dialog)
  final String? city;
  final String? stateCode;
  final String? zip;
  final String? county;
  final String? gender;

  // True if the candidate is currently holding this exact seat — drives the
  // INCUMBENT badge and the "Running for re-election" language on the hero.
  final bool isIncumbent;

  // Link to public.legislation_legislators (only populated for incumbents
  // of MO state House/Senate). Makes it possible to pull capitol contact,
  // bio, official portrait, etc. straight from the legislator record.
  final String? legislatorId;

  // Score breakdown fields
  final int scoreParty;
  final int scorePrimary;
  final int scoreContributions;
  final int scoreVan;
  final int scoreEndorsements;

  // ── Embedded join data (populated via fetchCandidate's PostgREST embed) ──
  // These are NOT persisted on `public.candidates`. They carry the joined
  // legislator + member rows so the UI can render avatars, member status, and
  // assignee photos without firing a second round-trip.
  final String? legislatorPhotoUrl;
  final Map<String, dynamic>? assignedMember; // members row when moyd_assigned_to is set
  final Map<String, dynamic>? linkedMember;   // members row when member_id is set

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
    this.moVoterFileId,
    this.birthYear,
    this.dobSource,
    this.matchConfidence,
    this.matchMethod,
    this.mecDonorId,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.campaignWebsite,
    this.socialTwitter,
    this.socialInstagram,
    this.socialFacebook,
    this.socialLinkedin,
    this.socialTiktok,
    this.ballotpediaUrl,
    this.photoUrl,
    this.occupation,
    this.education,
    this.bio,
    this.campaignIssues,
    this.endorsements,
    this.email,
    this.phone,
    this.fecCandidateId,
    this.mecCommitteeIds = const [],
    this.isEndorsed = false,
    this.isContacted = false,
    this.assignedTo,
    this.endorsementStatus,
    this.lastContactDate,
    this.contactMethod,
    this.memberId,
    this.dateOfBirth,
    this.city,
    this.stateCode,
    this.zip,
    this.county,
    this.gender,
    this.isIncumbent = false,
    this.legislatorId,
    this.scoreParty = 0,
    this.scorePrimary = 0,
    this.scoreContributions = 0,
    this.scoreVan = 0,
    this.scoreEndorsements = 0,
    this.legislatorPhotoUrl,
    this.assignedMember,
    this.linkedMember,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    // Hard rule: age 37+ is NEVER a Young Democrat, regardless of what
    // is_young_dem says in the DB. The imputed-age + is_young_dem pipeline
    // has been known to disagree (see: April 2026 backfill) so we enforce the
    // ceiling client-side as defense in depth.
    final age = (json['estimated_age'] as num?)?.toInt();
    final rawIsYoungDem = json['is_young_dem'] as bool? ?? false;
    final isYoungDem = rawIsYoungDem && (age == null || age <= 36);

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
      estimatedAge: age,
      isYoungDem: isYoungDem,
      moVoterFileId: json['mo_voter_file_id'] as String?,
      birthYear: (json['birth_year'] as num?)?.toInt(),
      dobSource: json['dob_source'] as String?,
      matchConfidence: json['match_confidence'] as num?,
      matchMethod: json['match_method'] as String?,
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
      socialTiktok: json['social_tiktok'] as String?,
      ballotpediaUrl: json['ballotpedia_url'] as String?,
      photoUrl: json['photo_url'] as String?,
      occupation: json['occupation'] as String?,
      education: json['education'] as String?,
      bio: json['bio'] as String?,
      campaignIssues: json['campaign_issues'] as String?,
      endorsements: json['endorsements'] as String?,
      email: json['campaign_email'] as String?,
      phone: json['campaign_phone'] as String?,
      fecCandidateId: json['fec_candidate_id'] as String?,
      mecCommitteeIds: (json['mec_committee_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isEndorsed: json['moyd_endorsed'] as bool? ?? false,
      isContacted: json['moyd_contacted'] as bool? ?? false,
      assignedTo: json['moyd_assigned_to'] as String?,
      endorsementStatus: json['moyd_endorsement_status'] as String?,
      lastContactDate: json['moyd_contact_date'] != null
          ? DateTime.tryParse(json['moyd_contact_date'] as String)
          : null,
      contactMethod: json['moyd_contact_method'] as String?,
      memberId: json['member_id'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      city: json['city'] as String?,
      stateCode: json['state'] as String?,
      zip: json['zip'] as String?,
      county: json['county'] as String?,
      gender: json['gender'] as String?,
      isIncumbent: json['incumbent'] as bool? ?? false,
      legislatorId: json['legislator_id'] as String?,
      scoreParty: (json['score_party'] as num?)?.toInt() ?? 0,
      scorePrimary: (json['score_primary_history'] as num?)?.toInt() ?? 0,
      scoreContributions: (json['score_contributions'] as num?)?.toInt() ?? 0,
      scoreVan: (json['score_van'] as num?)?.toInt() ?? 0,
      scoreEndorsements: (json['score_endorsements'] as num?)?.toInt() ?? 0,
      legislatorPhotoUrl: _embeddedString(json['legislator'], 'photo_url'),
      assignedMember: _embeddedMap(json['assigned_member']),
      linkedMember: _embeddedMap(json['linked_member']),
    );
  }

  /// Pulls a nested PostgREST-embedded scalar (e.g. legislator.photo_url).
  /// PostgREST returns either a Map (one-to-one) or a List (one-to-many);
  /// candidates ↔ legislators is a 1:1 FK so we expect a Map, but tolerate
  /// the list form for defensive parsing.
  static String? _embeddedString(dynamic node, String field) {
    if (node is Map && node[field] is String && (node[field] as String).isNotEmpty) {
      return node[field] as String;
    }
    if (node is List && node.isNotEmpty && node.first is Map) {
      final value = (node.first as Map)[field];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  static Map<String, dynamic>? _embeddedMap(dynamic node) {
    if (node is Map<String, dynamic>) return node;
    if (node is Map) return node.map((k, v) => MapEntry(k.toString(), v));
    if (node is List && node.isNotEmpty && node.first is Map) {
      final m = node.first as Map;
      return m.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
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
        'mo_voter_file_id': moVoterFileId,
        'birth_year': birthYear,
        'dob_source': dobSource,
        'match_confidence': matchConfidence,
        'match_method': matchMethod,
        'mec_donor_id': mecDonorId,
        'notes': notes,
        'campaign_website': campaignWebsite,
        'social_twitter': socialTwitter,
        'social_instagram': socialInstagram,
        'social_facebook': socialFacebook,
        'social_linkedin': socialLinkedin,
        'social_tiktok': socialTiktok,
        'ballotpedia_url': ballotpediaUrl,
        'photo_url': photoUrl,
        'occupation': occupation,
        'education': education,
        'bio': bio,
        'campaign_issues': campaignIssues,
        'endorsements': endorsements,
        'campaign_email': email,
        'campaign_phone': phone,
        'fec_candidate_id': fecCandidateId,
        'mec_committee_ids': mecCommitteeIds,
        'moyd_endorsed': isEndorsed,
        'moyd_contacted': isContacted,
        'moyd_assigned_to': assignedTo,
        'moyd_endorsement_status': endorsementStatus,
        'moyd_contact_date': lastContactDate?.toIso8601String(),
        'moyd_contact_method': contactMethod,
        'member_id': memberId,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'city': city,
        'state': stateCode,
        'zip': zip,
        'county': county,
        'gender': gender,
        'incumbent': isIncumbent,
        'legislator_id': legislatorId,
        'score_party': scoreParty,
        'score_primary_history': scorePrimary,
        'score_contributions': scoreContributions,
        'score_van': scoreVan,
        'score_endorsements': scoreEndorsements,
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
      case 'green':
        return 'G';
      case 'constitution':
        return 'C';
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

  /// Compact display for list views
  String get compactOffice {
    if (district != null && district!.isNotEmpty) {
      return 'D-${district}';
    }
    return office.length > 20 ? '${office.substring(0, 18)}…' : office;
  }

  /// Initials for avatar fallback
  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  /// First name only
  String get firstName {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.first : name;
  }

  /// Last name only
  String get lastName {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    return parts.length >= 2 ? parts.last : '';
  }

  /// Best-available photo for this candidate, in priority order:
  ///   1. Uploaded `photoUrl` (candidates.photo_url)
  ///   2. Incumbent legislator headshot (legislation_legislators.photo_url)
  ///   3. Linked MOYD member's primary profile picture
  /// Returns null when nothing usable is available — UI should fall back
  /// to initials.
  String? get effectivePhotoUrl {
    if (photoUrl != null && photoUrl!.isNotEmpty) return photoUrl;
    if (legislatorPhotoUrl != null && legislatorPhotoUrl!.isNotEmpty) {
      return legislatorPhotoUrl;
    }
    final memberUrl = _primaryProfilePictureUrl(linkedMember);
    if (memberUrl != null && memberUrl.isNotEmpty) return memberUrl;
    return null;
  }

  /// Convenience accessor for the avatar URL of the team member assigned
  /// to this candidate (Intel tab → Assigned To card).
  String? get assignedMemberPhotoUrl => _primaryProfilePictureUrl(assignedMember);

  /// Resolves a public URL for the primary photo inside a `members` row
  /// returned by PostgREST. Mirrors the logic in MemberProfilePhoto.parseList:
  /// prefers entries flagged `primary: true`, falls back to the first entry,
  /// and tolerates both list-form and {key: filename} legacy shapes.
  static String? _primaryProfilePictureUrl(Map<String, dynamic>? member) {
    if (member == null) return null;
    final pics = member['profile_pictures'];
    if (pics == null) return null;

    String? buildUrl(String? bucket, String? path) {
      if (path == null || path.isEmpty) return null;
      final b = (bucket == null || bucket.isEmpty) ? 'member-photos' : bucket;
      // If the path already contains a full URL (e.g. legacy avatar_url
      // pasted into profile_pictures), return as-is.
      if (path.startsWith('http')) return path;
      // Strip any accidentally-prefixed `storage/v1/object/public/<bucket>/`.
      var clean = path;
      final marker = 'storage/v1/object/public/$b/';
      if (clean.startsWith(marker)) {
        clean = clean.substring(marker.length);
      }
      return 'https://faajpcarasilbfndzkmd.supabase.co/storage/v1/object/public/$b/$clean';
    }

    if (pics is List) {
      Map? primary;
      for (final entry in pics) {
        if (entry is Map && entry['primary'] == true) {
          primary = entry;
          break;
        }
      }
      primary ??= pics.firstWhere(
        (e) => e is Map,
        orElse: () => null,
      ) as Map?;
      if (primary == null) return null;
      return buildUrl(
        primary['bucket']?.toString(),
        primary['path']?.toString(),
      );
    }

    if (pics is Map) {
      // Legacy {twitter|instagram: filename} shape — pick instagram first.
      for (final key in const ['instagram', 'twitter', 'facebook']) {
        final value = pics[key];
        if (value is String && value.isNotEmpty) {
          return buildUrl('member-photos', value);
        }
      }
    }
    return null;
  }

  /// Whether this candidate has any social media links
  bool get hasSocialLinks =>
      (socialTwitter?.isNotEmpty ?? false) ||
      (socialInstagram?.isNotEmpty ?? false) ||
      (socialFacebook?.isNotEmpty ?? false) ||
      (socialLinkedin?.isNotEmpty ?? false) ||
      (socialTiktok?.isNotEmpty ?? false) ||
      (campaignWebsite?.isNotEmpty ?? false);

  /// Count of social links
  int get socialLinkCount {
    int count = 0;
    if (socialTwitter?.isNotEmpty ?? false) count++;
    if (socialInstagram?.isNotEmpty ?? false) count++;
    if (socialFacebook?.isNotEmpty ?? false) count++;
    if (socialLinkedin?.isNotEmpty ?? false) count++;
    if (socialTiktok?.isNotEmpty ?? false) count++;
    if (campaignWebsite?.isNotEmpty ?? false) count++;
    if (ballotpediaUrl?.isNotEmpty ?? false) count++;
    return count;
  }

  /// Whether this candidate has contact info
  bool get hasContactInfo =>
      (email?.isNotEmpty ?? false) || (phone?.isNotEmpty ?? false);

  /// Whether this candidate has a linked MEC committee
  bool get hasMecFiled => mecCommitteeIds.isNotEmpty;

  /// Whether this candidate has a linked FEC candidate record
  bool get hasFecFiled => fecCandidateId?.isNotEmpty ?? false;

  /// Whether this candidate has campaign finance data
  bool get hasCampaignFinance => hasMecFiled || hasFecFiled || (mecDonorId != null);

  /// Whether this candidate has profile info
  bool get hasProfileInfo =>
      (bio?.isNotEmpty ?? false) ||
      (occupation?.isNotEmpty ?? false) ||
      (education?.isNotEmpty ?? false);

  /// Get campaign issues as a list
  List<String> get campaignIssuesList {
    if (campaignIssues == null || campaignIssues!.isEmpty) return [];
    return campaignIssues!
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Get endorsements as a list
  List<String> get endorsementsList {
    if (endorsements == null || endorsements!.isEmpty) return [];
    return endorsements!
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Age category for display
  String get ageCategory {
    if (estimatedAge == null) return 'Unknown';
    if (estimatedAge! <= 25) return 'Gen Z';
    if (estimatedAge! <= 36) return 'Young Millennial';
    if (estimatedAge! <= 45) return 'Millennial';
    if (estimatedAge! <= 60) return 'Gen X';
    return 'Boomer+';
  }

  /// Copy with modifications
  Candidate copyWith({
    String? id,
    String? name,
    String? office,
    String? party,
    String? address,
    String? filingDate,
    String? filingTime,
    String? district,
    String? officeLevel,
    int? youngDemScore,
    int? estimatedAge,
    bool? isYoungDem,
    String? moVoterFileId,
    int? birthYear,
    String? dobSource,
    num? matchConfidence,
    String? matchMethod,
    int? mecDonorId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? campaignWebsite,
    String? socialTwitter,
    String? socialInstagram,
    String? socialFacebook,
    String? socialLinkedin,
    String? socialTiktok,
    String? ballotpediaUrl,
    String? photoUrl,
    String? occupation,
    String? education,
    String? bio,
    String? campaignIssues,
    String? endorsements,
    String? email,
    String? phone,
    String? fecCandidateId,
    List<String>? mecCommitteeIds,
    bool? isEndorsed,
    bool? isContacted,
    String? assignedTo,
    String? endorsementStatus,
    DateTime? lastContactDate,
    String? contactMethod,
    String? memberId,
    DateTime? dateOfBirth,
    int? scoreParty,
    int? scorePrimary,
    int? scoreContributions,
    int? scoreVan,
    int? scoreEndorsements,
    String? legislatorPhotoUrl,
    Map<String, dynamic>? assignedMember,
    Map<String, dynamic>? linkedMember,
  }) {
    return Candidate(
      id: id ?? this.id,
      name: name ?? this.name,
      office: office ?? this.office,
      party: party ?? this.party,
      address: address ?? this.address,
      filingDate: filingDate ?? this.filingDate,
      filingTime: filingTime ?? this.filingTime,
      district: district ?? this.district,
      officeLevel: officeLevel ?? this.officeLevel,
      youngDemScore: youngDemScore ?? this.youngDemScore,
      estimatedAge: estimatedAge ?? this.estimatedAge,
      isYoungDem: isYoungDem ?? this.isYoungDem,
      moVoterFileId: moVoterFileId ?? this.moVoterFileId,
      birthYear: birthYear ?? this.birthYear,
      dobSource: dobSource ?? this.dobSource,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      matchMethod: matchMethod ?? this.matchMethod,
      mecDonorId: mecDonorId ?? this.mecDonorId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      campaignWebsite: campaignWebsite ?? this.campaignWebsite,
      socialTwitter: socialTwitter ?? this.socialTwitter,
      socialInstagram: socialInstagram ?? this.socialInstagram,
      socialFacebook: socialFacebook ?? this.socialFacebook,
      socialLinkedin: socialLinkedin ?? this.socialLinkedin,
      socialTiktok: socialTiktok ?? this.socialTiktok,
      ballotpediaUrl: ballotpediaUrl ?? this.ballotpediaUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      occupation: occupation ?? this.occupation,
      education: education ?? this.education,
      bio: bio ?? this.bio,
      campaignIssues: campaignIssues ?? this.campaignIssues,
      endorsements: endorsements ?? this.endorsements,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fecCandidateId: fecCandidateId ?? this.fecCandidateId,
      mecCommitteeIds: mecCommitteeIds ?? this.mecCommitteeIds,
      isEndorsed: isEndorsed ?? this.isEndorsed,
      isContacted: isContacted ?? this.isContacted,
      assignedTo: assignedTo ?? this.assignedTo,
      endorsementStatus: endorsementStatus ?? this.endorsementStatus,
      lastContactDate: lastContactDate ?? this.lastContactDate,
      contactMethod: contactMethod ?? this.contactMethod,
      memberId: memberId ?? this.memberId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      scoreParty: scoreParty ?? this.scoreParty,
      scorePrimary: scorePrimary ?? this.scorePrimary,
      scoreContributions: scoreContributions ?? this.scoreContributions,
      scoreVan: scoreVan ?? this.scoreVan,
      scoreEndorsements: scoreEndorsements ?? this.scoreEndorsements,
      legislatorPhotoUrl: legislatorPhotoUrl ?? this.legislatorPhotoUrl,
      assignedMember: assignedMember ?? this.assignedMember,
      linkedMember: linkedMember ?? this.linkedMember,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Candidate && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Candidate($name, $party, $officeDisplay)';
}

/// Contact log entry for a candidate
class CandidateContact {
  final String id;
  final String candidateId;
  final String contactType; // email, phone, in-person, text, social
  final String? subject;
  final String? body;
  final String? contactedBy;
  final DateTime contactDate;
  final String? outcome;
  final String? followUpDate;
  final String? notes;

  const CandidateContact({
    required this.id,
    required this.candidateId,
    required this.contactType,
    this.subject,
    this.body,
    this.contactedBy,
    required this.contactDate,
    this.outcome,
    this.followUpDate,
    this.notes,
  });

  factory CandidateContact.fromJson(Map<String, dynamic> json) {
    return CandidateContact(
      id: json['id'] as String? ?? '',
      candidateId: json['candidate_id'] as String? ?? '',
      contactType: json['contact_type'] as String? ?? 'email',
      subject: json['subject'] as String?,
      body: json['body'] as String?,
      contactedBy: json['contacted_by'] as String?,
      contactDate: DateTime.tryParse(json['contact_date'] as String? ?? '') ??
          DateTime.now(),
      outcome: json['outcome'] as String?,
      followUpDate: json['follow_up_date'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'candidate_id': candidateId,
        'contact_type': contactType,
        'subject': subject,
        'body': body,
        'contacted_by': contactedBy,
        'contact_date': contactDate.toIso8601String(),
        'outcome': outcome,
        'follow_up_date': followUpDate,
        'notes': notes,
      };

  IconData get typeIcon {
    switch (contactType) {
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'in-person':
        return Icons.people;
      case 'text':
        return Icons.message;
      case 'social':
        return Icons.share;
      default:
        return Icons.contact_mail;
    }
  }
}

/// News mention for a candidate
class CandidateNews {
  final String id;
  final String candidateId;
  final String headline;
  final String? source;
  final String? url;
  final String? summary;
  final DateTime? publishedAt;

  // AI-digested fields (populated by the news_digest_gemini.py pipeline)
  final String? aiSummary;         // 1-2 sentence plain-English summary
  final String? sentimentLabel;    // 'positive' | 'neutral' | 'negative' | 'mixed'
  final double? sentimentScore;    // -1.0 to +1.0 wrt this candidate
  final DateTime? validatedAt;     // set when the row passed the relevance check

  const CandidateNews({
    required this.id,
    required this.candidateId,
    required this.headline,
    this.source,
    this.url,
    this.summary,
    this.publishedAt,
    this.aiSummary,
    this.sentimentLabel,
    this.sentimentScore,
    this.validatedAt,
  });

  factory CandidateNews.fromJson(Map<String, dynamic> json) {
    return CandidateNews(
      id: json['id'] as String? ?? '',
      candidateId: json['candidate_id'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      source: json['source'] as String?,
      url: json['url'] as String?,
      summary: json['summary'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      aiSummary: json['ai_summary'] as String?,
      sentimentLabel: json['sentiment_label'] as String?,
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble(),
      validatedAt: json['validated_at'] != null
          ? DateTime.tryParse(json['validated_at'] as String)
          : null,
    );
  }
}

/// Election history entry for a district
class ElectionResult {
  final String id;
  final String district;
  final int year;
  final String? demCandidate;
  final String? repCandidate;
  final int? demVotes;
  final int? repVotes;
  final int? totalVotes;
  final String? winner;
  final double? demPercent;
  final double? repPercent;

  const ElectionResult({
    required this.id,
    required this.district,
    required this.year,
    this.demCandidate,
    this.repCandidate,
    this.demVotes,
    this.repVotes,
    this.totalVotes,
    this.winner,
    this.demPercent,
    this.repPercent,
  });

  factory ElectionResult.fromJson(Map<String, dynamic> json) {
    return ElectionResult(
      id: json['id'] as String? ?? '',
      district: json['district'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      demCandidate: json['dem_candidate'] as String?,
      repCandidate: json['rep_candidate'] as String?,
      demVotes: (json['dem_votes'] as num?)?.toInt(),
      repVotes: (json['rep_votes'] as num?)?.toInt(),
      totalVotes: (json['total_votes'] as num?)?.toInt(),
      winner: json['winner'] as String?,
      demPercent: (json['dem_percent'] as num?)?.toDouble(),
      repPercent: (json['rep_percent'] as num?)?.toDouble(),
    );
  }

  bool get demWon => winner?.toLowerCase() == 'democratic' || winner?.toLowerCase() == 'democrat';
  bool get repWon => winner?.toLowerCase() == 'republican';
}

/// FEC finance summary for a candidate
class CandidateFinance {
  final String candidateId;
  final String? fecId;
  final double totalRaised;
  final double totalSpent;
  final double cashOnHand;
  final double totalDebt;
  final int contributorCount;
  final double avgContribution;
  final double pacContributions;
  final double individualContributions;
  final String? lastUpdated;

  const CandidateFinance({
    required this.candidateId,
    this.fecId,
    this.totalRaised = 0,
    this.totalSpent = 0,
    this.cashOnHand = 0,
    this.totalDebt = 0,
    this.contributorCount = 0,
    this.avgContribution = 0,
    this.pacContributions = 0,
    this.individualContributions = 0,
    this.lastUpdated,
  });

  factory CandidateFinance.fromJson(Map<String, dynamic> json) {
    return CandidateFinance(
      candidateId: json['candidate_id'] as String? ?? '',
      fecId: json['fec_id'] as String?,
      totalRaised: (json['total_raised'] as num?)?.toDouble() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      cashOnHand: (json['cash_on_hand'] as num?)?.toDouble() ?? 0,
      totalDebt: (json['total_debt'] as num?)?.toDouble() ?? 0,
      contributorCount: (json['contributor_count'] as num?)?.toInt() ?? 0,
      avgContribution: (json['avg_contribution'] as num?)?.toDouble() ?? 0,
      pacContributions: (json['pac_contributions'] as num?)?.toDouble() ?? 0,
      individualContributions:
          (json['individual_contributions'] as num?)?.toDouble() ?? 0,
      lastUpdated: json['last_updated'] as String?,
    );
  }
}

/// MEC (Missouri Ethics Commission) contribution record
class MECContribution {
  final String? id;
  final String mecId;
  final int? donorId;
  final String? contributorLastName;
  final String? contributorFirstName;
  final double contributionAmount;
  final String? contributionDate;
  final String? contributionType;
  final String? contributorEmployer;
  final String? contributorOccupation;
  final String? contributorAddress;
  final String? contributorCity;
  final String? contributorState;

  const MECContribution({
    this.id,
    required this.mecId,
    this.donorId,
    this.contributorLastName,
    this.contributorFirstName,
    this.contributionAmount = 0,
    this.contributionDate,
    this.contributionType,
    this.contributorEmployer,
    this.contributorOccupation,
    this.contributorAddress,
    this.contributorCity,
    this.contributorState,
  });

  factory MECContribution.fromJson(Map<String, dynamic> json) {
    return MECContribution(
      id: json['id']?.toString(),
      mecId: json['mec_id'] as String? ?? '',
      donorId: (json['donor_id'] as num?)?.toInt(),
      contributorLastName: json['contributor_last_name'] as String?,
      contributorFirstName: json['contributor_first_name'] as String?,
      contributionAmount: (json['contribution_amount'] as num?)?.toDouble() ?? 0,
      contributionDate: json['contribution_date'] as String?,
      contributionType: json['contribution_type'] as String?,
      contributorEmployer: (json['employer'] ?? json['contributor_employer']) as String?,
      contributorOccupation: (json['occupation'] ?? json['contributor_occupation']) as String?,
      contributorAddress: (json['address1'] ?? json['contributor_address']) as String?,
      contributorCity: (json['city'] ?? json['contributor_city']) as String?,
      contributorState: (json['state'] ?? json['contributor_state']) as String?,
    );
  }

  String get donorName {
    final first = contributorFirstName ?? '';
    final last = contributorLastName ?? '';
    return '$first $last'.trim();
  }

  String get donorLocation {
    final city = contributorCity ?? '';
    final state = contributorState ?? '';
    if (city.isEmpty && state.isEmpty) return '';
    return '$city, $state'.trim();
  }
}

/// District demographics data
class DistrictDemographics {
  final String district;
  final int? totalPopulation;
  final int? registeredVoters;
  final int? registeredDem;
  final int? registeredRep;
  final int? registeredOther;
  final double? medianAge;
  final double? medianIncome;
  final double? collegePercent;
  final double? diversityIndex;
  final String? urbanRural; // urban, suburban, rural, mixed

  const DistrictDemographics({
    required this.district,
    this.totalPopulation,
    this.registeredVoters,
    this.registeredDem,
    this.registeredRep,
    this.registeredOther,
    this.medianAge,
    this.medianIncome,
    this.collegePercent,
    this.diversityIndex,
    this.urbanRural,
  });

  factory DistrictDemographics.fromJson(Map<String, dynamic> json) {
    return DistrictDemographics(
      district: json['district'] as String? ?? '',
      totalPopulation: (json['total_population'] as num?)?.toInt(),
      registeredVoters: (json['registered_voters'] as num?)?.toInt(),
      registeredDem: (json['registered_dem'] as num?)?.toInt(),
      registeredRep: (json['registered_rep'] as num?)?.toInt(),
      registeredOther: (json['registered_other'] as num?)?.toInt(),
      medianAge: (json['median_age'] as num?)?.toDouble(),
      medianIncome: (json['median_income'] as num?)?.toDouble(),
      collegePercent: (json['college_percent'] as num?)?.toDouble(),
      diversityIndex: (json['diversity_index'] as num?)?.toDouble(),
      urbanRural: json['urban_rural'] as String?,
    );
  }

  double get demRegistrationPercent {
    if (registeredVoters == null || registeredVoters == 0 || registeredDem == null) return 0;
    return (registeredDem! / registeredVoters!) * 100;
  }

  double get repRegistrationPercent {
    if (registeredVoters == null || registeredVoters == 0 || registeredRep == null) return 0;
    return (registeredRep! / registeredVoters!) * 100;
  }
}
