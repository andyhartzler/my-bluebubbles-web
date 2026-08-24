import 'dart:async';

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
/// device disagrees by more than [_toleranceSeconds], the SDK's own refresh timing
/// cannot be trusted, so we stop its ticker and drive refreshes ourselves against
/// corrected time.
///
/// We cannot set the device clock and we cannot make gotrue read a different one.
/// Taking over the schedule is the only lever that actually exists.
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
      _schedule(client);
      unawaited(_report(client, skew));
    } catch (e) {
      debugPrint('ClockSkewGuard: install failed, leaving SDK alone: $e');
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
