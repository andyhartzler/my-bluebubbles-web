import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
        // Every PostgREST/auth/storage request becomes a Sentry breadcrumb;
        // failed requests become events (captureFailedRequests). No-op
        // wrapper when Sentry is disabled (debug builds).
        //
        // 400-599, NOT the 500-599 default. The failures that matter on this
        // app are 4xx: an RLS rejection on a vote write is a 403 or a 401,
        // an expired JWT is a 401, and a malformed filter is a 400. With the
        // default range every one of those was dropped on the floor, so the
        // single most important thing that can go wrong tonight, an exec
        // whose writes are all being refused, produced no Sentry event at
        // all and had to arrive as a phone call.
        httpClient: SentryHttpClient(
          failedRequestStatusCodes: [SentryStatusCode.range(400, 599)],
        ),
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
