import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// One executive member's yes/no vote on one candidate.
@immutable
class EndorsementVote {
  final String candidateId;
  final String voterId;
  final String voterName;

  /// 'yes' or 'no' (mirrors the table CHECK constraint).
  final String vote;
  final DateTime? updatedAt;

  const EndorsementVote({
    required this.candidateId,
    required this.voterId,
    required this.voterName,
    required this.vote,
    this.updatedAt,
  });

  bool get isYes => vote == 'yes';
}

/// A per-candidate yes/no tally plus who has not weighed in yet.
@immutable
class VoteTally {
  final int yes;
  final int no;

  /// Known committee voters (seen anywhere on the board) who have not voted
  /// on this candidate yet.
  final int pending;

  const VoteTally({required this.yes, required this.no, required this.pending});

  int get cast => yes + no;
  bool get hasVotes => cast > 0;

  /// Yes share of the votes actually cast (0..1); null when nobody has voted.
  double? get yesShare => cast == 0 ? null : yes / cast;

  /// Strict majority of the votes cast so far.
  bool get majorityYes => cast > 0 && yes > no;
}

/// Shared per-member voting store for the committee, backed by
/// `public.endorsement_votes` with realtime sync (same live-board pattern as
/// [SupabaseDecisionRepository]).
///
/// Every exec/staff member reads ALL votes; RLS restricts writes so each
/// member can only upsert/delete their OWN row (PK candidate_id + voter_id).
/// Casting is optimistic: the local map updates and notifies immediately,
/// then the write lands and the realtime feed reconciles everyone.
class EndorsementVoteRepository extends ChangeNotifier {
  static const _table = 'endorsement_votes';

  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// candidateId -> (voterId -> vote)
  final Map<String, Map<String, EndorsementVote>> _votes = {};

  /// Every voter seen anywhere on the board (voterId -> display name), plus
  /// the signed-in member. Used to show who has not voted yet.
  final Map<String, String> _knownVoters = {};

  bool _loaded = false;
  RealtimeChannel? _channel;

  String? _currentUserId;
  String _currentUserName = 'You';

  SupabaseClient get _client => _supabase.client;

  /// The signed-in member's auth uid (null when signed out).
  String? get currentUserId => _currentUserId;

  /// Display name stored alongside the signed-in member's votes.
  String get currentUserName => _currentUserName;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _currentUserId = _client.auth.currentUser?.id;
      await _resolveCurrentUserName();
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
    notifyListeners();
    _subscribe();
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

  void _applyRow(Map<String, dynamic> m) {
    final candidateId = m['candidate_id']?.toString();
    final voterId = m['voter_id']?.toString();
    final vote = m['vote']?.toString();
    if (candidateId == null || candidateId.isEmpty) return;
    if (voterId == null || voterId.isEmpty) return;
    if (vote == null || (vote != 'yes' && vote != 'no')) return;
    final name = m['voter_name']?.toString().trim();
    (_votes[candidateId] ??= {})[voterId] = EndorsementVote(
      candidateId: candidateId,
      voterId: voterId,
      voterName: (name == null || name.isEmpty) ? 'An exec' : name,
      vote: vote,
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal(),
    );
  }

  void _removeRow(Map<String, dynamic> old) {
    final candidateId = old['candidate_id']?.toString();
    final voterId = old['voter_id']?.toString();
    if (candidateId == null || voterId == null) return;
    final perCandidate = _votes[candidateId];
    if (perCandidate == null) return;
    perCandidate.remove(voterId);
    if (perCandidate.isEmpty) _votes.remove(candidateId);
  }

  void _rebuildKnownVoters() {
    _knownVoters.clear();
    for (final perCandidate in _votes.values) {
      for (final v in perCandidate.values) {
        _knownVoters[v.voterId] = v.voterName;
      }
    }
    final uid = _currentUserId;
    if (uid != null) _knownVoters[uid] = _currentUserName;
  }

  // Live-sync every other exec's votes into this board.
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
            notifyListeners();
          },
        ).subscribe();
    } catch (e) {
      debugPrint('EndorsementVoteRepository.subscribe error: $e');
    }
  }

  // ==================== reads ====================

  /// All votes on a candidate, keyed by voter uid.
  Map<String, EndorsementVote> votesFor(String candidateId) =>
      Map.unmodifiable(_votes[candidateId] ?? const {});

  /// The signed-in member's vote on a candidate: 'yes', 'no' or null.
  String? myVote(String candidateId) {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _votes[candidateId]?[uid]?.vote;
  }

  /// Live yes/no tally for a candidate, with how many known committee voters
  /// have not weighed in on it yet.
  VoteTally tallyFor(String candidateId) {
    final perCandidate = _votes[candidateId] ?? const <String, EndorsementVote>{};
    var yes = 0;
    var no = 0;
    for (final v in perCandidate.values) {
      if (v.isYes) {
        yes++;
      } else {
        no++;
      }
    }
    final pending = _knownVoters.keys
        .where((uid) => !perCandidate.containsKey(uid))
        .length;
    return VoteTally(yes: yes, no: no, pending: pending);
  }

  /// Everyone who has voted anywhere on the board (uid -> display name),
  /// including the signed-in member. This is the roster used to show who has
  /// not voted on a given candidate yet.
  Map<String, String> get knownVoters => Map.unmodifiable(_knownVoters);

  // ==================== writes ====================

  /// Cast or change the signed-in member's vote. Tapping the choice they have
  /// already selected clears their vote (deletes their row). Optimistic:
  /// the board updates instantly, then the write lands.
  Future<void> castVote(String candidateId, String vote) async {
    assert(vote == 'yes' || vote == 'no');
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint('EndorsementVoteRepository.castVote: no signed-in user');
      return;
    }
    if (myVote(candidateId) == vote) {
      await clearVote(candidateId);
      return;
    }
    (_votes[candidateId] ??= {})[uid] = EndorsementVote(
      candidateId: candidateId,
      voterId: uid,
      voterName: _currentUserName,
      vote: vote,
      updatedAt: DateTime.now(),
    );
    _rebuildKnownVoters();
    notifyListeners();
    try {
      await _client.from(_table).upsert({
        'candidate_id': candidateId,
        'voter_id': uid,
        'voter_name': _currentUserName,
        'vote': vote,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('EndorsementVoteRepository.castVote error: $e');
    }
  }

  /// Withdraw the signed-in member's vote on a candidate.
  Future<void> clearVote(String candidateId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    _votes[candidateId]?.remove(uid);
    if (_votes[candidateId]?.isEmpty ?? false) _votes.remove(candidateId);
    notifyListeners();
    try {
      await _client
          .from(_table)
          .delete()
          .eq('candidate_id', candidateId)
          .eq('voter_id', uid);
    } catch (e) {
      debugPrint('EndorsementVoteRepository.clearVote error: $e');
    }
  }

  @override
  void dispose() {
    try {
      final ch = _channel;
      if (ch != null) _client.removeChannel(ch);
    } catch (_) {}
    super.dispose();
  }
}
