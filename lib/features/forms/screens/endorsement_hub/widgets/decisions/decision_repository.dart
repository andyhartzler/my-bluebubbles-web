import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

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
  Future<void> reload();

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
  RealtimeChannel? _channel;
  DecisionLoadState _loadState = DecisionLoadState.loading;

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
  @override
  Future<void> reload() async {
    _loadState = DecisionLoadState.loading;
    notifyListeners();
    await _fetch();
    _subscribe();
  }

  Future<void> _fetch() async {
    try {
      final rows = await _client.from(_table).select();
      _records.clear();
      for (final row in (rows as List)) {
        _applyRow(Map<String, dynamic>.from(row as Map));
      }
      // An empty-but-successful result set is still ready; the gate guards
      // against FAILED loads, not small ones.
      _loadState = DecisionLoadState.ready;
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.load error: $e');
      _loadState = DecisionLoadState.failed;
    }
    notifyListeners();
  }

  void _applyRow(Map<String, dynamic> m) {
    final id = m['candidate_id']?.toString();
    if (id == null || id.isEmpty) return;
    // updated_by / updated_at used to be discarded here even though the
    // upsert writes them; the attribution sheet needs both (hedged typist
    // line + the recovery date), so they are kept now.
    _records[id] = DecisionRecord(
      state: DecisionState.fromName(m['state'] as String?),
      note: (m['note'] as String?) ?? '',
      updatedBy: m['updated_by']?.toString(),
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? ''),
    );
  }

  // Live-sync every other exec's edits into this board.
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
            notifyListeners();
          },
        ).subscribe();
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.subscribe error: $e');
    }
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
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.trySetState error: $e');
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
  Future<void> _upsertChecked(String candidateId) async {
    final rec = recordFor(candidateId);
    await _client.from(_table).upsert({
      'candidate_id': candidateId,
      'state': rec.state.name,
      'note': rec.note,
      'updated_by': _client.auth.currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
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
