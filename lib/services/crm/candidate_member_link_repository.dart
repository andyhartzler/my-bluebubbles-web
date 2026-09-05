import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/candidate_member_link.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';
import 'supabase_service.dart';

/// The [MapMode] a stored `source_region_mode` names, or null for a link made
/// member by member. The stored token is `MapMode.name` by construction, and
/// the column's CHECK allows exactly those four values, so anything else is a
/// row written outside this app and is treated as having no region.
MapMode? candidateLinkSourceMode(String? storedMode) {
  if (storedMode == null) return null;
  for (final mode in MapMode.values) {
    if (mode.name == storedMode) return mode;
  }
  return null;
}

/// Data layer for public.candidate_member_links: which members are the
/// volunteer base for a November nominee.
///
/// This is NOT `candidates.member_id`. That column says "this candidate IS this
/// member", is singular, and is written by CandidateRepository. Nothing here
/// touches it (spec 5.1). The two get confused because both talk about a
/// candidate and a member.
///
/// Area-wide links are materialized at link time, one row per member, rather
/// than stored as a region filter resolved on read. That is what makes a count
/// stable week to week, lets an exec drop one person from a linked county, and
/// leaves an audit trail of who linked what and when (spec 5.2).
///
/// Same conventions as [OutreachRepository]: an isReady guard, reads throw,
/// writes on the optimistic path rethrow, and anything unbounded pages with
/// .range() against the PostgREST 1000-row cap.
class CandidateMemberLinkRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client => _supabase.client;

  static const int _pageSize = 1000;

  /// A region can carry more nominee ids, and a nominee more linked members,
  /// than belong in one URL's `in.()` list or in one insert body. Every
  /// multi-id filter and every bulk insert goes in chunks this size.
  static const int _filterChunk = 200;

  static const String _table = 'candidate_member_links';

  static const Uuid _uuid = Uuid();

  /// Link [memberIds] to a nominee. One gesture, one batch_id, so the whole
  /// insert can later be named ("Boone County, 42 members") and undone as a
  /// unit. Pass [sourceMode] and [sourceRegionId] when the gesture came from a
  /// region; leave both null when the exec picked people individually.
  ///
  /// Returns the count of GENUINELY NEW rows, the way addParticipants does:
  /// the already-linked ids are read first and excluded, so the caller can say
  /// "12 added, 3 already linked" rather than guessing. The insert is still an
  /// upsert that ignores duplicates, because two execs can link the same county
  /// at the same time and the loser of that race must not see an error.
  ///
  /// [actorUserId] is an auth.users id and [actorMemberId] is a public.members
  /// id. They are separate parameters, never one `userId`, because both columns
  /// hold bare uuids and a swap surfaces only as an opaque 23503 at insert
  /// time (spec 4.1). This class never reads the session itself.
  Future<int> linkMembers({
    required String candidateId,
    required List<String> memberIds,
    MapMode? sourceMode,
    String? sourceRegionId,
    String? note,
    required String actorUserId,
    required String actorMemberId,
  }) async {
    if (!isReady || memberIds.isEmpty) return 0;

    try {
      final existing = await _linkedMemberIds(candidateId);
      final seen = <String>{};
      final fresh = <String>[
        for (final id in memberIds)
          if (!existing.contains(id) && seen.add(id)) id,
      ];
      if (fresh.isEmpty) return 0;

      final batchId = _uuid.v4();
      final rows = <Map<String, dynamic>>[
        for (final memberId in fresh)
          <String, dynamic>{
            'candidate_id': candidateId,
            'member_id': memberId,
            // The stored token is MapMode.name, which is exactly what the
            // column's CHECK allows. A region id without a mode would describe
            // nothing, so it is dropped rather than stored half.
            'source_region_mode': sourceMode?.name,
            'source_region_id': sourceMode == null ? null : sourceRegionId,
            'batch_id': batchId,
            'note': note,
            'created_by_user_id': actorUserId,
            'created_by_member_id': actorMemberId,
            // created_at is left to the column default. Browser clocks in this
            // org have run hours fast before, and this timestamp is what the
            // batch is dated by.
          },
      ];

      for (var start = 0; start < rows.length; start += _filterChunk) {
        final end = start + _filterChunk;
        await _client.from(_table).upsert(
              rows.sublist(start, end > rows.length ? rows.length : end),
              onConflict: 'candidate_id,member_id',
              ignoreDuplicates: true,
            );
      }
      return rows.length;
    } catch (e) {
      debugPrint('❌ linkMembers: $e');
      rethrow;
    }
  }

  /// Drop one member from a nominee's base. Their batch keeps its batch_id, so
  /// "Refresh from Boone County" will add them back: we cannot tell "removed on
  /// purpose" from "not yet added", and the confirm text says so (spec 5.4).
  /// Rethrows so the caller's optimistic revert fires.
  Future<void> unlink(String candidateId, String memberId) async {
    if (!isReady) return;

    try {
      await _client
          .from(_table)
          .delete()
          .eq('candidate_id', candidateId)
          .eq('member_id', memberId);
    } catch (e) {
      debugPrint('❌ unlink: $e');
      rethrow;
    }
  }

  /// Undo a whole link gesture. Returns how many rows went, which is what the
  /// confirmation reports back ("42 members unlinked"). Rows already unlinked
  /// one at a time are simply not there to delete.
  Future<int> unlinkBatch(String batchId) async {
    if (!isReady) return 0;

    try {
      final response = await _client
          .from(_table)
          .delete()
          .eq('batch_id', batchId)
          .select('member_id');
      return (response as List<dynamic>? ?? const <dynamic>[]).length;
    } catch (e) {
      debugPrint('❌ unlinkBatch: $e');
      rethrow;
    }
  }

  /// Every link for a nominee, newest first, paged. The CONNECT section groups
  /// these with [CandidateMemberLinkBatch.groupFrom] rather than asking again.
  Future<List<CandidateMemberLink>> linksForCandidate(
      String candidateId) async {
    if (!isReady) return <CandidateMemberLink>[];

    final links = <CandidateMemberLink>[];
    var offset = 0;

    while (true) {
      final response = await _client
          .from(_table)
          .select()
          .eq('candidate_id', candidateId)
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final rows = (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      links.addAll(rows.map(CandidateMemberLink.fromJson));

      if (rows.length < _pageSize) break;
      offset += _pageSize;
    }

    return links;
  }

  /// "n members linked" for a whole pane of nominee cards, in one pass.
  /// Candidates with no links are absent from the map, so callers read it as
  /// `counts[id] ?? 0`.
  Future<Map<String, int>> linkCountsForCandidates(
      List<String> candidateIds) async {
    if (!isReady || candidateIds.isEmpty) return <String, int>{};

    final wanted = candidateIds.toSet().toList();
    final counts = <String, int>{};

    for (var start = 0; start < wanted.length; start += _filterChunk) {
      final end = start + _filterChunk;
      final chunk =
          wanted.sublist(start, end > wanted.length ? wanted.length : end);

      var offset = 0;
      while (true) {
        final response = await _client
            .from(_table)
            .select('candidate_id')
            .inFilter('candidate_id', chunk)
            .range(offset, offset + _pageSize - 1);

        final rows = (response as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
        for (final row in rows) {
          final id = row['candidate_id']?.toString();
          if (id != null) counts[id] = (counts[id] ?? 0) + 1;
        }

        if (rows.length < _pageSize) break;
        offset += _pageSize;
      }
    }

    return counts;
  }

  /// The nominee's volunteer base as full [Member] rows, which is what the
  /// Desk's "Everyone linked to {nominee}" audience source hands the composer.
  /// A link whose member row is gone resolves to nothing and is dropped: the
  /// FK cascades on delete, so this only happens mid-delete.
  Future<List<Member>> linkedMembers(String candidateId) async {
    if (!isReady) return <Member>[];

    final ids = (await _linkedMemberIds(candidateId)).toList();
    if (ids.isEmpty) return <Member>[];

    final members = <Member>[];
    for (var start = 0; start < ids.length; start += _filterChunk) {
      final end = start + _filterChunk;
      final chunk = ids.sublist(start, end > ids.length ? ids.length : end);

      final response =
          await _client.from('members').select().inFilter('id', chunk);
      members.addAll((response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Member.fromJson));
    }
    return members;
  }

  /// The member ids already linked to a nominee, paged. Used both to fetch the
  /// base and to make [linkMembers] report an exact count of new rows.
  Future<Set<String>> _linkedMemberIds(String candidateId) async {
    final ids = <String>{};
    var offset = 0;

    while (true) {
      final response = await _client
          .from(_table)
          .select('member_id')
          .eq('candidate_id', candidateId)
          .range(offset, offset + _pageSize - 1);

      final rows = (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final row in rows) {
        final id = row['member_id']?.toString();
        if (id != null) ids.add(id);
      }

      if (rows.length < _pageSize) break;
      offset += _pageSize;
    }

    return ids;
  }
}
