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
