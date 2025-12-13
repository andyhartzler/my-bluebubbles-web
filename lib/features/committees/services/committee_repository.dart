import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show CountOption, PostgrestResponse;

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Repository for committee-related data operations
class CommitteeRepository {
  static final CommitteeRepository _instance = CommitteeRepository._internal();
  factory CommitteeRepository() => _instance;
  CommitteeRepository._internal();

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Get all members belonging to a committee
  Future<List<Member>> getMembersForCommittee(String committeeName, {int? limit}) async {
    if (!isReady) return [];

    try {
      var query = _readClient
          .from('members')
          .select()
          .contains('committee', [committeeName])
          .order('name', ascending: true);

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      final data = await query;
      return _mapMembers(data as List<dynamic>);
    } catch (e) {
      print('Error fetching committee members: $e');
      return [];
    }
  }

  /// Get member count for a committee
  Future<int> getMemberCountForCommittee(String committeeName) async {
    if (!isReady) return 0;

    try {
      final PostgrestResponse response = await _readClient
          .from('members')
          .select('id')
          .contains('committee', [committeeName])
          .count(CountOption.exact);
      return response.count ?? 0;
    } catch (e) {
      print('Error counting committee members: $e');
      return 0;
    }
  }

  /// Add a member to a committee
  /// Updates the committee array column for the member
  Future<bool> addMemberToCommittee(String memberId, String committeeName) async {
    if (!isReady) return false;

    try {
      final writeClient = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

      // First get the current committee list for this member
      final memberData = await _readClient
          .from('members')
          .select('committee')
          .eq('id', memberId)
          .single();

      final currentCommittees = <String>[];
      if (memberData['committee'] != null) {
        currentCommittees.addAll(
          (memberData['committee'] as List<dynamic>).map((e) => e.toString()),
        );
      }

      // Check if already in committee
      if (currentCommittees.contains(committeeName)) {
        return true; // Already a member
      }

      // Add the new committee
      currentCommittees.add(committeeName);

      // Update the member
      await writeClient
          .from('members')
          .update({'committee': currentCommittees})
          .eq('id', memberId);

      return true;
    } catch (e) {
      print('Error adding member to committee: $e');
      return false;
    }
  }

  /// Remove a member from a committee
  /// Updates the committee array column for the member
  Future<bool> removeMemberFromCommittee(String memberId, String committeeName) async {
    if (!isReady) return false;

    try {
      final writeClient = _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

      // First get the current committee list for this member
      final memberData = await _readClient
          .from('members')
          .select('committee')
          .eq('id', memberId)
          .single();

      final currentCommittees = <String>[];
      if (memberData['committee'] != null) {
        currentCommittees.addAll(
          (memberData['committee'] as List<dynamic>).map((e) => e.toString()),
        );
      }

      // Remove the committee
      currentCommittees.remove(committeeName);

      // Update the member
      await writeClient
          .from('members')
          .update({'committee': currentCommittees})
          .eq('id', memberId);

      return true;
    } catch (e) {
      print('Error removing member from committee: $e');
      return false;
    }
  }

  /// Get all members NOT in a specific committee (for adding new members)
  Future<List<Member>> getMembersNotInCommittee(String committeeName, {String? searchQuery}) async {
    if (!isReady) return [];

    try {
      // Get all members and filter out those in the committee
      var query = _readClient
          .from('members')
          .select()
          .order('name', ascending: true);

      final data = await query;
      final allMembers = _mapMembers(data as List<dynamic>);

      // Filter to members NOT in this committee
      var filtered = allMembers.where((m) {
        final committees = m.committee ?? [];
        return !committees.contains(committeeName);
      }).toList();

      // Apply search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        filtered = filtered.where((m) {
          return m.name.toLowerCase().contains(query) ||
              (m.email?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      return filtered.take(50).toList(); // Limit results
    } catch (e) {
      print('Error fetching non-committee members: $e');
      return [];
    }
  }

  /// Get committee leadership (executive committee members for this committee)
  /// Looks at executive_committee = TRUE and executive_role column for committee name
  Future<List<CommitteeLeader>> getCommitteeLeadership(String committeeName) async {
    if (!isReady) return [];

    try {
      // Use ilike to handle variations like "Communications" matching "Communications Committee"
      final data = await _readClient
          .from('members')
          .select('id, name, executive_title, executive_role, profile_pictures, email, phone')
          .eq('executive_committee', true)
          .ilike('executive_role', '%$committeeName%');

      final leaders = <CommitteeLeader>[];
      for (final item in data as List<dynamic>) {
        if (item is! Map<String, dynamic>) continue;
        final member = Member.fromJson(item);
        leaders.add(CommitteeLeader(
          memberId: member.id,
          name: member.name,
          title: member.executiveTitle,
          photoUrl: member.primaryProfilePhotoUrl,
          email: member.preferredEmail,
          phone: member.primaryPhone,
        ));
      }
      return leaders;
    } catch (e) {
      print('Error fetching committee leadership: $e');
      return [];
    }
  }

  /// Get statistics for a specific committee
  Future<CommitteeStats> getCommitteeStats(Committee committee) async {
    if (!isReady) {
      return const CommitteeStats();
    }

    try {
      final results = await Future.wait([
        getMemberCountForCommittee(committee.name),
        getCommitteeLeadership(committee.name),
        _getCommitteeSpecificStats(committee),
      ]);

      final memberCount = results[0] as int;
      final leaders = results[1] as List<CommitteeLeader>;
      final specificStats = results[2] as Map<String, dynamic>;

      // Separate chairs and co-chairs (supports multiple of each)
      final chairs = <CommitteeLeader>[];
      final coChairs = <CommitteeLeader>[];

      for (final leader in leaders) {
        final title = leader.title?.toLowerCase() ?? '';
        if (title.contains('co-chair') || title.contains('vice')) {
          coChairs.add(leader);
        } else if (title.contains('chair')) {
          chairs.add(leader);
        }
      }

      return CommitteeStats(
        memberCount: memberCount,
        chairs: chairs,
        coChairs: coChairs,
        specificStats: specificStats,
      );
    } catch (e) {
      print('Error getting committee stats: $e');
      return const CommitteeStats();
    }
  }

  /// Get committee-specific statistics
  Future<Map<String, dynamic>> _getCommitteeSpecificStats(Committee committee) async {
    final stats = <String, dynamic>{};

    try {
      switch (committee.id) {
        case 'Communications':
          stats.addAll(await _getCommunicationsStats());
          break;
        case 'Political Affairs':
          stats.addAll(await _getPoliticalAffairsStats());
          break;
        case 'Policy & Advocacy':
          stats.addAll(await _getPolicyAdvocacyStats());
          break;
        case 'Membership & Outreach':
          stats.addAll(await _getMembershipOutreachStats());
          break;
        case 'Fundraising':
          stats.addAll(await _getFundraisingStats());
          break;
        case 'College Democrats':
          stats.addAll(await _getCollegeDemocratsStats());
          break;
        case 'High School Democrats':
          stats.addAll(await _getHighSchoolDemocratsStats());
          break;
      }
    } catch (e) {
      print('Error getting specific stats for ${committee.name}: $e');
    }

    return stats;
  }

  Future<Map<String, dynamic>> _getCommunicationsStats() async {
    final stats = <String, dynamic>{};

    try {
      // Get latest stats for all accounts in one query using distinct on account_id
      // This gets the most recent stat row per account
      final statsResponse = await _readClient
          .from('social_media_stats')
          .select('account_id, platform, impressions, followers_count, platform_metrics')
          .order('metric_date', ascending: false);

      final allStats = statsResponse as List<dynamic>;

      // Deduplicate to get only the latest stat per account_id
      final latestByAccount = <String, Map<String, dynamic>>{};
      for (final stat in allStats) {
        final accountId = stat['account_id'] as String?;
        if (accountId != null && !latestByAccount.containsKey(accountId)) {
          latestByAccount[accountId] = stat as Map<String, dynamic>;
        }
      }

      int totalImpressions = 0;
      int totalFollowers = 0;

      for (final stat in latestByAccount.values) {
        final platform = (stat['platform'] as String?)?.toLowerCase() ?? '';

        // First try direct column values (these should have the correct data)
        int impressions = _toInt(stat['impressions']);
        int followers = _toInt(stat['followers_count']);

        // If direct values are 0, try to get from platform_metrics
        if (impressions == 0 || followers == 0) {
          final platformMetrics = stat['platform_metrics'];
          Map<String, dynamic>? metrics;

          if (platformMetrics is Map<String, dynamic>) {
            metrics = platformMetrics;
          } else if (platformMetrics is Map) {
            metrics = Map<String, dynamic>.from(platformMetrics);
          } else if (platformMetrics is String && platformMetrics.isNotEmpty) {
            try {
              final decoded = jsonDecode(platformMetrics);
              if (decoded is Map) {
                metrics = Map<String, dynamic>.from(decoded);
              }
            } catch (_) {}
          }

          if (metrics != null) {
            final last30Days = metrics['last_30_days'] as Map<String, dynamic>?;
            final totals = last30Days?['totals'] as Map<String, dynamic>?;

            if (impressions == 0) {
              if (platform == 'facebook') {
                impressions = _toInt(totals?['media_views']);
              } else if (platform == 'instagram' || platform == 'threads') {
                impressions = _toInt(totals?['views']);
              } else if (platform == 'youtube') {
                final statistics = metrics['statistics'] as Map<String, dynamic>?;
                final aggregates = metrics['aggregates'] as Map<String, dynamic>?;
                impressions = _toInt(statistics?['viewCount'] ?? aggregates?['totalViews']);
              }
            }

            if (followers == 0) {
              if (platform == 'youtube') {
                final statistics = metrics['statistics'] as Map<String, dynamic>?;
                followers = _toInt(statistics?['subscriberCount']);
              } else {
                final account = metrics['account'] as Map<String, dynamic>?;
                followers = _toInt(account?['current_followers']);
              }
            }
          }
        }

        totalImpressions += impressions;
        totalFollowers += followers;
      }

      stats['totalImpressions'] = totalImpressions;
      stats['totalFollowers'] = totalFollowers;
    } catch (e) {
      print('Error getting communications stats: $e');
      stats['totalImpressions'] = 0;
      stats['totalFollowers'] = 0;
    }

    return stats;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<Map<String, dynamic>> _getPoliticalAffairsStats() async {
    final stats = <String, dynamic>{};

    try {
      // Total events count
      final PostgrestResponse totalResponse = await _readClient
          .from('events')
          .select('id')
          .count(CountOption.exact);
      stats['totalEvents'] = totalResponse.count ?? 0;

      // Upcoming events count
      final PostgrestResponse upcomingResponse = await _readClient
          .from('events')
          .select('id')
          .gte('event_date', DateTime.now().toIso8601String())
          .count(CountOption.exact);
      stats['upcomingEvents'] = upcomingResponse.count ?? 0;
    } catch (e) {
      print('Error getting political affairs stats: $e');
      stats['totalEvents'] = 0;
      stats['upcomingEvents'] = 0;
    }

    return stats;
  }

  Future<Map<String, dynamic>> _getPolicyAdvocacyStats() async {
    final stats = <String, dynamic>{};

    try {
      // Total advocacy emails generated
      final PostgrestResponse generatedResponse = await _readClient
          .from('hanaway_campaign_tracking')
          .select('id')
          .count(CountOption.exact);
      stats['totalAdvocacyEmailsGenerated'] = generatedResponse.count ?? 0;

      // Total advocacy emails sent
      final PostgrestResponse sentResponse = await _readClient
          .from('hanaway_campaign_tracking')
          .select('id')
          .not('sent_at', 'is', null)
          .count(CountOption.exact);
      stats['totalAdvocacyEmailsSent'] = sentResponse.count ?? 0;
    } catch (e) {
      print('Error getting policy & advocacy stats: $e');
      stats['totalAdvocacyEmailsGenerated'] = 0;
      stats['totalAdvocacyEmailsSent'] = 0;
    }

    return stats;
  }

  Future<Map<String, dynamic>> _getMembershipOutreachStats() async {
    final stats = <String, dynamic>{};

    try {
      // Total member count
      final PostgrestResponse totalResponse = await _readClient
          .from('members')
          .select('id')
          .count(CountOption.exact);
      stats['totalMembers'] = totalResponse.count ?? 0;

      // Active members count
      final PostgrestResponse activeResponse = await _readClient
          .from('members')
          .select('id')
          .eq('current_chapter_member', 'Yes')
          .count(CountOption.exact);
      stats['activeMembers'] = activeResponse.count ?? 0;
    } catch (e) {
      print('Error getting membership & outreach stats: $e');
      stats['totalMembers'] = 0;
      stats['activeMembers'] = 0;
    }

    return stats;
  }

  Future<Map<String, dynamic>> _getFundraisingStats() async {
    final stats = <String, dynamic>{};

    try {
      // Total donors count
      final PostgrestResponse donorResponse = await _readClient
          .from('donors')
          .select('id')
          .count(CountOption.exact);
      stats['totalDonors'] = donorResponse.count ?? 0;

      // Total amount raised
      final donorData = await _readClient
          .from('donors')
          .select('total_donated');

      double totalRaised = 0;
      for (final item in donorData as List<dynamic>) {
        if (item is Map && item['total_donated'] != null) {
          totalRaised += (item['total_donated'] as num).toDouble();
        }
      }
      stats['totalRaised'] = totalRaised;
    } catch (e) {
      print('Error getting fundraising stats: $e');
      stats['totalDonors'] = 0;
      stats['totalRaised'] = 0.0;
    }

    return stats;
  }

  Future<Map<String, dynamic>> _getCollegeDemocratsStats() async {
    final stats = <String, dynamic>{};

    try {
      // Total college chapters
      final PostgrestResponse totalResponse = await _readClient
          .from('chapters')
          .select('chapter_name')
          .eq('chapter_type', 'college')
          .count(CountOption.exact);
      stats['totalCollegeChapters'] = totalResponse.count ?? 0;

      // Chartered college chapters
      final PostgrestResponse charteredResponse = await _readClient
          .from('chapters')
          .select('chapter_name')
          .eq('chapter_type', 'college')
          .eq('is_chartered', true)
          .count(CountOption.exact);
      stats['charteredCollegeChapters'] = charteredResponse.count ?? 0;

      // Unique colleges represented (from members in this committee only)
      final collegeData = await _readClient
          .from('members')
          .select('college')
          .not('college', 'is', null)
          .contains('committee', ['College Democrats']);

      final uniqueColleges = <String>{};
      for (final item in collegeData as List<dynamic>) {
        if (item is Map) {
          final college = item['college']?.toString().trim();
          if (college != null && college.isNotEmpty) {
            uniqueColleges.add(college);
          }
        }
      }
      stats['uniqueColleges'] = uniqueColleges.length;
    } catch (e) {
      print('Error getting college democrats stats: $e');
      stats['totalCollegeChapters'] = 0;
      stats['charteredCollegeChapters'] = 0;
      stats['uniqueColleges'] = 0;
    }

    return stats;
  }

  Future<Map<String, dynamic>> _getHighSchoolDemocratsStats() async {
    final stats = <String, dynamic>{};

    try {
      // Total high school chapters
      final PostgrestResponse totalResponse = await _readClient
          .from('chapters')
          .select('chapter_name')
          .eq('chapter_type', 'highschool')
          .count(CountOption.exact);
      stats['totalHSChapters'] = totalResponse.count ?? 0;

      // Chartered high school chapters
      final PostgrestResponse charteredResponse = await _readClient
          .from('chapters')
          .select('chapter_name')
          .eq('chapter_type', 'highschool')
          .eq('is_chartered', true)
          .count(CountOption.exact);
      stats['charteredHSChapters'] = charteredResponse.count ?? 0;

      // Unique high schools represented (from members in this committee only)
      final hsData = await _readClient
          .from('members')
          .select('high_school')
          .not('high_school', 'is', null)
          .contains('committee', ['High School Democrats']);

      final uniqueHS = <String>{};
      for (final item in hsData as List<dynamic>) {
        if (item is Map) {
          final hs = item['high_school']?.toString().trim();
          if (hs != null && hs.isNotEmpty) {
            uniqueHS.add(hs);
          }
        }
      }
      stats['uniqueHighSchools'] = uniqueHS.length;
    } catch (e) {
      print('Error getting high school democrats stats: $e');
      stats['totalHSChapters'] = 0;
      stats['charteredHSChapters'] = 0;
      stats['uniqueHighSchools'] = 0;
    }

    return stats;
  }

  /// Get distribution of colleges with member counts
  /// If committeeName is provided, only includes members in that committee
  Future<Map<String, int>> getCollegeDistribution({String? committeeName}) async {
    if (!isReady) return {};

    try {
      // Get members with a college field, optionally filtered by committee
      var query = _readClient
          .from('members')
          .select('college')
          .not('college', 'is', null);

      if (committeeName != null) {
        query = query.contains('committee', [committeeName]);
      }

      final collegeData = await query;

      final distribution = <String, int>{};
      for (final item in collegeData as List<dynamic>) {
        if (item is Map) {
          final college = item['college']?.toString().trim();
          if (college != null && college.isNotEmpty) {
            distribution[college] = (distribution[college] ?? 0) + 1;
          }
        }
      }
      return distribution;
    } catch (e) {
      print('Error getting college distribution: $e');
      return {};
    }
  }

  /// Get distribution of high schools with member counts
  /// If committeeName is provided, only includes members in that committee
  Future<Map<String, int>> getHighSchoolDistribution({String? committeeName}) async {
    if (!isReady) return {};

    try {
      // Get members with a high_school field, optionally filtered by committee
      var query = _readClient
          .from('members')
          .select('high_school')
          .not('high_school', 'is', null);

      if (committeeName != null) {
        query = query.contains('committee', [committeeName]);
      }

      final hsData = await query;

      final distribution = <String, int>{};
      for (final item in hsData as List<dynamic>) {
        if (item is Map) {
          final hs = item['high_school']?.toString().trim();
          if (hs != null && hs.isNotEmpty) {
            distribution[hs] = (distribution[hs] ?? 0) + 1;
          }
        }
      }
      return distribution;
    } catch (e) {
      print('Error getting high school distribution: $e');
      return {};
    }
  }

  /// Get Slack channel ID for a committee
  /// Uses ilike to handle variations like "Communications" matching "Communications Committee"
  Future<String?> getSlackChannelId(String committeeName) async {
    if (!isReady) return null;

    try {
      // Use ilike to handle name variations in the mapping table
      final data = await _readClient
          .from('slack_channel_committee_mapping')
          .select('slack_channel_id')
          .ilike('committee_name', '%$committeeName%')
          .eq('is_active', true)
          .maybeSingle();

      if (data is Map<String, dynamic>) {
        return data['slack_channel_id']?.toString();
      }
      return null;
    } catch (e) {
      print('Error getting Slack channel ID: $e');
      return null;
    }
  }

  /// Get Slack user mapping for parsing mentions
  Future<Map<String, Map<String, String>>> getSlackUserMappings() async {
    if (!isReady) return {};

    try {
      // Use correct column names from slack_user_mapping table
      final data = await _readClient
          .from('slack_user_mapping')
          .select('slack_user_id, slack_real_name, slack_display_name, slack_avatar_url, member_id');

      final mappings = <String, Map<String, String>>{};
      for (final item in data as List<dynamic>) {
        if (item is Map) {
          final slackUserId = item['slack_user_id']?.toString();
          if (slackUserId != null) {
            mappings[slackUserId] = {
              'real_name': item['slack_real_name']?.toString() ?? '',
              'display_name': item['slack_display_name']?.toString() ?? '',
              'avatar_url': item['slack_avatar_url']?.toString() ?? '',
              'member_id': item['member_id']?.toString() ?? '',
            };
          }
        }
      }
      return mappings;
    } catch (e) {
      print('Error getting Slack user mappings: $e');
      return {};
    }
  }

  /// Get Slack messages for a committee
  Future<List<Map<String, dynamic>>> getSlackMessages(
    String committeeName, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    try {
      final channelId = await getSlackChannelId(committeeName);
      if (channelId == null) {
        print('No channel ID found for committee: $committeeName');
        return [];
      }

      print('Fetching messages for channel: $channelId (committee: $committeeName)');

      // Query messages without join - user info will be matched via getSlackUserMappings
      final data = await _readClient
          .from('slack_messages')
          .select('id, slack_message_ts, slack_channel_id, slack_user_id, member_id, message_text, message_type, thread_ts, posted_at, has_files, files, files_archived, reactions')
          .eq('slack_channel_id', channelId)
          .order('posted_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('Found ${(data as List).length} messages');
      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting Slack messages: $e');
      return [];
    }
  }

  /// Get Slack messages by channel ID directly
  Future<List<Map<String, dynamic>>> getSlackMessagesByChannelId(
    String channelId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('slack_messages')
          .select('id, slack_message_ts, slack_channel_id, slack_user_id, member_id, message_text, message_type, thread_ts, posted_at, has_files, files, files_archived, reactions')
          .eq('slack_channel_id', channelId)
          .order('posted_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting Slack messages by channel ID: $e');
      return [];
    }
  }

  /// Get advocacy campaign data for Policy & Advocacy
  Future<Map<String, dynamic>> getAdvocacyCampaignData() async {
    if (!isReady) {
      return {
        'totalGenerated': 0,
        'totalSent': 0,
        'uniqueParticipants': 0,
        'sendMethodBreakdown': <String, int>{},
        'participantsByZip': <String, int>{},
        'participants': <Map<String, dynamic>>[],
      };
    }

    try {
      final data = await _readClient
          .from('hanaway_campaign_tracking')
          .select()
          .order('created_at', ascending: false);

      final records = (data as List<dynamic>).cast<Map<String, dynamic>>();

      int totalGenerated = records.length;
      int totalSent = 0;
      final uniqueEmails = <String>{};
      final sendMethodBreakdown = <String, int>{};
      final participantsByZip = <String, int>{};

      for (final record in records) {
        // Count sent
        if (record['sent_at'] != null) {
          totalSent++;
        }

        // Unique participants
        final email = record['user_email']?.toString();
        if (email != null && email.isNotEmpty) {
          uniqueEmails.add(email.toLowerCase());
        }

        // Send method breakdown
        final method = record['send_method']?.toString() ?? 'unknown';
        sendMethodBreakdown[method] = (sendMethodBreakdown[method] ?? 0) + 1;

        // By zip code
        final zip = record['user_zip_code']?.toString();
        if (zip != null && zip.isNotEmpty) {
          participantsByZip[zip] = (participantsByZip[zip] ?? 0) + 1;
        }
      }

      return {
        'totalGenerated': totalGenerated,
        'totalSent': totalSent,
        'uniqueParticipants': uniqueEmails.length,
        'sendMethodBreakdown': sendMethodBreakdown,
        'participantsByZip': participantsByZip,
        'participants': records.take(100).toList(),
      };
    } catch (e) {
      print('Error getting advocacy campaign data: $e');
      return {
        'totalGenerated': 0,
        'totalSent': 0,
        'uniqueParticipants': 0,
        'sendMethodBreakdown': <String, int>{},
        'participantsByZip': <String, int>{},
        'participants': <Map<String, dynamic>>[],
      };
    }
  }

  /// Get enriched campaign data with member/subscriber lookups for detailed view
  Future<Map<String, dynamic>> getEnrichedCampaignData() async {
    if (!isReady) {
      return _emptyEnrichedData();
    }

    try {
      // Fetch all campaign tracking records
      final data = await _readClient
          .from('hanaway_campaign_tracking')
          .select()
          .order('created_at', ascending: false);

      final records = (data as List<dynamic>).cast<Map<String, dynamic>>();

      // Collect unique emails for batch lookup
      final uniqueEmails = <String>{};
      for (final record in records) {
        final email = record['user_email']?.toString()?.toLowerCase();
        if (email != null && email.isNotEmpty) {
          uniqueEmails.add(email);
        }
      }

      // Batch fetch members and subscribers by email
      final membersByEmail = await _fetchMembersByEmails(uniqueEmails.toList());
      final subscribersByEmail = await _fetchSubscribersByEmails(uniqueEmails.toList());

      // Process records with enriched data
      int totalGenerated = records.length;
      int totalSent = 0;
      final sendMethodBreakdown = <String, int>{};
      final participantsByZip = <String, int>{};
      final participantsByCounty = <String, int>{};
      final enrichedParticipants = <Map<String, dynamic>>[];

      for (final record in records) {
        // Count sent
        if (record['sent_at'] != null) {
          totalSent++;
        }

        // Send method breakdown
        final method = record['send_method']?.toString() ?? 'unknown';
        sendMethodBreakdown[method] = (sendMethodBreakdown[method] ?? 0) + 1;

        // By zip code
        final zip = record['user_zip_code']?.toString();
        if (zip != null && zip.isNotEmpty) {
          participantsByZip[zip] = (participantsByZip[zip] ?? 0) + 1;
        }

        // Look up member/subscriber
        final email = record['user_email']?.toString()?.toLowerCase() ?? '';
        final member = membersByEmail[email];
        final subscriber = subscribersByEmail[email];

        // Get county from member/subscriber if not in record
        String? county = member?.county ?? subscriber?.county;
        if (county != null && county.isNotEmpty) {
          // Normalize county name
          county = county.replaceFirst(RegExp(r'\s*county\$', caseSensitive: false), '').trim();
          if (county.isNotEmpty) {
            participantsByCounty[county] = (participantsByCounty[county] ?? 0) + 1;
          }
        }

        // Build enriched participant record
        enrichedParticipants.add({
          ...record,
          'linked_member': member?.toJson(),
          'linked_subscriber': subscriber != null ? _subscriberToJson(subscriber) : null,
          'profile_photo_url': member?.primaryProfilePhotoUrl,
          'county': county,
        });
      }

      return {
        'totalGenerated': totalGenerated,
        'totalSent': totalSent,
        'uniqueParticipants': uniqueEmails.length,
        'sendMethodBreakdown': sendMethodBreakdown,
        'participantsByZip': participantsByZip,
        'participantsByCounty': participantsByCounty,
        'participants': enrichedParticipants,
      };
    } catch (e) {
      print('Error getting enriched campaign data: $e');
      return _emptyEnrichedData();
    }
  }

  Map<String, dynamic> _emptyEnrichedData() {
    return {
      'totalGenerated': 0,
      'totalSent': 0,
      'uniqueParticipants': 0,
      'sendMethodBreakdown': <String, int>{},
      'participantsByZip': <String, int>{},
      'participantsByCounty': <String, int>{},
      'participants': <Map<String, dynamic>>[],
    };
  }

  /// Fetch members by email addresses in batch
  Future<Map<String, Member>> _fetchMembersByEmails(List<String> emails) async {
    if (emails.isEmpty) return {};

    try {
      final data = await _readClient
          .from('members')
          .select()
          .inFilter('email', emails);

      final members = <String, Member>{};
      for (final item in data as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          final member = Member.fromJson(item);
          final email = member.email?.toLowerCase();
          if (email != null) {
            members[email] = member;
          }
        }
      }
      return members;
    } catch (e) {
      print('Error fetching members by email: $e');
      return {};
    }
  }

  /// Fetch subscribers by email addresses in batch
  Future<Map<String, _SimpleSubscriber>> _fetchSubscribersByEmails(List<String> emails) async {
    if (emails.isEmpty) return {};

    try {
      final data = await _readClient
          .from('subscribers')
          .select()
          .inFilter('email', emails);

      final subscribers = <String, _SimpleSubscriber>{};
      for (final item in data as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          final email = (item['email'] as String?)?.toLowerCase();
          if (email != null) {
            subscribers[email] = _SimpleSubscriber.fromJson(item);
          }
        }
      }
      return subscribers;
    } catch (e) {
      print('Error fetching subscribers by email: $e');
      return {};
    }
  }

  Map<String, dynamic> _subscriberToJson(_SimpleSubscriber subscriber) {
    return {
      'id': subscriber.id,
      'email': subscriber.email,
      'name': subscriber.name,
      'phone': subscriber.phone,
      'zip_code': subscriber.zipCode,
      'county': subscriber.county,
      'state': subscriber.state,
      'source': subscriber.source,
      'tags': subscriber.tags,
    };
  }

  /// Get overall stats for the committees dashboard
  Future<Map<String, int>> getOverallStats() async {
    if (!isReady) {
      return {
        'slackMessages': 0,
        'totalImpressions': 0,
        'countiesRepresented': 0,
      };
    }

    final stats = <String, int>{};

    try {
      // Total Slack messages
      final PostgrestResponse slackResponse = await _readClient
          .from('slack_messages')
          .select('id')
          .count(CountOption.exact);
      stats['slackMessages'] = slackResponse.count ?? 0;
    } catch (e) {
      print('Error getting Slack messages count: $e');
      stats['slackMessages'] = 0;
    }

    try {
      // Total impressions from social media accounts
      final statsResponse = await _readClient
          .from('social_media_stats')
          .select('account_id, platform, impressions, platform_metrics')
          .order('metric_date', ascending: false);

      final allStats = statsResponse as List<dynamic>;

      // Deduplicate to get only the latest stat per account_id
      final latestByAccount = <String, Map<String, dynamic>>{};
      for (final stat in allStats) {
        final accountId = stat['account_id'] as String?;
        if (accountId != null && !latestByAccount.containsKey(accountId)) {
          latestByAccount[accountId] = stat as Map<String, dynamic>;
        }
      }

      int totalImpressions = 0;
      for (final stat in latestByAccount.values) {
        final platform = (stat['platform'] as String?)?.toLowerCase() ?? '';
        int impressions = _toInt(stat['impressions']);

        // If direct value is 0, try to get from platform_metrics
        if (impressions == 0) {
          final platformMetrics = stat['platform_metrics'];
          Map<String, dynamic>? metrics;

          if (platformMetrics is Map<String, dynamic>) {
            metrics = platformMetrics;
          } else if (platformMetrics is Map) {
            metrics = Map<String, dynamic>.from(platformMetrics);
          } else if (platformMetrics is String && platformMetrics.isNotEmpty) {
            try {
              final decoded = jsonDecode(platformMetrics);
              if (decoded is Map) {
                metrics = Map<String, dynamic>.from(decoded);
              }
            } catch (_) {}
          }

          if (metrics != null) {
            final last30Days = metrics['last_30_days'] as Map<String, dynamic>?;
            final totals = last30Days?['totals'] as Map<String, dynamic>?;

            if (platform == 'facebook') {
              impressions = _toInt(totals?['media_views']);
            } else if (platform == 'instagram' || platform == 'threads') {
              impressions = _toInt(totals?['views']);
            } else if (platform == 'youtube') {
              final statistics = metrics['statistics'] as Map<String, dynamic>?;
              final aggregates = metrics['aggregates'] as Map<String, dynamic>?;
              impressions = _toInt(statistics?['viewCount'] ?? aggregates?['totalViews']);
            }
          }
        }

        totalImpressions += impressions;
      }

      stats['totalImpressions'] = totalImpressions;
    } catch (e) {
      print('Error getting impressions count: $e');
      stats['totalImpressions'] = 0;
    }

    try {
      // Count unique counties from members table
      final countyData = await _readClient
          .from('members')
          .select('county')
          .not('county', 'is', null);

      final uniqueCounties = <String>{};
      for (final item in countyData as List<dynamic>) {
        if (item is Map) {
          final county = item['county']?.toString();
          if (county != null && county.isNotEmpty) {
            // Normalize county name (remove "County" suffix if present)
            final normalized = county
                .replaceAll(RegExp(r'\s*county\s*$', caseSensitive: false), '')
                .trim();
            if (normalized.isNotEmpty) {
              uniqueCounties.add(normalized.toLowerCase());
            }
          }
        }
      }
      stats['countiesRepresented'] = uniqueCounties.length;
    } catch (e) {
      print('Error getting counties count: $e');
      stats['countiesRepresented'] = 0;
    }

    return stats;
  }

  List<Member> _mapMembers(List<dynamic> data) {
    final members = <Member>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        members.add(Member.fromJson(item));
      } else if (item is Map) {
        final mapped = item.map((key, dynamic value) => MapEntry(key.toString(), value));
        members.add(Member.fromJson(mapped));
      }
    }
    return members;
  }

  /// Search for members by name or email (for canvas board entity picker)
  Future<List<Member>> searchMembers(String query, {int limit = 20}) async {
    if (!isReady || query.length < 2) return [];

    try {
      final searchQuery = query.toLowerCase();

      // Search by name (using ilike for case-insensitive partial matching)
      final data = await _readClient
          .from('members')
          .select()
          .or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%')
          .order('name', ascending: true)
          .limit(limit);

      return _mapMembers(data as List<dynamic>);
    } catch (e) {
      print('Error searching members: $e');
      return [];
    }
  }

  /// Get a member by ID (for canvas board entity loading)
  Future<Member?> getMemberById(String memberId) async {
    if (!isReady) return null;

    try {
      final data = await _readClient
          .from('members')
          .select()
          .eq('id', memberId)
          .maybeSingle();

      if (data == null) return null;
      return Member.fromJson(data);
    } catch (e) {
      print('Error fetching member by ID: $e');
      return null;
    }
  }
}

/// Simple subscriber model for campaign participant lookups
class _SimpleSubscriber {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? zipCode;
  final String? county;
  final String? state;
  final String? source;
  final String? tags;

  const _SimpleSubscriber({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.zipCode,
    this.county,
    this.state,
    this.source,
    this.tags,
  });

  factory _SimpleSubscriber.fromJson(Map<String, dynamic> json) {
    return _SimpleSubscriber(
      id: json['id'] as String,
      email: json['email'] as String,
      name: (json['name'] as String?)?.trim() ?? 'N/A',
      phone: json['phone'] as String?,
      zipCode: json['zip_code'] as String?,
      county: json['county'] as String?,
      state: json['state'] as String?,
      source: json['source'] as String?,
      tags: json['tags'] as String?,
    );
  }
}
