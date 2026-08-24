import 'dart:convert';

import 'package:bluebubbles/services/clock_skew_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// The arithmetic that decides when to refresh, tested against the real
/// measurement that produced FLUTTER's auth_refresh_storm: a device clock
/// 7,279 seconds fast, holding a token issued good for one hour.
///
/// Both halves of the guard need a live SupabaseClient to run, so what is
/// exercised here is the two computations they call: the refresh delay, which
/// covers the ticker, and the expiry correction, which covers the per-request
/// path that stopping the ticker cannot reach.
///
/// Both take EXACTLY what production passes them. That is not a style choice.
/// The first version of the delay test took a true expiry and a skew, while
/// production passed an already-corrected expiry, so the test stayed green
/// through four hours of production computing a delay two hours past the point
/// the token had died. A test whose inputs differ from the caller's is not a
/// test of the caller.
void main() {
  // Token issued at local 12:00 on a clock running 7,279 seconds fast, so the
  // server issued it at 09:58:41 and it truly expires at 10:58:41 server time.
  final skew = const Duration(seconds: 7279);
  final expiry = DateTime.utc(2026, 8, 24, 10, 58, 41);

  // Everything below feeds refreshDelayFor the SAME shape production feeds it:
  // the expiry ClockSkewGuard has ALREADY written into the session, which is in
  // the DEVICE's frame, plus the device's own clock. The previous helper took
  // the true expiry and a skew, so these tests passed green for four hours while
  // production was computing something else entirely.
  group('refreshDelayFor', () {
    final trueExp = expiry.millisecondsSinceEpoch ~/ 1000;
    // What _correctExpiry writes on the 7,279s-fast machine.
    final correctedExp = trueExp + skew.inSeconds;

    test('a token issued moments ago is NOT treated as expired', () {
      // Device says 12:00:00, which is 09:58:41 real time, so a full hour of
      // token life remains and the refresh belongs 50 minutes out.
      expect(
        ClockSkewGuard.refreshDelayFor(
          correctedExpiryEpochSeconds: correctedExp,
          localNow: DateTime.utc(2026, 8, 24, 12, 0, 0),
        ),
        const Duration(minutes: 50),
      );
    });

    test('THE REGRESSION: the skew is not counted twice', () {
      // The bug shipped at 21:11 compared a device-frame expiry against
      // server-frame now, which added the offset a second time and scheduled
      // the refresh 2h01m AFTER the token had already died. Anything over an
      // hour here means the proactive refresh never fires at all.
      final delay = ClockSkewGuard.refreshDelayFor(
        correctedExpiryEpochSeconds: correctedExp,
        localNow: DateTime.utc(2026, 8, 24, 12, 0, 0),
      );
      expect(delay < const Duration(hours: 1), isTrue,
          reason: 'a delay past the token lifetime is the double-count bug');
    });

    test('the refresh lands on the margin, not on expiry', () {
      // Device 12:45 is 10:43:41 real, fifteen minutes from real expiry.
      expect(
        ClockSkewGuard.refreshDelayFor(
          correctedExpiryEpochSeconds: correctedExp,
          localNow: DateTime.utc(2026, 8, 24, 12, 45, 0),
        ),
        const Duration(minutes: 5),
      );
    });

    test('a genuinely expired token floors rather than spinning', () {
      expect(
        ClockSkewGuard.refreshDelayFor(
          correctedExpiryEpochSeconds: correctedExp,
          localNow: DateTime.utc(2026, 8, 24, 14, 0, 0),
        ),
        const Duration(minutes: 1),
      );
    });

    test('a SLOW clock does not become a one-per-minute loop', () {
      // The same double-count inverted: on a device 7,279s slow the old code
      // went negative and floored forever. Device 09:58:41 is 12:00:00 real,
      // so this token died an hour ago and ONE floored delay is correct, but
      // a device that is merely slow and holding a fresh token must not floor.
      final freshForSlowDevice =
          DateTime.utc(2026, 8, 24, 9, 58, 41).millisecondsSinceEpoch ~/ 1000;
      expect(
        ClockSkewGuard.refreshDelayFor(
          correctedExpiryEpochSeconds: freshForSlowDevice + 3600,
          localNow: DateTime.utc(2026, 8, 24, 9, 58, 41),
        ),
        const Duration(minutes: 50),
      );
    });

    test('an unskewed device gets the ordinary schedule', () {
      expect(
        ClockSkewGuard.refreshDelayFor(
          correctedExpiryEpochSeconds: trueExp,
          localNow: DateTime.utc(2026, 8, 24, 10, 0, 0),
        ),
        const Duration(minutes: 48, seconds: 41),
      );
    });
  });

  group('correctedExpiryFor', () {
    // A token whose exp is 10:58:41 UTC, the real expiry the server issued.
    String tokenExpiring(int exp) {
      String seg(Map<String, dynamic> m) => base64Url
          .encode(utf8.encode(json.encode(m)))
          .replaceAll('=', ''); // real tokens are unpadded
      return '${seg({'alg': 'HS256'})}.${seg({'exp': exp, 'sub': 'x'})}.sig';
    }

    final trueExp = expiry.millisecondsSinceEpoch ~/ 1000;

    test('restates the expiry in the device frame', () {
      // Device 7,279s fast, so it must believe the token lives 7,279s longer
      // than it does. That is what makes isExpired come out right.
      expect(
        ClockSkewGuard.correctedExpiryFor(tokenExpiring(trueExp), skew),
        trueExp + 7279,
      );
    });

    test('a SLOW device is moved the other way', () {
      expect(
        ClockSkewGuard.correctedExpiryFor(tokenExpiring(trueExp), -skew),
        trueExp - 7279,
      );
    });

    test('applying it twice cannot stack the offset', () {
      // The correction is re-applied on every auth state change, and a session
      // can see more than one. It reads exp from the token each time rather
      // than from the field it just wrote, so this has to be idempotent.
      final token = tokenExpiring(trueExp);
      final once = ClockSkewGuard.correctedExpiryFor(token, skew);
      final twice = ClockSkewGuard.correctedExpiryFor(token, skew);
      expect(twice, once);
    });

    test('an unreadable token leaves the session alone', () {
      // Null means do not touch expiresAt. Writing a wrong expiry would be
      // worse than the storm: the session could look valid past real expiry
      // and every request would 401.
      expect(ClockSkewGuard.correctedExpiryFor('not-a-jwt', skew), isNull);
      expect(ClockSkewGuard.correctedExpiryFor('a.b', skew), isNull);
      expect(ClockSkewGuard.correctedExpiryFor('a.!!!not-base64!!!.c', skew),
          isNull);
      expect(
        ClockSkewGuard.correctedExpiryFor(
          '${base64Url.encode(utf8.encode('{}')).replaceAll('=', '')}.'
          '${base64Url.encode(utf8.encode('{"sub":"x"}')).replaceAll('=', '')}.s',
          skew,
        ),
        isNull,
        reason: 'a JWT with no exp claim carries no expiry to correct',
      );
    });
  });

  test('the tolerance is wide enough to ignore ordinary drift', () {
    // Below this the SDK keeps the schedule. It has to sit far under the ten
    // minute refresh margin or correcting drift would itself cause refreshes.
    expect(ClockSkewGuard.toleranceSecondsForTest, 120);
    expect(ClockSkewGuard.toleranceSecondsForTest < 600, isTrue);
  });

  test('serverNow equals the device clock when nothing is being corrected', () {
    expect(ClockSkewGuard.isCorrecting, isFalse);
    expect(ClockSkewGuard.offset, Duration.zero);
    final drift = DateTime.now().difference(ClockSkewGuard.serverNow()).abs();
    expect(drift < const Duration(seconds: 1), isTrue);
  });
}
