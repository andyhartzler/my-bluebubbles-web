import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
