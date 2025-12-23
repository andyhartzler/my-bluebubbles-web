import 'dart:convert';

/// Comprehensive model for all pre-calculated dashboard metrics from crm_dashboard_metrics table.
class DashboardMetrics {
  final String id;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Core member counts
  final int totalMembers;
  final int totalMembersWithPhone;
  final int totalSubscribers;
  final int totalDonors;

  // Chapter counts
  final int totalChapters;
  final int totalCharteredChapters;
  final int totalCollegeChapters;
  final int totalHighschoolChapters;
  final int totalCountyChapters;

  // Unique counts
  final int totalUniqueColleges;
  final int totalUniqueHighSchools;
  final int totalUniqueCounties;
  final int totalUniqueCongressionalDistricts;
  final int totalUniqueHouseDistricts;
  final int totalUniqueSenateDistricts;

  // Donation stats
  final double totalDonationsAmount;
  final int totalDonationCount;
  final double averageDonationAmount;
  final int totalRecurringDonors;
  final double donationsThisMonth;
  final double donationsThisYear;
  final List<TopDonor> top5Donors;

  // Slack/Communication stats
  final int totalSlackMessages;
  final int slackMessagesThisMonth;
  final int totalSocialImpressions;
  final List<TopSlackMember> top50SlackMembers;

  // Age demographics
  final int age14To17Count;
  final int age18To21Count;
  final int age22To25Count;
  final int age26To30Count;
  final int age31To36Count;
  final int ageUnknownCount;
  final double averageMemberAge;

  // Growth metrics
  final int newMembersThisWeek;
  final int newMembersThisMonth;
  final int newMembersThisYear;
  final int newSubscribersThisMonth;
  final List<MonthlyCount> membersJoinedByMonth;

  // Campaign/Email stats
  final int totalCampaigns;
  final int campaignsSent;
  final int totalEmailsSent;
  final int totalEmailsOpened;
  final int totalEmailsClicked;
  final double averageOpenRate;
  final double averageClickRate;

  // Event stats
  final int totalEvents;
  final int upcomingEvents;
  final int totalEventAttendees;

  // Distribution maps (for charts)
  final List<NameCount> membersByCounty;
  final List<NameCount> membersByCongressionalDistrict;
  final List<NameCount> membersByHouseDistrict;
  final List<NameCount> membersBySenateDistrict;
  final List<NameCount> membersByCommunityType;
  final List<AgeCount> membersByAge;
  final List<NameCount> membersByCollege;
  final List<NameCount> membersByHighSchool;
  final List<NameCount> membersByGraduationYear;
  final List<NameCount> membersByEducationLevel;
  final List<NameCount> membersByInSchoolStatus;
  final List<NameCount> membersByChapter;
  final List<NameCount> membersByChapterStatus;
  final List<NameCount> membersByChapterPosition;
  final List<NameCount> membersByCommittee;
  final List<NameCount> membersByGenderIdentity;
  final List<NameCount> membersByPronouns;
  final List<NameCount> membersByRace;
  final List<NameCount> membersBySexualOrientation;
  final List<NameCount> membersByHispanicLatino;
  final List<NameCount> membersByReligion;
  final List<NameCount> membersByDisability;
  final List<NameCount> membersByLanguages;
  final List<NameCount> membersByIndustry;
  final List<NameCount> membersByEmploymentStatus;
  final List<NameCount> membersByVoterRegistration;
  final List<NameCount> membersByDesireToLead;
  final List<NameCount> membersByHoursPerWeek;
  final List<NameCount> membersByReferralSource;
  final List<NameCount> membersByAreasOfInterest;

  const DashboardMetrics({
    required this.id,
    this.createdAt,
    this.updatedAt,
    required this.totalMembers,
    required this.totalMembersWithPhone,
    required this.totalSubscribers,
    required this.totalDonors,
    required this.totalChapters,
    required this.totalCharteredChapters,
    required this.totalCollegeChapters,
    required this.totalHighschoolChapters,
    required this.totalCountyChapters,
    required this.totalUniqueColleges,
    required this.totalUniqueHighSchools,
    required this.totalUniqueCounties,
    required this.totalUniqueCongressionalDistricts,
    required this.totalUniqueHouseDistricts,
    required this.totalUniqueSenateDistricts,
    required this.totalDonationsAmount,
    required this.totalDonationCount,
    required this.averageDonationAmount,
    required this.totalRecurringDonors,
    required this.donationsThisMonth,
    required this.donationsThisYear,
    required this.top5Donors,
    required this.totalSlackMessages,
    required this.slackMessagesThisMonth,
    required this.totalSocialImpressions,
    required this.top50SlackMembers,
    required this.age14To17Count,
    required this.age18To21Count,
    required this.age22To25Count,
    required this.age26To30Count,
    required this.age31To36Count,
    required this.ageUnknownCount,
    required this.averageMemberAge,
    required this.newMembersThisWeek,
    required this.newMembersThisMonth,
    required this.newMembersThisYear,
    required this.newSubscribersThisMonth,
    required this.membersJoinedByMonth,
    required this.totalCampaigns,
    required this.campaignsSent,
    required this.totalEmailsSent,
    required this.totalEmailsOpened,
    required this.totalEmailsClicked,
    required this.averageOpenRate,
    required this.averageClickRate,
    required this.totalEvents,
    required this.upcomingEvents,
    required this.totalEventAttendees,
    required this.membersByCounty,
    required this.membersByCongressionalDistrict,
    required this.membersByHouseDistrict,
    required this.membersBySenateDistrict,
    required this.membersByCommunityType,
    required this.membersByAge,
    required this.membersByCollege,
    required this.membersByHighSchool,
    required this.membersByGraduationYear,
    required this.membersByEducationLevel,
    required this.membersByInSchoolStatus,
    required this.membersByChapter,
    required this.membersByChapterStatus,
    required this.membersByChapterPosition,
    required this.membersByCommittee,
    required this.membersByGenderIdentity,
    required this.membersByPronouns,
    required this.membersByRace,
    required this.membersBySexualOrientation,
    required this.membersByHispanicLatino,
    required this.membersByReligion,
    required this.membersByDisability,
    required this.membersByLanguages,
    required this.membersByIndustry,
    required this.membersByEmploymentStatus,
    required this.membersByVoterRegistration,
    required this.membersByDesireToLead,
    required this.membersByHoursPerWeek,
    required this.membersByReferralSource,
    required this.membersByAreasOfInterest,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      id: json['id'] as String? ?? 'singleton',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      totalMembers: _parseInt(json['total_members']) ?? 0,
      totalMembersWithPhone: _parseInt(json['total_members_with_phone']) ?? 0,
      totalSubscribers: _parseInt(json['total_subscribers']) ?? 0,
      totalDonors: _parseInt(json['total_donors']) ?? 0,
      totalChapters: _parseInt(json['total_chapters']) ?? 0,
      totalCharteredChapters: _parseInt(json['total_chartered_chapters']) ?? 0,
      totalCollegeChapters: _parseInt(json['total_college_chapters']) ?? 0,
      totalHighschoolChapters: _parseInt(json['total_highschool_chapters']) ?? 0,
      totalCountyChapters: _parseInt(json['total_county_chapters']) ?? 0,
      totalUniqueColleges: _parseInt(json['total_unique_colleges']) ?? 0,
      totalUniqueHighSchools: _parseInt(json['total_unique_high_schools']) ?? 0,
      totalUniqueCounties: _parseInt(json['total_unique_counties']) ?? 0,
      totalUniqueCongressionalDistricts: _parseInt(json['total_unique_congressional_districts']) ?? 0,
      totalUniqueHouseDistricts: _parseInt(json['total_unique_house_districts']) ?? 0,
      totalUniqueSenateDistricts: _parseInt(json['total_unique_senate_districts']) ?? 0,
      totalDonationsAmount: _parseDouble(json['total_donations_amount']) ?? 0.0,
      totalDonationCount: _parseInt(json['total_donation_count']) ?? 0,
      averageDonationAmount: _parseDouble(json['average_donation_amount']) ?? 0.0,
      totalRecurringDonors: _parseInt(json['total_recurring_donors']) ?? 0,
      donationsThisMonth: _parseDouble(json['donations_this_month']) ?? 0.0,
      donationsThisYear: _parseDouble(json['donations_this_year']) ?? 0.0,
      top5Donors: _parseTopDonors(json['top_5_donors']),
      totalSlackMessages: _parseInt(json['total_slack_messages']) ?? 0,
      slackMessagesThisMonth: _parseInt(json['slack_messages_this_month']) ?? 0,
      totalSocialImpressions: _parseInt(json['total_social_impressions']) ?? 0,
      top50SlackMembers: _parseTopSlackMembers(json['top_50_slack_members']),
      age14To17Count: _parseInt(json['age_14_17_count']) ?? 0,
      age18To21Count: _parseInt(json['age_18_21_count']) ?? 0,
      age22To25Count: _parseInt(json['age_22_25_count']) ?? 0,
      age26To30Count: _parseInt(json['age_26_30_count']) ?? 0,
      age31To36Count: _parseInt(json['age_31_36_count']) ?? 0,
      ageUnknownCount: _parseInt(json['age_unknown_count']) ?? 0,
      averageMemberAge: _parseDouble(json['average_member_age']) ?? 0.0,
      newMembersThisWeek: _parseInt(json['new_members_this_week']) ?? 0,
      newMembersThisMonth: _parseInt(json['new_members_this_month']) ?? 0,
      newMembersThisYear: _parseInt(json['new_members_this_year']) ?? 0,
      newSubscribersThisMonth: _parseInt(json['new_subscribers_this_month']) ?? 0,
      membersJoinedByMonth: _parseMonthlyCounts(json['members_joined_by_month']),
      totalCampaigns: _parseInt(json['total_campaigns']) ?? 0,
      campaignsSent: _parseInt(json['campaigns_sent']) ?? 0,
      totalEmailsSent: _parseInt(json['total_emails_sent']) ?? 0,
      totalEmailsOpened: _parseInt(json['total_emails_opened']) ?? 0,
      totalEmailsClicked: _parseInt(json['total_emails_clicked']) ?? 0,
      averageOpenRate: _parseDouble(json['average_open_rate']) ?? 0.0,
      averageClickRate: _parseDouble(json['average_click_rate']) ?? 0.0,
      totalEvents: _parseInt(json['total_events']) ?? 0,
      upcomingEvents: _parseInt(json['upcoming_events']) ?? 0,
      totalEventAttendees: _parseInt(json['total_event_attendees']) ?? 0,
      membersByCounty: _parseNameCounts(json['members_by_county']),
      membersByCongressionalDistrict: _parseNameCounts(json['members_by_congressional_district']),
      membersByHouseDistrict: _parseNameCounts(json['members_by_house_district']),
      membersBySenateDistrict: _parseNameCounts(json['members_by_senate_district']),
      membersByCommunityType: _parseNameCounts(json['members_by_community_type']),
      membersByAge: _parseAgeCounts(json['members_by_age']),
      membersByCollege: _parseNameCounts(json['members_by_college']),
      membersByHighSchool: _parseNameCounts(json['members_by_high_school']),
      membersByGraduationYear: _parseNameCounts(json['members_by_graduation_year']),
      membersByEducationLevel: _parseNameCounts(json['members_by_education_level']),
      membersByInSchoolStatus: _parseNameCounts(json['members_by_in_school_status']),
      membersByChapter: _parseNameCounts(json['members_by_chapter']),
      membersByChapterStatus: _parseNameCounts(json['members_by_chapter_status']),
      membersByChapterPosition: _parseNameCounts(json['members_by_chapter_position']),
      membersByCommittee: _parseNameCounts(json['members_by_committee']),
      membersByGenderIdentity: _parseNameCounts(json['members_by_gender_identity']),
      membersByPronouns: _parseNameCounts(json['members_by_pronouns']),
      membersByRace: _parseNameCounts(json['members_by_race']),
      membersBySexualOrientation: _parseNameCounts(json['members_by_sexual_orientation']),
      membersByHispanicLatino: _parseNameCounts(json['members_by_hispanic_latino']),
      membersByReligion: _parseNameCounts(json['members_by_religion']),
      membersByDisability: _parseNameCounts(json['members_by_disability']),
      membersByLanguages: _parseNameCounts(json['members_by_languages']),
      membersByIndustry: _parseNameCounts(json['members_by_industry']),
      membersByEmploymentStatus: _parseNameCounts(json['members_by_employment_status']),
      membersByVoterRegistration: _parseNameCounts(json['members_by_voter_registration']),
      membersByDesireToLead: _parseNameCounts(json['members_by_desire_to_lead']),
      membersByHoursPerWeek: _parseNameCounts(json['members_by_hours_per_week']),
      membersByReferralSource: _parseNameCounts(json['members_by_referral_source']),
      membersByAreasOfInterest: _parseNameCounts(json['members_by_areas_of_interest']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<TopDonor> _parseTopDonors(dynamic value) {
    final list = _parseJsonList(value);
    return list.map((e) => TopDonor.fromJson(e)).toList();
  }

  static List<TopSlackMember> _parseTopSlackMembers(dynamic value) {
    final list = _parseJsonList(value);
    return list.map((e) => TopSlackMember.fromJson(e)).toList();
  }

  static List<NameCount> _parseNameCounts(dynamic value) {
    final list = _parseJsonList(value);
    return list.map((e) => NameCount.fromJson(e)).toList();
  }

  static List<AgeCount> _parseAgeCounts(dynamic value) {
    final list = _parseJsonList(value);
    return list.map((e) => AgeCount.fromJson(e)).toList();
  }

  static List<MonthlyCount> _parseMonthlyCounts(dynamic value) {
    final list = _parseJsonList(value);
    return list.map((e) => MonthlyCount.fromJson(e)).toList();
  }

  static List<Map<String, dynamic>> _parseJsonList(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      } catch (_) {}
      return [];
    }
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Convert NameCount list to Map for chart compatibility
  Map<String, int> nameCountsToMap(List<NameCount> counts) {
    final map = <String, int>{};
    for (final nc in counts) {
      if (nc.name.isNotEmpty) {
        map[nc.name] = nc.count;
      }
    }
    return map;
  }

  /// Empty/default metrics factory
  static DashboardMetrics get empty => DashboardMetrics(
    id: 'empty',
    totalMembers: 0,
    totalMembersWithPhone: 0,
    totalSubscribers: 0,
    totalDonors: 0,
    totalChapters: 0,
    totalCharteredChapters: 0,
    totalCollegeChapters: 0,
    totalHighschoolChapters: 0,
    totalCountyChapters: 0,
    totalUniqueColleges: 0,
    totalUniqueHighSchools: 0,
    totalUniqueCounties: 0,
    totalUniqueCongressionalDistricts: 0,
    totalUniqueHouseDistricts: 0,
    totalUniqueSenateDistricts: 0,
    totalDonationsAmount: 0,
    totalDonationCount: 0,
    averageDonationAmount: 0,
    totalRecurringDonors: 0,
    donationsThisMonth: 0,
    donationsThisYear: 0,
    top5Donors: const [],
    totalSlackMessages: 0,
    slackMessagesThisMonth: 0,
    totalSocialImpressions: 0,
    top50SlackMembers: const [],
    age14To17Count: 0,
    age18To21Count: 0,
    age22To25Count: 0,
    age26To30Count: 0,
    age31To36Count: 0,
    ageUnknownCount: 0,
    averageMemberAge: 0,
    newMembersThisWeek: 0,
    newMembersThisMonth: 0,
    newMembersThisYear: 0,
    newSubscribersThisMonth: 0,
    membersJoinedByMonth: const [],
    totalCampaigns: 0,
    campaignsSent: 0,
    totalEmailsSent: 0,
    totalEmailsOpened: 0,
    totalEmailsClicked: 0,
    averageOpenRate: 0,
    averageClickRate: 0,
    totalEvents: 0,
    upcomingEvents: 0,
    totalEventAttendees: 0,
    membersByCounty: const [],
    membersByCongressionalDistrict: const [],
    membersByHouseDistrict: const [],
    membersBySenateDistrict: const [],
    membersByCommunityType: const [],
    membersByAge: const [],
    membersByCollege: const [],
    membersByHighSchool: const [],
    membersByGraduationYear: const [],
    membersByEducationLevel: const [],
    membersByInSchoolStatus: const [],
    membersByChapter: const [],
    membersByChapterStatus: const [],
    membersByChapterPosition: const [],
    membersByCommittee: const [],
    membersByGenderIdentity: const [],
    membersByPronouns: const [],
    membersByRace: const [],
    membersBySexualOrientation: const [],
    membersByHispanicLatino: const [],
    membersByReligion: const [],
    membersByDisability: const [],
    membersByLanguages: const [],
    membersByIndustry: const [],
    membersByEmploymentStatus: const [],
    membersByVoterRegistration: const [],
    membersByDesireToLead: const [],
    membersByHoursPerWeek: const [],
    membersByReferralSource: const [],
    membersByAreasOfInterest: const [],
  );
}

/// Name/Count pair for distribution data
class NameCount {
  final String name;
  final int count;

  const NameCount({required this.name, required this.count});

  factory NameCount.fromJson(Map<String, dynamic> json) {
    return NameCount(
      name: json['name']?.toString() ?? '',
      count: DashboardMetrics._parseInt(json['count']) ?? 0,
    );
  }
}

/// Age/Count pair for age distribution
class AgeCount {
  final int age;
  final int count;

  const AgeCount({required this.age, required this.count});

  factory AgeCount.fromJson(Map<String, dynamic> json) {
    return AgeCount(
      age: DashboardMetrics._parseInt(json['age']) ?? 0,
      count: DashboardMetrics._parseInt(json['count']) ?? 0,
    );
  }
}

/// Monthly count for growth tracking
class MonthlyCount {
  final String month;
  final int count;

  const MonthlyCount({required this.month, required this.count});

  factory MonthlyCount.fromJson(Map<String, dynamic> json) {
    return MonthlyCount(
      month: json['month']?.toString() ?? '',
      count: DashboardMetrics._parseInt(json['count']) ?? 0,
    );
  }
}

/// Top donor data
class TopDonor {
  final String name;
  final String? email;
  final double totalDonated;

  const TopDonor({required this.name, this.email, required this.totalDonated});

  factory TopDonor.fromJson(Map<String, dynamic> json) {
    return TopDonor(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      totalDonated: DashboardMetrics._parseDouble(json['total_donated']) ?? 0.0,
    );
  }
}

/// Top Slack member data
class TopSlackMember {
  final String id;
  final String name;
  final String? email;
  final int messageCount;
  final String? profilePhotoUrl;

  const TopSlackMember({
    required this.id,
    required this.name,
    this.email,
    required this.messageCount,
    this.profilePhotoUrl,
  });

  factory TopSlackMember.fromJson(Map<String, dynamic> json) {
    return TopSlackMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      messageCount: DashboardMetrics._parseInt(json['message_count']) ?? 0,
      profilePhotoUrl: json['profile_photo_url']?.toString(),
    );
  }

  /// Create a copy with updated profile photo URL
  TopSlackMember copyWith({String? profilePhotoUrl}) {
    return TopSlackMember(
      id: id,
      name: name,
      email: email,
      messageCount: messageCount,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }
}
