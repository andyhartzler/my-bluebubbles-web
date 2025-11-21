import 'dart:html' as html;

/// Manages MapKit JS tokens based on the current domain
/// CRITICAL: Each domain requires its own token from Apple Developer
class MapKitTokenManager {
  // Token for moyd.app domain
  static const String _moydToken = 'PASTE_MAPKIT_TOKEN_MOYD_VALUE_HERE';

  // Token for *.netlify.app domains (includes preview deployments)
  static const String _netlifyToken = 'PASTE_MAPKIT_TOKEN_NETLIFY_VALUE_HERE';

  /// Returns the appropriate token based on current hostname
  /// Falls back to Netlify token for localhost development
  static String getToken() {
    final hostname = html.window.location.hostname ?? '';

    print('[MapKitToken] Current hostname: $hostname');

    // Production domain
    if (hostname == 'moyd.app') {
      print('[MapKitToken] Using moyd.app token');
      return _moydToken;
    }

    // Netlify deployments (including previews)
    if (hostname.contains('netlify.app')) {
      print('[MapKitToken] Using Netlify token');
      return _netlifyToken;
    }

    // Localhost - use Netlify token as fallback
    if (hostname.contains('localhost') || hostname.contains('127.0.0.1')) {
      print('[MapKitToken] Using Netlify token for localhost');
      return _netlifyToken;
    }

    // Default fallback
    print('[MapKitToken] Using Netlify token as fallback');
    return _netlifyToken;
  }

  /// Validates that the token is not empty
  static bool isTokenValid() {
    final token = getToken();
    return token.isNotEmpty && !token.contains('PASTE_');
  }
}
