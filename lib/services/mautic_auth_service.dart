import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling Mautic authentication via Edge Function
class MauticAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Base URL for Mautic
  static const String mauticBaseUrl = 'https://email.moyd.app';

  /// Dashboard URL (used as fallback)
  static const String mauticDashboardUrl = '$mauticBaseUrl/s/dashboard';

  /// Gets a one-time auto-login URL for Mautic
  ///
  /// [redirect] - Optional path to redirect to after login (e.g., '/s/emails' for emails page)
  ///
  /// Returns the full URL to load in WebView or browser
  /// Falls back to dashboard URL if Edge Function fails
  Future<String> getMauticLoginUrl({String? redirect}) async {
    // Verify user is logged into CRM
    final session = _supabase.auth.currentSession;
    if (session == null) {
      debugPrint('Mautic: No CRM session, loading dashboard directly');
      return mauticDashboardUrl;
    }

    try {
      debugPrint('Mautic: Calling mautic-auth Edge Function...');

      final response = await _supabase.functions.invoke(
        'mautic-auth',
        body: {
          if (redirect != null) 'redirect': redirect,
        },
      );

      debugPrint('Mautic: Edge Function response status: ${response.status}');
      debugPrint('Mautic: Edge Function response data: ${response.data}');

      if (response.status != 200) {
        final errorData = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : null;
        final error = errorData?['error'] ?? 'Unknown error (status ${response.status})';
        debugPrint('Mautic: Edge Function error: $error');
        // Fall back to dashboard URL
        return mauticDashboardUrl;
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;
      final loginUrl = data?['login_url'] as String?;
      if (loginUrl == null || loginUrl.isEmpty) {
        debugPrint('Mautic: No login_url in response, falling back to dashboard');
        return mauticDashboardUrl;
      }

      debugPrint('Mautic: Got login URL: $loginUrl');
      return loginUrl;
    } catch (e) {
      debugPrint('Mautic: Exception calling Edge Function: $e');
      // Fall back to dashboard URL on any error
      return mauticDashboardUrl;
    }
  }

  /// Gets a fresh login URL and returns it along with expiration info
  Future<MauticAuthResult> getAuthResult({String? redirect}) async {
    final loginUrl = await getMauticLoginUrl(redirect: redirect);
    return MauticAuthResult(
      loginUrl: loginUrl,
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
  }
}

/// Result from Mautic auth request
class MauticAuthResult {
  final String loginUrl;
  final DateTime expiresAt;

  MauticAuthResult({
    required this.loginUrl,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
