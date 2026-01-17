import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

/// Service to manage session timeout based on app mode (PWA vs regular web)
///
/// - Regular web users: 4-hour session timeout
/// - PWA users (added to home screen): No timeout - stay logged in
class SessionTimeoutService {
  static final SessionTimeoutService _instance = SessionTimeoutService._internal();
  factory SessionTimeoutService() => _instance;
  SessionTimeoutService._internal();

  static const String _lastActivityKey = 'session_last_activity';
  static const String _sessionStartKey = 'session_start_time';

  /// Session timeout duration for regular web users (4 hours)
  static const Duration sessionTimeout = Duration(hours: 4);

  SharedPreferences? _prefs;

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if the app is running as an installed PWA (added to home screen)
  ///
  /// On iOS Safari, this is detected via the 'standalone' display mode.
  /// On Android Chrome, this is detected via the 'standalone' display mode
  /// or the display-mode media query.
  bool get isPWAMode {
    if (!kIsWeb) return false;

    try {
      // Check display-mode media query (works for most PWAs)
      final displayMode = html.window.matchMedia('(display-mode: standalone)');
      if (displayMode.matches) {
        debugPrint('PWA detected: display-mode: standalone');
        return true;
      }

      // Also check for fullscreen mode which some PWAs use
      final fullscreen = html.window.matchMedia('(display-mode: fullscreen)');
      if (fullscreen.matches) {
        debugPrint('PWA detected: display-mode: fullscreen');
        return true;
      }

      // Check for minimal-ui mode (another PWA display mode)
      final minimalUi = html.window.matchMedia('(display-mode: minimal-ui)');
      if (minimalUi.matches) {
        debugPrint('PWA detected: display-mode: minimal-ui');
        return true;
      }

      // Check iOS Safari standalone mode via navigator.standalone
      // This is set to true when running as a home screen app on iOS
      if (_checkIOSStandalone()) {
        debugPrint('PWA detected: iOS standalone mode');
        return true;
      }

      debugPrint('Not in PWA mode - regular browser');
      return false;
    } catch (e) {
      // If detection fails, assume regular web (safer to enforce timeout)
      debugPrint('PWA detection failed: $e');
      return false;
    }
  }

  /// Check iOS Safari standalone mode via JavaScript
  bool _checkIOSStandalone() {
    if (!kIsWeb) return false;

    try {
      // Use dart:js to access navigator.standalone
      // This property is iOS Safari specific and indicates home screen launch
      final navigator = js.context['navigator'];
      if (navigator == null) return false;

      final standalone = navigator['standalone'];
      return standalone == true;
    } catch (e) {
      debugPrint('iOS standalone check failed: $e');
      return false;
    }
  }

  /// Record that user just logged in or performed activity
  Future<void> recordSessionStart() async {
    await _ensurePrefs();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs!.setInt(_sessionStartKey, now);
    await _prefs!.setInt(_lastActivityKey, now);
    debugPrint('Session started at: ${DateTime.now()}');
  }

  /// Record user activity (extends session for activity-based timeout)
  Future<void> recordActivity() async {
    await _ensurePrefs();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs!.setInt(_lastActivityKey, now);
  }

  /// Clear session timestamps (on logout)
  Future<void> clearSession() async {
    await _ensurePrefs();
    await _prefs!.remove(_sessionStartKey);
    await _prefs!.remove(_lastActivityKey);
    debugPrint('Session timestamps cleared');
  }

  /// Check if the session has expired
  /// Returns true if session is expired and user should be logged out
  ///
  /// PWA users never expire (returns false)
  /// Regular web users expire after [sessionTimeout]
  Future<bool> isSessionExpired() async {
    // PWA users don't have session timeout
    if (isPWAMode) {
      debugPrint('PWA mode detected - session never expires');
      return false;
    }

    await _ensurePrefs();

    final sessionStart = _prefs!.getInt(_sessionStartKey);
    if (sessionStart == null) {
      // No session recorded - might be first login, don't expire
      // The session will be recorded after successful login
      return false;
    }

    final sessionStartTime = DateTime.fromMillisecondsSinceEpoch(sessionStart);
    final elapsed = DateTime.now().difference(sessionStartTime);

    if (elapsed > sessionTimeout) {
      debugPrint('Session expired: started ${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago (limit: ${sessionTimeout.inHours}h)');
      return true;
    }

    debugPrint('Session valid: ${elapsed.inMinutes}m elapsed (limit: ${sessionTimeout.inHours}h)');
    return false;
  }

  /// Get remaining session time (for UI display if needed)
  Future<Duration?> getRemainingSessionTime() async {
    if (isPWAMode) return null; // PWA users have unlimited session

    await _ensurePrefs();

    final sessionStart = _prefs!.getInt(_sessionStartKey);
    if (sessionStart == null) return null;

    final sessionStartTime = DateTime.fromMillisecondsSinceEpoch(sessionStart);
    final elapsed = DateTime.now().difference(sessionStartTime);
    final remaining = sessionTimeout - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check session and sign out if expired
  /// Returns true if user was signed out due to expiration
  Future<bool> checkAndExpireSession() async {
    final expired = await isSessionExpired();

    if (expired) {
      try {
        debugPrint('Signing out user due to session expiration');
        await Supabase.instance.client.auth.signOut();
        await clearSession();
        return true;
      } catch (e) {
        debugPrint('Error signing out: $e');
      }
    }

    return false;
  }
}
