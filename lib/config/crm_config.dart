import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
const String _supabaseUrlNextDefine = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL');
const String _supabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
const String _supabaseAnonKeyNextDefine = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY');
const String _supabaseServiceRoleDefine = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const String _supabaseServiceRoleNextDefine =
    String.fromEnvironment('NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY');

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
  static String get supabaseUrl {
    if (_supabaseUrlDefine.isNotEmpty) return _supabaseUrlDefine;
    if (_supabaseUrlNextDefine.isNotEmpty) return _supabaseUrlNextDefine;
    return _readEnv([
      'SUPABASE_URL',
      'NEXT_PUBLIC_SUPABASE_URL',
    ]);
  }

  /// Supabase anon key sourced from environment variables. Falls back to
  /// the NEXT_PUBLIC variant for compatibility with web deploy pipelines.
  static String get supabaseAnonKey {
    if (_supabaseAnonKeyDefine.isNotEmpty) return _supabaseAnonKeyDefine;
    if (_supabaseAnonKeyNextDefine.isNotEmpty) return _supabaseAnonKeyNextDefine;
    return _readEnv([
      'SUPABASE_ANON_KEY',
      'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    ]);
  }

  /// Optional service role key used only for privileged server tasks.
  /// This should never be exposed in a public build.
  static String get supabaseServiceRoleKey {
    if (_supabaseServiceRoleDefine.isNotEmpty) return _supabaseServiceRoleDefine;
    if (_supabaseServiceRoleNextDefine.isNotEmpty) return _supabaseServiceRoleNextDefine;
    return _readEnv([
      'SUPABASE_SERVICE_ROLE_KEY',
      'NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY',
    ]);
  }

  /// Feature flags for toggling CRM-related functionality.
  static const bool crmEnabled = true;
  static const bool bulkMessagingEnabled = true;

  /// Rate limiting configuration for bulk messaging workflows.
  static const int messagesPerMinute = 30;
  static const Duration messageDelay = Duration(seconds: 2);

  /// Default sender mailbox used for CRM-driven email flows.
  static const String defaultSenderEmail = 'info@moyoungdemocrats.org';
}
