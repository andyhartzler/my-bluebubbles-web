import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// Rows per page of the decisions fetch, and the pager's hard ceiling.
///
/// Same latent shape as the ballot fetch: PostgREST silently caps an
/// unbounded `select()` at the project row cap (measured 1000 on this
/// project), returning HTTP 200 with fewer rows and no error. 26 decisions
/// exist today so nothing is truncated, but a silently short decision
/// baseline is strictly the more dangerous of the two truncations, because
/// `stateFor` defaults a missing row to undecided: every dropped decision
/// puts a settled candidate back on all 16 ballots.
const int kDecisionFetchPageSize = 1000;
const int kDecisionFetchMaxPages = 20;

/// Ceiling on a decisions read, matching the ballot repository's.
const Duration kDecisionReadTimeout = Duration(seconds: 20);

/// Ceiling on a decision write (the chair's Confirm and the final-call
/// pills), matching the ballot repository's write budget.
const Duration kDecisionWriteTimeout = Duration(seconds: 12);

/// The final endorsement outcome for a candidate. The per-member yes/no
/// voting board is the committee's working mechanism; this is the lightweight
/// final call recorded once the committee lands. Rows persisted with any
/// retired state name fall back to undecided.
enum DecisionState {
  undecided('Undecided'),
  endorse('Endorse'),
  decline('Decline');

  const DecisionState(this.label);
  final String label;

  static DecisionState fromName(String? n) {
    return DecisionState.values.firstWhere(
      (d) => d.name == n,
      orElse: () => DecisionState.undecided,
    );
  }
}

/// Whether the decisions load has completed. The board MUST NOT render any
/// vote controls until this is [ready]: `stateFor` defaults missing entries to
/// undecided, so a failed/empty load would silently put every already-decided
/// candidate back on the ballot.
enum DecisionLoadState { loading, ready, failed }

/// A stored decision: a state plus an optional working note, and the write
/// metadata the table already carries.
///
/// [updatedBy] is the auth uid the app LAST stamped on the row, and nothing
/// more: 18 of the 23 locked rows are NULL because the Jul 15 recovery ran
/// outside the app, and audit_log holds zero rows for endorsement_decisions,
/// so this can never be presented as "who authored the decision". The
/// attribution sheet is the only consumer and it hedges accordingly.
@immutable
class DecisionRecord {
  final DecisionState state;
  final String note;
  final String? updatedBy;
  final DateTime? updatedAt;
  const DecisionRecord({
    required this.state,
    this.note = '',
    this.updatedBy,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'note': note,
        if (updatedBy != null) 'updated_by': updatedBy,
        if (updatedAt != null)
          'updated_at': updatedAt!.toUtc().toIso8601String(),
      };

  static DecisionRecord fromJson(Map<String, dynamic> j) => DecisionRecord(
        state: DecisionState.fromName(j['state'] as String?),
        note: (j['note'] as String?) ?? '',
        updatedBy: j['updated_by']?.toString(),
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? ''),
      );
}

/// Persistence boundary for endorsement decisions. The local implementation
/// ships now; a Supabase-backed implementation (table
/// `public.endorsement_decisions`) can drop in later behind the same interface
/// once the schema is approved.
abstract class DecisionRepository extends ChangeNotifier {
  Future<void> load();
  DecisionState stateFor(String candidateId);
  DecisionRecord recordFor(String candidateId);
  Future<void> setState(String candidateId, DecisionState state);
  Future<void> setNote(String candidateId, String note);
  Map<String, DecisionRecord> get all;

  /// Load gate for the board: no vote controls render until [DecisionLoadState.ready].
  DecisionLoadState get loadState;

  /// Re-run the initial load (Retry button on the failed state).
  ///
  /// DESTRUCTIVE: flips [loadState] back to loading, which tears the whole
  /// CustomScrollView down to a spinner and loses scroll offset, expansion
  /// and toolbar state. Only the failed-load retry button may call this, and
  /// only because there is nothing to lose in that state. Everything else
  /// wants [refresh].
  Future<void> reload();

  /// NON-DESTRUCTIVE re-fetch: re-reads the table and notifies WITHOUT
  /// touching [loadState], so the board never blinks to a spinner and the
  /// exec keeps their place in the list.
  ///
  /// This exists because Postgres Changes has NO backfill: when a phone
  /// sleeps the websocket drops, and although the channel auto-rejoins,
  /// everything committed while it was down is lost to that client forever.
  /// The decision baseline going stale is worse than a stale vote tally,
  /// because `stateFor` defaults a missing row to undecided, so a candidate
  /// the committee decided while the phone was locked silently stays on that
  /// exec's ballot and every count on their screen is measured against a
  /// baseline that no longer exists. Called on every realtime (re)subscribe
  /// and on app resume.
  Future<void> refresh();

  /// Whether the realtime channel is currently joined. False means this board
  /// may be silently behind the database, which the UI must say out loud
  /// rather than continuing to promise live sync.
  bool get realtimeHealthy;

  /// CHECKED state write: optimistic local update, awaited persist, rollback
  /// + `false` on failure instead of the fire-and-forget [setState]. The
  /// chair's Confirm button and the final-call pills call ONLY this.
  Future<bool> trySetState(String candidateId, DecisionState state);
}

/// A [shared_preferences]-backed decision store. Keys everything under a single
/// JSON blob so it round-trips as one small preference.
class LocalDecisionRepository extends DecisionRepository {
  static const _prefsKey = 'endorsement_decisions_v1';

  final Map<String, DecisionRecord> _records = {};
  bool _loaded = false;

  @override
  Map<String, DecisionRecord> get all => Map.unmodifiable(_records);

  /// Local storage cannot fail in a way that would fake an empty board.
  @override
  DecisionLoadState get loadState => DecisionLoadState.ready;

  @override
  Future<void> reload() => load();

  /// Local storage has no realtime channel and therefore no gap to close.
  @override
  Future<void> refresh() async {}

  /// No channel, so it can never be behind.
  @override
  bool get realtimeHealthy => true;

  @override
  Future<bool> trySetState(String candidateId, DecisionState state) async {
    await setState(candidateId, state);
    return true;
  }

  @override
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              _records[k.toString()] =
                  DecisionRecord.fromJson(Map<String, dynamic>.from(v));
            }
          });
        }
      }
    } catch (e) {
      debugPrint('LocalDecisionRepository.load error: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  DecisionState stateFor(String candidateId) =>
      _records[candidateId]?.state ?? DecisionState.undecided;

  @override
  DecisionRecord recordFor(String candidateId) =>
      _records[candidateId] ?? const DecisionRecord(state: DecisionState.undecided);

  @override
  Future<void> setState(String candidateId, DecisionState state) async {
    final existing = recordFor(candidateId);
    _records[candidateId] =
        DecisionRecord(state: state, note: existing.note);
    notifyListeners();
    await _persist();
  }

  @override
  Future<void> setNote(String candidateId, String note) async {
    final existing = recordFor(candidateId);
    _records[candidateId] = DecisionRecord(state: existing.state, note: note);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _records.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('LocalDecisionRepository.persist error: $e');
    }
  }
}

/// A Supabase-backed decision store, shared across ALL executive members via the
/// `public.endorsement_decisions` table with realtime sync. A decision one exec
/// records shows up live on every other exec's board (replaces the per-device
/// [LocalDecisionRepository] so the committee sees one shared board).
class SupabaseDecisionRepository extends DecisionRepository {
  static const _table = 'endorsement_decisions';

  final CRMSupabaseService _supabase = CRMSupabaseService();
  final Map<String, DecisionRecord> _records = {};
  bool _loaded = false;
  bool _disposed = false;
  RealtimeChannel? _channel;
  Timer? _rtDebounce;
  DecisionLoadState _loadState = DecisionLoadState.loading;

  /// Optimistic: true until the channel actually reports a non-subscribed
  /// status, so the board does not flash "Reconnecting" during the initial
  /// join before any status has arrived.
  bool _realtimeHealthy = true;

  @override
  bool get realtimeHealthy => _realtimeHealthy;

  SupabaseClient get _client => _supabase.client;

  @override
  Map<String, DecisionRecord> get all => Map.unmodifiable(_records);

  @override
  DecisionLoadState get loadState => _loadState;

  @override
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await _fetch();
    _subscribe();
  }

  /// Retry after a failed initial load (the board's error-state button).
  ///
  /// DESTRUCTIVE by design (see the interface doc): only the failed-state
  /// button calls it. Anything closing a realtime gap must call [refresh].
  @override
  Future<void> reload() async {
    _loadState = DecisionLoadState.loading;
    notifyListeners();
    await _fetch();
    _subscribe();
  }

  /// Non-destructive re-fetch. Deliberately does NOT touch [_loadState]: the
  /// board gates its entire scroll view on loadState, so flipping to loading
  /// here would replace the ballot with a spinner and drop the exec back at
  /// the top of a 50-row list every time a phone woke up.
  ///
  /// A failure here is also non-destructive: the previously loaded baseline
  /// stays exactly as it was rather than being cleared, because a stale
  /// baseline is strictly better than an empty one (an empty one silently
  /// returns every decided candidate to the ballot).
  @override
  Future<void> refresh() async {
    try {
      final rows = await _fetchAllDecisions();
      final next = <String, DecisionRecord>{};
      for (final row in rows) {
        _applyRowInto(next, row);
      }
      // Swap in one step so no frame can observe a half-empty baseline.
      _records
        ..clear()
        ..addAll(next);
      // A successful refresh also clears a previously failed load.
      _loadState = DecisionLoadState.ready;
      notifyListeners();
    } catch (e, s) {
      Logger.error('Endorsement decision refresh failed',
          tag: 'EndorsementDecisions', error: e, trace: s);
    }
  }

  /// Every decision row, paged and bounded, for the reasons in
  /// [kDecisionFetchPageSize]. Terminates on an EMPTY page rather than a
  /// short one, so it stays correct whatever the server's row cap is, and
  /// throws rather than returning a partial baseline if the pager runs away.
  Future<List<Map<String, dynamic>>> _fetchAllDecisions() async {
    final out = <Map<String, dynamic>>[];
    for (var page = 0; page < kDecisionFetchMaxPages; page++) {
      final rows = await _client
          .from(_table)
          .select()
          .order('candidate_id', ascending: true)
          .range(out.length, out.length + kDecisionFetchPageSize - 1)
          .timeout(kDecisionReadTimeout);
      if (rows.isEmpty) return out;
      for (final row in rows) {
        out.add(Map<String, dynamic>.from(row));
      }
    }
    throw StateError('decision fetch did not terminate within '
        '$kDecisionFetchMaxPages pages (${out.length} rows read)');
  }

  Future<void> _fetch() async {
    try {
      final rows = await _fetchAllDecisions();
      _records.clear();
      for (final row in rows) {
        _applyRow(row);
      }
      // An empty-but-successful result set is still ready; the gate guards
      // against FAILED loads, not small ones.
      _loadState = DecisionLoadState.ready;
    } catch (e, s) {
      Logger.error('Endorsement decision baseline fetch failed',
          tag: 'EndorsementDecisions', error: e, trace: s);
      _loadState = DecisionLoadState.failed;
    }
    notifyListeners();
  }

  void _applyRow(Map<String, dynamic> m) => _applyRowInto(_records, m);

  void _applyRowInto(Map<String, DecisionRecord> target, Map<String, dynamic> m) {
    final id = m['candidate_id']?.toString();
    if (id == null || id.isEmpty) return;
    // updated_by / updated_at used to be discarded here even though the
    // upsert writes them; the attribution sheet needs both (hedged typist
    // line + the recovery date), so they are kept now.
    target[id] = DecisionRecord(
      state: DecisionState.fromName(m['state'] as String?),
      note: (m['note'] as String?) ?? '',
      updatedBy: m['updated_by']?.toString(),
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? ''),
    );
  }

  // Live-sync every other exec's edits into this board.
  //
  // The subscribe status callback is load-bearing, not diagnostics. Postgres
  // Changes does not replay anything missed while the socket was down, so a
  // rejoin on its own leaves this client permanently behind. The callback
  // fires `subscribed` on the initial join AND on every rejoin (verified in
  // realtime_client 2.7.3: `resend()` never clears the push's recHooks, so
  // joinPush.receive('ok') runs again), which makes it the exact moment to
  // re-read the table and close the gap.
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
              final id = payload.oldRecord['candidate_id']?.toString();
              if (id != null) _records.remove(id);
            } else if (payload.newRecord.isNotEmpty) {
              _applyRow(Map<String, dynamic>.from(payload.newRecord));
            }
            _notifyDebounced();
          },
        ).subscribe((status, error) {
          final healthy = status == RealtimeSubscribeStatus.subscribed;
          if (healthy != _realtimeHealthy) {
            _realtimeHealthy = healthy;
            notifyListeners();
          }
          if (!healthy) {
            debugPrint('SupabaseDecisionRepository realtime $status: $error');
            return;
          }
          // Initial join is harmless (the fetch just ran); every later one is
          // a rejoin after a drop, which is precisely the gap to close.
          refresh();
        });
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.subscribe error: $e');
    }
  }

  /// Coalesce realtime bursts, mirroring the vote repository. The chair
  /// working through a run of already-decided rows would otherwise force an
  /// immediate full ballot-pipeline rebuild on all 16 devices per change.
  void _notifyDebounced() {
    _rtDebounce?.cancel();
    _rtDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  DecisionState stateFor(String candidateId) =>
      _records[candidateId]?.state ?? DecisionState.undecided;

  @override
  DecisionRecord recordFor(String candidateId) =>
      _records[candidateId] ?? const DecisionRecord(state: DecisionState.undecided);

  /// Optimistic local record mirroring exactly what [_upsertChecked] is about
  /// to write, so updatedBy/updatedAt never go stale between the local update
  /// and the realtime echo.
  DecisionRecord _stamped(DecisionState state, String note) => DecisionRecord(
        state: state,
        note: note,
        updatedBy: _client.auth.currentUser?.id,
        updatedAt: DateTime.now().toUtc(),
      );

  @override
  Future<void> setState(String candidateId, DecisionState state) async {
    final existing = recordFor(candidateId);
    _records[candidateId] = _stamped(state, existing.note);
    notifyListeners();
    await _upsert(candidateId);
  }

  /// The checked write for the chair's Confirm and the final-call pills:
  /// optimistic local update, AWAITED upsert, rollback + false on failure so
  /// a flaky network never shows a locally-green decision nobody received.
  @override
  Future<bool> trySetState(String candidateId, DecisionState state) async {
    final DecisionRecord? snapshot = _records[candidateId];
    final existing = recordFor(candidateId);
    _records[candidateId] = _stamped(state, existing.note);
    notifyListeners();
    try {
      await _upsertChecked(candidateId);
      return true;
    } catch (e, s) {
      Logger.error('Endorsement decision write failed (trySetState)',
          tag: 'EndorsementDecisions', error: e, trace: s);
      if (snapshot == null) {
        _records.remove(candidateId);
      } else {
        _records[candidateId] = snapshot;
      }
      notifyListeners();
      return false;
    }
  }

  @override
  Future<void> setNote(String candidateId, String note) async {
    final existing = recordFor(candidateId);
    _records[candidateId] = _stamped(existing.state, note);
    notifyListeners();
    await _upsert(candidateId);
  }

  Future<void> _upsert(String candidateId) async {
    try {
      await _upsertChecked(candidateId);
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.upsert error: $e');
    }
  }

  /// Same upsert as [_upsert] but RETHROWS so [trySetState] can roll back.
  ///
  /// Bounded: without a timeout a hung request leaves the chair's Confirm
  /// button spinning with no rollback and no error, exactly the failure the
  /// checked write exists to prevent.
  Future<void> _upsertChecked(String candidateId) async {
    final rec = recordFor(candidateId);
    await _client.from(_table).upsert({
      'candidate_id': candidateId,
      'state': rec.state.name,
      'note': rec.note,
      'updated_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).timeout(kDecisionWriteTimeout);
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
