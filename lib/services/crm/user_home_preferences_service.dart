import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/user_home_preferences.dart';
import 'supabase_service.dart';

/// Reads / writes a single row in `public.user_home_preferences`.
/// One row per auth user. RLS enforces ownership (or superadmin).
class UserHomePreferencesService {
  UserHomePreferencesService({CRMSupabaseService? supabaseService})
      : _supabase = supabaseService ?? CRMSupabaseService();

  static const String _table = 'user_home_preferences';

  final CRMSupabaseService _supabase;

  SupabaseClient? get _client {
    if (_supabase.isInitialized) return _supabase.client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Returns the user's preferences. If no row exists yet, returns
  /// `UserHomePreferences.defaultsFor(userId)` without writing — the
  /// caller decides when (and if) to persist defaults.
  Future<UserHomePreferences> fetchOrDefault(String userId) async {
    final client = _client;
    if (client == null) return UserHomePreferences.defaultsFor(userId);
    try {
      final row = await client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return UserHomePreferences.defaultsFor(userId);
      return UserHomePreferences.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[UserHomePreferencesService] fetchOrDefault: $e');
      return UserHomePreferences.defaultsFor(userId);
    }
  }

  Future<bool> upsert(UserHomePreferences prefs) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from(_table).upsert(prefs.toUpsert(), onConflict: 'user_id');
      return true;
    } catch (e) {
      debugPrint('[UserHomePreferencesService] upsert: $e');
      return false;
    }
  }
}
