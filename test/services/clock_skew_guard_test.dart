import 'package:bluebubbles/services/clock_skew_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// The arithmetic that decides when to refresh, tested against the real
/// measurement that produced FLUTTER's auth_refresh_storm: a device clock
/// 7,279 seconds fast, holding a token issued good for one hour.
///
/// The scheduling code itself needs a live SupabaseClient, so what is exercised
/// here is the delay computation it calls. That is the part that was wrong in
/// gotrue and the part a future edit is most likely to break.
void main() {
  // Token issued at local 12:00 on a clock running 7,279 seconds fast, so the
  // server issued it at 09:58:41 and it truly expires at 10:58:41 server time.
  final skew = const Duration(seconds: 7279);
  final expiry = DateTime.utc(2026, 8, 24, 10, 58, 41);

  group('ClockSkewGuard.debugRefreshDelay', () {
    test('a token issued moments ago is NOT treated as expired', () {
      // The device says 12:00:00. gotrue would compute expiry - now as minus
      // 3,679 seconds here and refresh immediately, forever.
      final delay = ClockSkewGuard.debugRefreshDelay(
        expiryUtc: expiry,
        localNow: DateTime.utc(2026, 8, 24, 12, 0, 0),
        skew: skew,
      );

      // Corrected now is 09:58:41, so 60 minutes remain, less the 10 minute
      // margin.
      expect(delay, const Duration(minutes: 50));
      expect(delay > const Duration(minutes: 1), isTrue,
          reason: 'anything at or near the floor means the storm is back');
    });

    test('the refresh lands on the margin, not on expiry', () {
      // Corrected now is 10:43:41, fifteen minutes from real expiry.
      final delay = ClockSkewGuard.debugRefreshDelay(
        expiryUtc: expiry,
        localNow: DateTime.utc(2026, 8, 24, 12, 45, 0),
        skew: skew,
      );
      expect(delay, const Duration(minutes: 5));
    });

    test('a genuinely expired token floors rather than spinning', () {
      // Corrected now is 11:58:41, an hour past real expiry. The arithmetic is
      // negative; the floor is what keeps a wrong correction from becoming a
      // hot loop.
      final delay = ClockSkewGuard.debugRefreshDelay(
        expiryUtc: expiry,
        localNow: DateTime.utc(2026, 8, 24, 14, 0, 0),
        skew: skew,
      );
      expect(delay, const Duration(minutes: 1));
    });

    test('a clock running SLOW is corrected in the other direction', () {
      // Same size of error, opposite sign: the device says 09:58:41 when the
      // server says 12:00:00, so the token expired an hour ago in fact and the
      // guard must not sit on it for another 50 minutes.
      final delay = ClockSkewGuard.debugRefreshDelay(
        expiryUtc: expiry,
        localNow: DateTime.utc(2026, 8, 24, 9, 58, 41),
        skew: -skew,
      );
      expect(delay, const Duration(minutes: 1));
    });

    test('an unskewed device gets the ordinary schedule', () {
      final delay = ClockSkewGuard.debugRefreshDelay(
        expiryUtc: expiry,
        localNow: DateTime.utc(2026, 8, 24, 10, 0, 0),
        skew: Duration.zero,
      );
      expect(delay, const Duration(minutes: 48, seconds: 41));
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
