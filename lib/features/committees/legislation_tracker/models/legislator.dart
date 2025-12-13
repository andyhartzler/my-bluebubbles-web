import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model representing a Missouri state legislator
class Legislator {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Identifiers
  final String? openstatesPersonId;

  // Name fields
  final String name;
  final String? firstName;
  final String? lastName;
  final String? suffix;
  final String? nickname;

  // Position
  final String chamber; // 'upper' (Senate) or 'lower' (House)
  final String district;
  final String? party;
  final String? title;
  final String? divisionId;
  final String? leadershipRole;

  // Photos
  final String? photoUrl;
  final String? photoStoragePath;

  // Contact - Capitol
  final String? capitolAddress;
  final String? capitolPhone;
  final String? capitolEmail;
  final String? officeHours;

  // Contact - District
  final String? districtAddress;
  final String? districtPhone;

  // Web & Social
  final String? websiteUrl;
  final String? legislatureUrl;
  final String? legislatureMemberId;
  final String? twitter;
  final String? facebook;
  final String? instagram;

  // Biography
  final String? biography;

  // Term Info
  final int? firstElectedYear;
  final DateTime? termStartDate;
  final DateTime? termEndDate;
  final bool isCurrent;

  // Bill Counts
  final int billsSponsoredCount;
  final int billsCosponsoredCount;

  // Metadata
  final DateTime? lastScrapedAt;
  final String? scrapeError;
  final Map<String, dynamic>? extras;

  Legislator({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.openstatesPersonId,
    required this.name,
    this.firstName,
    this.lastName,
    this.suffix,
    this.nickname,
    required this.chamber,
    required this.district,
    this.party,
    this.title,
    this.divisionId,
    this.leadershipRole,
    this.photoUrl,
    this.photoStoragePath,
    this.capitolAddress,
    this.capitolPhone,
    this.capitolEmail,
    this.officeHours,
    this.districtAddress,
    this.districtPhone,
    this.websiteUrl,
    this.legislatureUrl,
    this.legislatureMemberId,
    this.twitter,
    this.facebook,
    this.instagram,
    this.biography,
    this.firstElectedYear,
    this.termStartDate,
    this.termEndDate,
    this.isCurrent = true,
    this.billsSponsoredCount = 0,
    this.billsCosponsoredCount = 0,
    this.lastScrapedAt,
    this.scrapeError,
    this.extras,
  });

  factory Legislator.fromJson(Map<String, dynamic> json) {
    return Legislator(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      openstatesPersonId: json['openstates_person_id'] as String?,
      name: json['name'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      suffix: json['suffix'] as String?,
      nickname: json['nickname'] as String?,
      chamber: json['chamber'] as String,
      district: json['district'] as String,
      party: json['party'] as String?,
      title: json['title'] as String?,
      divisionId: json['division_id'] as String?,
      leadershipRole: json['leadership_role'] as String?,
      photoUrl: json['photo_url'] as String?,
      photoStoragePath: json['photo_storage_path'] as String?,
      capitolAddress: json['capitol_address'] as String?,
      capitolPhone: json['capitol_phone'] as String?,
      capitolEmail: json['capitol_email'] as String?,
      officeHours: json['office_hours'] as String?,
      districtAddress: json['district_address'] as String?,
      districtPhone: json['district_phone'] as String?,
      websiteUrl: json['website_url'] as String?,
      legislatureUrl: json['legislature_url'] as String?,
      legislatureMemberId: json['legislature_member_id'] as String?,
      twitter: json['twitter'] as String?,
      facebook: json['facebook'] as String?,
      instagram: json['instagram'] as String?,
      biography: json['biography'] as String?,
      firstElectedYear: json['first_elected_year'] as int?,
      termStartDate: json['term_start_date'] != null
          ? DateTime.parse(json['term_start_date'] as String)
          : null,
      termEndDate: json['term_end_date'] != null
          ? DateTime.parse(json['term_end_date'] as String)
          : null,
      isCurrent: json['is_current'] as bool? ?? true,
      billsSponsoredCount: json['bills_sponsored_count'] as int? ?? 0,
      billsCosponsoredCount: json['bills_cosponsored_count'] as int? ?? 0,
      lastScrapedAt: json['last_scraped_at'] != null
          ? DateTime.parse(json['last_scraped_at'] as String)
          : null,
      scrapeError: json['scrape_error'] as String?,
      extras: json['extras'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'openstates_person_id': openstatesPersonId,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'suffix': suffix,
      'nickname': nickname,
      'chamber': chamber,
      'district': district,
      'party': party,
      'title': title,
      'division_id': divisionId,
      'leadership_role': leadershipRole,
      'photo_url': photoUrl,
      'photo_storage_path': photoStoragePath,
      'capitol_address': capitolAddress,
      'capitol_phone': capitolPhone,
      'capitol_email': capitolEmail,
      'office_hours': officeHours,
      'district_address': districtAddress,
      'district_phone': districtPhone,
      'website_url': websiteUrl,
      'legislature_url': legislatureUrl,
      'legislature_member_id': legislatureMemberId,
      'twitter': twitter,
      'facebook': facebook,
      'instagram': instagram,
      'biography': biography,
      'first_elected_year': firstElectedYear,
      'term_start_date': termStartDate?.toIso8601String(),
      'term_end_date': termEndDate?.toIso8601String(),
      'is_current': isCurrent,
      'bills_sponsored_count': billsSponsoredCount,
      'bills_cosponsored_count': billsCosponsoredCount,
      'last_scraped_at': lastScrapedAt?.toIso8601String(),
      'scrape_error': scrapeError,
      'extras': extras,
    };
  }

  // Helper getters
  String get displayTitle => chamber == 'upper' ? 'Senator' : 'Representative';
  String get chamberName => chamber == 'upper' ? 'Senate' : 'House';
  String get fullTitle => '$displayTitle $name';

  String get partyAbbr {
    switch (party) {
      case 'Republican':
        return 'R';
      case 'Democratic':
        return 'D';
      default:
        return '?';
    }
  }

  Color get partyColor {
    switch (party) {
      case 'Republican':
        return const Color(0xFFEF4444);
      case 'Democratic':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get districtLabel => '$chamberName District $district';

  // Extras getters
  String? get room => extras?['room'] as String?;
  String? get gender => extras?['gender'] as String?;
  String? get homeTown => extras?['homeTown'] as String?;

  /// Get the public URL for the legislator's photo from Supabase storage
  String? getPhotoPublicUrl() {
    if (photoStoragePath == null) return null;
    try {
      return Supabase.instance.client.storage
          .from('legislator-photos')
          .getPublicUrl(photoStoragePath!);
    } catch (e) {
      return null;
    }
  }

  /// Get initials for avatar fallback
  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (name.contains(' ')) {
      final parts = name.split(' ');
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Legislator copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? openstatesPersonId,
    String? name,
    String? firstName,
    String? lastName,
    String? suffix,
    String? nickname,
    String? chamber,
    String? district,
    String? party,
    String? title,
    String? divisionId,
    String? leadershipRole,
    String? photoUrl,
    String? photoStoragePath,
    String? capitolAddress,
    String? capitolPhone,
    String? capitolEmail,
    String? officeHours,
    String? districtAddress,
    String? districtPhone,
    String? websiteUrl,
    String? legislatureUrl,
    String? legislatureMemberId,
    String? twitter,
    String? facebook,
    String? instagram,
    String? biography,
    int? firstElectedYear,
    DateTime? termStartDate,
    DateTime? termEndDate,
    bool? isCurrent,
    int? billsSponsoredCount,
    int? billsCosponsoredCount,
    DateTime? lastScrapedAt,
    String? scrapeError,
    Map<String, dynamic>? extras,
  }) {
    return Legislator(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openstatesPersonId: openstatesPersonId ?? this.openstatesPersonId,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      nickname: nickname ?? this.nickname,
      chamber: chamber ?? this.chamber,
      district: district ?? this.district,
      party: party ?? this.party,
      title: title ?? this.title,
      divisionId: divisionId ?? this.divisionId,
      leadershipRole: leadershipRole ?? this.leadershipRole,
      photoUrl: photoUrl ?? this.photoUrl,
      photoStoragePath: photoStoragePath ?? this.photoStoragePath,
      capitolAddress: capitolAddress ?? this.capitolAddress,
      capitolPhone: capitolPhone ?? this.capitolPhone,
      capitolEmail: capitolEmail ?? this.capitolEmail,
      officeHours: officeHours ?? this.officeHours,
      districtAddress: districtAddress ?? this.districtAddress,
      districtPhone: districtPhone ?? this.districtPhone,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      legislatureUrl: legislatureUrl ?? this.legislatureUrl,
      legislatureMemberId: legislatureMemberId ?? this.legislatureMemberId,
      twitter: twitter ?? this.twitter,
      facebook: facebook ?? this.facebook,
      instagram: instagram ?? this.instagram,
      biography: biography ?? this.biography,
      firstElectedYear: firstElectedYear ?? this.firstElectedYear,
      termStartDate: termStartDate ?? this.termStartDate,
      termEndDate: termEndDate ?? this.termEndDate,
      isCurrent: isCurrent ?? this.isCurrent,
      billsSponsoredCount: billsSponsoredCount ?? this.billsSponsoredCount,
      billsCosponsoredCount: billsCosponsoredCount ?? this.billsCosponsoredCount,
      lastScrapedAt: lastScrapedAt ?? this.lastScrapedAt,
      scrapeError: scrapeError ?? this.scrapeError,
      extras: extras ?? this.extras,
    );
  }
}
