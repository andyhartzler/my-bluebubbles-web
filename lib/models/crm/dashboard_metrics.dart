/// Model for pre-calculated dashboard metrics from the crm_dashboard_metrics table.
/// This table uses a single-row pattern with database triggers for real-time updates.
class DashboardMetrics {
  final String id;
  final int totalMembers;
  final int contactableMembers;
  final int optedOutMembers;
  final int membersWithPhone;
  final int charteredChapters;
  final int countiesRepresented;
  final int totalDonations;
  final double totalDonationAmount;
  final int donationsThisMonth;
  final double donationAmountThisMonth;
  final int totalEvents;
  final int upcomingEvents;
  final int totalForms;
  final int formSubmissionsThisMonth;
  final int totalMeetings;
  final int meetingsThisMonth;
  final int totalAttendanceRecords;
  final Map<String, int> membersByCounty;
  final Map<String, int> membersByDistrict;
  final Map<String, int> membersByChapter;
  final Map<String, int> membersByChapterStatus;
  final Map<String, int> membersByGraduationYear;
  final Map<String, int> membersByPronoun;
  final Map<String, int> membersByGender;
  final Map<String, int> membersByRace;
  final Map<String, int> membersByLanguage;
  final Map<String, int> membersByCommunityType;
  final Map<String, int> membersByIndustry;
  final Map<String, int> membersByEducationLevel;
  final Map<String, int> membersByVoterStatus;
  final Map<String, int> membersBySexualOrientation;
  final Map<String, int> membersByAgeBucket;
  final Map<String, int> membersByHighSchool;
  final Map<String, int> membersByCollege;
  final Map<String, int> membersByCommittee;
  final DateTime lastUpdatedAt;

  const DashboardMetrics({
    required this.id,
    required this.totalMembers,
    required this.contactableMembers,
    required this.optedOutMembers,
    required this.membersWithPhone,
    required this.charteredChapters,
    required this.countiesRepresented,
    required this.totalDonations,
    required this.totalDonationAmount,
    required this.donationsThisMonth,
    required this.donationAmountThisMonth,
    required this.totalEvents,
    required this.upcomingEvents,
    required this.totalForms,
    required this.formSubmissionsThisMonth,
    required this.totalMeetings,
    required this.meetingsThisMonth,
    required this.totalAttendanceRecords,
    required this.membersByCounty,
    required this.membersByDistrict,
    required this.membersByChapter,
    required this.membersByChapterStatus,
    required this.membersByGraduationYear,
    required this.membersByPronoun,
    required this.membersByGender,
    required this.membersByRace,
    required this.membersByLanguage,
    required this.membersByCommunityType,
    required this.membersByIndustry,
    required this.membersByEducationLevel,
    required this.membersByVoterStatus,
    required this.membersBySexualOrientation,
    required this.membersByAgeBucket,
    required this.membersByHighSchool,
    required this.membersByCollege,
    required this.membersByCommittee,
    required this.lastUpdatedAt,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      id: json['id'] as String? ?? 'singleton',
      totalMembers: _parseInt(json['total_members']) ?? 0,
      contactableMembers: _parseInt(json['contactable_members']) ?? 0,
      optedOutMembers: _parseInt(json['opted_out_members']) ?? 0,
      membersWithPhone: _parseInt(json['members_with_phone']) ?? 0,
      charteredChapters: _parseInt(json['chartered_chapters']) ?? 0,
      countiesRepresented: _parseInt(json['counties_represented']) ?? 0,
      totalDonations: _parseInt(json['total_donations']) ?? 0,
      totalDonationAmount: _parseDouble(json['total_donation_amount']) ?? 0.0,
      donationsThisMonth: _parseInt(json['donations_this_month']) ?? 0,
      donationAmountThisMonth: _parseDouble(json['donation_amount_this_month']) ?? 0.0,
      totalEvents: _parseInt(json['total_events']) ?? 0,
      upcomingEvents: _parseInt(json['upcoming_events']) ?? 0,
      totalForms: _parseInt(json['total_forms']) ?? 0,
      formSubmissionsThisMonth: _parseInt(json['form_submissions_this_month']) ?? 0,
      totalMeetings: _parseInt(json['total_meetings']) ?? 0,
      meetingsThisMonth: _parseInt(json['meetings_this_month']) ?? 0,
      totalAttendanceRecords: _parseInt(json['total_attendance_records']) ?? 0,
      membersByCounty: _parseCountMap(json['members_by_county']),
      membersByDistrict: _parseCountMap(json['members_by_district']),
      membersByChapter: _parseCountMap(json['members_by_chapter']),
      membersByChapterStatus: _parseCountMap(json['members_by_chapter_status']),
      membersByGraduationYear: _parseCountMap(json['members_by_graduation_year']),
      membersByPronoun: _parseCountMap(json['members_by_pronoun']),
      membersByGender: _parseCountMap(json['members_by_gender']),
      membersByRace: _parseCountMap(json['members_by_race']),
      membersByLanguage: _parseCountMap(json['members_by_language']),
      membersByCommunityType: _parseCountMap(json['members_by_community_type']),
      membersByIndustry: _parseCountMap(json['members_by_industry']),
      membersByEducationLevel: _parseCountMap(json['members_by_education_level']),
      membersByVoterStatus: _parseCountMap(json['members_by_voter_status']),
      membersBySexualOrientation: _parseCountMap(json['members_by_sexual_orientation']),
      membersByAgeBucket: _parseCountMap(json['members_by_age_bucket']),
      membersByHighSchool: _parseCountMap(json['members_by_high_school']),
      membersByCollege: _parseCountMap(json['members_by_college']),
      membersByCommittee: _parseCountMap(json['members_by_committee']),
      lastUpdatedAt: DateTime.tryParse(json['last_updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
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

  static Map<String, int> _parseCountMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, int>) return Map<String, int>.from(value);
    if (value is Map) {
      final result = <String, int>{};
      value.forEach((key, dynamic count) {
        final label = key?.toString() ?? '';
        final parsed = _parseInt(count);
        if (label.isNotEmpty && parsed != null) {
          result[label] = parsed;
        }
      });
      return result;
    }
    return {};
  }

  /// Empty/default metrics factory
  static DashboardMetrics get empty => DashboardMetrics(
    id: 'empty',
    totalMembers: 0,
    contactableMembers: 0,
    optedOutMembers: 0,
    membersWithPhone: 0,
    charteredChapters: 0,
    countiesRepresented: 0,
    totalDonations: 0,
    totalDonationAmount: 0,
    donationsThisMonth: 0,
    donationAmountThisMonth: 0,
    totalEvents: 0,
    upcomingEvents: 0,
    totalForms: 0,
    formSubmissionsThisMonth: 0,
    totalMeetings: 0,
    meetingsThisMonth: 0,
    totalAttendanceRecords: 0,
    membersByCounty: const {},
    membersByDistrict: const {},
    membersByChapter: const {},
    membersByChapterStatus: const {},
    membersByGraduationYear: const {},
    membersByPronoun: const {},
    membersByGender: const {},
    membersByRace: const {},
    membersByLanguage: const {},
    membersByCommunityType: const {},
    membersByIndustry: const {},
    membersByEducationLevel: const {},
    membersByVoterStatus: const {},
    membersBySexualOrientation: const {},
    membersByAgeBucket: const {},
    membersByHighSchool: const {},
    membersByCollege: const {},
    membersByCommittee: const {},
    lastUpdatedAt: DateTime(1970),
  );
}
