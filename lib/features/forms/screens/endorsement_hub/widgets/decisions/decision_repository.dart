import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// The endorsement decision state for a candidate.
enum DecisionState {
  undecided('Undecided'),
  interview('Interview'),
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

/// A stored decision: a state plus an optional working note.
@immutable
class DecisionRecord {
  final DecisionState state;
  final String note;
  const DecisionRecord({required this.state, this.note = ''});

  Map<String, dynamic> toJson() => {'state': state.name, 'note': note};

  static DecisionRecord fromJson(Map<String, dynamic> j) => DecisionRecord(
        state: DecisionState.fromName(j['state'] as String?),
        note: (j['note'] as String?) ?? '',
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
}

/// A [shared_preferences]-backed decision store. Keys everything under a single
/// JSON blob so it round-trips as one small preference.
class LocalDecisionRepository extends DecisionRepository {
  static const _prefsKey = 'endorsement_decisions_v1';

  final Map<String, DecisionRecord> _records = {};
  bool _loaded = false;

  @override
  Map<String, DecisionRecord> get all => Map.unmodifiable(_records);

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

  SupabaseClient get _client => _supabase.client;

  @override
  Map<String, DecisionRecord> get all => Map.unmodifiable(_records);

  @override
  Future<void> load() async {
    if (_loaded) return;
    try {
      final rows = await _client.from(_table).select();
      _records.clear();
      for (final row in (rows as List)) {
        _applyRow(Map<String, dynamic>.from(row as Map));
      }
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.load error: $e');
    }
    _loaded = true;
    notifyListeners();
    _subscribe();
  }

  void _applyRow(Map<String, dynamic> m) {
    final id = m['candidate_id']?.toString();
    if (id == null || id.isEmpty) return;
    _records[id] = DecisionRecord(
      state: DecisionState.fromName(m['state'] as String?),
      note: (m['note'] as String?) ?? '',
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

  @override
  Future<void> setState(String candidateId, DecisionState state) async {
    final existing = recordFor(candidateId);
    _records[candidateId] = DecisionRecord(state: state, note: existing.note);
    notifyListeners();
    await _upsert(candidateId);
  }

  @override
  Future<void> setNote(String candidateId, String note) async {
    final existing = recordFor(candidateId);
    _records[candidateId] = DecisionRecord(state: existing.state, note: note);
    notifyListeners();
    await _upsert(candidateId);
  }

  Future<void> _upsert(String candidateId) async {
    final rec = recordFor(candidateId);
    try {
      await _client.from(_table).upsert({
        'candidate_id': candidateId,
        'state': rec.state.name,
        'note': rec.note,
        'updated_by': _client.auth.currentUser?.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SupabaseDecisionRepository.upsert error: $e');
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
