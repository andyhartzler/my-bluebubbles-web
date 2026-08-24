import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stops a wrong device clock from turning into a token refresh storm.
///
/// THE BUG THIS PREVENTS, measured on a real executive's machine 2026-08-24.
/// gotrue decides whether an access token has expired by comparing the token's
/// `expiresAt` against the LOCAL clock. Tokens are issued good for one hour. That
/// member's Windows clock was 7,279 seconds fast, which is two hours and one
/// minute. So the instant the server handed him a fresh token his browser computed
/// `expiresAt - now` as roughly minus 3,679 seconds, concluded it had expired an
/// hour ago, and asked for another. The replacement looked equally expired.
///
/// The result was 51 tokens in 2 minutes 40 seconds, one every 3.2 seconds, and it
/// had been silently logging him out and back in for a month: every session in his
/// history ends and the next begins 2 to 4 seconds later.
///
/// Nothing he did caused it and no account is special. Any login on that machine
/// behaves the same way, which is why it looked like one person always having
/// trouble.
///
/// WHY AuthRefreshGuard DOES NOT COVER THIS. That class is the containment half:
/// it notices a storm already in progress, stops the ticker and backs off, and it
/// measures the skew so the device can be fixed with evidence. It is reactive by
/// design. This class is the prevention half, so the storm does not start.
///
/// THE APPROACH. Ask the server what time it actually is, once, at startup. If the
/// device disagrees by more than [_toleranceSeconds], two things follow, and the
/// first version of this class shipped only the second:
///
///  1. Every session is permanently `isExpired`, so `SupabaseClient` refreshes
///     before every single API call. [_correctExpiry] closes that by restating
///     the session's expiry in the device's own frame. This is the dominant
///     path and the one that actually storms.
///  2. The SDK's refresh ticker reads the same wrong clock, so its schedule
///     cannot be trusted either. We stop it and drive refreshes ourselves
///     against corrected time.
///
/// We cannot set the device clock and we cannot make gotrue read a different one,
/// so those two are the only levers that exist. Do not remove either believing the
/// other covers it: stopping the ticker leaves an exec refreshing on every request,
/// and correcting the expiry alone leaves the schedule in the SDK's hands with no
/// guarantee about a version that computes it some other way.
class ClockSkewGuard {
  ClockSkewGuard._();

  /// Below this we leave the SDK alone. Ordinary drift of a few seconds is
  /// harmless: gotrue refreshes on a margin far wider than this, so correcting it
  /// would add risk and buy nothing. The real case was over 7,000 seconds.
  static const int _toleranceSeconds = 120;

  /// Refresh this long before the token actually expires, measured on corrected
  /// time. Wide enough to absorb a slow network and a retry.
  static const Duration _refreshMargin = Duration(minutes: 10);

  /// Never schedule closer together than this, whatever the arithmetic says. This
  /// is the backstop: if the correction is itself wrong somehow, the worst case is
  /// a slow refresh loop rather than the 3-second storm we are fixing.
  static const Duration _minInterval = Duration(minutes: 1);

  static Duration _offset = Duration.zero;
  static bool _active = false;
  static bool _reported = false;
  static Timer? _timer;
  static StreamSubscription<AuthState>? _authSub;

  /// Server time as best we know it. Equals the device clock when no correction
  /// is in force, so callers can use it unconditionally.
  static DateTime serverNow() => DateTime.now().subtract(_offset);

  /// How far the device clock is ahead of the server. Negative means behind.
  static Duration get offset => _offset;

  static bool get isCorrecting => _active;

  /// Measure the skew and take over refresh scheduling if it is large enough to
  /// break the SDK. Safe to call more than once.
  ///
  /// Never throws. A device that cannot reach the server is a device that cannot
  /// refresh anyway, and turning a diagnostic into a crash on the sign-in path
  /// would be a worse bug than the one this fixes.
  static Future<void> install(SupabaseClient client) async {
    try {
      final skew = await _measureSkew(client);
      if (skew == null) return;

      _offset = skew;

      if (skew.abs().inSeconds <= _toleranceSeconds) {
        // Normal drift. Leave gotrue to do its job.
        if (_active) {
          _active = false;
          _timer?.cancel();
          client.auth.startAutoRefresh();
        }
        return;
      }

      debugPrint(
        'ClockSkewGuard: device clock is ${skew.inSeconds}s off server time. '
        'Taking over refresh scheduling.',
      );

      // The SDK's ticker reads the same wrong clock we just measured, so it has
      // to stop before it starts the loop.
      client.auth.stopAutoRefresh();
      _active = true;

      // Stopping the ticker is only half of it, and the smaller half. See
      // _correctExpiry: SupabaseClient refreshes before EVERY request whenever
      // the session looks expired, and that path is not the ticker.
      _correctExpiry(client);
      _watchForNewSessions(client);

      _schedule(client);
      unawaited(_report(client, skew));
    } catch (e) {
      debugPrint('ClockSkewGuard: install failed, leaving SDK alone: $e');
    }
  }

  /// Restate the session's expiry in the DEVICE's terms, which is what closes
  /// the path stopping the ticker cannot reach.
  ///
  /// Read from the installed packages rather than assumed, because the first
  /// version of this class fixed the wrong half and said so. There are TWO
  /// refresh paths, not one:
  ///
  ///   1. gotrue's auto-refresh ticker, which `stopAutoRefresh()` stops.
  ///   2. `SupabaseClient._getAccessToken`, which runs before EVERY PostgREST,
  ///      storage and functions call and refreshes whenever
  ///      `currentSession.isExpired`. Nothing client-side stops that one.
  ///
  /// Both read `Session.expiresAt`, and `isExpired` compares it against
  /// `DateTime.now()`. `expiresAt` is not stored: it is a late field derived
  /// from the `exp` claim of the access token, which is absolute server time.
  /// So on a device two hours fast, every session is permanently expired and
  /// path 2 refreshes on every request forever. Stopping the ticker leaves the
  /// dominant path untouched, which is exactly what shipped at 20:52 today.
  ///
  /// The lever is that `expiresAt` is a plain mutable field. Restating it as
  /// `exp + offset` puts it in the same frame as the wrong clock that will be
  /// compared against it, so BOTH paths compute correctly and neither needs to
  /// know a correction happened.
  ///
  /// The true `exp` is re-read from the token every time rather than taken from
  /// `expiresAt`, so this is idempotent: applying it twice to one session
  /// cannot stack the offset.
  static void _correctExpiry(SupabaseClient client) {
    if (!_active) return;
    final session = client.auth.currentSession;
    if (session == null) return;
    final corrected = correctedExpiryFor(session.accessToken, _offset);
    if (corrected == null) return;
    session.expiresAt = corrected;
  }

  /// The whole computation in one place so a test can exercise it without a
  /// live client: read the true `exp` out of the token and restate it in the
  /// device's frame. Null when the token is not a readable JWT, which means
  /// leave the session exactly as gotrue built it.
  @visibleForTesting
  static int? correctedExpiryFor(String accessToken, Duration offset) {
    final trueExp = _expFromJwt(accessToken);
    if (trueExp == null) return null;
    return trueExp + offset.inSeconds;
  }

  /// Every refresh mints a new Session object, and gotrue derives its expiry
  /// from the token again, so the correction has to be re-applied to each one.
  /// A refresh this class did not initiate, from a tab regaining focus or from
  /// path 2 firing once before the correction landed, arrives here too.
  static void _watchForNewSessions(SupabaseClient client) {
    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen(
      (_) => _correctExpiry(client),
      onError: (Object e) =>
          debugPrint('ClockSkewGuard: auth state stream error: $e'),
    );
  }

  /// The `exp` claim, in seconds since the epoch, or null if the token is not
  /// a readable JWT. Deliberately not a package dependency: this is three lines
  /// and a failure here must degrade to leaving the session alone.
  static int? _expFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      return exp is int ? exp : null;
    } catch (e) {
      debugPrint('ClockSkewGuard: could not read exp from token: $e');
      return null;
    }
  }

  /// Record the correction once per session, so a wrong device clock stays
  /// VISIBLE after we stop it from causing damage.
  ///
  /// This exists because the fix would otherwise hide the fault. AuthRefreshGuard
  /// reports skew, but only when a storm trips it, and the whole point of this
  /// class is that the storm no longer happens. Without this row the machine
  /// goes on running two hours out with nobody able to tell, and the member is
  /// never told to turn automatic time back on.
  ///
  /// Same table and shape AuthRefreshGuard writes, so both halves of this
  /// problem are readable from one place. Best effort: a failed insert must
  /// never cost the correction it is describing.
  static Future<void> _report(SupabaseClient client, Duration skew) async {
    if (_reported) return;
    final userId = client.auth.currentUser?.id;
    // Nothing to attribute the row to yet, and the anon role has no business
    // writing here. The next refresh tries again with a session in hand.
    if (userId == null) return;
    _reported = true;
    try {
      await client.from('client_diagnostics').insert({
        'user_id': userId,
        'kind': 'clock_skew_corrected',
        'detail': {
          'clock_skew_seconds': skew.inSeconds,
          'tolerance_seconds': _toleranceSeconds,
          'refresh_margin_minutes': _refreshMargin.inMinutes,
          'device_now': DateTime.now().toUtc().toIso8601String(),
          'server_now': serverNow().toUtc().toIso8601String(),
        },
      });
    } catch (e) {
      // Let a later refresh retry rather than swallowing the finding for good.
      _reported = false;
      debugPrint('ClockSkewGuard: diagnostic insert failed: $e');
    }
  }

  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _authSub?.cancel();
    _authSub = null;
    _active = false;
    _reported = false;
    _offset = Duration.zero;
  }

  /// Round-trip the server_time RPC and take the midpoint of the local clock
  /// either side of it, so the measurement is not skewed by network latency in
  /// one direction. Same technique AuthRefreshGuard already uses to report skew.
  static Future<Duration?> _measureSkew(SupabaseClient client) async {
    try {
      final before = DateTime.now();
      final raw = await client.rpc('server_time');
      final after = DateTime.now();
      final server = DateTime.parse(raw as String).toUtc();
      final localMid = before
          .toUtc()
          .add(Duration(
              milliseconds: after.difference(before).inMilliseconds ~/ 2));
      return localMid.difference(server);
    } catch (e) {
      debugPrint('ClockSkewGuard: could not read server_time: $e');
      return null;
    }
  }

  static void _schedule(SupabaseClient client) {
    _timer?.cancel();
    if (!_active) return;

    final session = client.auth.currentSession;
    final expiresAt = session?.expiresAt;
    if (expiresAt == null) {
      // Signed out, or a session with no expiry. Check back rather than spin.
      _timer = Timer(const Duration(minutes: 5), () => _schedule(client));
      return;
    }

    final expiry =
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
    // The comparison that matters: expiry is server time, so it must be compared
    // against corrected time. Using DateTime.now() here is the original bug.
    final untilRefresh =
        expiry.difference(serverNow().toUtc()) - _refreshMargin;

    final wait = untilRefresh < _minInterval ? _minInterval : untilRefresh;
    _timer = Timer(wait, () => _refresh(client));
  }

  static Future<void> _refresh(SupabaseClient client) async {
    if (!_active) return;
    try {
      await client.auth.refreshSession();
    } catch (e) {
      // A failed refresh is not fatal here. The next tick tries again, and
      // _minInterval keeps that from becoming a hot loop.
      debugPrint('ClockSkewGuard: refresh failed: $e');
    }
    // Re-measure occasionally rather than trusting one reading forever: the user
    // may fix their clock mid-session, and a stale offset would then be the thing
    // causing the problem.
    final skew = await _measureSkew(client);
    if (skew != null) {
      _offset = skew;
      if (skew.abs().inSeconds <= _toleranceSeconds) {
        debugPrint('ClockSkewGuard: clock corrected, handing back to the SDK.');
        _active = false;
        _timer?.cancel();
        try {
          client.auth.startAutoRefresh();
        } catch (_) {}
        return;
      }
      // Still skewed. If install had no session to attribute the finding to,
      // it does now.
      unawaited(_report(client, skew));
    }
    _schedule(client);
  }

  /// Exposed for the diagnostics screen so an operator can see the real number
  /// rather than inferring it from a storm alert.
  static Map<String, Object?> diagnostics() => {
        'clock_skew_seconds': _offset.inSeconds,
        'correcting': _active,
        'tolerance_seconds': _toleranceSeconds,
        'refresh_margin_minutes': _refreshMargin.inMinutes,
      };

  /// Rough human phrasing for a banner. Kept here so the wording stays with the
  /// arithmetic that produced it.
  static String? userFacingWarning() {
    if (!_active) return null;
    final mins = (_offset.inSeconds.abs() / 60).round();
    final ahead = _offset.isNegative ? 'behind' : 'ahead of';
    final amount = mins >= 60
        ? '${(mins / 60).toStringAsFixed(mins % 60 == 0 ? 0 : 1)} hours'
        : '$mins minutes';
    return 'This device’s clock is about $amount $ahead the correct time. '
        'Signing in still works, but turning on automatic time in your system '
        'settings will stop the repeated sign-outs.';
  }

  @visibleForTesting
  static Duration debugRefreshDelay({
    required DateTime expiryUtc,
    required DateTime localNow,
    required Duration skew,
  }) {
    final corrected = localNow.toUtc().subtract(skew);
    final until = expiryUtc.difference(corrected) - _refreshMargin;
    return until < _minInterval ? _minInterval : until;
  }

  @visibleForTesting
  static int get toleranceSecondsForTest => _toleranceSeconds;
}
