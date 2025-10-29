import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';

/// Singleton service for Supabase connection
/// This is the ONLY place that interacts with Supabase
class CRMSupabaseService {
  static final CRMSupabaseService _instance = CRMSupabaseService._internal();
  factory CRMSupabaseService() => _instance;
  CRMSupabaseService._internal();

  SupabaseClient? _client;
  bool _initialized = false;

  /// Initialize Supabase connection.
  /// Call this once during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    if (CRMConfig.supabaseUrl.isEmpty || CRMConfig.supabaseAnonKey.isEmpty) {
      // Without credentials, the CRM should gracefully stay disabled.
      print('⚠️ CRM Supabase credentials not provided. Skipping initialization.');
      return;
    }

    try {
      await Supabase.initialize(
        url: CRMConfig.supabaseUrl,
        anonKey: CRMConfig.supabaseAnonKey,
      );

      _client = Supabase.instance.client;
      _initialized = true;
      print('✅ CRM Supabase initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize CRM Supabase: $e');
      rethrow;
    }
  }

  /// Get Supabase client instance.
  SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw Exception('CRMSupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  bool get isInitialized => _initialized;
}
