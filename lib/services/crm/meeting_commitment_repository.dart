import 'package:flutter/foundation.dart';

import 'package:bluebubbles/models/crm/meeting_commitment.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Reads and writes public.meeting_commitments.
///
/// Both tables this touches are executive-committee-only in the database, so
/// there is no permission check here and there must not be one: a member who
/// reached this code would get an empty list from RLS, which is the answer.
/// Hiding the panel in the UI is presentation, not access control.
class MeetingCommitmentRepository {
  MeetingCommitmentRepository._();

  static final MeetingCommitmentRepository _instance =
      MeetingCommitmentRepository._();

  factory MeetingCommitmentRepository() => _instance;

  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  static const String _columns =
      'id, meeting_id, kind, owner_member_id, owner_label, commitment, '
      'counties, due_on, evidence, needs_confirmation, status, progress_note, '
      'status_set_at, human_edited_fields, sort_order';

  List<Map<String, dynamic>> _rows(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<List<MeetingCommitment>> getForMeeting(String meetingId) async {
    if (!_isReady) return const [];
    try {
      final response = await _supabase.client
          .from('meeting_commitments')
          .select(_columns)
          .eq('meeting_id', meetingId)
          .order('sort_order');
      return _rows(response).map(MeetingCommitment.fromJson).toList();
    } catch (e) {
      debugPrint('❌ Error loading meeting commitments: $e');
      return const [];
    }
  }

  /// Writes only the two columns a person owns.
  ///
  /// Deliberately narrow. Sending the derived columns back on a save is how a
  /// screen silently reverts a field somebody else corrected, and once this
  /// update names a column the trigger records it as a human edit and locks
  /// automation out of it for good. So the request carries status and note and
  /// nothing else.
  Future<MeetingCommitment?> saveProgress(
    String commitmentId, {
    required CommitmentStatus status,
    String? progressNote,
  }) async {
    if (!_isReady) return null;
    final note = progressNote?.trim();
    try {
      final response = await _supabase.client
          .from('meeting_commitments')
          .update({
            'status': status.wire,
            'progress_note': (note == null || note.isEmpty) ? null : note,
          })
          .eq('id', commitmentId)
          .select(_columns)
          .maybeSingle();
      if (response == null) return null;
      return MeetingCommitment.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('❌ Error saving commitment progress: $e');
      rethrow;
    }
  }

  /// County coverage across the whole membership. Ordered so the gaps with the
  /// most members in them come first, because that is the decision this is for.
  ///
  /// No member_count filter. After the eligibility fix an owned county that
  /// matches zero members is the signature of a mistyped county string in a
  /// commitment row, and that has to stay VISIBLE rather than vanish.
  ///
  /// THROWS rather than returning an empty list. The old version swallowed the
  /// error, which left every caller unable to tell "the fetch failed" from
  /// "there are no counties". On a surface whose whole job is to show gaps,
  /// those two render identically and mean opposite things.
  Future<List<RegionCoverage>> getRegionCoverage() async {
    if (!_isReady) return const [];
    final response = await _supabase.client
        .from('exec_region_coverage')
        .select('county, member_count, phone_count, owner_labels, '
            'owner_member_ids, has_owner, any_unconfirmed')
        .order('member_count', ascending: false);
    return _rows(response).map(RegionCoverage.fromJson).toList();
  }
}
