import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// The three ballot choices (mirrors the widened table CHECK constraint).
const Set<String> kValidVotes = {'yes', 'no', 'undecided'};

/// Consensus floor: never let fewer than 5 participants "reach consensus"
/// for the org, no matter how light attendance is.
const int kQuorumFloor = 5;

/// One executive member's ballot on one candidate: a 3-way vote plus the
/// optional reason capture (single-element `reasonCodes` today; array type
/// keeps future multi-select free).
@immutable
class BallotEntry {
  final String candidateId;
  final String voterId;
  final String voterName;

  /// 'yes', 'no' or 'undecided' (mirrors the table CHECK constraint).
  final String vote;
  final List<String> reasonCodes;
  final String? otherText;
  final DateTime? updatedAt;

  const BallotEntry({
    required this.candidateId,
    required this.voterId,
    required this.voterName,
    required this.vote,
    this.reasonCodes = const [],
    this.otherText,
    this.updatedAt,
  });

  bool get isYes => vote == 'yes';
  bool get hasReason => reasonCodes.isNotEmpty;
}

/// A per-candidate 3-way tally plus how many seeded execs have not weighed in.
@immutable
class VoteTally {
  final int yes;
  final int no;
  final int undecided;

  /// Seeded roster members (exec roster + anyone seen voting) who have not
  /// cast a ballot on this candidate yet. Clamped at 0.
  final int pending;

  const VoteTally({
    required this.yes,
    required this.no,
    required this.undecided,
    required this.pending,
  });

  int get cast => yes + no + undecided;
  bool get hasVotes => cast > 0;

  /// Yes share of the votes actually cast (0..1); null when nobody has voted.
  double? get yesShare => cast == 0 ? null : yes / cast;

  /// Strict majority of the votes cast so far.
  bool get majorityYes => cast > 0 && yes > no;
}

/// Which consensus bucket a ballot candidate falls into tonight.
enum VoteBucket { stillOpen, consensusReady, split }

/// The cached buckets snapshot: consensus math for every ballot candidate,
/// plus the dynamic quorum derived from actual participation (never a
/// hardcoded head-count).
@immutable
class VoteBuckets {
  final List<String> consensusReady;
  final List<String> split;
  final List<String> stillOpen;

  /// Distinct voters who have cast at least one ballot on any ballot
  /// candidate tonight (legacy pre-cast voters count).
  final int participants;

  /// `max(kQuorumFloor, majority of participants)`.
  final int effectiveQuorum;

  final Map<String, VoteBucket> byCandidate;

  /// For consensus-ready candidates: 'yes' (suggests Endorse) or 'no'
  /// (suggests Decline).
  final Map<String, String> suggestionFor;

  const VoteBuckets({
    required this.consensusReady,
    required this.split,
    required this.stillOpen,
    required this.participants,
    required this.effectiveQuorum,
    required this.byCandidate,
    required this.suggestionFor,
  });

  static const empty = VoteBuckets(
    consensusReady: [],
    split: [],
    stillOpen: [],
    participants: 0,
    effectiveQuorum: kQuorumFloor,
    byCandidate: {},
    suggestionFor: {},
  );

  VoteBucket bucketOf(String candidateId) =>
      byCandidate[candidateId] ?? VoteBucket.stillOpen;
}

/// Shared per-member voting store for the committee, backed by
/// `public.endorsement_votes` with realtime sync (same live-board pattern as
/// [SupabaseDecisionRepository]).
///
/// Every exec/staff member reads ALL votes; RLS restricts writes so each
/// member can only upsert/delete their OWN row (PK candidate_id + voter_id).
/// EVERY write is optimistic-with-rollback: the local map updates and
/// notifies immediately, the write is awaited, and on failure the snapshot is
/// restored and `false` returned so the UI can surface a Retry (the 7/14
/// lesson: no more silent failures).
class EndorsementVoteRepository extends ChangeNotifier {
  static const _table = 'endorsement_votes';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// candidateId -> (voterId -> ballot)
  final Map<String, Map<String, BallotEntry>> _votes = {};

  /// The exec roster seeded from public.members (uid -> name); vote rows then
  /// overwrite/add so an edge-case voter outside the seed still counts.
  final Map<String, String> _seededVoters = {};

  /// Seeded roster + every voter seen in a vote row + the signed-in member.
  final Map<String, String> _knownVoters = {};

  // -------- memoized derived state (the whole board rebuilds per notify) --
  final Map<String, VoteTally> _tallyCache = {};
  VoteBuckets _bucketsCache = VoteBuckets.empty;
  String _bucketsKey = '';
  bool _bucketsDirty = true;

  bool _loaded = false;
  bool _disposed = false;
  RealtimeChannel? _channel;
  Timer? _rtDebounce;

  String? _currentUserId;
  String _currentUserName = 'You';

  /// Human-readable description of the last failed write, for debugging.
  String? lastError;

  SupabaseClient get _client => _supabase.client;

  /// The signed-in member's auth uid (null when signed out).
  String? get currentUserId => _currentUserId;

  /// Display name stored alongside the signed-in member's votes.
  String get currentUserName => _currentUserName;

  /// Denominator for "{cast} of {roomSize} execs in".
  int get roomSize => _knownVoters.length;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _currentUserId = _client.auth.currentUser?.id;
      await _resolveCurrentUserName();
      await _seedExecRoster();
      final rows = await _client.from(_table).select();
      _votes.clear();
      for (final row in (rows as List)) {
        _applyRow(Map<String, dynamic>.from(row as Map));
      }
      _rebuildKnownVoters();
    } catch (e) {
      debugPrint('EndorsementVoteRepository.load error: $e');
    }
    _loaded = true;
    _invalidateAll();
    notifyListeners();
    _subscribe();
  }

  /// Re-run the select-all and reapply. Wired to pull-to-refresh: covers
  /// realtime gaps after phone sleep / offline.
  Future<void> refresh() async {
    try {
      final rows = await _client.from(_table).select();
      _votes.clear();
      for (final row in (rows as List)) {
        _applyRow(Map<String, dynamic>.from(row as Map));
      }
      _rebuildKnownVoters();
      _invalidateAll();
      notifyListeners();
    } catch (e) {
      lastError = 'refresh: $e';
      debugPrint('EndorsementVoteRepository.refresh error: $e');
    }
  }

  /// Resolve the member's display name the same way the decision board's
  /// activity feed does: public.members keyed by user_id = auth.uid().
  Future<void> _resolveCurrentUserName() async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final row = await _client
          .from('members')
          .select('name')
          .eq('user_id', uid)
          .maybeSingle();
      final name = row?['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        _currentUserName = name;
        return;
      }
    } catch (e) {
      debugPrint('EndorsementVoteRepository.name error: $e');
    }
    // Fallback so a vote is never stored with an empty display name.
    final email = _client.auth.currentUser?.email ?? '';
    _currentUserName = email.contains('@')
        ? email.substring(0, email.indexOf('@'))
        : 'An exec';
  }

  /// Seed the voter roster from the exec committee so "pending" counts every
  /// exec, not just voters-seen-in-rows. Execs without a user_id cannot auth
  /// and are correctly excluded by the filter. On failure fall back to
  /// today's rows+self behavior (degraded pending counts beat a dead board).
  Future<void> _seedExecRoster() async {
    try {
      final rows = await _client
          .from('members')
          .select('user_id, name')
          .eq('executive_committee', true)
          .not('user_id', 'is', null);
      _seededVoters.clear();
      for (final row in (rows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final uid = m['user_id']?.toString();
        if (uid == null || uid.isEmpty) continue;
        final name = m['name']?.toString().trim();
        _seededVoters[uid] = (name == null || name.isEmpty) ? 'An exec' : name;
      }
    } catch (e) {
      debugPrint('EndorsementVoteRepository.seedExecRoster error: $e');
    }
  }

  void _applyRow(Map<String, dynamic> m) {
    final candidateId = m['candidate_id']?.toString();
    final voterId = m['voter_id']?.toString();
    final vote = m['vote']?.toString();
    if (candidateId == null || candidateId.isEmpty) return;
    if (voterId == null || voterId.isEmpty) return;
    if (vote == null || !kValidVotes.contains(vote)) return;
    final name = m['voter_name']?.toString().trim();
    final other = m['other_text']?.toString();
    (_votes[candidateId] ??= {})[voterId] = BallotEntry(
      candidateId: candidateId,
      voterId: voterId,
      voterName: (name == null || name.isEmpty) ? 'An exec' : name,
      vote: vote,
      reasonCodes: (m['reason_codes'] as List?)?.cast<String>() ?? const [],
      otherText: (other == null || other.isEmpty) ? null : other,
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal(),
    );
    _invalidateCandidate(candidateId);
  }

  void _removeRow(Map<String, dynamic> old) {
    final candidateId = old['candidate_id']?.toString();
    final voterId = old['voter_id']?.toString();
    if (candidateId == null || voterId == null) return;
    final perCandidate = _votes[candidateId];
    if (perCandidate == null) return;
    perCandidate.remove(voterId);
    if (perCandidate.isEmpty) _votes.remove(candidateId);
    _invalidateCandidate(candidateId);
  }

  void _rebuildKnownVoters() {
    final before = Map<String, String>.of(_knownVoters);
    _knownVoters
      ..clear()
      ..addAll(_seededVoters);
    for (final perCandidate in _votes.values) {
      for (final v in perCandidate.values) {
        _knownVoters[v.voterId] = v.voterName;
      }
    }
    final uid = _currentUserId;
    if (uid != null) _knownVoters[uid] = _currentUserName;
    // Room size feeds every tally's pending count: if the roster changed,
    // every cached tally is stale.
    if (!mapEquals(before, _knownVoters)) _invalidateAll();
  }

  void _invalidateCandidate(String candidateId) {
    _tallyCache.remove(candidateId);
    _bucketsDirty = true;
  }

  void _invalidateAll() {
    _tallyCache.clear();
    _bucketsDirty = true;
  }

  // Live-sync every other exec's votes into this board. Realtime bursts are
  // coalesced behind a ~100ms trailing-edge debounce; local optimistic writes
  // still notify immediately so the caster's tap feels instant.
  void _subscribe() {
    if (_channel != null) return;
    try {
      _channel = _client.channel('public:$_table')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              _removeRow(payload.oldRecord);
            } else if (payload.newRecord.isNotEmpty) {
              _applyRow(Map<String, dynamic>.from(payload.newRecord));
            }
            _rebuildKnownVoters();
            _notifyDebounced();
          },
        ).subscribe();
    } catch (e) {
      debugPrint('EndorsementVoteRepository.subscribe error: $e');
    }
  }

  void _notifyDebounced() {
    _rtDebounce?.cancel();
    _rtDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) notifyListeners();
    });
  }

  // ==================== reads ====================

  /// All ballots on a candidate, keyed by voter uid.
  Map<String, BallotEntry> votesFor(String candidateId) =>
      Map.unmodifiable(_votes[candidateId] ?? const {});

  /// Alias of [votesFor] under the ballot vocabulary (reason rollups etc).
  Map<String, BallotEntry> ballotsFor(String candidateId) =>
      votesFor(candidateId);

  /// The signed-in member's vote on a candidate: 'yes', 'no', 'undecided' or
  /// null.
  String? myVote(String candidateId) => myBallot(candidateId)?.vote;

  /// The signed-in member's full ballot (vote + reasons), or null.
  BallotEntry? myBallot(String candidateId) {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _votes[candidateId]?[uid];
  }

  /// Live 3-way tally for a candidate. Memoized: recomputed only after a vote
  /// mutation touches this candidate (or the roster changes).
  VoteTally tallyFor(String candidateId) {
    final cached = _tallyCache[candidateId];
    if (cached != null) return cached;
    final perCandidate = _votes[candidateId] ?? const <String, BallotEntry>{};
    var yes = 0;
    var no = 0;
    var undecided = 0;
    for (final v in perCandidate.values) {
      switch (v.vote) {
        case 'yes':
          yes++;
        case 'no':
          no++;
        default:
          undecided++;
      }
    }
    final cast = yes + no + undecided;
    final tally = VoteTally(
      yes: yes,
      no: no,
      undecided: undecided,
      pending: (roomSize - cast).clamp(0, roomSize),
    );
    _tallyCache[candidateId] = tally;
    return tally;
  }

  /// The consensus buckets snapshot for tonight's ballot set. Memoized behind
  /// a dirty flag that only vote mutations set, so the board can read it on
  /// every rebuild without O(candidates x voters) recomputes per notify.
  ///
  /// Rules (per candidate, `cast = yes + no + undecided`):
  ///  - still open: cast < effectiveQuorum
  ///  - consensus ready: cast >= effectiveQuorum AND a 2/3 supermajority of
  ///    cast ballots agrees yes (suggests Endorse) or no (suggests Decline)
  ///  - split: quorum reached, no supermajority.
  VoteBuckets buckets(List<String> ballotCandidateIds) {
    final key = ballotCandidateIds.join('|');
    if (!_bucketsDirty && key == _bucketsKey) return _bucketsCache;

    final participantIds = <String>{};
    for (final id in ballotCandidateIds) {
      final perCandidate = _votes[id];
      if (perCandidate != null) participantIds.addAll(perCandidate.keys);
    }
    final participants = participantIds.length;
    final effectiveQuorum =
        participants > 0 ? (participants ~/ 2) + 1 : kQuorumFloor;
    final quorum =
        effectiveQuorum < kQuorumFloor ? kQuorumFloor : effectiveQuorum;

    final ready = <String>[];
    final split = <String>[];
    final open = <String>[];
    final byCandidate = <String, VoteBucket>{};
    final suggestionFor = <String, String>{};
    for (final id in ballotCandidateIds) {
      final t = tallyFor(id);
      if (t.cast < quorum) {
        open.add(id);
        byCandidate[id] = VoteBucket.stillOpen;
        continue;
      }
      final threshold = (2 * t.cast / 3).ceil();
      if (t.yes >= threshold) {
        ready.add(id);
        byCandidate[id] = VoteBucket.consensusReady;
        suggestionFor[id] = 'yes';
      } else if (t.no >= threshold) {
        ready.add(id);
        byCandidate[id] = VoteBucket.consensusReady;
        suggestionFor[id] = 'no';
      } else {
        split.add(id);
        byCandidate[id] = VoteBucket.split;
      }
    }
    _bucketsCache = VoteBuckets(
      consensusReady: List.unmodifiable(ready),
      split: List.unmodifiable(split),
      stillOpen: List.unmodifiable(open),
      participants: participants,
      effectiveQuorum: quorum,
      byCandidate: Map.unmodifiable(byCandidate),
      suggestionFor: Map.unmodifiable(suggestionFor),
    );
    _bucketsKey = key;
    _bucketsDirty = false;
    return _bucketsCache;
  }

  /// The full voter roster (uid -> display name): seeded execs plus everyone
  /// seen voting plus the signed-in member.
  Map<String, String> get knownVoters => Map.unmodifiable(_knownVoters);

  // ==================== writes ====================

  /// Cast or change the signed-in member's vote. Tapping the choice they have
  /// already selected withdraws it (deletes their row). Switching a vote
  /// always clears reasons; the reason sheet then optionally re-writes them.
  ///
  /// Optimistic-with-rollback: returns false (and restores the previous local
  /// ballot) when the write fails, so the UI can show a Retry.
  Future<bool> castVote(String candidateId, String vote) async {
    assert(kValidVotes.contains(vote));
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('EndorsementVoteRepository.castVote: no signed-in user');
      return false;
    }
    if (myVote(candidateId) == vote) {
      return clearVote(candidateId);
    }
    final snapshot = _votes[candidateId]?[uid];
    (_votes[candidateId] ??= {})[uid] = BallotEntry(
      candidateId: candidateId,
      voterId: uid,
      voterName: _currentUserName,
      vote: vote,
      reasonCodes: const [],
      otherText: null,
      updatedAt: DateTime.now(),
    );
    _rebuildKnownVoters();
    _invalidateCandidate(candidateId);
    notifyListeners();
    try {
      await _client.from(_table).upsert({
        'candidate_id': candidateId,
        'voter_id': uid,
        'voter_name': _currentUserName,
        'vote': vote,
        'reason_codes': <String>[],
        'other_text': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      lastError = 'castVote: $e';
      debugPrint('EndorsementVoteRepository.castVote error: $e');
      _restoreBallot(candidateId, uid, snapshot);
      return false;
    }
  }

  /// Withdraw the signed-in member's vote on a candidate. Rolls the local
  /// ballot back and returns false when the delete fails.
  Future<bool> clearVote(String candidateId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    final snapshot = _votes[candidateId]?[uid];
    _votes[candidateId]?.remove(uid);
    if (_votes[candidateId]?.isEmpty ?? false) _votes.remove(candidateId);
    _invalidateCandidate(candidateId);
    notifyListeners();
    try {
      await _client
          .from(_table)
          .delete()
          .eq('candidate_id', candidateId)
          .eq('voter_id', uid);
      return true;
    } catch (e) {
      lastError = 'clearVote: $e';
      debugPrint('EndorsementVoteRepository.clearVote error: $e');
      _restoreBallot(candidateId, uid, snapshot);
      return false;
    }
  }

  /// Attach (or replace) the reason on the signed-in member's existing no /
  /// undecided ballot. The ballot itself was already recorded; this is the
  /// optional follow-up from the reason sheet. Reasons never attach to a yes.
  Future<bool> updateReason(
    String candidateId, {
    required List<String> reasonCodes,
    String? otherText,
  }) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    final existing = _votes[candidateId]?[uid];
    if (existing == null ||
        (existing.vote != 'no' && existing.vote != 'undecided')) {
      return false;
    }
    final snapshot = existing;
    (_votes[candidateId] ??= {})[uid] = BallotEntry(
      candidateId: candidateId,
      voterId: uid,
      voterName: existing.voterName,
      vote: existing.vote,
      reasonCodes: List.unmodifiable(reasonCodes),
      otherText: otherText,
      updatedAt: DateTime.now(),
    );
    _invalidateCandidate(candidateId);
    notifyListeners();
    try {
      await _client.from(_table).upsert({
        'candidate_id': candidateId,
        'voter_id': uid,
        'voter_name': existing.voterName,
        'vote': existing.vote,
        'reason_codes': reasonCodes,
        'other_text': otherText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      lastError = 'updateReason: $e';
      debugPrint('EndorsementVoteRepository.updateReason error: $e');
      _restoreBallot(candidateId, uid, snapshot);
      return false;
    }
  }

  /// Rollback helper: restore (or clear) the local ballot after a failed
  /// write, then notify so every card reflects reality again.
  void _restoreBallot(String candidateId, String uid, BallotEntry? snapshot) {
    if (snapshot == null) {
      _votes[candidateId]?.remove(uid);
      if (_votes[candidateId]?.isEmpty ?? false) _votes.remove(candidateId);
    } else {
      (_votes[candidateId] ??= {})[uid] = snapshot;
    }
    _rebuildKnownVoters();
    _invalidateCandidate(candidateId);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _rtDebounce?.cancel();
    try {
      final ch = _channel;
      if (ch != null) _client.removeChannel(ch);
    } catch (_) {}
    super.dispose();
  }
}
