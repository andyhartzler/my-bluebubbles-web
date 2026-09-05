import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart' show MemberProfilePhoto;
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

  /// Insert an activity with its candidate links and its participants in ONE
  /// transaction, through the create_outreach_activity RPC. This used to be
  /// three sequential inserts, so a failure on the second or third left an
  /// orphan activity with a partial roster and no way to tell. Returns the new
  /// activity id, or null if the CRM is not ready or the write fails.
  ///
  /// [actorUserId] is an auth.users id and [actorMemberId] is a public.members
  /// id. They are separate parameters because both columns hold bare uuids, and
  /// a swap would surface only as an opaque 23503 at insert time. The session
  /// lives in the workspace, not here; the fallback to the signed-in user
  /// covers created_by alone, and organizer_member_id is anonymous unless a
  /// caller supplies it, which is how it came to be never set.
  Future<String?> createActivity(
    OutreachActivity activity, {
    List<String> candidateIds = const <String>[],
    List<OutreachParticipantInput> participants = const <OutreachParticipantInput>[],
    String? actorUserId,
    String? actorMemberId,
  }) async {
    if (!isReady) return null;

    try {
      final payload = activity.toInsertJson();
      payload['created_by'] =
          actorUserId ?? _client.auth.currentUser?.id ?? activity.createdBy;
      // The acting exec organizes it unless the form named someone else.
      payload['organizer_member_id'] =
          activity.organizerMemberId ?? actorMemberId;

      final id = await _client.rpc(
        'create_outreach_activity',
        params: <String, dynamic>{
          'p_activity': payload,
          'p_candidate_ids': candidateIds.toSet().toList(),
          'p_participants': _participantRows(participants),
        },
      );
      return id?.toString();
    } catch (e) {
      debugPrint('❌ createActivity: $e');
      return null;
    }
  }

  /// Deduped on member_id, first entry wins, because a roster assembled from a
  /// map selection can name the same member twice.
  List<Map<String, dynamic>> _participantRows(
      List<OutreachParticipantInput> participants) {
    final seen = <String>{};
    return <Map<String, dynamic>>[
      for (final participant in participants)
        if (seen.add(participant.memberId)) participant.toJson(),
    ];
  }

  /// Write only the keys present in [fields], so the toolkit form can save a
  /// title edit without resending the roster. id and the server-managed columns
  /// are stripped, created_by among them: attribution is written once, at
  /// create, and is never rewritable.
  ///
  /// completed_at belongs to [updateStatus] and should not appear here.
  ///
  /// Rethrows on failure: this write backs an optimistic UI whose revert path
  /// depends on the exception surfacing.
  Future<void> updateActivity(String id, Map<String, dynamic> fields) async {
    if (!isReady) return;

    final writable = Map<String, dynamic>.from(fields)
      ..remove('id')
      ..remove('created_by')
      ..remove('created_at')
      ..remove('updated_at');
    if (writable.isEmpty) return;

    try {
      await _client.from('outreach_activities').update(writable).eq('id', id);
    } catch (e) {
      debugPrint('❌ updateActivity: $e');
      rethrow;
    }
  }

  /// Replace an activity's nominee set through the
  /// set_outreach_activity_candidates RPC, so an edit that drops one is a
  /// single transaction rather than a delete that can land while the insert
  /// fails. An empty list clears every link. Rethrows.
  Future<void> setActivityCandidates(
    String activityId,
    List<String> candidateIds,
  ) async {
    if (!isReady) return;

    try {
      await _client.rpc(
        'set_outreach_activity_candidates',
        params: <String, dynamic>{
          'p_activity_id': activityId,
          'p_candidate_ids': candidateIds.toSet().toList(),
        },
      );
    } catch (e) {
      debugPrint('❌ setActivityCandidates: $e');
      rethrow;
    }
  }

  /// Delete an activity. Both join tables cascade, so this takes the roster and
  /// the nominee links with it; the caller confirms first. Rethrows.
  Future<void> deleteActivity(String id) async {
    if (!isReady) return;

    try {
      await _client.from('outreach_activities').delete().eq('id', id);
    } catch (e) {
      debugPrint('❌ deleteActivity: $e');
      rethrow;
    }
  }

  /// One activity by id, or null when it does not exist or the CRM is not
  /// ready. The Desk needs this after promoting a touchpoint: the RPC returns
  /// an id and the screen it opens takes a row.
  Future<OutreachActivity?> activityById(String id) async {
    if (!isReady) return null;

    final row = await _client
        .from('outreach_activities')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : OutreachActivity.fromJson(row);
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

  /// Set an activity's status. Stamps completed_at when it becomes 'completed'
  /// and clears it on any move away from 'completed' (a reopen), so a reopened
  /// activity never keeps a stale completion timestamp.
  ///
  /// Rethrows on failure: this write backs an optimistic UI whose revert path
  /// depends on the exception surfacing. Callers wrap it in try/catch.
  Future<void> updateStatus(String id, String status) async {
    if (!isReady) return;

    try {
      final fields = <String, dynamic>{
        'status': status,
        'completed_at': status == 'completed'
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      };
      await _client.from('outreach_activities').update(fields).eq('id', id);
    } catch (e) {
      debugPrint('❌ updateStatus: $e');
      rethrow;
    }
  }

  /// Record whether a member attended an activity. Rethrows on failure so the
  /// caller's optimistic-UI revert fires.
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
      rethrow;
    }
  }

  /// Add participants to an EXISTING activity, deduped on the
  /// (activity_id, member_id) unique constraint. Existing members are skipped
  /// (not an error); so are duplicates within [participants]. Returns the count
  /// of NEW rows inserted. This is the method the volunteers detail panel calls
  /// to fold a map selection into an activity already on the board.
  Future<int> addParticipants(
    String activityId,
    List<OutreachParticipantInput> participants,
  ) async {
    if (!isReady || participants.isEmpty) return 0;

    try {
      // Pre-select the member_ids already on this activity so we insert only the
      // genuinely new ones and can report an exact count.
      final existing = await _client
          .from('outreach_participants')
          .select('member_id')
          .eq('activity_id', activityId);
      final existingIds = (existing as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((row) => row['member_id']?.toString())
          .whereType<String>()
          .toSet();

      final seen = <String>{};
      final rows = <Map<String, dynamic>>[];
      for (final participant in participants) {
        if (existingIds.contains(participant.memberId) ||
            !seen.add(participant.memberId)) {
          continue;
        }
        rows.add(participant.toRow(activityId));
      }

      if (rows.isEmpty) return 0;
      await _client.from('outreach_participants').insert(rows);
      return rows.length;
    } catch (e) {
      debugPrint('❌ addParticipants: $e');
      // Rethrow so a rejected write is not mistaken for "0 new (all already
      // on the activity)". The caller surfaces the failure.
      rethrow;
    }
  }

  /// Take one member off an activity's roster. Their attendance row goes with
  /// them; there is no soft delete here. Rethrows so the caller's optimistic
  /// revert fires.
  Future<void> removeParticipant(String activityId, String memberId) async {
    if (!isReady) return;

    try {
      await _client
          .from('outreach_participants')
          .delete()
          .eq('activity_id', activityId)
          .eq('member_id', memberId);
    } catch (e) {
      debugPrint('❌ removeParticipant: $e');
      rethrow;
    }
  }

  /// Change a single participant's role. There is no bulk equivalent; the detail
  /// screen's role dropdown calls this per row.
  Future<void> updateParticipantRole(
    String activityId,
    String memberId,
    String role,
  ) async {
    if (!isReady) return;

    try {
      await _client
          .from('outreach_participants')
          .update(<String, dynamic>{'role': role})
          .eq('activity_id', activityId)
          .eq('member_id', memberId);
    } catch (e) {
      debugPrint('❌ updateParticipantRole: $e');
      rethrow;
    }
  }

  /// Org-wide activity list for the Activities hub, newest scheduled_on first
  /// then created_at. Every provided filter is applied; the join-backed
  /// [candidateId]/[memberId] filters are resolved to an activity-id set first,
  /// then folded into a single column-filtered, paged query on the parent table.
  ///
  /// [memberId] and [organizerMemberId] ask different questions and are not
  /// interchangeable: the first is "was on the roster", resolved through
  /// outreach_participants, and the second is "ran it", a plain column filter.
  /// MY DESK wants the second (spec 4.4).
  Future<List<OutreachActivity>> listActivities({
    List<String>? statuses,
    String? kind,
    MapMode? regionMode,
    String? regionId,
    String? candidateId,
    String? memberId,
    String? organizerMemberId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    if (!isReady) return <OutreachActivity>[];

    // Resolve join constraints up front. An empty set after any join means no
    // activity can match, so short-circuit.
    Set<String>? idConstraint;
    if (candidateId != null) {
      idConstraint = await _activityIdsFor(
        'outreach_activity_candidates',
        'candidate_id',
        candidateId,
      );
    }
    if (memberId != null) {
      final memberIds =
          await _activityIdsFor('outreach_participants', 'member_id', memberId);
      idConstraint =
          idConstraint == null ? memberIds : idConstraint.intersection(memberIds);
    }
    if (idConstraint != null && idConstraint.isEmpty) {
      return <OutreachActivity>[];
    }

    final activities = <OutreachActivity>[];
    var offset = 0;

    while (activities.length < limit) {
      var query = _client.from('outreach_activities').select();

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }
      if (kind != null) {
        query = query.eq('kind', kind);
      }
      if (organizerMemberId != null) {
        query = query.eq('organizer_member_id', organizerMemberId);
      }
      if (regionMode != null && regionId != null) {
        query = query.contains(_geoColumn(regionMode), <String>[regionId]);
      }
      if (idConstraint != null) {
        query = query.inFilter('id', idConstraint.toList());
      }
      if (from != null) {
        query = query.gte(
            'scheduled_on', from.toIso8601String().split('T').first);
      }
      if (to != null) {
        query =
            query.lte('scheduled_on', to.toIso8601String().split('T').first);
      }

      final response = await query
          .order('scheduled_on', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final rows = (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>();
      var pageCount = 0;
      for (final row in rows) {
        pageCount++;
        activities.add(OutreachActivity.fromJson(row));
        if (activities.length >= limit) break;
      }

      if (pageCount < _pageSize) break;
      offset += _pageSize;
    }

    return activities.length > limit ? activities.sublist(0, limit) : activities;
  }

  /// The distinct activity_ids for a value in a join/link [table], paged against
  /// the 1000-row cap.
  Future<Set<String>> _activityIdsFor(
    String table,
    String column,
    String value,
  ) async {
    final ids = <String>{};
    var offset = 0;

    while (true) {
      final response = await _client
          .from(table)
          .select('activity_id')
          .eq(column, value)
          .range(offset, offset + _pageSize - 1);

      final rows = (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>();
      var pageCount = 0;
      for (final row in rows) {
        pageCount++;
        final id = row['activity_id']?.toString();
        if (id != null) ids.add(id);
      }

      if (pageCount < _pageSize) break;
      offset += _pageSize;
    }

    return ids;
  }

  /// The roster view-model for the detail screen: one entry per participant,
  /// each carrying a resolved display name and best avatar url via a PostgREST
  /// embed of the linked member row.
  Future<List<ActivityRosterEntry>> getRoster(String activityId) async {
    if (!isReady) return <ActivityRosterEntry>[];

    final response = await _client
        .from('outreach_participants')
        .select(
            'id, member_id, role, attended, members(name, avatar_url, profile_pictures)')
        .eq('activity_id', activityId)
        .order('created_at', ascending: true);

    final entries = <ActivityRosterEntry>[];
    for (final row in (response as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()) {
      final embedded = row['members'];
      final member =
          embedded is Map<String, dynamic> ? embedded : const <String, dynamic>{};
      final rawName = (member['name'] as String?)?.trim();
      entries.add(ActivityRosterEntry(
        participantId: row['id'] as String,
        memberId: row['member_id'] as String,
        memberName: rawName == null || rawName.isEmpty ? 'Unknown member' : rawName,
        memberAvatarUrl: _bestAvatarUrl(member),
        role: (row['role'] as String?) ?? 'volunteer',
        attended: row['attended'] as bool?,
      ));
    }
    return entries;
  }

  /// Prefer the user-uploaded avatar, then the primary auto-fetched photo.
  String? _bestAvatarUrl(Map<String, dynamic> member) {
    final uploaded = member['avatar_url'];
    if (uploaded is String && uploaded.trim().isNotEmpty) return uploaded;
    final photos = MemberProfilePhoto.parseList(member['profile_pictures']);
    if (photos.isEmpty) return null;
    for (final photo in photos) {
      if (photo.isPrimary) return photo.publicUrl;
    }
    return photos.first.publicUrl;
  }

  /// Count the candidates (nominees) attached to an activity, for the "n
  /// nominees" meta line.
  Future<int> activityCandidateCount(String activityId) async {
    if (!isReady) return 0;

    try {
      final response = await _client
          .from('outreach_activity_candidates')
          .select('candidate_id')
          .eq('activity_id', activityId)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('❌ activityCandidateCount: $e');
      return 0;
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

/// One row of an activity's roster, resolved for display. Carries the member's
/// name and best avatar url alongside the participant's role and attendance, so
/// the detail screen never has to reach back into the member repository to
/// render the list.
class ActivityRosterEntry {
  const ActivityRosterEntry({
    required this.participantId,
    required this.memberId,
    required this.memberName,
    this.memberAvatarUrl,
    this.role = 'volunteer',
    this.attended,
  });

  final String participantId;
  final String memberId;
  final String memberName;
  final String? memberAvatarUrl;
  final String role;

  /// null means attendance has not been recorded yet, distinct from false.
  final bool? attended;
}
