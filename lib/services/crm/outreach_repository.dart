import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';
import 'supabase_service.dart';

/// Data layer for the outreach-tracking subsystem (Layer 2 of Candidate
/// Volunteers). Wraps [CRMSupabaseService].client, following the conventions
/// in donor_profile_repository.dart: writes print-and-swallow, reads throw, and
/// anything unbounded pages with .range() against the PostgREST 1000-row cap.
class OutreachRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client => _supabase.client;

  /// PostgREST caps an un-ranged select at 1000 rows, so a table that can grow
  /// past that is fetched a page at a time.
  static const int _pageSize = 1000;

  /// The geo column a [MapMode] filters on. Counties are county names; the
  /// three district modes are bare-digit district numbers.
  String _geoColumn(MapMode mode) {
    switch (mode) {
      case MapMode.county:
        return 'counties';
      case MapMode.congressional:
        return 'congressional_districts';
      case MapMode.house:
        return 'house_districts';
      case MapMode.senate:
        return 'senate_districts';
    }
  }

  /// Insert an activity and, in the same call, its candidate and participant
  /// links. Returns the new activity id, or null if the CRM is not ready or the
  /// insert fails. created_by is stamped from the signed-in user.
  Future<String?> createActivity(
    OutreachActivity activity, {
    List<String> candidateIds = const <String>[],
    List<OutreachParticipantInput> participants = const <OutreachParticipantInput>[],
  }) async {
    if (!isReady) return null;

    try {
      final insert = activity.toInsertJson();
      insert['created_by'] =
          _client.auth.currentUser?.id ?? activity.createdBy;

      final row = await _client
          .from('outreach_activities')
          .insert(insert)
          .select('id')
          .single();
      final id = row['id'] as String;

      final uniqueCandidateIds = candidateIds.toSet();
      if (uniqueCandidateIds.isNotEmpty) {
        await _client.from('outreach_activity_candidates').insert([
          for (final candidateId in uniqueCandidateIds)
            <String, dynamic>{'activity_id': id, 'candidate_id': candidateId},
        ]);
      }

      if (participants.isNotEmpty) {
        await _client.from('outreach_participants').insert([
          for (final participant in participants) participant.toRow(id),
        ]);
      }

      return id;
    } catch (e) {
      debugPrint('❌ createActivity: $e');
      return null;
    }
  }

  /// Activities that covered a region, most recent first. `.contains` maps to
  /// PostgREST array containment against the GIN-indexed geo column.
  Future<List<OutreachActivity>> activitiesForRegion(
    MapMode mode,
    String id, {
    int limit = 20,
  }) async {
    if (!isReady) return <OutreachActivity>[];

    final response = await _client
        .from('outreach_activities')
        .select()
        .contains(_geoColumn(mode), <String>[id])
        .order('scheduled_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(OutreachActivity.fromJson)
        .toList();
  }

  /// Every activity that supported a candidate, via the join table. Paged
  /// against the 1000-row cap, then sorted most-recent first in memory.
  Future<List<OutreachActivity>> activitiesForCandidate(
      String candidateId) async {
    if (!isReady) return <OutreachActivity>[];

    final activities = await _pagedEmbeddedActivities(
      table: 'outreach_activity_candidates',
      filterColumn: 'candidate_id',
      filterValue: candidateId,
    );
    _sortRecentFirst(activities);
    return activities;
  }

  /// Every activity a member took part in, via the participants table. Paged
  /// against the 1000-row cap, then sorted most-recent first in memory.
  Future<List<OutreachActivity>> activitiesForMember(String memberId) async {
    if (!isReady) return <OutreachActivity>[];

    final activities = await _pagedEmbeddedActivities(
      table: 'outreach_participants',
      filterColumn: 'member_id',
      filterValue: memberId,
    );
    _sortRecentFirst(activities);
    return activities;
  }

  /// Set an activity's status. Stamps completed_at when it becomes 'completed';
  /// other transitions leave completed_at as it stands.
  Future<void> updateStatus(String id, String status) async {
    if (!isReady) return;

    try {
      final fields = <String, dynamic>{'status': status};
      if (status == 'completed') {
        fields['completed_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await _client.from('outreach_activities').update(fields).eq('id', id);
    } catch (e) {
      debugPrint('❌ updateStatus: $e');
    }
  }

  /// Record whether a member attended an activity.
  Future<void> setAttendance(
      String activityId, String memberId, bool attended) async {
    if (!isReady) return;

    try {
      await _client
          .from('outreach_participants')
          .update(<String, dynamic>{'attended': attended})
          .eq('activity_id', activityId)
          .eq('member_id', memberId);
    } catch (e) {
      debugPrint('❌ setAttendance: $e');
    }
  }

  /// Page a join/link [table] filtered on [filterColumn] = [filterValue],
  /// embedding the parent outreach_activities row, until a short page ends it.
  Future<List<OutreachActivity>> _pagedEmbeddedActivities({
    required String table,
    required String filterColumn,
    required String filterValue,
  }) async {
    final activities = <OutreachActivity>[];
    var from = 0;

    while (true) {
      final response = await _client
          .from(table)
          .select('outreach_activities(*)')
          .eq(filterColumn, filterValue)
          .range(from, from + _pageSize - 1);

      final rows =
          (response as List<dynamic>? ?? const <dynamic>[]).whereType<Map<String, dynamic>>();
      var pageCount = 0;
      for (final row in rows) {
        pageCount++;
        final embedded = row['outreach_activities'];
        if (embedded is Map<String, dynamic>) {
          activities.add(OutreachActivity.fromJson(embedded));
        }
      }

      if (pageCount < _pageSize) break;
      from += _pageSize;
    }

    return activities;
  }

  void _sortRecentFirst(List<OutreachActivity> activities) {
    DateTime keyOf(OutreachActivity a) =>
        a.scheduledOn ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    activities.sort((a, b) => keyOf(b).compareTo(keyOf(a)));
  }
}
