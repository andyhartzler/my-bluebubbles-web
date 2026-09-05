import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/outreach_touchpoint.dart';
import 'package:bluebubbles/screens/crm/volunteers/volunteers_map_models.dart';
import 'supabase_service.dart';

/// The geo column a [MapMode] filters on: county names for counties, bare-digit
/// district numbers for the three district modes.
///
/// Top-level and public because two repositories read the same arrays.
/// OutreachRepository still carries a private copy of this switch; deleting it
/// in favour of this one is what stops the two drifting on region key shapes
/// (spec 7.2).
String outreachGeoColumn(MapMode mode) {
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

/// Data layer for public.outreach_touchpoints: the Mobilize Desk's drafts and
/// its record of what was sent. Same conventions as [OutreachRepository]:
/// an isReady guard, reads throw, writes on the optimistic path rethrow, and
/// anything unbounded pages with .range() against the PostgREST 1000-row cap.
///
/// The two id spaces are never conflated here. Every write takes the acting
/// exec's ids from the caller (spec 4.1); this class never reads the session,
/// because a silent session fallback is how organizer_member_id ended up never
/// being set on activities in the first place.
class TouchpointRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client => _supabase.client;

  static const int _pageSize = 1000;

  static const String _table = 'outreach_touchpoints';

  /// Insert the draft the moment the Desk has both an audience and a body.
  /// Returns the new id, which is also this send's idempotency key (3.5), or
  /// null if the CRM is not ready or the insert fails.
  Future<String?> startDraft(TouchpointDraft draft) async {
    if (!isReady) return null;

    try {
      final row = await _client
          .from(_table)
          .insert(draft.toInsertJson())
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      debugPrint('❌ startDraft: $e');
      return null;
    }
  }

  /// The debounced composer save. Scoped to status = 'draft' so a save still in
  /// flight when the exec hits Send cannot overwrite a claimed or resolved row
  /// with stale composer state.
  ///
  /// Rethrows: the composer's "Saved" caption reverts to "Not saved" on
  /// failure, which it can only do if the exception surfaces.
  Future<void> saveDraft(String id, TouchpointDraft draft) async {
    if (!isReady) return;

    try {
      await _client
          .from(_table)
          .update(draft.toUpdateJson())
          .eq('id', id)
          .eq('status', 'draft');
    } catch (e) {
      debugPrint('❌ saveDraft: $e');
      rethrow;
    }
  }

  /// The send guard (3.5). Compare-and-set from 'draft' to 'sending': zero rows
  /// back means another tab, a double-tap or a retried request already claimed
  /// this send, so the caller must not send again.
  ///
  /// The touchpoint id is the idempotency key. There is no separate send key,
  /// and the Desk holds exactly one id per composer, so no path can mint a
  /// second row for the same send.
  Future<TouchpointClaim> claimForSend(String id, int attemptedCount) async {
    if (!isReady) return TouchpointClaim.unavailable;

    try {
      final claimed = await _client
          .from(_table)
          .update(<String, dynamic>{
            'status': 'sending',
            'attempted_count': attemptedCount,
          })
          .eq('id', id)
          .eq('status', 'draft')
          .select('id')
          .maybeSingle();
      return claimed == null
          ? TouchpointClaim.alreadyClaimed
          : TouchpointClaim.claimed;
    } catch (e) {
      debugPrint('❌ claimForSend: $e');
      rethrow;
    }
  }

  /// Write the outcome once the send resolves (3.6). Delivered and failed are
  /// counts and a member-id list, never a boolean, because an sms send can
  /// land for some recipients and not others.
  Future<void> finishSend(String id, TouchpointSendOutcome outcome) async {
    if (!isReady) return;

    try {
      await _client.from(_table).update(outcome.toUpdateJson()).eq('id', id);
    } catch (e) {
      debugPrint('❌ finishSend: $e');
      rethrow;
    }
  }

  /// Abandon a draft. It is kept, not deleted, so the audit trail still shows
  /// that an exec started this and chose not to send it.
  Future<void> discardDraft(String id) async {
    if (!isReady) return;

    try {
      await _client
          .from(_table)
          .update(<String, dynamic>{'status': 'discarded'})
          .eq('id', id)
          .eq('status', 'draft');
    } catch (e) {
      debugPrint('❌ discardDraft: $e');
      rethrow;
    }
  }

  /// The desk rail's Drafts group: unsent composer state, newest edit first.
  /// Interrupted sends ('sending') come back in the same call because the rail
  /// sorts them above the drafts (4.4).
  ///
  /// [actorMemberId] null is the rail's "Show the whole committee" toggle.
  /// Scoping is a UI choice, not a policy one: the RLS on this table is
  /// committee-wide on purpose, because Andrew asked that this work be tracked
  /// and monitored rather than kept private to whoever typed it.
  Future<List<OutreachTouchpoint>> drafts({String? actorMemberId}) async {
    if (!isReady) return <OutreachTouchpoint>[];

    final rows = <OutreachTouchpoint>[];
    var offset = 0;

    while (true) {
      var query = _client
          .from(_table)
          .select()
          .inFilter('status', <String>['draft', 'sending']);
      if (actorMemberId != null) {
        query = query.eq('actor_member_id', actorMemberId);
      }

      final page = _parse(await query
          .order('last_edited_at', ascending: false)
          .range(offset, offset + _pageSize - 1));

      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    return rows;
  }

  /// The desk rail's Recent sends group: resolved touchpoints, newest send
  /// first. [actorMemberId] null is the committee-wide view, exactly as in
  /// [drafts].
  Future<List<OutreachTouchpoint>> recent({
    String? actorMemberId,
    int limit = 20,
  }) async {
    if (!isReady) return <OutreachTouchpoint>[];

    var query = _client
        .from(_table)
        .select()
        .inFilter('status', <String>['sent', 'partial', 'failed']);
    if (actorMemberId != null) {
      query = query.eq('actor_member_id', actorMemberId);
    }

    return _parse(
        await query.order('sent_at', ascending: false).limit(limit));
  }

  /// Close out a send whose tab went away mid-flight (3.5). There is no way to
  /// learn from here what the provider actually did, so the exec says, and the
  /// row records that a human said it rather than pretending the send path
  /// reported.
  ///
  /// Compare-and-set from 'sending', the same guard [claimForSend] uses: a row
  /// that resolved on its own in another tab between the card opening and this
  /// call is left exactly as that tab wrote it.
  Future<void> resolveInterrupted(
    String id,
    TouchpointSendOutcome outcome,
  ) async {
    if (!isReady) return;

    try {
      await _client
          .from(_table)
          .update(outcome.toUpdateJson())
          .eq('id', id)
          .eq('status', 'sending');
    } catch (e) {
      debugPrint('❌ resolveInterrupted: $e');
      rethrow;
    }
  }

  /// The region section's "Recent contact" block. `.contains` maps to
  /// PostgREST array containment against the GIN-indexed geo column, exactly as
  /// the activities do. Drafts and discards are excluded: the region's profile
  /// records contact that happened, not contact somebody thought about.
  Future<List<OutreachTouchpoint>> forRegion(
    MapMode mode,
    String regionId, {
    int limit = 10,
  }) async {
    if (!isReady) return <OutreachTouchpoint>[];

    final response = await _client
        .from(_table)
        .select()
        .contains(outreachGeoColumn(mode), <String>[regionId])
        .inFilter('status', <String>['sent', 'partial', 'failed'])
        .order('sent_at', ascending: false)
        .limit(limit);

    return _parse(response);
  }

  /// The nominee profile's "Recent contact" block, filtered on the
  /// GIN-indexed candidate_ids array.
  Future<List<OutreachTouchpoint>> forCandidate(
    String candidateId, {
    int limit = 20,
  }) async {
    if (!isReady) return <OutreachTouchpoint>[];

    final response = await _client
        .from(_table)
        .select()
        .contains('candidate_ids', <String>[candidateId])
        .inFilter('status', <String>['sent', 'partial', 'failed'])
        .order('sent_at', ascending: false)
        .limit(limit);

    return _parse(response);
  }

  /// The member profile's "Recent contact" block: every bulk send this member
  /// was a recipient of, newest first. Backed by the GIN index on
  /// recipient_member_ids, which exists for exactly this read.
  ///
  /// It answers "what have we said to this person", so it deliberately does
  /// NOT subtract the failures: a send that did not reach them is part of the
  /// history an exec needs before contacting them again. The row's own status
  /// says which is which.
  Future<List<OutreachTouchpoint>> forMember(
    String memberId, {
    int limit = 20,
  }) async {
    if (!isReady) return <OutreachTouchpoint>[];

    final response = await _client
        .from(_table)
        .select()
        .contains('recipient_member_ids', <String>[memberId])
        .inFilter('status', <String>['sent', 'partial', 'failed'])
        .order('sent_at', ascending: false)
        .limit(limit);

    return _parse(response);
  }

  /// "Log this as an activity" (3.1). One RPC, so the activity, its candidate
  /// links, a participant row per delivered recipient and the activity_id
  /// stamped back on the touchpoint are all or nothing.
  ///
  /// Both attribution ids are passed separately and neither is derived from the
  /// other: [actorUserId] is an auth.users.id and lands on created_by,
  /// [actorMemberId] is a members.id and lands on organizer_member_id, which
  /// closes the gap in 4.2 for every activity this path creates.
  ///
  /// Idempotent in the database: a touchpoint that already carries an
  /// activity_id returns that activity rather than writing a second one, so a
  /// double tap or a stale card costs nothing.
  Future<String?> promoteToActivity(
    String touchpointId, {
    required String actorUserId,
    required String actorMemberId,
  }) async {
    if (!isReady) return null;

    try {
      final id = await _client.rpc(
        'promote_touchpoint_to_activity',
        params: <String, dynamic>{
          'p_touchpoint_id': touchpointId,
          'p_created_by': actorUserId,
          'p_organizer_member_id': actorMemberId,
        },
      );
      return id?.toString();
    } catch (e) {
      debugPrint('❌ promoteToActivity: $e');
      rethrow;
    }
  }

  List<OutreachTouchpoint> _parse(dynamic response) =>
      (response as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OutreachTouchpoint.fromJson)
          .toList();
}
