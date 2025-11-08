import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:bluebubbles/config/crm_config.dart';

/// Member model - maps to Supabase 'members' table
/// This is a separate model from BlueBubbles Contact/Handle
class Member {
  final String id;
  final DateTime? createdAt;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneE164; // KEY FIELD - links to Handle.address
  final DateTime? dateOfBirth;
  final String? preferredPronouns;
  final String? genderIdentity;
  final String? address;
  final String? city;
  final String? state;
  final String? county;
  final String? congressionalDistrict;
  final String? race;
  final String? sexualOrientation;
  final String? desireToLead;
  final String? hoursPerWeek;
  final String? educationLevel;
  final bool? registeredVoter;
  final String? inSchool;
  final String? schoolName;
  final String? highSchool;
  final String? college;
  final String? schoolEmail;
  final String? employed;
  final String? industry;
  final bool? hispanicLatino;
  final String? accommodations;
  final String? communityType;
  final String? languages;
  final String? whyJoin;
  final DateTime? lastContacted;
  final bool optOut;
  final List<String>? committee;
  final String? notes;
  final DateTime? introSentAt;
  final String? optOutReason;
  final DateTime? optOutDate;
  final DateTime? optInDate;
  final String? disability;
  final String? politicalExperience;
  final String? currentInvolvement;
  final String? religion;
  final String? instagram;
  final String? tiktok;
  final String? x;
  final String? zodiacSign;
  final String? leadershipExperience;
  final DateTime? dateJoined;
  final String? goalsAndAmbitions;
  final String? qualifiedExperience;
  final String? referralSource;
  final String? passionateIssues;
  final String? whyIssuesMatter;
  final String? areasOfInterest;
  final bool executiveCommittee;
  final String? executiveTitle;
  final String? executiveRole;
  final String? executiveRoleShort;
  final String? currentChapterMember;
  final String? chapterName;
  final String? graduationYear;
  final String? chapterPosition;
  final DateTime? dateElected;
  final DateTime? termExpiration;
  final List<MemberProfilePhoto> profilePhotos;
  final MemberInternalInfo internalInfo;

  Member({
    required this.id,
    this.createdAt,
    required this.name,
    this.email,
    this.phone,
    this.phoneE164,
    this.dateOfBirth,
    this.preferredPronouns,
    this.genderIdentity,
    this.address,
    this.city,
    this.state,
    this.county,
    this.congressionalDistrict,
    this.race,
    this.sexualOrientation,
    this.desireToLead,
    this.hoursPerWeek,
    this.educationLevel,
    this.registeredVoter,
    this.inSchool,
    this.schoolName,
    this.highSchool,
    this.college,
    this.schoolEmail,
    this.employed,
    this.industry,
    this.hispanicLatino,
    this.accommodations,
    this.communityType,
    this.languages,
    this.whyJoin,
    this.lastContacted,
    this.optOut = false,
    this.committee,
    this.notes,
    this.introSentAt,
    this.optOutReason,
    this.optOutDate,
    this.optInDate,
    this.disability,
    this.politicalExperience,
    this.currentInvolvement,
    this.religion,
    this.instagram,
    this.tiktok,
    this.x,
    this.zodiacSign,
    this.leadershipExperience,
    this.dateJoined,
    this.goalsAndAmbitions,
    this.qualifiedExperience,
    this.referralSource,
    this.passionateIssues,
    this.whyIssuesMatter,
    this.areasOfInterest,
    this.executiveCommittee = false,
    this.executiveTitle,
    this.executiveRole,
    this.executiveRoleShort,
    this.currentChapterMember,
    this.chapterName,
    this.graduationYear,
    this.chapterPosition,
    this.dateElected,
    this.termExpiration,
    List<MemberProfilePhoto> profilePhotos = const [],
    MemberInternalInfo internalInfo = MemberInternalInfo.empty,
  }) : profilePhotos = List<MemberProfilePhoto>.unmodifiable(profilePhotos),
       internalInfo = internalInfo;

  /// Helper used to normalize free-form Supabase fields that may be stored as
  /// raw strings, JSON objects, or Airtable-style maps.
  static String? normalizeText(dynamic value) => _normalizeText(value);

  /// Helper specifically for congressional district strings which may include
  /// prefixes such as "District" or embedded JSON blobs from Airtable exports.
  static String? normalizeDistrict(dynamic value) {
    final normalized = _normalizeText(value);
    if (normalized == null || normalized.isEmpty) return null;

    final withoutPrefix =
        normalized.replaceFirst(RegExp(r'^District\s+', caseSensitive: false), '').trim();
    if (withoutPrefix.isEmpty) return null;

    final secondPass = _normalizeText(withoutPrefix) ?? withoutPrefix;
    return _formatDistrictString(secondPass);
  }

  /// Format a district value for display, ensuring we only show a single CD-
  /// prefix when the value is numeric.
  static String? formatDistrictLabel(String? value) {
    if (value == null) return null;
    return _formatDistrictString(value);
  }

  /// Helper used to normalize lists of free-form values.
  static List<String> normalizeTextList(dynamic value) => _normalizeTextList(value);

  static String? _normalizeText(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      final startsWithBrace = trimmed.startsWith('{') || trimmed.startsWith('[');
      final endsWithBrace = trimmed.endsWith('}') || trimmed.endsWith(']');
      if (startsWithBrace && endsWithBrace) {
        try {
          final decoded = jsonDecode(trimmed);
          return _normalizeText(decoded);
        } catch (_) {
          final fallback = _extractCommonValue(trimmed);
          return fallback ?? trimmed;
        }
      }

      final fallback = _extractCommonValue(trimmed);
      return fallback ?? trimmed;
    }

    if (value is Map) {
      const preferredKeys = ['name', 'value', 'label', 'title', 'text'];
      for (final key in preferredKeys) {
        if (value.containsKey(key)) {
          final result = _normalizeText(value[key]);
          if (result != null && result.isNotEmpty) {
            return result;
          }
        }
      }

      for (final entry in value.entries) {
        final result = _normalizeText(entry.value);
        if (result != null && result.isNotEmpty) {
          return result;
        }
      }

      return null;
    }

    if (value is Iterable) {
      for (final element in value) {
        final result = _normalizeText(element);
        if (result != null && result.isNotEmpty) {
          return result;
        }
      }
      return null;
    }

    final stringValue = value.toString().trim();
    if (stringValue.isEmpty) return null;

    final fallback = _extractCommonValue(stringValue);
    return fallback ?? stringValue;
  }

  /// Normalize a list of free-form Supabase values to readable strings.
  static List<String> _normalizeTextList(dynamic value) {
    final normalized = <String>{};
    if (value is Iterable) {
      for (final element in value) {
        final result = _normalizeText(element);
        if (result != null && result.isNotEmpty) {
          normalized.add(result);
        }
      }
    } else {
      final result = _normalizeText(value);
      if (result != null && result.isNotEmpty) {
        normalized.add(result);
      }
    }
    return normalized.toList();
  }

  static bool? _normalizeBool(dynamic value) => coerceBool(value);

  /// Coerce a dynamic value into a nullable boolean, handling common truthy
  /// and falsy string/number representations used across Supabase imports.
  static bool? coerceBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      const truthy = {'true', 't', '1', 'yes', 'y'};
      const falsy = {'false', 'f', '0', 'no', 'n'};
      if (truthy.contains(normalized)) return true;
      if (falsy.contains(normalized)) return false;
    }
    return null;
  }


  /// Attempt to pull a human readable value out of loosely formatted JSON blobs.
  static String? _extractCommonValue(String source) {
    const fallbackKeys = ['name', 'value', 'label', 'title', 'text'];
    for (final key in fallbackKeys) {
      try {
        final escapedKey = RegExp.escape(key);
        final pattern = RegExp('"$escapedKey"\\s*:\s*"([^"]+)"');
        final match = pattern.firstMatch(source);
        if (match != null) {
          final extracted = match.group(1)?.trim();
          if (extracted != null && extracted.isNotEmpty) {
            return extracted;
          }
        }
      } catch (_) {
        continue;
      }
    }

    final cdMatch = RegExp(r'CD[-\s]?(\d+)', caseSensitive: false).firstMatch(source);
    if (cdMatch != null) {
      return 'CD-${cdMatch.group(1)}';
    }

    return null;
  }

  static String? _formatDistrictString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final upper = trimmed.toUpperCase();
    final collapsed = upper.replaceFirst(RegExp(r'^(?:CD[-\s]*)+'), 'CD-');

    final directMatch = RegExp(r'^CD-(\d+)$').firstMatch(collapsed);
    if (directMatch != null) {
      return 'CD-${directMatch.group(1)}';
    }

    final digitsOnly = RegExp(r'^(\d+)$').firstMatch(trimmed);
    if (digitsOnly != null) {
      return 'CD-${digitsOnly.group(1)}';
    }

    final embeddedCd = RegExp(r'(?:CD|DISTRICT)[-\s]*(\d+)', caseSensitive: false).firstMatch(trimmed);
    if (embeddedCd != null) {
      return 'CD-${embeddedCd.group(1)}';
    }

    return trimmed;
  }

  /// Create Member from Supabase JSON response
  factory Member.fromJson(Map<String, dynamic> json) {
    final committeeValues = _normalizeTextList(json['committee']);
    final committees = committeeValues.isEmpty ? null : committeeValues;

    return Member(
      id: json['id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      name: _normalizeText(json['name']) ?? (json['name'] as String),
      email: _normalizeText(json['email']),
      phone: _normalizeText(json['phone']),
      phoneE164: _normalizeText(json['phone_e164']),
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      preferredPronouns: _normalizeText(json['preferred_pronouns']),
      genderIdentity: _normalizeText(json['gender_identity']),
      address: _normalizeText(json['address']),
      city: _normalizeText(json['city'] ?? json['address_city']),
      state: _normalizeText(json['state'] ?? json['address_state']),
      county: _normalizeText(json['county']),
      congressionalDistrict: normalizeDistrict(json['congressional_district']),
      race: _normalizeText(json['race']),
      sexualOrientation: _normalizeText(json['sexual_orientation']),
      desireToLead: _normalizeText(json['desire_to_lead']),
      hoursPerWeek: _normalizeText(json['hours_per_week']),
      educationLevel: _normalizeText(json['education_level']),
      registeredVoter: json['registered_voter'] as bool?,
      inSchool: _normalizeText(json['in_school']),
      schoolName: _normalizeText(json['school_name']),
      highSchool: _normalizeText(json['high_school']),
      college: _normalizeText(json['college']),
      employed: _normalizeText(json['employed']),
      industry: _normalizeText(json['industry']),
      hispanicLatino: json['hispanic_latino'] as bool?,
      accommodations: _normalizeText(json['accommodations']),
      communityType: _normalizeText(json['community_type']),
      languages: _normalizeText(json['languages']),
      whyJoin: _normalizeText(json['why_join']),
      lastContacted: json['last_contacted'] != null
          ? DateTime.parse(json['last_contacted'] as String)
          : null,
      optOut: json['opt_out'] as bool? ?? false,
      committee: committees,
      notes: _normalizeText(json['notes']),
      introSentAt: json['intro_sent_at'] != null
          ? DateTime.parse(json['intro_sent_at'] as String)
          : null,
      optOutReason: _normalizeText(json['opt_out_reason']),
      optOutDate: json['opt_out_date'] != null
          ? DateTime.parse(json['opt_out_date'] as String)
          : null,
      optInDate: json['opt_in_date'] != null
          ? DateTime.parse(json['opt_in_date'] as String)
          : null,
      disability: _normalizeText(json['disability']),
      politicalExperience: _normalizeText(json['political_experience']),
      currentInvolvement: _normalizeText(json['current_involvement']),
      religion: _normalizeText(json['religion']),
      instagram: _normalizeText(json['instagram']),
      tiktok: _normalizeText(json['tiktok']),
      x: _normalizeText(json['x']),
      zodiacSign: _normalizeText(json['zodiac_sign']),
      leadershipExperience: _normalizeText(json['leadership_experience']),
      dateJoined: json['date_joined'] != null
          ? DateTime.parse(json['date_joined'] as String)
          : null,
      goalsAndAmbitions: _normalizeText(json['goals_and_ambitions']),
      qualifiedExperience: _normalizeText(json['qualified_experience']),
      referralSource: _normalizeText(json['referral_source']),
      passionateIssues: _normalizeText(json['passionate_issues']),
      whyIssuesMatter: _normalizeText(json['why_issues_matter']),
      areasOfInterest: _normalizeText(json['areas_of_interest']),
      executiveCommittee: _normalizeBool(json['executive_committee']) ?? false,
      executiveTitle: _normalizeText(json['executive_title']),
      executiveRole: _normalizeText(json['executive_role']),
      executiveRoleShort:
          _normalizeText(json['executive_role_short'] ?? json['executive_role_small']),
      currentChapterMember: _normalizeText(json['current_chapter_member']),
      chapterName: _normalizeText(json['chapter_name']),
      graduationYear: _normalizeText(json['graduation_year']),
      schoolEmail: _normalizeText(json['school_email']),
      chapterPosition: _normalizeText(json['chapter_position']),
      dateElected: json['date_elected'] != null
          ? DateTime.tryParse(json['date_elected'] as String)
          : null,
      termExpiration: json['term_expiration'] != null
          ? DateTime.tryParse(json['term_expiration'] as String)
          : null,
      profilePhotos: MemberProfilePhoto.parseList(json['profile_pictures']),
      internalInfo: MemberInternalInfo.fromJson(json['internal_member_info']),
    );
  }

  /// Convert to JSON for Supabase updates
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'name': name,
      'email': email,
      'phone': phone,
      'phone_e164': phoneE164,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'preferred_pronouns': preferredPronouns,
      'gender_identity': genderIdentity,
      'address': address,
      'city': city,
      'state': state,
      'county': county,
      'congressional_district': congressionalDistrict,
      'race': race,
      'sexual_orientation': sexualOrientation,
      'desire_to_lead': desireToLead,
      'hours_per_week': hoursPerWeek,
      'education_level': educationLevel,
      'registered_voter': registeredVoter,
      'in_school': inSchool,
      'school_name': schoolName,
      'high_school': highSchool,
      'college': college,
      'school_email': schoolEmail,
      'employed': employed,
      'industry': industry,
      'hispanic_latino': hispanicLatino,
      'accommodations': accommodations,
      'community_type': communityType,
      'languages': languages,
      'why_join': whyJoin,
      'last_contacted': lastContacted?.toIso8601String(),
      'opt_out': optOut,
      'committee': committee,
      'notes': notes,
      'intro_sent_at': introSentAt?.toIso8601String(),
      'opt_out_reason': optOutReason,
      'opt_out_date': optOutDate?.toIso8601String(),
      'opt_in_date': optInDate?.toIso8601String(),
      'disability': disability,
      'political_experience': politicalExperience,
      'current_involvement': currentInvolvement,
      'religion': religion,
      'instagram': instagram,
      'tiktok': tiktok,
      'x': x,
      'zodiac_sign': zodiacSign,
      'leadership_experience': leadershipExperience,
      'date_joined': dateJoined?.toIso8601String().split('T').first,
      'goals_and_ambitions': goalsAndAmbitions,
      'qualified_experience': qualifiedExperience,
      'referral_source': referralSource,
      'passionate_issues': passionateIssues,
      'why_issues_matter': whyIssuesMatter,
      'areas_of_interest': areasOfInterest,
      'executive_committee': executiveCommittee,
      'executive_title': executiveTitle,
      'executive_role': executiveRole,
      'executive_role_short': executiveRoleShort,
      'current_chapter_member': currentChapterMember,
      'chapter_name': chapterName,
      'graduation_year': graduationYear,
      'chapter_position': chapterPosition,
      'date_elected': dateElected?.toIso8601String().split('T').first,
      'term_expiration': termExpiration?.toIso8601String().split('T').first,
      'profile_pictures': profilePhotos.map((photo) => photo.toJson()).toList(),
      'internal_member_info': internalInfo.toJson(),
    };
  }

  /// Helper: Get age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  /// Helper: Check if member can be contacted
  bool get canContact => !optOut && phoneE164 != null && phoneE164!.isNotEmpty;

  /// Helper: Format committees as string
  String get committeesString => committee?.join(', ') ?? 'None';

  /// Whether the member has at least one stored profile photo reference.
  bool get hasProfilePhoto => profilePhotos.isNotEmpty;

  /// Convenience getter for executive flag used by downstream UI.
  bool get isExecutive => executiveCommittee;

  /// Whether we have any structured internal information available.
  bool get hasInternalMemberInfo => internalInfo.isNotEmpty;

  /// Best-effort public URL for the member's primary profile photo.
  String? get primaryProfilePhotoUrl {
    final primary = profilePhotos.firstWhereOrNull((photo) => photo.isPrimary) ??
        profilePhotos.firstOrNull;
    return primary?.publicUrl;
  }

  /// Preferred school/education label prioritizing dedicated columns.
  String? get primarySchool => college ?? highSchool ?? schoolName;

  /// Copy with method for updates
  Member copyWith({
    String? id,
    DateTime? createdAt,
    String? name,
    String? email,
    String? phone,
    String? phoneE164,
    DateTime? dateOfBirth,
    String? preferredPronouns,
    String? genderIdentity,
    String? address,
    String? county,
    String? city,
    String? state,
    String? congressionalDistrict,
    String? race,
    String? sexualOrientation,
    String? desireToLead,
    String? hoursPerWeek,
    String? educationLevel,
    bool? registeredVoter,
    String? inSchool,
    String? schoolName,
    String? highSchool,
    String? college,
    String? employed,
    String? industry,
    bool? hispanicLatino,
    String? accommodations,
    String? communityType,
    String? languages,
    String? whyJoin,
    DateTime? lastContacted,
    bool? optOut,
    List<String>? committee,
    String? notes,
    DateTime? introSentAt,
    String? optOutReason,
    DateTime? optOutDate,
    DateTime? optInDate,
    String? disability,
    String? politicalExperience,
    String? currentInvolvement,
    String? religion,
    String? instagram,
    String? tiktok,
    String? x,
    String? zodiacSign,
    String? leadershipExperience,
    DateTime? dateJoined,
    String? goalsAndAmbitions,
    String? qualifiedExperience,
    String? referralSource,
    String? passionateIssues,
    String? whyIssuesMatter,
    String? areasOfInterest,
    bool? executiveCommittee,
    String? executiveTitle,
    String? executiveRole,
    String? executiveRoleShort,
    String? currentChapterMember,
    String? chapterName,
    String? graduationYear,
    String? schoolEmail,
    String? chapterPosition,
    DateTime? dateElected,
    DateTime? termExpiration,
    List<MemberProfilePhoto>? profilePhotos,
    MemberInternalInfo? internalInfo,
  }) {
    return Member(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneE164: phoneE164 ?? this.phoneE164,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredPronouns: preferredPronouns ?? this.preferredPronouns,
      genderIdentity: genderIdentity ?? this.genderIdentity,
      address: address ?? this.address,
      county: county ?? this.county,
      city: city ?? this.city,
      state: state ?? this.state,
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      race: race ?? this.race,
      sexualOrientation: sexualOrientation ?? this.sexualOrientation,
      desireToLead: desireToLead ?? this.desireToLead,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      educationLevel: educationLevel ?? this.educationLevel,
      registeredVoter: registeredVoter ?? this.registeredVoter,
      inSchool: inSchool ?? this.inSchool,
      schoolName: schoolName ?? this.schoolName,
      highSchool: highSchool ?? this.highSchool,
      college: college ?? this.college,
      schoolEmail: schoolEmail ?? this.schoolEmail,
      employed: employed ?? this.employed,
      industry: industry ?? this.industry,
      hispanicLatino: hispanicLatino ?? this.hispanicLatino,
      accommodations: accommodations ?? this.accommodations,
      communityType: communityType ?? this.communityType,
      languages: languages ?? this.languages,
      whyJoin: whyJoin ?? this.whyJoin,
      lastContacted: lastContacted ?? this.lastContacted,
      optOut: optOut ?? this.optOut,
      committee: committee ?? this.committee,
      notes: notes ?? this.notes,
      introSentAt: introSentAt ?? this.introSentAt,
      optOutReason: optOutReason ?? this.optOutReason,
      optOutDate: optOutDate ?? this.optOutDate,
      optInDate: optInDate ?? this.optInDate,
      disability: disability ?? this.disability,
      politicalExperience: politicalExperience ?? this.politicalExperience,
      currentInvolvement: currentInvolvement ?? this.currentInvolvement,
      religion: religion ?? this.religion,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      x: x ?? this.x,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      leadershipExperience: leadershipExperience ?? this.leadershipExperience,
      dateJoined: dateJoined ?? this.dateJoined,
      goalsAndAmbitions: goalsAndAmbitions ?? this.goalsAndAmbitions,
      qualifiedExperience: qualifiedExperience ?? this.qualifiedExperience,
      referralSource: referralSource ?? this.referralSource,
      passionateIssues: passionateIssues ?? this.passionateIssues,
      whyIssuesMatter: whyIssuesMatter ?? this.whyIssuesMatter,
      areasOfInterest: areasOfInterest ?? this.areasOfInterest,
      executiveCommittee: executiveCommittee ?? this.executiveCommittee,
      executiveTitle: executiveTitle ?? this.executiveTitle,
      executiveRole: executiveRole ?? this.executiveRole,
      executiveRoleShort: executiveRoleShort ?? this.executiveRoleShort,
      currentChapterMember: currentChapterMember ?? this.currentChapterMember,
      chapterName: chapterName ?? this.chapterName,
      graduationYear: graduationYear ?? this.graduationYear,
      chapterPosition: chapterPosition ?? this.chapterPosition,
      dateElected: dateElected ?? this.dateElected,
      termExpiration: termExpiration ?? this.termExpiration,
      profilePhotos: profilePhotos ?? this.profilePhotos,
      internalInfo: internalInfo ?? this.internalInfo,
    );
  }

  /// Convenience accessor to prefer personal email while falling back to school email.
  String? get preferredEmail => email ?? schoolEmail;

  /// Shortened executive role display preferring the compact label when available.
  String? get executiveRoleDisplay => executiveRoleShort ?? executiveRole;

  /// Best effort phone display choosing formatted phone first then E.164 value.
  String? get primaryPhone {
    if (phone != null && phone!.trim().isNotEmpty) {
      return phone;
    }

    if (phoneE164 != null && phoneE164!.trim().isNotEmpty) {
      return phoneE164;
    }

    return null;
  }
}


class MemberInternalInfo {
  static const MemberInternalInfo empty = MemberInternalInfo._const();

  final Map<String, dynamic> _data;
  final List<MemberInternalReportEntry> reports;
  final bool _includeReportsKey;

  const MemberInternalInfo._const()
      : _data = const {},
        reports = const [],
        _includeReportsKey = false;

  const factory MemberInternalInfo() = MemberInternalInfo._const;

  MemberInternalInfo._({
    Map<String, dynamic> data = const {},
    List<MemberInternalReportEntry> reports = const [],
    bool includeReportsKey = false,
  })  : _data = Map<String, dynamic>.unmodifiable(data),
        reports = List<MemberInternalReportEntry>.unmodifiable(reports),
        _includeReportsKey = includeReportsKey;

  bool get hasReports => reports.isNotEmpty;

  bool get isEmpty => _data.isEmpty && !hasReports;

  bool get isNotEmpty => !isEmpty;

  MemberInternalInfo copyWith({List<MemberInternalReportEntry>? reports}) {
    final newReports = reports ?? this.reports;
    return MemberInternalInfo._(
      data: _data,
      reports: newReports,
      includeReportsKey: _includeReportsKey || reports != null,
    );
  }

  factory MemberInternalInfo.fromJson(dynamic raw) {
    return tryParse(raw) ?? MemberInternalInfo.empty;
  }

  static MemberInternalInfo? tryParse(dynamic raw) {
    final parsed = _ParsedInternalInfo.tryParse(raw);
    if (parsed == null) return null;
    return MemberInternalInfo._(
      data: parsed.data,
      reports: parsed.reports,
      includeReportsKey: parsed.includeReportsKey,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{..._data};
    if (_includeReportsKey || reports.isNotEmpty) {
      json['reports'] = reports.map((entry) => entry.toJson()).toList();
    }
    return json;
  }

  dynamic operator [](String key) => _data[key];

  static dynamic _normalizeValue(dynamic value) {
    if (value == null) return null;

    if (value is bool || value is num) return value;

    if (value is DateTime) return value.toIso8601String();

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final boolCandidate = Member.coerceBool(trimmed);
      if (boolCandidate != null) return boolCandidate;
      final normalized = Member._normalizeText(trimmed);
      return normalized ?? trimmed;
    }

    if (value is Map) {
      final nested = <String, dynamic>{};
      value.forEach((key, nestedValue) {
        final keyString = key.toString().trim();
        if (keyString.isEmpty) return;
        final normalizedNested = _normalizeValue(nestedValue);
        if (normalizedNested != null) {
          nested[keyString] = normalizedNested;
        }
      });
      return nested.isEmpty ? null : nested;
    }

    if (value is Iterable) {
      final list = value
          .map(_normalizeValue)
          .where((element) => element != null)
          .cast<dynamic>()
          .toList();
      return list.isEmpty ? null : list;
    }

    final normalized = Member._normalizeText(value);
    return normalized ?? value.toString();
  }

  static bool _looksLikeReportsKey(String key) {
    final normalized = key.trim().toLowerCase();
    return const {
      'reports',
      'report',
      'report_entries',
      'reportentries',
      'entries',
      'items',
      'data',
    }.contains(normalized);
  }

  static List<MemberInternalReportEntry> _parseReports(dynamic value) {
    if (value == null) {
      return const [];
    }

    if (value is MemberInternalInfo) {
      return value.reports;
    }

    if (value is MemberInternalReportEntry) {
      return [value];
    }

    if (value is Iterable) {
      final entries = <MemberInternalReportEntry>[];
      for (final item in value) {
        try {
          entries.add(MemberInternalReportEntry.fromJson(item));
        } catch (_) {}
      }
      return entries;
    }

    if (value is Map) {
      final normalizedMap =
          value.map((key, val) => MapEntry(key.toString(), val));
      for (final key in const ['reports', 'entries', 'items', 'data']) {
        if (normalizedMap.containsKey(key)) {
          final nested = _parseReports(normalizedMap[key]);
          if (nested.isNotEmpty || normalizedMap[key] != null) {
            return nested;
          }
        }
      }

      try {
        return [MemberInternalReportEntry.fromJson(normalizedMap)];
      } catch (_) {}

      final firstIterable =
          normalizedMap.values.whereType<Iterable>().firstOrNull;
      if (firstIterable != null) {
        return _parseReports(firstIterable);
      }

      return const [];
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return const [];
      }
      try {
        final decoded = jsonDecode(trimmed);
        final parsed = _parseReports(decoded);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (_) {}
      try {
        return [MemberInternalReportEntry.fromJson(trimmed)];
      } catch (_) {
        return const [];
      }
    }

    try {
      return [MemberInternalReportEntry.fromJson(value)];
    } catch (_) {
      return const [];
    }
  }
}

class _ParsedInternalInfo {
  _ParsedInternalInfo({
    required this.data,
    required this.reports,
    required this.includeReportsKey,
  });

  final Map<String, dynamic> data;
  final List<MemberInternalReportEntry> reports;
  final bool includeReportsKey;

  static _ParsedInternalInfo? tryParse(dynamic raw) {
    if (raw == null) return null;

    if (raw is MemberInternalInfo) {
      return _ParsedInternalInfo(
        data: raw._data,
        reports: raw.reports,
        includeReportsKey: raw._includeReportsKey,
      );
    }

    if (raw is Map) {
      if (raw.isEmpty) return null;

      final normalized = <String, dynamic>{};
      var reports = <MemberInternalReportEntry>[];
      var includeReportsKey = false;

      raw.forEach((key, value) {
        final keyString = key.toString().trim();
        if (keyString.isEmpty) return;

        if (MemberInternalInfo._looksLikeReportsKey(keyString)) {
          includeReportsKey = true;
          reports = MemberInternalInfo._parseReports(value);
          return;
        }

        final normalizedValue = MemberInternalInfo._normalizeValue(value);
        if (normalizedValue != null) {
          normalized[keyString] = normalizedValue;
        }
      });

      if (normalized.isEmpty && reports.isEmpty && !includeReportsKey) {
        return null;
      }

      return _ParsedInternalInfo(
        data: normalized,
        reports: reports,
        includeReportsKey: includeReportsKey || reports.isNotEmpty,
      );
    }

    if (raw is Iterable) {
      final parsedReports = MemberInternalInfo._parseReports(raw);
      if (parsedReports.isNotEmpty || raw.isEmpty) {
        return _ParsedInternalInfo(
          data: const {},
          reports: parsedReports,
          includeReportsKey: true,
        );
      }

      final list = raw
          .map(MemberInternalInfo._normalizeValue)
          .where((element) => element != null)
          .cast<dynamic>()
          .toList();
      if (list.isEmpty) return null;
      return _ParsedInternalInfo(
        data: {'items': list},
        reports: const [],
        includeReportsKey: false,
      );
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      try {
        final decoded = jsonDecode(trimmed);
        final parsed = tryParse(decoded);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {}

      final normalizedValue = MemberInternalInfo._normalizeValue(trimmed);
      if (normalizedValue == null) return null;

      return _ParsedInternalInfo(
        data: {'value': normalizedValue},
        reports: const [],
        includeReportsKey: false,
      );
    }

    final normalizedValue = MemberInternalInfo._normalizeValue(raw);
    if (normalizedValue == null) return null;

    return _ParsedInternalInfo(
      data: {'value': normalizedValue},
      reports: const [],
      includeReportsKey: false,
    );
  }
}

class MemberProfilePhoto {
  MemberProfilePhoto({
    required this.path,
    this.bucket = _defaultBucket,
    this.filename,
    this.uploadedAt,
    this.isPrimary = false,
    this.metadata,
  });

  static const String _defaultBucket = 'member-photos';

  final String path;
  final String bucket;
  final String? filename;
  final DateTime? uploadedAt;
  final bool isPrimary;
  final Map<String, dynamic>? metadata;

  static List<MemberProfilePhoto> parseList(dynamic raw) {
    if (raw == null) return const [];

    final pending = <dynamic>[raw];
    final photos = <MemberProfilePhoto>[];

    while (pending.isNotEmpty) {
      final current = pending.removeAt(0);
      if (current == null) continue;

      if (current is String) {
        final trimmed = current.trim();
        if (trimmed.isEmpty) continue;

        try {
          final decoded = jsonDecode(trimmed);
          pending.add(decoded);
          continue;
        } catch (_) {
          try {
            photos.add(MemberProfilePhoto.fromJson(trimmed));
          } catch (_) {}
          continue;
        }
      }

      if (current is List) {
        for (final item in current) {
          pending.add(item);
        }
        continue;
      }

      if (current is Map) {
        final normalizedMap =
            current.map((key, value) => MapEntry(key.toString(), value));

        if (_looksLikePhotoEntry(normalizedMap)) {
          try {
            photos.add(MemberProfilePhoto.fromJson(normalizedMap));
          } catch (_) {}
          continue;
        }

        final inferredStrings = <MapEntry<String, String>>[];
        for (final entry in normalizedMap.entries) {
          if (entry.value is! String) continue;
          final coerced = _coerceString(entry.value);
          if (coerced != null && coerced.isNotEmpty) {
            inferredStrings.add(MapEntry(entry.key, coerced));
          }
        }

        for (final entry in inferredStrings) {
          final normalized =
              _normalizePath(entry.value, bucket: _defaultBucket);
          if (normalized == null) continue;

          final metadata = entry.key.isEmpty
              ? null
              : <String, dynamic>{'source': entry.key};
          photos.add(
            MemberProfilePhoto(
              path: normalized.toString(),
              bucket: _defaultBucket,
              metadata: metadata,
            ),
          );
        }

        bool pushedNested = false;
        for (final nestedKey in const [
          'data',
          'items',
          'list',
          'results',
          'entries',
          'photos',
          'profile_pictures',
          'profilePhotos',
          'objects',
          'files',
        ]) {
          if (normalizedMap.containsKey(nestedKey)) {
            pending.add(normalizedMap[nestedKey]);
            pushedNested = true;
          }
        }

        if (!pushedNested) {
          for (final value in normalizedMap.values) {
            if (value is Map || value is List) {
              pending.add(value);
            }
          }
        }

        continue;
      }

      try {
        photos.add(MemberProfilePhoto.fromJson(current));
      } catch (_) {}
    }

    if (photos.isEmpty) return const [];

    if (!photos.any((photo) => photo.isPrimary)) {
      photos[0] = photos.first.copyWith(isPrimary: true);
    }

    return List<MemberProfilePhoto>.unmodifiable(photos);
  }

  factory MemberProfilePhoto.fromJson(dynamic raw) {
    if (raw == null) {
      throw const FormatException('Cannot parse null profile photo');
    }

    if (raw is String) {
      return MemberProfilePhoto(path: raw);
    }

    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));

      final String? publicUrlValue =
          _coerceString(map['publicUrl'] ?? map['public_url']);

      String? bucketValue = _coerceString(
        map['bucket'] ??
            map['bucket_id'] ??
            map['bucketId'] ??
            map['bucket_name'] ??
            map['bucketName'],
      );

      if ((bucketValue == null || bucketValue.isEmpty) && publicUrlValue != null) {
        bucketValue = _inferBucketFromPath(publicUrlValue);
      }

      final String resolvedBucket =
          bucketValue == null || bucketValue.isEmpty ? _defaultBucket : bucketValue;

      String? rawPath = _coerceString(
        map['storage_path'] ??
            map['path'] ??
            map['file_path'] ??
            map['url'] ??
            map['public_path'] ??
            map['publicPath'],
      );

      rawPath ??= publicUrlValue;

      final String? inferredNameRaw = _coerceString(
        map['filename'] ??
            map['file_name'] ??
            map['fileName'] ??
            map['name'] ??
            map['full_path'] ??
            map['fullPath'],
      );
      final String? inferredName =
          inferredNameRaw == null ? null : _sanitizeObjectName(inferredNameRaw, resolvedBucket);

      if (rawPath == null || rawPath.trim().isEmpty) {
        if (inferredName != null && inferredName.isNotEmpty) {
          rawPath = 'storage/v1/object/public/$resolvedBucket/$inferredName';
        } else if (publicUrlValue != null && publicUrlValue.isNotEmpty) {
          rawPath = publicUrlValue;
        }
      }

      final Uri? normalizedUri =
          rawPath == null ? null : _normalizePath(rawPath, bucket: resolvedBucket);
      if (normalizedUri == null) {
        throw const FormatException('Missing profile photo path');
      }

      return MemberProfilePhoto(
        path: normalizedUri.toString(),
        bucket: resolvedBucket,
        filename: inferredName?.isNotEmpty == true ? inferredName : null,
        uploadedAt: _coerceDate(map['uploaded_at'] ?? map['created_at']),
        isPrimary: map['primary'] == true || map['is_primary'] == true,
        metadata: map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : null,
      );
    }

    throw FormatException('Unsupported profile photo payload: ${raw.runtimeType}');
  }

  MemberProfilePhoto copyWith({
    String? path,
    String? bucket,
    String? filename,
    DateTime? uploadedAt,
    bool? isPrimary,
    Map<String, dynamic>? metadata,
  }) {
    return MemberProfilePhoto(
      path: path ?? this.path,
      bucket: bucket ?? this.bucket,
      filename: filename ?? this.filename,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isPrimary: isPrimary ?? this.isPrimary,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bucket': bucket,
      'path': path,
      if (filename != null) 'filename': filename,
      if (uploadedAt != null) 'uploaded_at': uploadedAt!.toIso8601String(),
      'primary': isPrimary,
      if (metadata != null) 'metadata': metadata,
    };
  }

  String? get publicUrl {
    final normalized = _normalizePath(path, bucket: bucket);
    if (normalized == null) return null;

    if (normalized.hasScheme) {
      return normalized.toString();
    }

    final supabaseUrl = CRMConfig.supabaseUrl;
    final normalizedPath = normalized.path.startsWith('/')
        ? normalized.path
        : '/${normalized.path}';
    final query = normalized.hasQuery ? normalized.query : null;
    final fragment = normalized.fragment.isEmpty ? null : normalized.fragment;
    final normalizedBase = query == null ? normalizedPath : '$normalizedPath?$query';
    final normalizedString =
        fragment == null ? normalizedBase : '$normalizedBase#$fragment';

    if (supabaseUrl.isEmpty) {
      return normalizedString;
    }

    final baseUri = Uri.tryParse(supabaseUrl);
    if (baseUri == null || baseUri.host.isEmpty) {
      return normalizedString;
    }

    final origin = Uri(
      scheme: baseUri.scheme.isEmpty ? 'https' : baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
    );

    final resolved = origin.replace(
      path: normalizedPath,
      query: query,
      fragment: fragment,
    );

    return resolved.toString();
  }

  static Uri? _normalizePath(String path, {required String bucket}) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }

    final sanitizedBucket = bucket.isEmpty ? _defaultBucket : bucket;

    String normalizedPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;

    const storagePrefix = 'storage/v1/object/';
    if (normalizedPath.startsWith(storagePrefix)) {
      normalizedPath = normalizedPath.substring(storagePrefix.length);
      if (normalizedPath.startsWith('/')) {
        normalizedPath = normalizedPath.substring(1);
      }
    }

    final publicBucketPrefix = 'public/$sanitizedBucket/';
    if (normalizedPath == 'public/$sanitizedBucket') {
      normalizedPath = '';
    } else if (normalizedPath.startsWith(publicBucketPrefix)) {
      normalizedPath = normalizedPath.substring(publicBucketPrefix.length);
    } else {
      final bucketPrefix = '$sanitizedBucket/';
      if (normalizedPath == sanitizedBucket) {
        normalizedPath = '';
      } else if (normalizedPath.startsWith(bucketPrefix)) {
        normalizedPath = normalizedPath.substring(bucketPrefix.length);
      }
    }

    if (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }

    final publicPath = 'storage/v1/object/public/$sanitizedBucket/$normalizedPath';
    return Uri.parse(publicPath);
  }

  static String? _sanitizeObjectName(String name, String bucket) {
    var trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    trimmed = trimmed.replaceAll(RegExp(r'^/+'), '');

    const storagePrefix = 'storage/v1/object/';
    if (trimmed.startsWith(storagePrefix)) {
      trimmed = trimmed.substring(storagePrefix.length);
    }

    const publicPrefix = 'public/';
    if (trimmed.startsWith(publicPrefix)) {
      trimmed = trimmed.substring(publicPrefix.length);
    }

    final bucketPrefix = '$bucket/';
    if (trimmed == bucket) {
      trimmed = '';
    } else if (trimmed.startsWith(bucketPrefix)) {
      trimmed = trimmed.substring(bucketPrefix.length);
    }

    return trimmed;
  }

  static String? _inferBucketFromPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      return _extractBucketFromSegments(uri.pathSegments);
    }

    final segments = trimmed.split('/').where((segment) => segment.isNotEmpty).toList();
    return _extractBucketFromSegments(segments);
  }

  static String? _extractBucketFromSegments(List<String> segments) {
    if (segments.isEmpty) return null;
    final publicIndex = segments.indexOf('public');
    if (publicIndex != -1 && publicIndex + 1 < segments.length) {
      return segments[publicIndex + 1];
    }

    final nonEmpty = segments.where((segment) => segment.isNotEmpty).toList();
    if (nonEmpty.length <= 1) return null;

    return nonEmpty.first;
  }

  static String? _coerceString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  static bool _looksLikePhotoEntry(Map<String, dynamic> map) {
    const candidateKeys = {
      'public_url',
      'publicUrl',
      'url',
      'public_path',
      'publicPath',
      'storage_path',
      'path',
      'file_path',
      'bucket',
      'bucket_id',
      'bucketId',
      'bucket_name',
      'bucketName',
      'name',
      'filename',
      'file_name',
      'fileName',
      'full_path',
      'fullPath',
      'primary',
      'is_primary',
    };

    return map.keys.any(candidateKeys.contains);
  }

  static DateTime? _coerceDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class MemberInternalReportEntry {
  final String id;
  final String? type;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<MemberInternalReportAttachment> attachments;
  final Map<String, dynamic>? metadata;
  final bool isPending;

  MemberInternalReportEntry({
    required this.id,
    String? type,
    this.description,
    DateTime? createdAt,
    this.updatedAt,
    List<MemberInternalReportAttachment> attachments = const [],
    this.metadata,
    this.isPending = false,
  })  : type = (type ?? '').isEmpty ? _inferType(description, attachments) : type,
        createdAt = createdAt ?? DateTime.now(),
        attachments = List<MemberInternalReportAttachment>.unmodifiable(attachments);

  static String generateId() => 'report-${DateTime.now().microsecondsSinceEpoch}';

  bool get hasAttachments => attachments.isNotEmpty;

  MemberInternalReportEntry copyWith({
    String? id,
    String? type,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MemberInternalReportAttachment>? attachments,
    Map<String, dynamic>? metadata,
    bool? isPending,
  }) {
    final updatedAttachments = attachments ?? this.attachments;
    final shouldInferType = type == null && attachments != null;
    return MemberInternalReportEntry(
      id: id ?? this.id,
      type: shouldInferType ? null : (type ?? this.type),
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: updatedAttachments,
      metadata: metadata ?? this.metadata,
      isPending: isPending ?? this.isPending,
    );
  }

  factory MemberInternalReportEntry.fromJson(dynamic raw) {
    if (raw == null) {
      throw const FormatException('Cannot parse null report entry');
    }

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return MemberInternalReportEntry.fromJson(decoded);
      } catch (_) {
        return MemberInternalReportEntry(
          id: generateId(),
          description: raw,
        );
      }
    }

    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      final dynamic attachmentsValue =
          map['attachments'] ?? map['files'] ?? map['documents'] ?? map['assets'];
      final attachments = <MemberInternalReportAttachment>[];
      if (attachmentsValue is List) {
        for (final item in attachmentsValue) {
          try {
            attachments.add(MemberInternalReportAttachment.fromJson(item));
          } catch (_) {}
        }
      }

      DateTime? createdAt = _coerceDate(map['created_at'] ?? map['createdAt']);
      createdAt ??= _coerceDate(map['timestamp']);

      return MemberInternalReportEntry(
        id: (map['id'] ?? map['entry_id'] ?? map['uuid'] ?? generateId()).toString(),
        type: _coerceString(map['type']),
        description: _coerceString(
              map['description'] ?? map['text'] ?? map['notes'] ?? map['body'],
            ) ??
            (attachments.isEmpty ? null : ''),
        createdAt: createdAt,
        updatedAt: _coerceDate(map['updated_at'] ?? map['updatedAt']),
        attachments: attachments,
        metadata: map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : null,
      );
    }

    throw FormatException('Unsupported report entry payload: ${raw.runtimeType}');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (type != null && type!.isNotEmpty) 'type': type,
      if (description != null) ...{
        'description': description,
        'notes': description,
      },
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  static String? _coerceString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  static DateTime? _coerceDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _inferType(String? description, List<MemberInternalReportAttachment> attachments) {
    if (attachments.isNotEmpty) {
      final first = attachments.first;
      final contentType = first.contentType ?? '';
      if (contentType.startsWith('image/')) {
        return 'image';
      }
      if (contentType.startsWith('video/')) {
        return 'video';
      }
      if (contentType.startsWith('application/')) {
        return 'document';
      }
      if (contentType.startsWith('text/')) {
        return 'document';
      }
      return 'file';
    }

    if (description != null && description.trim().isNotEmpty) {
      return 'note';
    }

    return null;
  }
}

class MemberInternalReportAttachment {
  final String bucket;
  final String path;
  final String? filename;
  final String? contentType;
  final int? size;
  final DateTime? uploadedAt;
  final Map<String, dynamic>? metadata;
  final bool isLocalPlaceholder;

  const MemberInternalReportAttachment({
    required this.bucket,
    required this.path,
    this.filename,
    this.contentType,
    this.size,
    this.uploadedAt,
    this.metadata,
    this.isLocalPlaceholder = false,
  });

  MemberInternalReportAttachment copyWith({
    String? bucket,
    String? path,
    String? filename,
    String? contentType,
    int? size,
    DateTime? uploadedAt,
    Map<String, dynamic>? metadata,
    bool? isLocalPlaceholder,
  }) {
    return MemberInternalReportAttachment(
      bucket: bucket ?? this.bucket,
      path: path ?? this.path,
      filename: filename ?? this.filename,
      contentType: contentType ?? this.contentType,
      size: size ?? this.size,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      metadata: metadata ?? this.metadata,
      isLocalPlaceholder: isLocalPlaceholder ?? this.isLocalPlaceholder,
    );
  }

  factory MemberInternalReportAttachment.fromJson(dynamic raw) {
    if (raw == null) {
      throw const FormatException('Cannot parse null attachment');
    }

    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        throw const FormatException('Empty attachment path');
      }
      return MemberInternalReportAttachment(
        bucket: 'member-documents',
        path: trimmed,
        filename: trimmed.split('/').last,
      );
    }

    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      final String bucket = (map['bucket'] ?? map['bucket_id'] ?? 'member-documents').toString();
      final String? filename =
          map['filename']?.toString() ?? map['file_name']?.toString() ?? map['name']?.toString();
      String? path = map['path']?.toString() ?? map['storage_path']?.toString();
      path ??= map['public_path']?.toString() ?? map['publicUrl']?.toString();

      if (path == null || path.isEmpty) {
        if (filename != null) {
          path = filename;
        } else {
          throw const FormatException('Attachment missing path');
        }
      }

      return MemberInternalReportAttachment(
        bucket: bucket,
        path: path,
        filename: filename,
        contentType: map['content_type']?.toString() ?? map['mime_type']?.toString(),
        size: _coerceSize(map['size'] ?? map['byte_size']),
        uploadedAt: MemberInternalReportEntry._coerceDate(map['uploaded_at'] ?? map['created_at']),
        metadata: map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : null,
      );
    }

    throw FormatException('Unsupported attachment payload: ${raw.runtimeType}');
  }

  Map<String, dynamic> toJson() {
    return {
      'bucket': bucket,
      'path': path,
      if (filename != null) 'filename': filename,
      if (contentType != null) 'content_type': contentType,
      if (size != null) 'size': size,
      if (uploadedAt != null) 'uploaded_at': uploadedAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  String? get publicUrl {
    final normalized = MemberProfilePhoto._normalizePath(path, bucket: bucket);
    if (normalized == null) return null;
    if (normalized.hasScheme) {
      return normalized.toString();
    }

    final supabaseUrl = CRMConfig.supabaseUrl;
    if (supabaseUrl.isEmpty) {
      return normalized.toString();
    }

    final baseUri = Uri.tryParse(supabaseUrl);
    if (baseUri == null || baseUri.host.isEmpty) {
      return normalized.toString();
    }

    final resolved = baseUri.replace(
      path: normalized.path,
      query: normalized.hasQuery ? normalized.query : null,
      fragment: normalized.fragment.isEmpty ? null : normalized.fragment,
    );

    return resolved.toString();
  }

  static int? _coerceSize(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String && value.isNotEmpty) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }
}
