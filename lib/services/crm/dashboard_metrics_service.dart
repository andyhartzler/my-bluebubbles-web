import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/crm/dashboard_metrics.dart';
import 'supabase_service.dart';

/// Service for fetching pre-calculated dashboard metrics from the crm_dashboard_metrics table.
/// The table uses a single-row pattern with database triggers for real-time updates.
class DashboardMetricsService {
  final CRMSupabaseService _crmService = CRMSupabaseService();

  /// Get the Supabase client for read operations.
  /// Falls back to Supabase.instance.client if CRMSupabaseService isn't initialized
  /// but the global Supabase instance is available.
  SupabaseClient? get _client {
    // Prefer privileged client if CRM service is fully initialized with service role
    if (_crmService.isInitialized && _crmService.hasServiceRole) {
      return _crmService.privilegedClient;
    }

    // Fallback: try to use Supabase.instance.client directly
    // This works if Supabase.initialize() was called, even if CRMSupabaseService
    // had initialization issues (e.g., service role setup failed)
    try {
      final client = Supabase.instance.client;
      // If we can access the client without throwing, it's initialized
      return client;
    } catch (e) {
      debugPrint('[DashboardMetricsService] Supabase.instance.client not available: $e');
    }

    return null;
  }

  /// Fetch the singleton dashboard metrics row
  Future<DashboardMetrics?> fetchMetrics() async {
    final client = _client;
    if (client == null) {
      debugPrint('[DashboardMetricsService] fetchMetrics: client is null');
      debugPrint('[DashboardMetricsService] CRMSupabaseService.isInitialized: ${_crmService.isInitialized}');
      debugPrint('[DashboardMetricsService] CRMSupabaseService.hasServiceRole: ${_crmService.hasServiceRole}');
      debugPrint('[DashboardMetricsService] Neither CRM service nor Supabase.instance is available');
      return null;
    }

    debugPrint('[DashboardMetricsService] fetchMetrics: Using Supabase client');

    try {
      debugPrint('[DashboardMetricsService] fetchMetrics: Querying crm_dashboard_metrics...');
      final response = await client
          .from('crm_dashboard_metrics')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint('[DashboardMetricsService] fetchMetrics: Response is null - no data in table');
        return null;
      }

      debugPrint('[DashboardMetricsService] fetchMetrics: Got response with ${response.keys.length} keys');
      debugPrint('[DashboardMetricsService] fetchMetrics: total_members = ${response['total_members']}');
      debugPrint('[DashboardMetricsService] fetchMetrics: top_5_donors count = ${(response['top_5_donors'] as List?)?.length ?? 0}');

      return DashboardMetrics.fromJson(response);
    } catch (e, stack) {
      debugPrint('[DashboardMetricsService] Error fetching metrics: $e');
      debugPrint('[DashboardMetricsService] Stack trace: ${stack.toString().split('\n').take(5).join('\n')}');
      return null;
    }
  }

  /// Fetch the saved dashboard layout configuration
  Future<Map<String, dynamic>?> fetchDashboardLayout() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('crm_dashboard_metrics')
          .select('dashboard_layout')
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      final layout = response['dashboard_layout'];
      if (layout == null) return null;
      return layout is Map<String, dynamic> ? layout : null;
    } catch (e) {
      debugPrint('[DashboardMetricsService] Error fetching dashboard layout: $e');
      return null;
    }
  }

  /// Save the dashboard layout configuration
  Future<bool> saveDashboardLayout(Map<String, dynamic> layout) async {
    final client = _client;
    if (client == null) return false;

    try {
      // Get the ID of the first row
      final existingRow = await client
          .from('crm_dashboard_metrics')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existingRow == null) {
        // No row exists - this shouldn't happen but handle it
        debugPrint(
          '[DashboardMetricsService] No metrics row found to update layout',
        );
        return false;
      }

      // Update the dashboard_layout column
      await client
          .from('crm_dashboard_metrics')
          .update({'dashboard_layout': layout})
          .eq('id', existingRow['id']);

      return true;
    } catch (e) {
      debugPrint('[DashboardMetricsService] Error saving dashboard layout: $e');
      return false;
    }
  }

  /// Fetch the saved mobile dashboard layout configuration
  Future<Map<String, dynamic>?> fetchDashboardLayoutMobile() async {
    final client = _client;
    if (client == null) {
      debugPrint(
        '[DashboardMetricsService] fetchDashboardLayoutMobile: client is null',
      );
      return null;
    }

    try {
      debugPrint(
        '[DashboardMetricsService] fetchDashboardLayoutMobile: Fetching from database...',
      );

      final response = await client
          .from('crm_dashboard_metrics')
          .select('dashboard_layout_mobile')
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint(
          '[DashboardMetricsService] fetchDashboardLayoutMobile: No row found',
        );
        return null;
      }

      final layout = response['dashboard_layout_mobile'];
      if (layout == null) {
        debugPrint(
          '[DashboardMetricsService] fetchDashboardLayoutMobile: Layout is null (not set yet)',
        );
        return null;
      }

      final widgetCount = (layout is Map)
          ? (layout['widgets'] as List?)?.length ?? 0
          : 0;
      debugPrint(
        '[DashboardMetricsService] fetchDashboardLayoutMobile: Loaded layout with $widgetCount widgets',
      );

      return layout is Map<String, dynamic> ? layout : null;
    } catch (e) {
      debugPrint(
        '[DashboardMetricsService] Error fetching mobile dashboard layout: $e',
      );
      return null;
    }
  }

  /// Save the mobile dashboard layout configuration
  Future<bool> saveDashboardLayoutMobile(Map<String, dynamic> layout) async {
    final client = _client;
    if (client == null) {
      debugPrint(
        '[DashboardMetricsService] saveDashboardLayoutMobile: client is null',
      );
      return false;
    }

    try {
      debugPrint(
        '[DashboardMetricsService] saveDashboardLayoutMobile: Fetching existing row...',
      );

      // Get the ID of the first row
      final existingRow = await client
          .from('crm_dashboard_metrics')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existingRow == null) {
        debugPrint(
          '[DashboardMetricsService] No metrics row found to update mobile layout',
        );
        return false;
      }

      final rowId = existingRow['id'];
      debugPrint(
        '[DashboardMetricsService] saveDashboardLayoutMobile: Updating row $rowId with ${layout['widgets']?.length ?? 0} widgets',
      );

      // Update the dashboard_layout_mobile column
      await client
          .from('crm_dashboard_metrics')
          .update({'dashboard_layout_mobile': layout})
          .eq('id', rowId);

      debugPrint(
        '[DashboardMetricsService] saveDashboardLayoutMobile: Update completed successfully',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[DashboardMetricsService] Error saving mobile dashboard layout: $e',
      );
      debugPrint('[DashboardMetricsService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Watch the dashboard metrics for real-time updates
  Stream<DashboardMetrics?> watchMetrics() {
    final client = _client;
    if (client == null) {
      return Stream.value(null);
    }

    return client.from('crm_dashboard_metrics').stream(primaryKey: ['id']).map((
      data,
    ) {
      if (data.isEmpty) return null;
      return DashboardMetrics.fromJson(data.first);
    });
  }

  /// Check if the metrics table exists and has data
  Future<bool> hasMetrics() async {
    final client = _client;
    if (client == null) return false;

    try {
      final response = await client
          .from('crm_dashboard_metrics')
          .select('id')
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('[DashboardMetricsService] Error checking metrics table: $e');
      return false;
    }
  }

  /// Fetch Slack analytics from slack_analytics_cache table
  Future<Map<String, dynamic>> fetchSlackAnalytics() async {
    final client = _client;
    if (client == null) return {};

    try {
      // Fetch latest metrics from slack_analytics_cache
      final response = await client
          .from('slack_analytics_cache')
          .select()
          .order('computed_at', ascending: false)
          .limit(10);

      if (response.isEmpty) return {};

      final result = <String, dynamic>{};

      // Process the cached metrics
      for (final row in response) {
        final metricName = row['metric_name'] as String?;
        final metricValue = row['metric_value'];

        if (metricName != null) {
          // Map metric names to our expected fields
          switch (metricName) {
            case 'active_users':
              result['slack_active_users'] = metricValue is int
                  ? metricValue
                  : int.tryParse(metricValue.toString()) ?? 0;
              break;
            case 'messages_this_week':
              result['slack_messages_this_week'] = metricValue is int
                  ? metricValue
                  : int.tryParse(metricValue.toString()) ?? 0;
              break;
            case 'channel_activity':
              // Convert to NameCount list format
              if (metricValue is Map) {
                final activity = <Map<String, dynamic>>[];
                metricValue.forEach((key, value) {
                  activity.add({'name': key, 'count': value});
                });
                result['slack_channel_activity'] = activity;
              } else if (metricValue is List) {
                result['slack_channel_activity'] = metricValue;
              }
              break;
            case 'engagement_trend':
              if (metricValue is List) {
                result['slack_engagement_trend'] = metricValue;
              }
              break;
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('[DashboardMetricsService] Error fetching Slack analytics: $e');
      return {};
    }
  }

  /// Fetch social media stats from social_media_stats table
  Future<Map<String, dynamic>> fetchSocialMediaStats() async {
    final client = _client;
    if (client == null) return {};

    try {
      // Fetch latest stats grouped by platform
      final response = await client
          .from('social_media_stats')
          .select()
          .order('metric_date', ascending: false)
          .limit(20);

      if (response.isEmpty) return {};

      // Aggregate stats across platforms
      int totalFollowers = 0;
      int totalReach = 0;
      int totalLikes = 0;
      int totalEngagements = 0;
      final platformFollowers = <Map<String, dynamic>>[];
      final seenPlatforms = <String>{};

      for (final row in response) {
        final platform = row['platform'] as String? ?? 'Unknown';

        // Only count each platform once (most recent)
        if (!seenPlatforms.contains(platform)) {
          seenPlatforms.add(platform);

          final followers = row['followers_count'] as int? ?? 0;
          final reach = row['reach'] as int? ?? 0;
          final likes = row['likes_count'] as int? ?? 0;
          final impressions = row['impressions'] as int? ?? 0;

          totalFollowers += followers;
          totalReach += reach;
          totalLikes += likes;
          totalEngagements +=
              likes +
              (row['comments_count'] as int? ?? 0) +
              (row['shares_count'] as int? ?? 0);

          platformFollowers.add({'name': platform, 'count': followers});
        }
      }

      // Calculate engagement rate
      final engagementRate = totalReach > 0
          ? totalEngagements / totalReach
          : 0.0;

      return {
        'total_followers': totalFollowers,
        'social_media_reach': totalReach,
        'social_engagement_rate': engagementRate,
        'followers_by_platform': platformFollowers,
      };
    } catch (e) {
      debugPrint('[DashboardMetricsService] Error fetching social media stats: $e');
      return {};
    }
  }

  /// Fetch legislation statistics from legislation_statistics table
  Future<Map<String, dynamic>> fetchLegislationStats() async {
    final client = _client;
    if (client == null) return {};

    try {
      // Fetch the latest legislation statistics row
      final response = await client
          .from('legislation_statistics')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return {};

      // Extract relevant fields
      return {
        'total_bills_tracked': response['total_bills'] ?? 0,
        'bills_supported': response['support_count'] ?? 0,
        'bills_opposed': response['oppose_count'] ?? 0,
        'priority_bills':
            response['priority_count'] ?? response['high_priority_count'] ?? 0,
        'bills_by_position': [
          {'name': 'Support', 'count': response['support_count'] ?? 0},
          {'name': 'Oppose', 'count': response['oppose_count'] ?? 0},
          {'name': 'Neutral', 'count': response['neutral_count'] ?? 0},
          {'name': 'Watch', 'count': response['watch_count'] ?? 0},
        ],
        'bills_by_priority': [
          {'name': 'High', 'count': response['high_priority_count'] ?? 0},
          {'name': 'Medium', 'count': response['medium_priority_count'] ?? 0},
          {'name': 'Low', 'count': response['low_priority_count'] ?? 0},
        ],
      };
    } catch (e) {
      debugPrint('[DashboardMetricsService] Error fetching legislation stats: $e');
      return {};
    }
  }

  /// Fetch email campaign statistics from email_campaign_statistics table
  Future<Map<String, dynamic>> fetchEmailCampaignStats() async {
    final client = _client;
    if (client == null) return {};

    try {
      final response = await client
          .from('email_campaign_statistics')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) return {};

      return {
        'total_campaigns': response['total_campaigns'] ?? 0,
        'campaigns_sent': response['campaigns_sent_this_month'] ?? 0,
        'total_emails_sent': response['total_emails_sent'] ?? 0,
        'total_emails_opened': response['total_unique_opens'] ?? 0,
        'total_emails_clicked': response['total_unique_clicks'] ?? 0,
        'average_open_rate': (response['average_open_rate'] is num)
            ? (response['average_open_rate'] as num).toDouble() / 100.0
            : 0.0,
        'average_click_rate': (response['average_click_rate'] is num)
            ? (response['average_click_rate'] as num).toDouble() / 100.0
            : 0.0,
        'email_unsubscribe_rate': (response['average_unsubscribe_rate'] is num)
            ? (response['average_unsubscribe_rate'] as num).toDouble() / 100.0
            : 0.0,
      };
    } catch (e) {
      debugPrint(
        '[DashboardMetricsService] Error fetching email campaign stats: $e',
      );
      return {};
    }
  }

  /// Fetch all metrics including additional stats from other tables
  Future<DashboardMetrics?> fetchMetricsWithAdditionalStats() async {
    final baseMetrics = await fetchMetrics();
    if (baseMetrics == null) return null;

    // Fetch additional stats in parallel
    final results = await Future.wait([
      fetchSlackAnalytics(),
      fetchSocialMediaStats(),
      fetchLegislationStats(),
      fetchEmailCampaignStats(),
    ]);

    final slackData = results[0];
    final socialData = results[1];
    final legislationData = results[2];
    final emailData = results[3];

    // Merge all data into a combined JSON and recreate the metrics
    // IMPORTANT: Include ALL fields from baseMetrics, including JSONB array fields!
    final combinedJson = <String, dynamic>{
      'id': baseMetrics.id,
      'total_members': baseMetrics.totalMembers,
      'total_members_with_phone': baseMetrics.totalMembersWithPhone,
      'total_subscribers': baseMetrics.totalSubscribers,
      'total_donors': baseMetrics.totalDonors,
      'total_chapters': baseMetrics.totalChapters,
      'total_chartered_chapters': baseMetrics.totalCharteredChapters,
      'total_college_chapters': baseMetrics.totalCollegeChapters,
      'total_highschool_chapters': baseMetrics.totalHighschoolChapters,
      'total_county_chapters': baseMetrics.totalCountyChapters,
      'total_unique_colleges': baseMetrics.totalUniqueColleges,
      'total_unique_high_schools': baseMetrics.totalUniqueHighSchools,
      'total_unique_counties': baseMetrics.totalUniqueCounties,
      'total_unique_congressional_districts':
          baseMetrics.totalUniqueCongressionalDistricts,
      'total_unique_house_districts': baseMetrics.totalUniqueHouseDistricts,
      'total_unique_senate_districts': baseMetrics.totalUniqueSenateDistricts,
      'total_donations_amount': baseMetrics.totalDonationsAmount,
      'total_donation_count': baseMetrics.totalDonationCount,
      'average_donation_amount': baseMetrics.averageDonationAmount,
      'total_recurring_donors': baseMetrics.totalRecurringDonors,
      'donations_this_month': baseMetrics.donationsThisMonth,
      'donations_this_year': baseMetrics.donationsThisYear,
      'total_slack_messages': baseMetrics.totalSlackMessages,
      'slack_messages_this_month': baseMetrics.slackMessagesThisMonth,
      'total_social_impressions': baseMetrics.totalSocialImpressions,
      'age_14_17_count': baseMetrics.age14To17Count,
      'age_18_21_count': baseMetrics.age18To21Count,
      'age_22_25_count': baseMetrics.age22To25Count,
      'age_26_30_count': baseMetrics.age26To30Count,
      'age_31_36_count': baseMetrics.age31To36Count,
      'age_unknown_count': baseMetrics.ageUnknownCount,
      'average_member_age': baseMetrics.averageMemberAge,
      'new_members_this_week': baseMetrics.newMembersThisWeek,
      'new_members_this_month': baseMetrics.newMembersThisMonth,
      'new_members_this_year': baseMetrics.newMembersThisYear,
      'new_subscribers_this_month': baseMetrics.newSubscribersThisMonth,
      'total_campaigns': baseMetrics.totalCampaigns,
      'campaigns_sent': baseMetrics.campaignsSent,
      'total_emails_sent': baseMetrics.totalEmailsSent,
      'total_emails_opened': baseMetrics.totalEmailsOpened,
      'total_emails_clicked': baseMetrics.totalEmailsClicked,
      'average_open_rate': baseMetrics.averageOpenRate,
      'average_click_rate': baseMetrics.averageClickRate,
      'total_events': baseMetrics.totalEvents,
      'upcoming_events': baseMetrics.upcomingEvents,
      'total_event_attendees': baseMetrics.totalEventAttendees,
      // JSONB array fields - TOP DONORS AND SLACK MEMBERS
      'top_5_donors': baseMetrics.top5Donors
          .map((d) => {'name': d.name, 'email': d.email, 'total_donated': d.totalDonated})
          .toList(),
      'top_50_slack_members': baseMetrics.top50SlackMembers
          .map((m) => {
                'id': m.id,
                'name': m.name,
                'email': m.email,
                'message_count': m.messageCount,
                'profile_photo_url': m.profilePhotoUrl,
              })
          .toList(),
      // JSONB array fields - DISTRIBUTION DATA
      'members_by_county': baseMetrics.membersByCounty
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_congressional_district': baseMetrics.membersByCongressionalDistrict
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_house_district': baseMetrics.membersByHouseDistrict
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_senate_district': baseMetrics.membersBySenateDistrict
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_community_type': baseMetrics.membersByCommunityType
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_age': baseMetrics.membersByAge
          .map((ac) => {'age': ac.age, 'count': ac.count})
          .toList(),
      'members_by_college': baseMetrics.membersByCollege
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_high_school': baseMetrics.membersByHighSchool
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_graduation_year': baseMetrics.membersByGraduationYear
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_education_level': baseMetrics.membersByEducationLevel
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_in_school_status': baseMetrics.membersByInSchoolStatus
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_chapter': baseMetrics.membersByChapter
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_chapter_status': baseMetrics.membersByChapterStatus
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_chapter_position': baseMetrics.membersByChapterPosition
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_committee': baseMetrics.membersByCommittee
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_gender_identity': baseMetrics.membersByGenderIdentity
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_pronouns': baseMetrics.membersByPronouns
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_race': baseMetrics.membersByRace
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_sexual_orientation': baseMetrics.membersBySexualOrientation
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_hispanic_latino': baseMetrics.membersByHispanicLatino
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_religion': baseMetrics.membersByReligion
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_disability': baseMetrics.membersByDisability
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_languages': baseMetrics.membersByLanguages
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_industry': baseMetrics.membersByIndustry
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_employment_status': baseMetrics.membersByEmploymentStatus
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_voter_registration': baseMetrics.membersByVoterRegistration
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_desire_to_lead': baseMetrics.membersByDesireToLead
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_hours_per_week': baseMetrics.membersByHoursPerWeek
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_referral_source': baseMetrics.membersByReferralSource
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_by_areas_of_interest': baseMetrics.membersByAreasOfInterest
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'members_joined_by_month': baseMetrics.membersJoinedByMonth
          .map((mc) => {'month': mc.month, 'count': mc.count})
          .toList(),
      // Slack JSONB array fields from base metrics (may be overridden by slackData)
      'slack_channel_activity': baseMetrics.slackChannelActivity
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'slack_engagement_trend': baseMetrics.slackEngagementTrend
          .map((mc) => {'month': mc.month, 'count': mc.count})
          .toList(),
      // Social media JSONB array fields from base metrics (may be overridden by socialData)
      'followers_by_platform': baseMetrics.followersByPlatform
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'social_growth_trend': baseMetrics.socialGrowthTrend
          .map((mc) => {'month': mc.month, 'count': mc.count})
          .toList(),
      // Legislation JSONB array fields from base metrics (may be overridden by legislationData)
      'bills_by_position': baseMetrics.billsByPosition
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'bills_by_priority': baseMetrics.billsByPriority
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      'bills_by_category': baseMetrics.billsByCategory
          .map((nc) => {'name': nc.name, 'count': nc.count})
          .toList(),
      // Add Slack analytics (overrides above if present)
      ...slackData,
      // Add social media stats
      ...socialData,
      // Add legislation stats
      ...legislationData,
      // Add email campaign stats
      ...emailData,
    };

    return DashboardMetrics.fromJson(combinedJson);
  }
}
