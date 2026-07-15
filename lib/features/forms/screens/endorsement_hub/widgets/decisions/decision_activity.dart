import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'decision_repository.dart';

/// Read-only "who touched what, when" attribution for the shared board.
///
/// The [DecisionRepository] owns persistence (state + note) and is not
/// modified here. This companion re-reads the same
/// `public.endorsement_decisions` rows for their `updated_by` / `updated_at`
/// columns whenever the repository notifies (which it does for both local
/// edits and realtime edits from other execs), then resolves the auth uuids
/// to display names via `public.members.user_id`. That lets the board show
/// "Kate Tyson · 2m ago" next to a decision. It never writes anything.
class DecisionActivity extends ChangeNotifier {
  DecisionActivity(this._repository) {
    _repository.addListener(_onRepositoryChanged);
    _refresh();
  }

  static const String _table = 'endorsement_decisions';

  final DecisionRepository _repository;
  final CRMSupabaseService _supabase = CRMSupabaseService();

  final Map<String, ({String? by, DateTime? at})> _meta = {};
  final Map<String, String> _names = {};
  Timer? _debounce;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _disposed = false;

  String? get _currentUserId {
    try {
      return _supabase.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  ({String? by, DateTime? at})? metaFor(String candidateId) =>
      _meta[candidateId];

  /// The most recently updated decision, or null when the board is untouched.
  ({String candidateId, String? by, DateTime at})? get latest {
    ({String candidateId, String? by, DateTime at})? best;
    _meta.forEach((id, m) {
      final at = m.at;
      if (at == null) return;
      if (best == null || at.isAfter(best!.at)) {
        best = (candidateId: id, by: m.by, at: at);
      }
    });
    return best;
  }

  /// "You · 2m ago" / "Kate Tyson · just now", or null when the candidate has
  /// no shared record yet.
  String? describe(String candidateId) {
    final m = _meta[candidateId];
    final at = m?.at;
    if (m == null || at == null) return null;
    return '${actorLabel(m.by)} · ${timeAgo(at)}';
  }

  /// Display name for an auth uuid: "You" for the signed-in exec, the
  /// member's name when resolvable, otherwise a neutral fallback.
  String actorLabel(String? uid) {
    if (uid == null || uid.isEmpty) return 'An exec';
    if (uid == _currentUserId) return 'You';
    return _names[uid] ?? 'An exec';
  }

  void _onRepositoryChanged() {
    // The repository notifies optimistically before its upsert commits; give
    // the write a beat to land, then re-read attribution in one small query.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _refresh);
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final rows = await _supabase.client
          .from(_table)
          .select('candidate_id, updated_by, updated_at');
      if (_disposed) return;
      _meta.clear();
      final unknown = <String>{};
      for (final row in (rows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['candidate_id']?.toString();
        if (id == null || id.isEmpty) continue;
        final by = m['updated_by']?.toString();
        final at =
            DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal();
        _meta[id] = (by: by, at: at);
        if (by != null &&
            by.isNotEmpty &&
            by != _currentUserId &&
            !_names.containsKey(by)) {
          unknown.add(by);
        }
      }
      if (unknown.isNotEmpty) {
        try {
          final people = await _supabase.client
              .from('members')
              .select('user_id, name')
              .inFilter('user_id', unknown.toList());
          if (_disposed) return;
          for (final row in (people as List)) {
            final p = Map<String, dynamic>.from(row as Map);
            final uid = p['user_id']?.toString();
            final name = p['name']?.toString().trim();
            if (uid != null && name != null && name.isNotEmpty) {
              _names[uid] = name;
            }
          }
        } catch (e) {
          debugPrint('DecisionActivity.names error: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('DecisionActivity.refresh error: $e');
    } finally {
      _refreshing = false;
      if (_refreshQueued && !_disposed) {
        _refreshQueued = false;
        _onRepositoryChanged();
      }
    }
  }

  /// Compact relative timestamp: "just now", "4m ago", "3h ago", "2d ago".
  static String timeAgo(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
