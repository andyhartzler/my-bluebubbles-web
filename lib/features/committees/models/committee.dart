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
  final String? chapterTypeFilter;

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
    this.chapterTypeFilter,
  });

  String get routeName => id.toLowerCase().replaceAll(' ', '-').replaceAll('&', 'and');
}

/// Static committee definitions
class CommitteeDefinitions {
  CommitteeDefinitions._();

  static const _unityBlue = Color(0xFF273351);
  static const _momentumBlue = Color(0xFF32A6DE);
  static const _sunriseGold = Color(0xFFFDB813);
  static const _grassrootsGreen = Color(0xFF43A047);
  static const _justicePurple = Color(0xFF6A1B9A);
  static const _actionOrange = Color(0xFFE65100);
  static const _communityTeal = Color(0xFF00796B);

  static const communications = Committee(
    id: 'Communications',
    name: 'Communications',
    displayName: 'Communications',
    description: 'Manages all internal and external communications, email campaigns, and social media presence.',
    icon: Icons.campaign_outlined,
    primaryColor: _momentumBlue,
    secondaryColor: _unityBlue,
  );

  static const politicalAffairs = Committee(
    id: 'Political Affairs',
    name: 'Political Affairs',
    displayName: 'Political Affairs',
    description: 'Coordinates political engagement, endorsements, and election activities.',
    icon: Icons.how_to_vote_outlined,
    primaryColor: _unityBlue,
    secondaryColor: _momentumBlue,
  );

  static const policyAdvocacy = Committee(
    id: 'Policy & Advocacy',
    name: 'Policy & Advocacy',
    displayName: 'Policy & Advocacy',
    description: 'Develops policy positions and leads advocacy campaigns on key issues.',
    icon: Icons.gavel_outlined,
    primaryColor: _justicePurple,
    secondaryColor: _unityBlue,
    hasCampaignsTab: true,
  );

  static const membershipOutreach = Committee(
    id: 'Membership & Outreach',
    name: 'Membership & Outreach',
    displayName: 'Membership & Outreach',
    description: 'Grows and engages the membership base through recruitment and community events.',
    icon: Icons.people_outline,
    primaryColor: _communityTeal,
    secondaryColor: _grassrootsGreen,
  );

  static const fundraising = Committee(
    id: 'Fundraising',
    name: 'Fundraising',
    displayName: 'Fundraising',
    description: 'Leads fundraising efforts to support organizational initiatives and programs.',
    icon: Icons.volunteer_activism_outlined,
    primaryColor: _sunriseGold,
    secondaryColor: _actionOrange,
    hasDonorsTab: true,
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
    primaryColor: _grassrootsGreen,
    secondaryColor: _communityTeal,
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
  final String? chairName;
  final String? coChairName;
  final String? chairPhotoUrl;
  final String? coChairPhotoUrl;
  final Map<String, dynamic> specificStats;

  const CommitteeStats({
    this.memberCount = 0,
    this.chairName,
    this.coChairName,
    this.chairPhotoUrl,
    this.coChairPhotoUrl,
    this.specificStats = const {},
  });
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
