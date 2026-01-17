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
  SupabaseClient? _serviceClient;
  bool _initialized = false;

  /// Initialize Supabase connection.
  /// Call this once during app startup.
  Future<void> initialize() async {
    if (_initialized) {
      print('[CRMSupabaseService] Already initialized, skipping');
      return;
    }

    final url = CRMConfig.supabaseUrl;
    final anonKey = CRMConfig.supabaseAnonKey;

    print('[CRMSupabaseService] Checking credentials...');
    print('[CRMSupabaseService] URL present: ${url.isNotEmpty} (${url.isNotEmpty ? url.substring(0, url.length.clamp(0, 30)) : "empty"}...)');
    print('[CRMSupabaseService] Anon key present: ${anonKey.isNotEmpty} (length: ${anonKey.length})');

    if (url.isEmpty || anonKey.isEmpty) {
      // Without credentials, the CRM should gracefully stay disabled.
      print('⚠️ CRM Supabase credentials not provided. Skipping initialization.');
      print('⚠️ URL empty: ${url.isEmpty}, AnonKey empty: ${anonKey.isEmpty}');
      return;
    }

    try {
      print('[CRMSupabaseService] Initializing Supabase with URL: $url');
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );

      _client = Supabase.instance.client;
      print('[CRMSupabaseService] Client created successfully');

      final serviceRoleKey = CRMConfig.supabaseServiceRoleKey;
      if (serviceRoleKey.isNotEmpty) {
        try {
          _serviceClient = SupabaseClient(
            url,
            serviceRoleKey,
          );
          print('✅ CRM Supabase service role client configured');
        } catch (e) {
          print('⚠️ Failed to create service role client: $e');
        }
      } else {
        print('[CRMSupabaseService] No service role key provided, using anon client only');
      }
      _initialized = true;
      print('✅ CRM Supabase initialized successfully');
    } catch (e, stack) {
      print('❌ Failed to initialize CRM Supabase: $e');
      print('❌ Stack: ${stack.toString().split('\n').take(5).join('\n')}');
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

  bool get hasServiceRole => _serviceClient != null;

  SupabaseClient get privilegedClient => _serviceClient ?? client;

  @visibleForTesting
  void debugSetInitialized(bool value) {
    _initialized = value;
    if (!value) {
      _client = null;
      _serviceClient = null;
    }
  }
}
