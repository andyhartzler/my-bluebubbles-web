import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tracked_bill.dart';

/// Result of an AI analysis request
class AiAnalysisResult {
  final bool success;
  final String? error;
  final bool alreadyAnalyzed;
  final DateTime? analyzedAt;
  final Map<String, dynamic>? analysis;
  final int? tokensUsed;
  final int? durationMs;

  AiAnalysisResult({
    required this.success,
    this.error,
    this.alreadyAnalyzed = false,
    this.analyzedAt,
    this.analysis,
    this.tokensUsed,
    this.durationMs,
  });

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AiAnalysisResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      alreadyAnalyzed: json['alreadyAnalyzed'] as bool? ?? false,
      analyzedAt: json['analyzedAt'] != null
          ? DateTime.parse(json['analyzedAt'] as String)
          : null,
      analysis: json['analysis'] as Map<String, dynamic>?,
      tokensUsed: json['tokensUsed'] as int?,
      durationMs: json['durationMs'] as int?,
    );
  }
}

/// Result of a batch analysis request
class BatchAnalysisResult {
  final bool success;
  final String? error;
  final int processed;
  final int successful;
  final int failed;
  final List<Map<String, dynamic>> results;

  BatchAnalysisResult({
    required this.success,
    this.error,
    this.processed = 0,
    this.successful = 0,
    this.failed = 0,
    this.results = const [],
  });

  factory BatchAnalysisResult.fromJson(Map<String, dynamic> json) {
    return BatchAnalysisResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      processed: json['processed'] as int? ?? 0,
      successful: json['successful'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      results: (json['results'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

/// Service for AI-powered bill analysis
class AiAnalysisService {
  static final AiAnalysisService _instance = AiAnalysisService._internal();
  factory AiAnalysisService() => _instance;
  AiAnalysisService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Analyze a single bill with Claude AI
  Future<AiAnalysisResult> analyzeBill({
    required String billId,
    bool forceReanalyze = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'analyze-bill',
        body: {
          'billId': billId,
          'forceReanalyze': forceReanalyze,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        return AiAnalysisResult(success: false, error: error.toString());
      }

      return AiAnalysisResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return AiAnalysisResult(success: false, error: e.toString());
    }
  }

  /// Analyze multiple bills in batch
  Future<BatchAnalysisResult> analyzeBillsBatch({
    int batchSize = 5,
    bool onlyUnanalyzed = true,
    String? session,
    bool prioritizeBillText = true,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'analyze-bills-batch',
        body: {
          'batchSize': batchSize,
          'onlyUnanalyzed': onlyUnanalyzed,
          'session': session,
          'prioritizeBillText': prioritizeBillText,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        return BatchAnalysisResult(success: false, error: error.toString());
      }

      return BatchAnalysisResult.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return BatchAnalysisResult(success: false, error: e.toString());
    }
  }

  /// Get bills that haven't been analyzed yet
  Future<List<TrackedBill>> getUnanalyzedBills({
    String? session,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select()
        .isFilter('ai_analyzed_at', null)
        .eq('is_archived', false)
        .order('created_at', ascending: false)
        .limit(limit);

    if (session != null) {
      query = query.eq('session', session);
    }

    final response = await query;
    return (response as List)
        .map((json) => TrackedBill.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get count of unanalyzed bills
  Future<int> getUnanalyzedBillCount({String? session}) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .isFilter('ai_analyzed_at', null)
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }

    final response = await query;
    return (response as List).length;
  }

  /// Get count of bills with AI analysis
  Future<int> getAnalyzedBillCount({String? session}) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .not('ai_analyzed_at', 'is', null)
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }

    final response = await query;
    return (response as List).length;
  }

  /// Apply AI recommendations to a bill (update position, priority, categories)
  Future<bool> applyAiRecommendations({
    required String billId,
    bool applyPosition = true,
    bool applyPriority = true,
    bool applyCategories = true,
  }) async {
    try {
      // Get current bill with AI recommendations
      final response = await _supabase
          .from('legislation_tracked_bills')
          .select('''
            ai_position_recommendation,
            ai_priority_recommendation,
            ai_categories_recommendation
          ''')
          .eq('id', billId)
          .single();

      final updates = <String, dynamic>{};

      if (applyPosition && response['ai_position_recommendation'] != null) {
        updates['position'] = response['ai_position_recommendation'];
        updates['position_set_at'] = DateTime.now().toIso8601String();
        updates['position_rationale'] = 'Set by AI recommendation';
      }

      if (applyPriority && response['ai_priority_recommendation'] != null) {
        updates['priority'] = response['ai_priority_recommendation'];
      }

      if (applyCategories && response['ai_categories_recommendation'] != null) {
        updates['categories'] = response['ai_categories_recommendation'];
      }

      if (updates.isEmpty) {
        return false;
      }

      await _supabase
          .from('legislation_tracked_bills')
          .update(updates)
          .eq('id', billId);

      return true;
    } catch (e) {
      print('Error applying AI recommendations: $e');
      return false;
    }
  }

  /// Apply AI recommendations to all bills that have them
  Future<int> applyAllAiRecommendations({
    String? session,
    bool onlyWatching = true, // Only apply to bills currently set to "watching"
  }) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .not('ai_position_recommendation', 'is', null)
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }

    if (onlyWatching) {
      query = query.eq('position', 'watching');
    }

    final bills = await query;
    int appliedCount = 0;

    for (final bill in (bills as List)) {
      final success = await applyAiRecommendations(billId: bill['id'] as String);
      if (success) appliedCount++;
    }

    return appliedCount;
  }

  /// Get bills where AI recommendation differs from current position
  Future<List<TrackedBill>> getBillsWithDifferentAiRecommendation({
    String? session,
    int limit = 50,
  }) async {
    // We can't do this comparison directly in Supabase, so we fetch and filter
    var query = _supabase
        .from('legislation_tracked_bills')
        .select()
        .not('ai_position_recommendation', 'is', null)
        .eq('is_archived', false)
        .order('ai_analyzed_at', ascending: false);

    if (session != null) {
      query = query.eq('session', session);
    }

    final response = await query;
    final bills = (response as List)
        .map((json) => TrackedBill.fromJson(json as Map<String, dynamic>))
        .where((bill) => bill.aiRecommendsDifferentPosition)
        .take(limit)
        .toList();

    return bills;
  }

  /// Get analysis history for a bill
  Future<List<Map<String, dynamic>>> getAnalysisHistory(String billId) async {
    try {
      final response = await _supabase
          .from('legislation_ai_analysis_history')
          .select()
          .eq('bill_id', billId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      print('Error fetching analysis history: $e');
      return [];
    }
  }
}
