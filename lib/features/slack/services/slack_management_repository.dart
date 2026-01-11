import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show CountOption, PostgrestResponse;

import 'package:bluebubbles/features/slack/models/slack_channel.dart';
import 'package:bluebubbles/features/slack/models/slack_analytics.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/slack_activity.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Repository for Slack management page data operations
class SlackManagementRepository {
  static final SlackManagementRepository _instance =
      SlackManagementRepository._internal();
  factory SlackManagementRepository() => _instance;
  SlackManagementRepository._internal();

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  SupabaseClient get _writeClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  // ============================================
  // CHANNELS TAB - Channel & Message Operations
  // ============================================

  /// Get all active Slack channels
  Future<List<SlackChannel>> getChannels() async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('slack_channel_committee_mapping')
          .select()
          .eq('is_active', true)
          .order('slack_channel_name', ascending: true);

      return (data as List<dynamic>)
          .map((e) => SlackChannel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching Slack channels: $e');
      return [];
    }
  }

  /// Get archive status for a channel
  Future<SlackArchiveStatus?> getArchiveStatus(String channelId) async {
    if (!isReady) return null;

    try {
      final data = await _readClient
          .from('slack_message_archive_status')
          .select()
          .eq('slack_channel_id', channelId)
          .maybeSingle();

      if (data == null) return null;
      return SlackArchiveStatus.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching archive status: $e');
      return null;
    }
  }

  /// Get messages for a specific channel with pagination
  Future<List<Map<String, dynamic>>> getChannelMessages(
    String channelId, {
    int limit = 50,
    int offset = 0,
    String? searchQuery,
  }) async {
    if (!isReady) return [];

    try {
      var query = _readClient
          .from('slack_messages')
          .select(
              'id, slack_message_ts, slack_channel_id, slack_user_id, member_id, message_text, message_type, thread_ts, posted_at, has_files, files, files_archived, reactions')
          .eq('slack_channel_id', channelId);

      // Apply full-text search if query provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.textSearch('search_vector', searchQuery);
      }

      final data = await query
          .order('posted_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching channel messages: $e');
      return [];
    }
  }

  /// Get thread messages for a specific parent message
  Future<List<Map<String, dynamic>>> getThreadMessages(
      String channelId, String threadTs) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('slack_messages')
          .select()
          .eq('slack_channel_id', channelId)
          .eq('thread_ts', threadTs)
          .order('posted_at', ascending: true);

      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching thread messages: $e');
      return [];
    }
  }

  /// Get Slack user mappings for user display
  Future<Map<String, Map<String, String>>> getSlackUserMappings() async {
    if (!isReady) return {};

    try {
      final data = await _readClient.from('slack_user_mapping').select(
          'slack_user_id, slack_real_name, slack_display_name, slack_avatar_url, member_id');

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
      debugPrint('Error getting Slack user mappings: $e');
      return {};
    }
  }

  /// Trigger archive sync for a channel via Edge Function
  Future<bool> triggerArchiveSync(String channelId, {int daysBack = 90}) async {
    if (!isReady) return false;

    try {
      await _supabase.client.functions.invoke(
        'slack-archive-messages',
        body: {
          'channelId': channelId,
          'daysBack': daysBack,
          'incremental': true,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error triggering archive sync: $e');
      return false;
    }
  }

  // ============================================
  // UNMATCHED USERS TAB
  // ============================================

  /// Get all unmatched Slack users
  Future<List<SlackUnmatchedUser>> getUnmatchedUsers({
    bool includeRejected = false,
    String? filter, // 'has_email', 'no_email', 'rejected'
  }) async {
    if (!isReady) return [];

    try {
      var query = _readClient.from('slack_users_unmatched').select();

      if (!includeRejected && filter != 'rejected') {
        query = query.eq('manually_rejected', false);
      }

      if (filter == 'has_email') {
        query = query.not('slack_email', 'is', null);
      } else if (filter == 'no_email') {
        query = query.filter('slack_email', 'is', null);
      } else if (filter == 'rejected') {
        query = query.eq('manually_rejected', true);
      }

      final data = await query.order('created_at', ascending: false);

      return (data as List<dynamic>)
          .map((e) => SlackUnmatchedUser.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching unmatched users: $e');
      return [];
    }
  }

  /// Get count of unmatched users
  Future<int> getUnmatchedUsersCount() async {
    if (!isReady) return 0;

    try {
      final PostgrestResponse response = await _readClient
          .from('slack_users_unmatched')
          .select('id')
          .eq('manually_rejected', false)
          .count(CountOption.exact);
      return response.count ?? 0;
    } catch (e) {
      debugPrint('Error counting unmatched users: $e');
      return 0;
    }
  }

  /// Search members for matching
  Future<List<Member>> searchMembers(String query, {int limit = 20}) async {
    if (!isReady || query.length < 2) return [];

    try {
      final searchQuery = query.toLowerCase();

      final data = await _readClient
          .from('members')
          .select()
          .or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%,school_email.ilike.%$searchQuery%')
          .order('name', ascending: true)
          .limit(limit);

      return (data as List<dynamic>)
          .map((e) => Member.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error searching members: $e');
      return [];
    }
  }

  /// Match a Slack user to a member
  Future<bool> matchUserToMember({
    required String slackUserId,
    required String memberId,
    String? slackEmail,
    String? slackDisplayName,
    String? slackRealName,
  }) async {
    if (!isReady) return false;

    try {
      // Check if member already has a different slack_user_id
      final existingMember = await _readClient
          .from('members')
          .select('slack_user_id')
          .eq('id', memberId)
          .maybeSingle();

      final existingSlackId = existingMember?['slack_user_id']?.toString();
      if (existingSlackId != null &&
          existingSlackId.isNotEmpty &&
          existingSlackId != slackUserId) {
        debugPrint('Member already has a different Slack user ID');
        return false;
      }

      // Check if slack_user_id is already in slack_user_mapping
      final existingMapping = await _readClient
          .from('slack_user_mapping')
          .select('id, member_id')
          .eq('slack_user_id', slackUserId)
          .maybeSingle();

      if (existingMapping != null) {
        final existingMemberId = existingMapping['member_id']?.toString();
        if (existingMemberId == memberId) {
          // Already mapped to this member, update the mapping
          debugPrint('Slack user already mapped to this member, updating...');
          await _writeClient
              .from('slack_user_mapping')
              .update({
                'slack_email': slackEmail,
                'slack_display_name': slackDisplayName,
                'slack_real_name': slackRealName,
                'manually_verified': true,
                'last_synced_at': DateTime.now().toIso8601String(),
              })
              .eq('slack_user_id', slackUserId);
        } else {
          // Mapped to a different member - this is a conflict
          debugPrint('Slack user ID already mapped to a different member');
          return false;
        }
      } else {
        // Insert new mapping
        await _writeClient.from('slack_user_mapping').insert({
          'member_id': memberId,
          'slack_user_id': slackUserId,
          'slack_email': slackEmail,
          'slack_display_name': slackDisplayName,
          'slack_real_name': slackRealName,
          'matched_by': 'manual',
          'match_confidence': 1.0,
          'manually_verified': true,
          'last_synced_at': DateTime.now().toIso8601String(),
        });
      }

      // Update members table with slack_user_id
      await _writeClient
          .from('members')
          .update({'slack_user_id': slackUserId}).eq('id', memberId);

      // Update slack_messages to link with member_id
      await _writeClient
          .from('slack_messages')
          .update({'member_id': memberId}).eq('slack_user_id', slackUserId);

      // Delete from slack_users_unmatched
      await _writeClient
          .from('slack_users_unmatched')
          .delete()
          .eq('slack_user_id', slackUserId);

      return true;
    } catch (e) {
      debugPrint('Error matching user to member: $e');
      return false;
    }
  }

  /// Create a new member from Slack user data
  Future<String?> createMemberFromSlackUser({
    required String slackUserId,
    String? name,
    String? email,
  }) async {
    if (!isReady) return null;

    try {
      // Parse name into first and last if possible
      String? firstName;
      String? lastName;
      if (name != null && name.isNotEmpty) {
        final parts = name.trim().split(' ');
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }

      // Insert new member
      final memberData = await _writeClient
          .from('members')
          .insert({
            'name': name ?? 'Unknown',
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'slack_user_id': slackUserId,
            'committee': <String>[],
          })
          .select('id')
          .single();

      final memberId = memberData['id']?.toString();
      if (memberId == null) return null;

      // Insert into slack_user_mapping
      await _writeClient.from('slack_user_mapping').insert({
        'member_id': memberId,
        'slack_user_id': slackUserId,
        'slack_email': email,
        'slack_real_name': name,
        'matched_by': 'manual_create',
        'match_confidence': 1.0,
        'manually_verified': true,
        'last_synced_at': DateTime.now().toIso8601String(),
      });

      // Update slack_messages to link with member_id
      await _writeClient
          .from('slack_messages')
          .update({'member_id': memberId}).eq('slack_user_id', slackUserId);

      // Delete from slack_users_unmatched
      await _writeClient
          .from('slack_users_unmatched')
          .delete()
          .eq('slack_user_id', slackUserId);

      return memberId;
    } catch (e) {
      debugPrint('Error creating member from Slack user: $e');
      return null;
    }
  }

  /// Mark a Slack user as rejected (bot, guest, etc.)
  Future<bool> rejectSlackUser(String slackUserId, {String? notes}) async {
    if (!isReady) return false;

    try {
      await _writeClient.from('slack_users_unmatched').update({
        'manually_rejected': true,
        if (notes != null) 'notes': notes,
      }).eq('slack_user_id', slackUserId);

      return true;
    } catch (e) {
      debugPrint('Error rejecting Slack user: $e');
      return false;
    }
  }

  /// Update notes for an unmatched user
  Future<bool> updateUnmatchedUserNotes(
      String slackUserId, String notes) async {
    if (!isReady) return false;

    try {
      await _writeClient
          .from('slack_users_unmatched')
          .update({'notes': notes}).eq('slack_user_id', slackUserId);

      return true;
    } catch (e) {
      debugPrint('Error updating notes: $e');
      return false;
    }
  }

  // ============================================
  // ANALYTICS TAB
  // ============================================

  /// Get all cached analytics metrics
  Future<List<SlackAnalyticsMetric>> getCachedAnalytics() async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('slack_analytics_cache')
          .select()
          .order('computed_at', ascending: false);

      return (data as List<dynamic>)
          .map((e) => SlackAnalyticsMetric.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching cached analytics: $e');
      return [];
    }
  }

  /// Get a specific analytics metric
  Future<SlackAnalyticsMetric?> getAnalyticsMetric(String metricName) async {
    if (!isReady) return null;

    try {
      final data = await _readClient
          .from('slack_analytics_cache')
          .select()
          .eq('metric_name', metricName)
          .order('computed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return SlackAnalyticsMetric.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching analytics metric: $e');
      return null;
    }
  }

  /// Trigger analytics computation via Edge Function
  Future<bool> refreshAnalytics({int daysBack = 30}) async {
    if (!isReady) return false;

    try {
      await _supabase.client.functions.invoke(
        'slack-compute-analytics',
        body: {'daysBack': daysBack},
      );
      return true;
    } catch (e) {
      debugPrint('Error refreshing analytics: $e');
      return false;
    }
  }

  /// Get messages by day data
  Future<List<DailyMessageCount>> getMessagesByDay() async {
    final metric = await getAnalyticsMetric('messages_by_day');
    if (metric == null) return [];

    try {
      final value = metric.metricValue as Map<String, dynamic>?;
      final data = value?['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => DailyMessageCount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing messages by day: $e');
      return [];
    }
  }

  /// Get channel activity data
  Future<List<ChannelActivity>> getChannelActivity() async {
    final metric = await getAnalyticsMetric('messages_by_channel');
    if (metric == null) return [];

    try {
      final value = metric.metricValue as Map<String, dynamic>?;
      final data = value?['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => ChannelActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing channel activity: $e');
      return [];
    }
  }

  /// Get user activity data
  Future<List<UserActivity>> getUserActivity() async {
    final metric = await getAnalyticsMetric('messages_by_user');
    if (metric == null) return [];

    try {
      final value = metric.metricValue as Map<String, dynamic>?;
      final data = value?['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => UserActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing user activity: $e');
      return [];
    }
  }

  /// Get day of week activity
  Future<List<DayOfWeekActivity>> getDayOfWeekActivity() async {
    final metric = await getAnalyticsMetric('messages_by_day_of_week');
    if (metric == null) return [];

    try {
      final value = metric.metricValue as Map<String, dynamic>?;
      final data = value?['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => DayOfWeekActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing day of week activity: $e');
      return [];
    }
  }

  /// Get hourly activity
  Future<List<HourlyActivity>> getHourlyActivity() async {
    final metric = await getAnalyticsMetric('messages_by_hour');
    if (metric == null) return [];

    try {
      final value = metric.metricValue as Map<String, dynamic>?;
      final data = value?['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => HourlyActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing hourly activity: $e');
      return [];
    }
  }

  /// Get recent membership changes with channel and user details
  Future<List<MembershipChange>> getRecentMembershipChanges(
      {int limit = 50}) async {
    if (!isReady) return [];

    try {
      // Query with joins to get channel names and user info
      final data = await _readClient
          .from('slack_channel_membership_log')
          .select('''
            *,
            slack_channel_committee_mapping!slack_channel_id(slack_channel_name),
            slack_user_mapping!slack_user_id(slack_display_name, slack_real_name, slack_avatar_url),
            members!member_id(name, profile_photos)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List<dynamic>)
          .map((e) => MembershipChange.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching membership changes: $e');
      return [];
    }
  }

  /// Get analytics summary from cached metrics
  Future<SlackAnalyticsSummary> getAnalyticsSummary() async {
    final metrics = await getCachedAnalytics();
    return SlackAnalyticsSummary.fromMetrics(metrics);
  }

  /// Get member by ID for displaying in message cards
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
      debugPrint('Error fetching member by ID: $e');
      return null;
    }
  }

  /// Get messages by Slack user ID with pagination
  Future<List<Map<String, dynamic>>> getMessagesBySlackUserId(
    String slackUserId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (!isReady) return [];

    try {
      final data = await _readClient
          .from('slack_messages')
          .select(
              'id, slack_message_ts, slack_channel_id, slack_user_id, member_id, message_text, message_type, thread_ts, posted_at, has_files, files, files_archived, reactions')
          .eq('slack_user_id', slackUserId)
          .order('posted_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error fetching messages by slack user ID: $e');
      return [];
    }
  }

  /// Get unmatched user info by Slack user ID
  Future<SlackUnmatchedUser?> getUnmatchedUserBySlackId(String slackUserId) async {
    if (!isReady) return null;

    try {
      final data = await _readClient
          .from('slack_users_unmatched')
          .select()
          .eq('slack_user_id', slackUserId)
          .maybeSingle();

      if (data == null) return null;
      return SlackUnmatchedUser.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching unmatched user by slack ID: $e');
      return null;
    }
  }

  /// Get user mapping info by Slack user ID
  Future<Map<String, dynamic>?> getUserMappingBySlackId(String slackUserId) async {
    if (!isReady) return null;

    try {
      final data = await _readClient
          .from('slack_user_mapping')
          .select('*, members!member_id(id, name, profile_photos)')
          .eq('slack_user_id', slackUserId)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('Error fetching user mapping by slack ID: $e');
      return null;
    }
  }
}
