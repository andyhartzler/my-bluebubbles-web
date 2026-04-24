import 'package:flutter/foundation.dart';
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
    if (_initialized) {
      debugPrint('[CRMSupabaseService] Already initialized, skipping');
      return;
    }

    final url = CRMConfig.supabaseUrl;
    final anonKey = CRMConfig.supabaseAnonKey;

    debugPrint('[CRMSupabaseService] Checking credentials...');
    debugPrint('[CRMSupabaseService] URL present: ${url.isNotEmpty} (${url.isNotEmpty ? url.substring(0, url.length.clamp(0, 30)) : "empty"}...)');
    debugPrint('[CRMSupabaseService] Anon key present: ${anonKey.isNotEmpty} (length: ${anonKey.length})');

    if (url.isEmpty || anonKey.isEmpty) {
      // Without credentials, the CRM should gracefully stay disabled.
      debugPrint('⚠️ CRM Supabase credentials not provided. Skipping initialization.');
      debugPrint('⚠️ URL empty: ${url.isEmpty}, AnonKey empty: ${anonKey.isEmpty}');
      return;
    }

    try {
      debugPrint('[CRMSupabaseService] Initializing Supabase with URL: $url');
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );

      _client = Supabase.instance.client;
      debugPrint('[CRMSupabaseService] Client created successfully');

      _initialized = true;
      debugPrint('✅ CRM Supabase initialized successfully');
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize CRM Supabase: $e');
      debugPrint('❌ Stack: ${stack.toString().split('\n').take(5).join('\n')}');
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

  @Deprecated('Service role key no longer ships in the client. hasServiceRole always returns false; migrate call sites to RPC-backed privilege checks.')
  bool get hasServiceRole => false;

  @Deprecated('Use `client`. privilegedClient is now an alias; will be removed once all call sites are migrated.')
  SupabaseClient get privilegedClient => client;

  @visibleForTesting
  void debugSetInitialized(bool value) {
    _initialized = value;
    if (!value) {
      _client = null;
    }
  }
}
