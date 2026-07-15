import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import 'journey_models.dart';
import 'journey_service.dart';

/// Loads and live-updates the candidate journey list. New starts and status
/// changes stream in over realtime (form_submissions + form_field_analytics
/// are both in the supabase_realtime publication); a slow poll covers the
/// autosave drafts table, which is not.
class LiveJourneyController extends ChangeNotifier {
  LiveJourneyController({
    required this.formId,
    required this.slug,
    JourneyService? service,
  }) : _service = service ?? JourneyService();

  final String formId;
  final String slug;
  final JourneyService _service;

  bool _loading = true;
  String? _error;
  List<JourneyEntry> _entries = const [];

  bool get loading => _loading;
  String? get error => _error;
  List<JourneyEntry> get entries => _entries;

  int get liveCount {
    final now = DateTime.now();
    return _entries
        .where((e) => e.statusAt(now) == JourneyStatus.liveNow)
        .length;
  }

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  Timer? _debounce;
  bool _disposed = false;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    await _refresh();
    _subscribe();
    // Drafts (the LIVE heartbeat while someone types) are not on realtime, so
    // refresh on a slow cadence too; also re-derives LIVE -> stalled decay.
    _pollTimer ??= Timer.periodic(const Duration(seconds: 60), (_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      final entries = await _service.loadEntries(formId, slug);
      if (_disposed) return;
      _entries = entries;
      _loading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _loading = false;
      _error = '$e';
      notifyListeners();
    }
  }

  void _subscribe() {
    if (_channel != null) return;
    try {
      final client = CRMSupabaseService().client;
      _channel = client.channel('public:journey:$formId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'form_submissions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'form_id',
            value: formId,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'form_field_analytics',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'form_id',
            value: formId,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        ..subscribe();
    } catch (e) {
      debugPrint('LiveJourneyController.subscribe error: $e');
    }
  }

  /// Realtime events arrive in bursts while someone fills the form; coalesce
  /// them into one reload.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _debounce?.cancel();
    try {
      final ch = _channel;
      if (ch != null) CRMSupabaseService().client.removeChannel(ch);
    } catch (_) {}
    super.dispose();
  }
}
