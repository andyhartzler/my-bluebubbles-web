import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/slack_activity.dart';

import 'supabase_service.dart';

class SlackActivityService {
  SlackActivityService._();

  static final SlackActivityService instance = SlackActivityService._();

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  Future<SlackActivityResult> fetchMemberMessages({
    required String memberId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (!_isReady) {
      throw StateError('CRM Supabase is not initialized');
    }

    final response = await _supabase.client.functions.invoke(
      'slack-member-messages',
      body: {
        'member_id': memberId,
        'limit': limit,
        'offset': offset,
      },
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      return SlackActivityResult.fromJson(payload);
    }

    throw StateError('Unexpected Slack activity response');
  }

  Future<SlackProfile?> fetchSlackProfile(String memberId) async {
    if (!_isReady) return null;

    final response = await _supabase.client
        .from('slack_user_mapping')
        .select(
          'slack_user_id, slack_email, slack_display_name, slack_real_name, slack_avatar_url',
        )
        .eq('member_id', memberId)
        .maybeSingle();

    if (response == null) return null;
    return SlackProfile.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<SlackUnmatchedUser>> fetchUnmatchedSlackUsers({String? searchQuery}) async {
    if (!_isReady) {
      throw StateError('CRM Supabase is not initialized');
    }

    final trimmed = searchQuery?.trim();
    final PostgrestFilterBuilder<dynamic> request = _supabase.client
        .from('slack_users_unmatched')
        .select()
        .eq('manually_rejected', false);

    if (trimmed != null && trimmed.isNotEmpty) {
      request.or(
        'slack_real_name.ilike.%$trimmed%,slack_email.ilike.%$trimmed%,slack_display_name.ilike.%$trimmed%',
      );
    }

    final response = await request.order('created_at', ascending: false);
    final List<dynamic> rows =
        response is List ? List<dynamic>.from(response) : <dynamic>[];

    return rows
        .map((row) => SlackUnmatchedUser.fromJson(
              row is Map<String, dynamic>
                  ? row
                  : Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  Future<void> linkMemberToSlack({
    required String memberId,
    required SlackUnmatchedUser slackUser,
  }) async {
    if (!_isReady) {
      throw StateError('CRM Supabase is not initialized');
    }

    final client = _supabase.client;
    final timestamp = DateTime.now().toUtc().toIso8601String();

    await client.from('slack_user_mapping').insert({
      'member_id': memberId,
      'slack_user_id': slackUser.slackUserId,
      'slack_email': slackUser.email,
      'slack_real_name': slackUser.realName,
      'slack_display_name': slackUser.displayName,
      'matched_by': 'manual',
      'match_confidence': 1.0,
      'last_synced_at': timestamp,
    });

    await client
        .from('members')
        .update({'slack_user_id': slackUser.slackUserId})
        .eq('id', memberId);

    await client
        .from('slack_users_unmatched')
        .delete()
        .eq('slack_user_id', slackUser.slackUserId);
  }
}
