import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

/// Detection + containment for auth token refresh storms.
///
/// The 2026-06/07 kick-out incidents were granted-refresh loops: one client
/// rotating its refresh token every ~0.3s until GoTrue's reuse detection
/// killed the session (a stale token copy reused past the 10s reuse window),
/// booting the user to login repeatedly and walling them behind the OTP
/// resend cooldown. Two SDK paths can drive a loop in gotrue 2.20:
///
///  1. the 10s auto-refresh ticker (stoppable via stopAutoRefresh), and
///  2. the per-request on-demand refresh in SupabaseClient._getAccessToken(),
///     which refreshes whenever Session.isExpired says so using LOCAL clock
///     math, so a device clock far ahead refreshes on every API call. No
///     client-side switch can stop that path.
///
/// The session-killing consequence is already fixed server-side (refresh
/// token reuse interval raised 10s -> 60s, so a ~0.3s loop can no longer
/// trip reuse detection). This guard's job is the rest: stop ticker-driven
/// loops outright, keep re-stopping the ticker when the SDK's lifecycle
/// observer restarts it on tab focus, and record ONE diagnostic row per
/// storm with the device's real measured clock skew, the SDK's session
/// expiry view, and the refresh cadence, so the per-device root cause is
/// readable from public.client_diagnostics instead of guessed at.
class AuthRefreshGuard {
  static final AuthRefreshGuard _instance = AuthRefreshGuard._internal();
  factory AuthRefreshGuard() => _instance;
  AuthRefreshGuard._internal();

  /// Fast window: catches request-cadence storms (~0.3s per refresh).
  static const int _fastThreshold = 6;
  static const Duration _fastWindow = Duration(seconds: 20);

  /// Slow window: catches ticker-driven loops (max 1 refresh per 10s tick,
  /// so a fast window can never see them). Healthy cadence is one refresh
  /// per ~50 minutes; 5 inside 2 minutes is unambiguous.
  static const int _slowThreshold = 5;
  static const Duration _slowWindow = Duration(minutes: 2);

  /// Refreshes arriving while tripped mean the on-demand path is looping
  /// (the ticker is stopped); past this count, record the escalation once.
  static const int _persistentThreshold = 10;

  final List<DateTime> _refreshTimes = [];
  StreamSubscription<AuthState>? _sub;
  SupabaseClient? _client;
  Timer? _reopenTimer;
  bool _tripped = false;
  bool _escalationRecorded = false;
  int _refreshesWhileTripped = 0;
  int _trips = 0;
  DateTime? _lastTripAt;

  bool get isTripped => _tripped;

  void start(SupabaseClient client) {
    if (_sub != null) return;
    _client = client;
    _sub = client.auth.onAuthStateChange.listen(
      _onAuthState,
      onError: _ignoreAuthStreamError,
    );
  }

  /// The auth stream carries errors as well as states, and it is an rxdart
  /// BehaviorSubject, so the most recent error is replayed to every later
  /// subscriber. This guard is a token-refresh cadence watchdog and has
  /// nothing to say about an auth failure; the sign-in gate is what reports
  /// those to the member. What an onError buys here is that the replay stops
  /// escaping THIS subscription into the zone, where it was being logged as a
  /// second, duplicate unhandled exception. Refs FLUTTER-Q.
  void _ignoreAuthStreamError(Object error, StackTrace stackTrace) {}

  void _onAuthState(AuthState state) {
    final client = _client;
    if (client == null) return;

    if (state.event == AuthChangeEvent.signedOut) {
      // New session (possibly a different person on a shared device) starts
      // with a clean slate; leave the ticker to the SDK's own lifecycle.
      _reset();
      return;
    }
    if (state.event != AuthChangeEvent.tokenRefreshed) return;
    // Rebroadcasts from other tabs would multiply one storm by the number of
    // open tabs; only count refreshes this tab performed.
    if (state.fromBroadcast) return;

    final now = DateTime.now();
    _refreshTimes.add(now);
    _refreshTimes.removeWhere((t) => now.difference(t) > _slowWindow);

    if (_tripped) {
      _refreshesWhileTripped++;
      // The SDK restarts auto-refresh on every app resume / tab focus;
      // keep it stopped for the duration of the backoff (idempotent).
      try {
        client.auth.stopAutoRefresh();
      } catch (_) {}
      if (_refreshesWhileTripped >= _persistentThreshold &&
          !_escalationRecorded) {
        // Still refreshing with the ticker stopped: this is the per-request
        // on-demand path, which cannot be disabled client-side. The 60s
        // reuse interval keeps the session alive through it; log the proof
        // (skew + cadence) so the device can be fixed with evidence.
        _escalationRecorded = true;
        debugPrint('AuthRefreshGuard: storm persists with ticker stopped '
            '($_refreshesWhileTripped refreshes) - on-demand path.');
        unawaited(_recordDiagnostic(client,
            kind: 'auth_refresh_storm_persistent',
            refreshCount: _refreshesWhileTripped,
            backoff: Duration.zero));
      }
      return;
    }

    final fastCount = _refreshTimes
        .where((t) => now.difference(t) <= _fastWindow)
        .length;
    if (fastCount >= _fastThreshold ||
        _refreshTimes.length >= _slowThreshold) {
      _trip(client, fastCount);
    }
  }

  void _trip(SupabaseClient client, int fastCount) {
    // Trips long in the past should not escalate today's backoff forever.
    if (_lastTripAt != null &&
        DateTime.now().difference(_lastTripAt!) > const Duration(hours: 3)) {
      _trips = 0;
    }
    _tripped = true;
    _escalationRecorded = false;
    _refreshesWhileTripped = 0;
    _trips++;
    _lastTripAt = DateTime.now();
    final refreshCount = _refreshTimes.length;

    // Exponential backoff capped at 30 minutes, but never longer than the
    // current access token's remaining life (minus margin): realtime
    // channels only re-auth on tokenRefreshed, so the ticker must resume
    // before the token dies or an idle realtime-only user drops silently.
    var backoff =
        Duration(minutes: math.min(3 * math.pow(2, _trips - 1).toInt(), 30));
    final expiresAtSecs = client.auth.currentSession?.expiresAt;
    if (expiresAtSecs != null) {
      final untilExpiry = DateTime.fromMillisecondsSinceEpoch(
              expiresAtSecs * 1000)
          .difference(DateTime.now()) - const Duration(minutes: 5);
      if (untilExpiry > const Duration(minutes: 2) && untilExpiry < backoff) {
        backoff = untilExpiry;
      } else if (untilExpiry <= const Duration(minutes: 2)) {
        backoff = const Duration(minutes: 2);
      }
    }

    debugPrint('AuthRefreshGuard: refresh storm detected '
        '($refreshCount refreshes, $fastCount in ${_fastWindow.inSeconds}s). '
        'Pausing auto-refresh ${backoff.inMinutes}m.');
    try {
      client.auth.stopAutoRefresh();
    } catch (e) {
      debugPrint('AuthRefreshGuard: stopAutoRefresh failed: $e');
    }
    _reopenTimer?.cancel();
    _reopenTimer = Timer(backoff, () {
      _tripped = false;
      _refreshTimes.clear();
      try {
        client.auth.startAutoRefresh();
        debugPrint('AuthRefreshGuard: auto-refresh resumed.');
      } catch (e) {
        debugPrint('AuthRefreshGuard: startAutoRefresh failed: $e');
      }
    });
    unawaited(_recordDiagnostic(client,
        kind: 'auth_refresh_storm',
        refreshCount: refreshCount,
        backoff: backoff));
  }

  /// One row per storm: who, real clock skew vs live server time, the SDK's
  /// session-expiry view (its actual refresh decision input), and the
  /// refresh cadence fingerprint (~10s gaps = ticker; ~RTT gaps = the
  /// on-demand per-request path; bursty = lifecycle flapping).
  Future<void> _recordDiagnostic(SupabaseClient client,
      {required String kind,
      required int refreshCount,
      required Duration backoff}) async {
    final gaps = <int>[];
    for (var i = math.max(1, _refreshTimes.length - 10);
        i < _refreshTimes.length;
        i++) {
      gaps.add(_refreshTimes[i]
          .difference(_refreshTimes[i - 1])
          .inMilliseconds);
    }
    final session = client.auth.currentSession;
    final expiresAtSecs = session?.expiresAt;

    int? skewSeconds;
    try {
      final before = DateTime.now();
      final server = await client.rpc('server_time');
      final after = DateTime.now();
      final serverTime = DateTime.parse(server as String);
      final localMid = before.add(Duration(
          milliseconds: after.difference(before).inMilliseconds ~/ 2));
      skewSeconds = localMid.difference(serverTime).inSeconds;
    } catch (e) {
      debugPrint('AuthRefreshGuard: server_time check failed: $e');
    }
    try {
      await client.from('client_diagnostics').insert({
        'user_id': client.auth.currentUser?.id,
        'kind': kind,
        'detail': {
          'refresh_count': refreshCount,
          'refresh_gaps_ms': gaps,
          'trip_count': _trips,
          'backoff_minutes': backoff.inMinutes,
          'clock_skew_seconds': skewSeconds,
          'session_expires_at': expiresAtSecs,
          'seconds_until_expiry_local': expiresAtSecs != null
              ? DateTime.fromMillisecondsSinceEpoch(expiresAtSecs * 1000)
                  .difference(DateTime.now())
                  .inSeconds
              : null,
          if (kIsWeb) 'user_agent': html.window.navigator.userAgent,
        },
      });
    } catch (e) {
      debugPrint('AuthRefreshGuard: diagnostic insert failed: $e');
    }
  }

  void _reset() {
    _refreshTimes.clear();
    _tripped = false;
    _escalationRecorded = false;
    _refreshesWhileTripped = 0;
    _reopenTimer?.cancel();
    _reopenTimer = null;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _reset();
  }
}
