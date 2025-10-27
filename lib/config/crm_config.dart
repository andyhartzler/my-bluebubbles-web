import 'package:flutter_dotenv/flutter_dotenv.dart';

/// CRM Configuration - Supabase connection details
/// IMPORTANT: Never commit real credentials to Git
class CRMConfig {
  static String _readEnv(List<String> keys) {
    for (final key in keys) {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  /// Supabase project URL sourced from environment variables. Supports
  /// both server-style and Next.js style keys so existing deployments
  /// keep working without additional renaming.
  static String get supabaseUrl => _readEnv([
        'SUPABASE_URL',
        'NEXT_PUBLIC_SUPABASE_URL',
      ]);

  /// Supabase anon key sourced from environment variables. Falls back to
  /// the NEXT_PUBLIC variant for compatibility with web deploy pipelines.
  static String get supabaseAnonKey => _readEnv([
        'SUPABASE_ANON_KEY',
        'NEXT_PUBLIC_SUPABASE_ANON_KEY',
      ]);

  /// Optional service role key used only for privileged server tasks.
  /// This should never be exposed in a public build.
  static String get supabaseServiceRoleKey => _readEnv([
        'SUPABASE_SERVICE_ROLE_KEY',
        'NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY',
      ]);

  /// Feature flags for toggling CRM-related functionality.
  static const bool crmEnabled = true;
  static const bool bulkMessagingEnabled = true;

  /// Rate limiting configuration for bulk messaging workflows.
  static const int messagesPerMinute = 30;
  static const Duration messageDelay = Duration(seconds: 2);
}
