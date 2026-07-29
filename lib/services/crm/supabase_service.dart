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
        // AuthCallbackScreen is the only thing that should redeem a magic
        // link. With detectSessionInUri at its default of true, the SDK
        // redeems it a second time on its own during initialize, and that
        // second redemption is what files Sentry FLUTTER-Q.
        //
        // When an exec opens the emailed link in a different browser than
        // the one that requested it, which is what happens every time Gmail
        // hands the link to Safari instead of reusing the tab, the PKCE code
        // verifier is not in that browser's local storage and the exchange
        // throws. The SDK's own path does catch it: SupabaseAuth's web
        // initial-URI handler catches the AuthException and then re-emits it
        // with GoTrueClient.notifyException, which calls addError on the
        // onAuthStateChange stream. Both of this app's listeners on that
        // stream (password_screen.dart and auth_refresh_guard.dart) subscribe
        // without an onError, so Dart rethrows the stream error into the zone
        // carrying the original getItem/exchangeCodeForSession stack. That is
        // the stack FLUTTER-Q shows.
        //
        // AuthCallbackScreen's own call cannot produce this: getSessionFromUrl
        // and exchangeCodeForSession throw straight to the caller and never
        // touch notifyException, so its try/catch really does contain it.
        // Disabling the automatic path therefore removes the only source of
        // this particular unhandled error, and it also drops the race the two
        // redeemers had over a single-use code.
        //
        // Safe to disable: every sign-in link this app mints points at
        // https://moyd.app/auth/callback (password_screen.dart), a registered
        // route rendering AuthCallbackScreen, and the only other auth entry
        // point is verifyOTP with the 6-digit code, which reads no URL at all.
        //
        // Still open, deliberately not fixed here because it is a separate
        // pre-existing bug: those two listeners will keep turning any other
        // notifyException, a failed token refresh above all, into its own
        // unhandled exception. They need onError handlers.
        authOptions: FlutterAuthClientOptions(detectSessionInUri: false),
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
