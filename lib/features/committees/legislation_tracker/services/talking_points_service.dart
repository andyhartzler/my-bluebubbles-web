import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/config/crm_config.dart';

/// Result of a talking points generation request
class TalkingPointsResult {
  final bool success;
  final String? error;
  final bool alreadyGenerated;
  final bool needsAnalysis;
  final Map<String, dynamic>? talkingPoints;
  final int? tokensUsed;

  TalkingPointsResult({
    required this.success,
    this.error,
    this.alreadyGenerated = false,
    this.needsAnalysis = false,
    this.talkingPoints,
    this.tokensUsed,
  });

  factory TalkingPointsResult.fromJson(Map<String, dynamic> json) {
    return TalkingPointsResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      alreadyGenerated: json['alreadyGenerated'] as bool? ?? false,
      needsAnalysis: json['needsAnalysis'] as bool? ?? false,
      talkingPoints: json['talkingPoints'] as Map<String, dynamic>?,
      tokensUsed: json['tokensUsed'] as int?,
    );
  }
}

/// Service for AI-generated talking points
class TalkingPointsService {
  static final TalkingPointsService _instance = TalkingPointsService._internal();
  factory TalkingPointsService() => _instance;
  TalkingPointsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get headers for Edge Function calls
  Map<String, String> get _functionHeaders => {
    'apikey': CRMConfig.supabaseAnonKey,
  };

  /// Generate talking points for a bill
  Future<TalkingPointsResult> generateTalkingPoints({
    required String billId,
    bool regenerate = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-talking-points',
        headers: _functionHeaders,
        body: {
          'billId': billId,
          'regenerate': regenerate,
        },
      );

      if (response.status != 200) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null;
        return TalkingPointsResult(
          success: false,
          error: data?['error']?.toString() ?? 'Unknown error',
          needsAnalysis: data?['needsAnalysis'] as bool? ?? false,
        );
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : throw Exception('Unexpected response from generate-talking-points');
      return TalkingPointsResult.fromJson(data);
    } catch (e) {
      return TalkingPointsResult(success: false, error: e.toString());
    }
  }

  /// Check if a bill has talking points
  Future<bool> hasTalkingPoints(String billId) async {
    try {
      final response = await _supabase
          .from('legislation_tracked_bills')
          .select('ai_talking_points')
          .eq('id', billId)
          .single();

      return response['ai_talking_points'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Get count of bills with talking points
  Future<int> getBillsWithTalkingPointsCount({String? session}) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .not('ai_talking_points', 'is', null)
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get count of bills without talking points (but with AI analysis)
  Future<int> getBillsNeedingTalkingPointsCount({String? session}) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .not('ai_analyzed_at', 'is', null) // Has AI analysis
        .isFilter('ai_talking_points', null) // But no talking points
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }

    final response = await query;
    return (response as List).length;
  }

  /// Track when talking points are copied (for analytics)
  Future<void> trackCopy(String billId) async {
    try {
      // Call RPC function to increment copy count
      await _supabase.rpc('increment_talking_points_copy', params: {
        'bill_uuid': billId,
      });
    } catch (e) {
      // Silently fail - analytics shouldn't break UX
      debugPrint('Failed to track copy: $e');
    }
  }

  /// Track when talking points are shared (for analytics)
  Future<void> trackShare(String billId, String platform) async {
    try {
      await _supabase.rpc('increment_talking_points_share', params: {
        'bill_uuid': billId,
        'platform': platform,
      });
    } catch (e) {
      // Silently fail
      debugPrint('Failed to track share: $e');
    }
  }

  /// Get talking points history for a bill
  Future<List<Map<String, dynamic>>> getTalkingPointsHistory(String billId) async {
    try {
      final response = await _supabase
          .from('legislation_talking_points_history')
          .select()
          .eq('bill_id', billId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Error fetching talking points history: $e');
      return [];
    }
  }
}
