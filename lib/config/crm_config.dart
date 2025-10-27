import 'package:flutter_dotenv/flutter_dotenv.dart';

/// CRM Configuration - Supabase connection details
/// IMPORTANT: Never commit real credentials to Git
class CRMConfig {
  /// Supabase project URL sourced from environment variables.
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Supabase anon key sourced from environment variables.
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Feature flags for toggling CRM-related functionality.
  static const bool crmEnabled = true;
  static const bool bulkMessagingEnabled = true;

  /// Rate limiting configuration for bulk messaging workflows.
  static const int messagesPerMinute = 30;
  static const Duration messageDelay = Duration(seconds: 2);
}
