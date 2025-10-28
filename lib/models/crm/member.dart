import 'dart:convert';

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
  });

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

      return trimmed;
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
    String? congressionalDistrict,
    String? race,
    String? sexualOrientation,
    String? desireToLead,
    String? hoursPerWeek,
    String? educationLevel,
    bool? registeredVoter,
    String? inSchool,
    String? schoolName,
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
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      race: race ?? this.race,
      sexualOrientation: sexualOrientation ?? this.sexualOrientation,
      desireToLead: desireToLead ?? this.desireToLead,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      educationLevel: educationLevel ?? this.educationLevel,
      registeredVoter: registeredVoter ?? this.registeredVoter,
      inSchool: inSchool ?? this.inSchool,
      schoolName: schoolName ?? this.schoolName,
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
    );
  }
}
