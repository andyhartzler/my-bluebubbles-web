import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling Mautic authentication via Edge Function
class MauticAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Base URL for Mautic (fallback if Edge Function doesn't return it)
  static const String mauticBaseUrl = 'https://email.moyd.app';

  /// Gets a one-time auto-login URL for Mautic
  ///
  /// [redirect] - Optional path to redirect to after login (e.g., '/s/emails' for emails page)
  ///
  /// Returns the full URL to load in WebView or browser
  /// Throws exception if user is not authenticated or Edge Function fails
  Future<String> getMauticLoginUrl({String? redirect}) async {
    // Verify user is logged into CRM
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('User not authenticated in CRM');
    }

    try {
      final response = await _supabase.functions.invoke(
        'mautic-auth',
        body: {
          if (redirect != null) 'redirect': redirect,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        throw Exception('Failed to get Mautic auth: $error');
      }

      final loginUrl = response.data['login_url'] as String?;
      if (loginUrl == null || loginUrl.isEmpty) {
        throw Exception('No login URL returned from Edge Function');
      }

      return loginUrl;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to connect to auth service: $e');
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
