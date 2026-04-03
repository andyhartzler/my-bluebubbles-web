import 'package:flutter/material.dart';

/// Represents an organizational committee
class Committee {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final bool hasChaptersTab;
  final bool hasDonorsTab;
  final bool hasCampaignsTab;
  final bool hasLegislationTab;
  final bool hasCandidatesTab;
  final String? chapterTypeFilter;
  /// The name used to filter meetings in the database (includes "Committee" suffix where needed)
  final String? _meetingsFilterName;

  const Committee({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    this.hasChaptersTab = false,
    this.hasDonorsTab = false,
    this.hasCampaignsTab = false,
    this.hasLegislationTab = false,
    this.hasCandidatesTab = false,
    this.chapterTypeFilter,
    String? meetingsFilterName,
  }) : _meetingsFilterName = meetingsFilterName;

  String get routeName => id.toLowerCase().replaceAll(' ', '-').replaceAll('&', 'and');

  /// Returns the name to use when filtering meetings from the database
  String get meetingsFilterName => _meetingsFilterName ?? name;
}

/// Static committee definitions
class CommitteeDefinitions {
  CommitteeDefinitions._();

  static const _unityBlue = Color(0xFF273351);
  static const _momentumBlue = Color(0xFF32A6DE);
  // Additional blue variations for committees
  static const _steelBlue = Color(0xFF4682B4);
  static const _navyBlue = Color(0xFF1E3A5F);
  static const _slateBlue = Color(0xFF5A7FA3);
  static const _royalBlue = Color(0xFF2B4B8C);

  static const communications = Committee(
    id: 'Communications',
    name: 'Communications',
    displayName: 'Communications',
    description: 'Manages all internal and external communications, email campaigns, and social media presence.',
    icon: Icons.campaign_outlined,
    primaryColor: _momentumBlue,
    secondaryColor: _unityBlue,
    meetingsFilterName: 'Communications Committee',
  );

  static const politicalAffairs = Committee(
    id: 'Political Affairs',
    name: 'Political Affairs',
    displayName: 'Political Affairs',
    description: 'Coordinates political engagement, endorsements, and election activities.',
    icon: Icons.how_to_vote_outlined,
    primaryColor: _unityBlue,
    secondaryColor: _momentumBlue,
    hasCandidatesTab: true,
    meetingsFilterName: 'Political Affairs Committee',
  );

  static const policyAdvocacy = Committee(
    id: 'Policy & Advocacy',
    name: 'Policy & Advocacy',
    displayName: 'Policy & Advocacy',
    description: 'Develops policy positions and leads advocacy campaigns on key issues.',
    icon: Icons.gavel_outlined,
    primaryColor: _unityBlue,
    secondaryColor: _momentumBlue,
    hasCampaignsTab: true,
    hasLegislationTab: true,
    meetingsFilterName: 'Policy & Advocacy Committee',
  );

  static const membershipOutreach = Committee(
    id: 'Membership & Outreach',
    name: 'Membership & Outreach',
    displayName: 'Membership & Outreach',
    description: 'Grows and engages the membership base through recruitment and community events.',
    icon: Icons.people_outline,
    primaryColor: _navyBlue,
    secondaryColor: _steelBlue,
    meetingsFilterName: 'Membership & Outreach Committee',
  );

  static const fundraising = Committee(
    id: 'Fundraising',
    name: 'Fundraising',
    displayName: 'Fundraising',
    description: 'Leads fundraising efforts to support organizational initiatives and programs.',
    icon: Icons.volunteer_activism_outlined,
    primaryColor: _steelBlue,
    secondaryColor: _navyBlue,
    hasDonorsTab: true,
    meetingsFilterName: 'Fundraising Committee',
  );

  static const collegeDemocrats = Committee(
    id: 'College Democrats',
    name: 'College Democrats',
    displayName: 'College Democrats',
    description: 'Supports and coordinates college-level Democratic organizations across Missouri.',
    icon: Icons.school_outlined,
    primaryColor: _unityBlue,
    secondaryColor: _momentumBlue,
    hasChaptersTab: true,
    chapterTypeFilter: 'college',
  );

  static const highSchoolDemocrats = Committee(
    id: 'High School Democrats',
    name: 'High School Democrats',
    displayName: 'High School Democrats',
    description: 'Engages and empowers high school students in Democratic political participation.',
    icon: Icons.emoji_people_outlined,
    primaryColor: _slateBlue,
    secondaryColor: _royalBlue,
    hasChaptersTab: true,
    chapterTypeFilter: 'highschool',
  );

  /// All committees in display order
  static const List<Committee> all = [
    communications,
    politicalAffairs,
    policyAdvocacy,
    membershipOutreach,
    fundraising,
    collegeDemocrats,
    highSchoolDemocrats,
  ];

  /// Find committee by name
  static Committee? findByName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final committee in all) {
      if (committee.name.toLowerCase() == normalized ||
          committee.id.toLowerCase() == normalized) {
        return committee;
      }
    }
    return null;
  }

  /// Find committee by route name
  static Committee? findByRouteName(String routeName) {
    final normalized = routeName.trim().toLowerCase();
    for (final committee in all) {
      if (committee.routeName == normalized) {
        return committee;
      }
    }
    return null;
  }
}

/// Committee statistics for the dashboard
class CommitteeStats {
  final int memberCount;
  final int slackMessageCount;
  final List<CommitteeLeader> chairs;
  final List<CommitteeLeader> coChairs;
  final Map<String, dynamic> specificStats;

  const CommitteeStats({
    this.memberCount = 0,
    this.slackMessageCount = 0,
    this.chairs = const [],
    this.coChairs = const [],
    this.specificStats = const {},
  });

  /// Get chair name for backward compatibility
  String? get chairName => chairs.isNotEmpty ? chairs.first.name : null;
  String? get chairPhotoUrl => chairs.isNotEmpty ? chairs.first.photoUrl : null;
  String? get coChairName => coChairs.isNotEmpty ? coChairs.first.name : null;
  String? get coChairPhotoUrl => coChairs.isNotEmpty ? coChairs.first.photoUrl : null;

  /// Get all leaders (chairs and co-chairs)
  List<CommitteeLeader> get allLeaders => [...chairs, ...coChairs];
}

/// Committee leadership member
class CommitteeLeader {
  final String memberId;
  final String name;
  final String? title;
  final String? photoUrl;
  final String? email;
  final String? phone;

  const CommitteeLeader({
    required this.memberId,
    required this.name,
    this.title,
    this.photoUrl,
    this.email,
    this.phone,
  });
}
