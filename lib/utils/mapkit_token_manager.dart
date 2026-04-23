import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Manages MapKit JS tokens based on the current domain
/// CRITICAL: Each domain requires its own token from Apple Developer
///
/// Tokens are injected at build time via `--dart-define`:
///   --dart-define=MAPKIT_TOKEN_MOYD=<jwt>
///   --dart-define=MAPKIT_TOKEN_NETLIFY=<jwt>
/// If a token is not provided at build time, maps for that domain will fail
/// to load and a debug warning will be printed on first use.
class MapKitTokenManager {
  // Token for moyd.app domain (injected at build time)
  static const String _moydToken = String.fromEnvironment(
    'MAPKIT_TOKEN_MOYD',
    defaultValue: '',
  );

  // Token for *.netlify.app domains (injected at build time; includes preview deployments)
  static const String _netlifyToken = String.fromEnvironment(
    'MAPKIT_TOKEN_NETLIFY',
    defaultValue: '',
  );

  static bool _warnedMissingToken = false;

  static void _warnIfMissing(String which, String token) {
    if (token.isEmpty && !_warnedMissingToken) {
      _warnedMissingToken = true;
      debugPrint(
        '[MapKitToken] MAPKIT_TOKEN_$which not provided at build time — maps will fail to load. '
        'Pass --dart-define=MAPKIT_TOKEN_$which=<jwt> to `flutter build web`.',
      );
    }
  }

  /// Returns the appropriate token based on current hostname.
  /// Returns `null` when no token is configured for the current domain so
  /// callers can handle the missing-token case (instead of silently passing
  /// an empty string to MapKit JS, which produces confusing auth errors).
  static String? getToken() {
    final hostname = html.window.location.hostname ?? '';

    if (kDebugMode) {
      debugPrint('[MapKitToken] Current hostname: $hostname');
    }

    // Production domain
    if (hostname == 'moyd.app') {
      _warnIfMissing('MOYD', _moydToken);
      if (_moydToken.isEmpty) return null;
      if (kDebugMode) debugPrint('[MapKitToken] Using moyd.app token');
      return _moydToken;
    }

    // Netlify deployments (including previews)
    if (hostname.contains('netlify.app')) {
      _warnIfMissing('NETLIFY', _netlifyToken);
      if (_netlifyToken.isEmpty) return null;
      if (kDebugMode) debugPrint('[MapKitToken] Using Netlify token');
      return _netlifyToken;
    }

    // Localhost - use Netlify token as fallback
    if (hostname.contains('localhost') || hostname.contains('127.0.0.1')) {
      _warnIfMissing('NETLIFY', _netlifyToken);
      if (_netlifyToken.isEmpty) return null;
      if (kDebugMode) {
        debugPrint('[MapKitToken] Using Netlify token for localhost');
      }
      return _netlifyToken;
    }

    // Default fallback
    _warnIfMissing('NETLIFY', _netlifyToken);
    if (_netlifyToken.isEmpty) return null;
    if (kDebugMode) {
      debugPrint('[MapKitToken] Using Netlify token as fallback');
    }
    return _netlifyToken;
  }

  /// Validates that a token is configured for the current domain.
  static bool isTokenValid() {
    final token = getToken();
    return token != null && token.isNotEmpty && !token.contains('PASTE_');
  }
}
