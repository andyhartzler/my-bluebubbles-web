import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// The three ballot choices (mirrors the widened table CHECK constraint).
const Set<String> kValidVotes = {'yes', 'no', 'undecided'};

/// Rows per page of the ballot fetch.
///
/// PostgREST caps EVERY response at the project's `db-max-rows` and does it
/// SILENTLY: HTTP 200, no error field, just fewer rows. Measured against this
/// project on 2026-07-27: an unbounded `select()` returned exactly 1000 rows
/// with `content-range: 0-999/*`, and no role carries a `pgrst.db_max_rows`
/// override (`pg_roles.rolconfig` for anon/authenticated/authenticator/
/// service_role holds only statement/lock timeouts).
///
/// A full board is 16 execs x 73 candidates = 1168 rows. The bare `select()`
/// this repository used to issue would therefore have dropped 168 ballots
/// with nothing to show for it, and the symptom is the worst one available:
/// an exec's OWN votes come back unvoted, they re-vote, and a re-cast clears
/// the stated reasons. 267 ballots exist tonight, so truncation was 733
/// votes away, i.e. mid-evening on a good turnout.
const int kVoteFetchPageSize = 1000;

/// Hard ceiling on the pager: 20 pages x 1000 = 20,000 ballots, about 17x a
/// full board. Reaching it means the cursor is not advancing, which is a bug
/// rather than a big board, so the fetch fails loudly instead of looping.
const int kVoteFetchMaxPages = 20;

/// Ceiling on a ballot READ (which may span several pages). Long enough that
/// a slow phone on venue wifi still lands; short enough that a wedged socket
/// surfaces the board's retry card instead of an eternal spinner.
const Duration kVoteReadTimeout = Duration(seconds: 20);

/// Ceiling on a single ballot WRITE.
///
/// Without it a request that never completes leaves the row's vote control
/// disabled FOREVER: `_VoteSegmentedControlState._busy` is only cleared in
/// the `finally` of the await, so a hung upsert takes that candidate's
/// controls out of service for the rest of the session with no error and no
/// Retry. The `authenticated` role carries `statement_timeout=8s`
/// server-side, so 12s only ever catches a network-level stall.
const Duration kVoteWriteTimeout = Duration(seconds: 12);

/// Why the last ballot write failed, in the only two shapes the UI needs to
/// say different things about.
///
/// A denial and a dropped packet look identical from `castVote`'s `false`,
/// and telling an exec whose account is not recognised as an executive to
/// "check connection" sends them into a retry loop that can never succeed.
enum VoteWriteFailure {
  /// No write has failed since the last successful one.
  none,

  /// RLS/JWT rejected the write. Retrying will not help.
  permissionDenied,

  /// Transport, timeout, or anything else. Retry is worth offering.
  other,
}

/// Classify a write failure. RLS violations surface as PostgREST `42501`;
/// an expired or missing JWT surfaces as `PGRST301` or a bare 401/403.
VoteWriteFailure classifyVoteWriteFailure(Object e) {
  if (e is PostgrestException) {
    final code = e.code;
    if (code == '42501' ||
        code == 'PGRST301' ||
        code == '401' ||
        code == '403') {
      return VoteWriteFailure.permissionDenied;
    }
  }
  if (e is AuthException) return VoteWriteFailure.permissionDenied;
  return VoteWriteFailure.other;
}

/// Whether the ballot fetch has completed, mirroring [DecisionLoadState].
///
/// This exists because a silently failed ballot fetch is the one wrong answer
/// an exec would ACT on. Before this enum, `load()` caught its error, logged
/// to debugPrint and set `loaded = true` regardless, so a single transient
/// failure (expired token mid-refresh, a phone waking, a 5xx) rendered a
/// fully-populated board on which nobody had voted: every row read "No
/// ballots yet", the progress pill read "0 / 50 voted", and the needs-vote
/// badge read the full ballot. An exec seeing that would rationally re-vote
/// everything, and because `castVote` always writes `reason_codes: []`, doing
/// so would wipe their own previously captured reasons. Failing loudly is the
/// only safe behavior.
enum VoteLoadState { loading, ready, failed }

/// Consensus floor: a candidate needs at least this many ballots of their own
/// before any supermajority on them counts as consensus for the org.
const int kQuorumFloor = 5;

/// Prefix of the reason codes that are NOT a voter's stated reason: they mark
/// where a ballot row came from. `meeting_2026_07_14` tags the 166 ballots the
/// July 14 committee call produced when they were backfilled into
/// `public.endorsement_votes` as ordinary ballots.
///
/// These codes are handled apart from the reason vocabulary everywhere:
///   * they are never rendered as "Reason: ..." (they are not one),
///   * they are never counted in the chair's split-note reason rollup,
///   * and they SURVIVE a re-cast, because a re-cast used to write
///     `reason_codes: []` unconditionally and silently erase them.
const String kProvenanceReasonPrefix = 'meeting_';

/// True for a provenance tag (see [kProvenanceReasonPrefix]) rather than a
/// reason the voter chose.
bool isProvenanceReasonCode(String code) =>
    code.startsWith(kProvenanceReasonPrefix);

/// Just the provenance tags out of a stored `reason_codes` array.
List<String> provenanceCodesOf(Iterable<String>? codes) => <String>[
      for (final c in codes ?? const <String>[])
        if (isProvenanceReasonCode(c)) c
    ];

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

  /// Only the codes the voter actually chose. `meeting_2026_07_14` is a
  /// provenance tag, not a reason, and rendering it as one printed the raw
  /// string under "Reason:" on 14 to 23 rows for every exec who was on the
  /// July 14 call.
  List<String> get statedReasonCodes =>
      [for (final c in reasonCodes) if (!isProvenanceReasonCode(c)) c];

  /// Provenance tags on this ballot (see [kProvenanceReasonPrefix]).
  List<String> get provenanceCodes => provenanceCodesOf(reasonCodes);

  bool get hasReason => statedReasonCodes.isNotEmpty;
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

/// One sentence describing the consensus rule, in a shape that is true.
///
/// Two separate numbers, never one fraction. [ballotsNeeded] is the per
/// candidate threshold ([kQuorumFloor]); [participants] is how many execs have
/// cast a ballot ANYWHERE on the roster, which is a different set from the
/// people who have voted on any given candidate. Printing them as
/// "5 of 8 voting" implied both a fraction and that all 8 were live tonight,
/// and 4 of those 8 have cast nothing since the July 14 call.
///
/// No "tonight" anywhere: there is no meeting tonight, there is a deadline.
String quorumSentence(int ballotsNeeded, int participants) {
  final execs = participants == 1 ? '1 exec has' : '$participants execs have';
  return 'Consensus needs $ballotsNeeded ballots on a candidate · '
      '$execs voted so far';
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

  /// Distinct voters who have cast at least one ballot anywhere on the
  /// roster. DISPLAY ONLY: it is not part of the consensus threshold any
  /// more (see [effectiveQuorum]).
  final int participants;

  /// Ballots one candidate needs before a supermajority on that candidate
  /// counts as consensus. A FIXED floor ([kQuorumFloor]), deliberately not
  /// derived from `participants`.
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

  VoteLoadState _loadState = VoteLoadState.loading;
  bool _disposed = false;
  RealtimeChannel? _channel;
  Timer? _rtDebounce;

  /// Optimistic until the channel reports otherwise, so the board does not
  /// flash "Reconnecting" during the initial join.
  bool _realtimeHealthy = true;

  /// Candidates with a local write in flight. Their own realtime echo must
  /// not overwrite the optimistic value, and a pull-to-refresh must not
  /// discard it. Keyed by candidateId because the PK is
  /// (candidate_id, voter_id) and only ever the signed-in member writes here.
  final Set<String> _pendingSelf = <String>{};

  String? _currentUserId;
  String _currentUserName = 'You';

  /// Human-readable description of the last failed write, for debugging.
  String? lastError;

  /// Shape of the last failed ballot write (see [VoteWriteFailure]). Read by
  /// the vote control and the reason sheet so an RLS denial gets honest copy
  /// and no Retry button, instead of "Check connection" and a loop.
  VoteWriteFailure lastFailure = VoteWriteFailure.none;

  SupabaseClient get _client => _supabase.client;

  /// The signed-in member's auth uid (null when signed out). Set as the FIRST
  /// statement of [load], so a non-null uid says nothing about whether the
  /// ballots have arrived. Anything that needs "the votes are in" must read
  /// [loaded] instead.
  String? get currentUserId => _currentUserId;

  /// True only once [load] has SUCCEEDED. The one honest "votes are in"
  /// signal on this repository: the board's landing decision reads it so an
  /// exec who has already voted on everything is never mis-landed by a slow
  /// ballot fetch, and, since a failed fetch leaves this false, never landed
  /// on Browse on the strength of a ballot that never arrived.
  bool get loaded => _loadState == VoteLoadState.ready;

  /// Load gate for the board's tallies, progress pill and vote controls.
  VoteLoadState get loadState => _loadState;

  /// Whether the realtime channel is currently joined. False means this
  /// board may be silently behind the database.
  bool get realtimeHealthy => _realtimeHealthy;

  /// Display name stored alongside the signed-in member's votes.
  String get currentUserName => _currentUserName;

  /// Denominator for "{cast} of {roomSize} execs in".
  int get roomSize => _knownVoters.length;

  /// EVERY ballot row on the table, fetched in bounded pages.
  ///
  /// See [kVoteFetchPageSize]: a bare `select()` is silently truncated by
  /// PostgREST at the project row cap, and a truncated ballot is the one
  /// wrong answer an exec would act on. Three properties make this safe:
  ///
  ///  * ORDERED BY THE PRIMARY KEY (candidate_id, voter_id), so offset paging
  ///    is deterministic rather than dependent on heap order.
  ///  * TERMINATES ON AN EMPTY PAGE, not on a short one, so it stays correct
  ///    whatever the server's row cap actually is. It costs exactly one extra
  ///    round trip (267 ballots today = one full page plus one empty one).
  ///  * BOUNDED by [kVoteFetchMaxPages], and throws rather than returning a
  ///    partial list if that bound is hit.
  ///
  /// Every page carries [kVoteReadTimeout] so a wedged socket cannot leave
  /// the board on a spinner forever.
  Future<List<Map<String, dynamic>>> _fetchAllVotes() async {
    final out = <Map<String, dynamic>>[];
    for (var page = 0; page < kVoteFetchMaxPages; page++) {
      final rows = await _client
          .from(_table)
          .select()
          .order('candidate_id', ascending: true)
          .order('voter_id', ascending: true)
          .range(out.length, out.length + kVoteFetchPageSize - 1)
          .timeout(kVoteReadTimeout);
      if (rows.isEmpty) return out;
      for (final row in rows) {
        out.add(Map<String, dynamic>.from(row));
      }
    }
    throw StateError('ballot fetch did not terminate within '
        '$kVoteFetchMaxPages pages (${out.length} rows read)');
  }

  /// Initial ballot fetch. Re-entrant only while it has never SUCCEEDED, so
  /// the failed state is genuinely retryable (it previously latched `loaded`
  /// true on failure, which made the outage permanent for that page).
  Future<void> load() async {
    if (_loadState == VoteLoadState.ready) return;
    try {
      _currentUserId = _client.auth.currentUser?.id;
      await _resolveCurrentUserName();
      await _seedExecRoster();
      final rows = await _fetchAllVotes();
      _votes.clear();
      for (final row in rows) {
        _applyRow(row);
      }
      _rebuildKnownVoters();
      _loadState = VoteLoadState.ready;
    } catch (e, s) {
      lastError = 'load: $e';
      // A Sentry event, not just a debugPrint. Nobody phones in a failed
      // ballot fetch: the board says "Could not load tonight's ballots" and
      // the exec reasonably assumes someone already knows.
      Logger.error('Endorsement ballot fetch failed',
          tag: 'EndorsementVotes', error: e, trace: s);
      // Do NOT fall through to a ready board: an empty _votes map renders a
      // board on which nobody has voted, which is indistinguishable from the
      // truth and is the one wrong answer an exec would act on.
      _loadState = VoteLoadState.failed;
    }
    _invalidateAll();
    notifyListeners();
    // Subscribe even after a failed fetch: the channel's subscribe callback
    // calls refresh(), so a later successful join self-heals the board.
    _subscribe();
  }

  /// Retry after a failed initial fetch (the board's inline retry button).
  Future<void> reload() async {
    _loadState = VoteLoadState.loading;
    notifyListeners();
    await load();
  }

  /// Re-run the select-all and reapply. Wired to pull-to-refresh, to app
  /// resume and to every realtime (re)subscribe: covers the gaps Postgres
  /// Changes leaves after phone sleep / offline, which it never backfills.
  Future<void> refresh() async {
    // SNAPSHOT BEFORE THE AWAIT. castVote / clearVote / updateReason drop
    // their candidate from `_pendingSelf` in a `finally` that runs the
    // instant the HTTP response lands, so a vote cast DURING this select can
    // already be gone from the set by the time the select resolves. Reading
    // the set only afterwards therefore skipped exactly the votes the
    // re-assert exists to protect: the server snapshot predates the write,
    // the re-assert passes over it, and the exec watches their own tap wiped
    // off the screen with no error and no Retry. The union below covers both
    // halves: pending when this started, plus anything that went in flight
    // while it ran.
    final pendingBefore = Set<String>.of(_pendingSelf);
    try {
      final rows = await _fetchAllVotes();
      // Build into a scratch map, then swap: `_votes.clear()` followed by an
      // async gap would be a window where the board renders an empty ballot.
      // (The old code was safe because the reapply was synchronous after the
      // await; keeping the swap explicit means it stays safe.)
      final next = <String, Map<String, BallotEntry>>{};
      for (final row in rows) {
        _applyRowInto(next, row);
      }
      // An in-flight local write is NOT yet visible to this select, so the
      // server snapshot would roll the exec's own tap back on screen with no
      // error and no Retry. Re-assert anything pending at either end.
      final uid = _currentUserId;
      if (uid != null) {
        final pending = <String>{...pendingBefore, ..._pendingSelf};
        for (final candidateId in pending) {
          final mine = _votes[candidateId]?[uid];
          if (mine != null) {
            (next[candidateId] ??= {})[uid] = mine;
          } else {
            next[candidateId]?.remove(uid);
            if (next[candidateId]?.isEmpty ?? false) next.remove(candidateId);
          }
        }
      }
      _votes
        ..clear()
        ..addAll(next);
      _rebuildKnownVoters();
      // A successful refresh clears a previously failed load.
      _loadState = VoteLoadState.ready;
      _invalidateAll();
      notifyListeners();
    } catch (e, s) {
      lastError = 'refresh: $e';
      // Deliberately NON-destructive (see the doc above): the previously
      // loaded ballot stays exactly as it was. A partial page count throws
      // out of _fetchAllVotes rather than being applied, so a truncated read
      // can never quietly understate the board here either.
      Logger.error('Endorsement ballot refresh failed',
          tag: 'EndorsementVotes', error: e, trace: s);
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
          // Bounded like every other await on the load path: this one runs
          // BEFORE the ballot fetch, so a hang here used to hold the whole
          // board on its spinner indefinitely.
          .maybeSingle()
          .timeout(kVoteReadTimeout);
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
          .not('user_id', 'is', null)
          // 16 rows today, far under any row cap, but still bounded: it is on
          // the load path ahead of the ballot fetch.
          .timeout(kVoteReadTimeout);
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
    if (candidateId == null || voterId == null) return;
    // Ignore our OWN echo while our own write is still in flight. Otherwise
    // changing Yes -> No inside the echo window renders No (optimistic), Yes
    // (echo of the first upsert), No (echo of the second); and if the socket
    // dies between those two echoes the board sits on the stale value with
    // nothing to correct it. Other execs' rows always apply: the PK is
    // (candidate_id, voter_id), so a remote payload can never carry ours.
    if (voterId == _currentUserId && _pendingSelf.contains(candidateId)) {
      return;
    }
    _applyRowInto(_votes, m);
    _invalidateCandidate(candidateId);
  }

  void _applyRowInto(
      Map<String, Map<String, BallotEntry>> target, Map<String, dynamic> m) {
    final candidateId = m['candidate_id']?.toString();
    final voterId = m['voter_id']?.toString();
    final vote = m['vote']?.toString();
    if (candidateId == null || candidateId.isEmpty) return;
    if (voterId == null || voterId.isEmpty) return;
    if (vote == null || !kValidVotes.contains(vote)) return;
    final name = m['voter_name']?.toString().trim();
    final other = m['other_text']?.toString();
    (target[candidateId] ??= {})[voterId] = BallotEntry(
      candidateId: candidateId,
      voterId: voterId,
      voterName: (name == null || name.isEmpty) ? 'An exec' : name,
      vote: vote,
      reasonCodes: (m['reason_codes'] as List?)?.cast<String>() ?? const [],
      otherText: (other == null || other.isEmpty) ? null : other,
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal(),
    );
  }

  void _removeRow(Map<String, dynamic> old) {
    final candidateId = old['candidate_id']?.toString();
    final voterId = old['voter_id']?.toString();
    if (candidateId == null || voterId == null) return;
    // Same self-echo guard as _applyRow: our own delete echo must not undo an
    // optimistic re-cast that is still in flight.
    if (voterId == _currentUserId && _pendingSelf.contains(candidateId)) {
      return;
    }
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
        ).subscribe((status, error) {
          final healthy = status == RealtimeSubscribeStatus.subscribed;
          if (healthy != _realtimeHealthy) {
            _realtimeHealthy = healthy;
            notifyListeners();
          }
          if (!healthy) {
            debugPrint('EndorsementVoteRepository realtime $status: $error');
            return;
          }
          // Postgres Changes replays nothing missed while the socket was
          // down, so a rejoin alone leaves this client permanently behind.
          // Re-read on every successful join to close the gap.
          refresh();
        });
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
  ///  - still open: cast < [kQuorumFloor]
  ///  - consensus ready: cast >= [kQuorumFloor] AND a 2/3 supermajority of
  ///    cast ballots agrees yes (suggests Endorse) or no (suggests Decline)
  ///  - split: floor reached, no supermajority.
  ///
  /// THE THRESHOLD IS PER CANDIDATE AND FIXED. It used to be
  /// `max(kQuorumFloor, participants ~/ 2 + 1)` over the DISTINCT VOTERS
  /// ACROSS THE WHOLE ROSTER, which grows monotonically as more execs start
  /// voting. At 8 participants that gave a threshold of 5 and every settled
  /// candidate (8 ballots each) read consensus-ready; the moment the other 8
  /// execs cast their first ballot anywhere, participants would hit 16, the
  /// threshold would jump to 9, and every candidate with 5 to 8 ballots would
  /// silently revert to STILL OPEN: accent strips clearing, Confirm buttons
  /// vanishing, and the STILL OPEN tile counting UP in response to more
  /// people voting. A candidate's own ballot count is the only input that can
  /// make its own bucket move.
  VoteBuckets buckets(List<String> ballotCandidateIds) {
    final key = ballotCandidateIds.join('|');
    if (!_bucketsDirty && key == _bucketsKey) return _bucketsCache;

    final participantIds = <String>{};
    for (final id in ballotCandidateIds) {
      final perCandidate = _votes[id];
      if (perCandidate != null) participantIds.addAll(perCandidate.keys);
    }
    final participants = participantIds.length;
    const quorum = kQuorumFloor;

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
  /// clears the STATED reasons (the reason sheet then optionally re-writes
  /// them) and keeps any provenance tag: see [kProvenanceReasonPrefix].
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
    // Stated reasons are cleared by a vote change (the sheet re-captures
    // them). PROVENANCE IS NOT: this write used to send an unconditional
    // `reason_codes: []`, so every re-cast on one of the 166 ballots the
    // July 14 call produced silently destroyed the only marker distinguishing
    // a backfilled ballot from a live one, with no way to tell afterwards how
    // many had been revised.
    final carried = provenanceCodesOf(snapshot?.reasonCodes);
    (_votes[candidateId] ??= {})[uid] = BallotEntry(
      candidateId: candidateId,
      voterId: uid,
      voterName: _currentUserName,
      vote: vote,
      reasonCodes: List.unmodifiable(carried),
      otherText: null,
      updatedAt: DateTime.now(),
    );
    _rebuildKnownVoters();
    _invalidateCandidate(candidateId);
    notifyListeners();
    _pendingSelf.add(candidateId);
    try {
      await _client.from(_table).upsert({
        'candidate_id': candidateId,
        'voter_id': uid,
        'voter_name': _currentUserName,
        'vote': vote,
        'reason_codes': carried,
        'other_text': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(kVoteWriteTimeout);
      lastFailure = VoteWriteFailure.none;
      return true;
    } catch (e, s) {
      lastError = 'castVote: $e';
      lastFailure = classifyVoteWriteFailure(e);
      Logger.error('Endorsement vote write failed (castVote $vote)',
          tag: 'EndorsementVotes', error: e, trace: s);
      _restoreBallot(candidateId, uid, snapshot);
      return false;
    } finally {
      _pendingSelf.remove(candidateId);
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
    _pendingSelf.add(candidateId);
    try {
      await _client
          .from(_table)
          .delete()
          .eq('candidate_id', candidateId)
          .eq('voter_id', uid)
          .timeout(kVoteWriteTimeout);
      lastFailure = VoteWriteFailure.none;
      return true;
    } catch (e, s) {
      lastError = 'clearVote: $e';
      lastFailure = classifyVoteWriteFailure(e);
      Logger.error('Endorsement vote withdrawal failed (clearVote)',
          tag: 'EndorsementVotes', error: e, trace: s);
      _restoreBallot(candidateId, uid, snapshot);
      return false;
    } finally {
      _pendingSelf.remove(candidateId);
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
    // The sheet only ever sends stated reasons; carry the row's provenance
    // tags through so saving a reason does not erase them either.
    final merged = <String>[
      ...provenanceCodesOf(existing.reasonCodes),
      ...reasonCodes.where((c) => !isProvenanceReasonCode(c)),
    ];
    (_votes[candidateId] ??= {})[uid] = BallotEntry(
      candidateId: candidateId,
      voterId: uid,
      voterName: existing.voterName,
      vote: existing.vote,
      reasonCodes: List.unmodifiable(merged),
      otherText: otherText,
      updatedAt: DateTime.now(),
    );
    _invalidateCandidate(candidateId);
    notifyListeners();
    _pendingSelf.add(candidateId);
    try {
      await _client.from(_table).upsert({
        'candidate_id': candidateId,
        'voter_id': uid,
        'voter_name': existing.voterName,
        'vote': existing.vote,
        'reason_codes': merged,
        'other_text': otherText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(kVoteWriteTimeout);
      lastFailure = VoteWriteFailure.none;
      return true;
    } catch (e, s) {
      lastError = 'updateReason: $e';
      lastFailure = classifyVoteWriteFailure(e);
      Logger.error('Endorsement reason write failed (updateReason)',
          tag: 'EndorsementVotes', error: e, trace: s);
      _restoreBallot(candidateId, uid, snapshot);
      return false;
    } finally {
      _pendingSelf.remove(candidateId);
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
