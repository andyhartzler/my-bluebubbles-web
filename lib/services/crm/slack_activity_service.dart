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
}
