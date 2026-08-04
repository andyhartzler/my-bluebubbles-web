import 'package:flutter/foundation.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import '../../models/submission_review_model.dart';

/// Loads Gemini-judged endorsement alignment scores from
/// `public.endorsement_ai_scores`, keyed by submission id.
///
/// These scores supersede the rigid rule-based [AlignmentScore] as the
/// alignment number the endorsement hub shows. Read-only from the client
/// (writes come from the server-side scoring pipeline); RLS restricts reads to
/// staff. Failures degrade gracefully to an empty map so the hub still renders
/// with the rule-based fallback.
class EndorsementAiScoreRepository {
  static const _table = 'endorsement_ai_scores';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// All AI scores as {submission_id: AiAlignmentScore}.
  Future<Map<String, AiAlignmentScore>> loadBySubmission() async {
    final out = <String, AiAlignmentScore>{};
    try {
      final rows = await _supabase.client.from(_table).select();
      for (final row in (rows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final sid = m['submission_id']?.toString();
        if (sid == null || sid.isEmpty) continue;
        final score = AiAlignmentScore.fromRow(m);
        if (score != null) out[sid] = score;
      }
    } catch (e) {
      debugPrint('EndorsementAiScoreRepository.loadBySubmission error: $e');
    }
    return out;
  }

  static const _historyTable = 'endorsement_ai_score_history';

  /// Every superseded scoring run for one submission, newest first.
  ///
  /// Explicitly bounded. A bare `select()` is silently truncated by PostgREST
  /// at the project row cap (HTTP 200, no error, just fewer rows), and while
  /// 50 is far above anything one submission produces today, the bound is what
  /// makes that a stated ceiling rather than an accident. Failure degrades to
  /// an empty list: the disclosure then renders nothing, which is also what a
  /// submission with no history renders.
  Future<List<AiScoreHistoryEntry>> loadHistory(String submissionId) async {
    if (submissionId.isEmpty) return const [];
    final out = <AiScoreHistoryEntry>[];
    try {
      final rows = await _supabase.client
          .from(_historyTable)
          .select()
          .eq('submission_id', submissionId)
          .order('scored_at', ascending: false)
          .limit(50);
      for (final row in (rows as List)) {
        final parsed =
            AiScoreHistoryEntry.fromRow(Map<String, dynamic>.from(row as Map));
        if (parsed != null) out.add(parsed);
      }
    } catch (e) {
      debugPrint('EndorsementAiScoreRepository.loadHistory error: $e');
    }
    return out;
  }

  /// A single submission's AI score, or null.
  Future<AiAlignmentScore?> loadOne(String submissionId) async {
    try {
      final row = await _supabase.client
          .from(_table)
          .select()
          .eq('submission_id', submissionId)
          .maybeSingle();
      if (row == null) return null;
      return AiAlignmentScore.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('EndorsementAiScoreRepository.loadOne error: $e');
      return null;
    }
  }
}
