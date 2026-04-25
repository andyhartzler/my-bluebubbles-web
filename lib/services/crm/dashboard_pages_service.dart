import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/dashboard_page.dart';
import 'package:bluebubbles/screens/dashboard/models/dashboard_widget_config.dart';
import 'supabase_service.dart';

/// CRUD + reorder for `public.dashboard_pages`.
/// Each row is one personal Dashboard page for a user. The universal
/// dashboard (singleton in `crm_dashboard_metrics`) is unchanged and
/// not represented in this table.
class DashboardPagesService {
  DashboardPagesService({CRMSupabaseService? supabaseService})
      : _supabase = supabaseService ?? CRMSupabaseService();

  static const String _table = 'dashboard_pages';
  static const String _universalLayoutTable = 'crm_dashboard_metrics';
  static const int maxPagesPerUser = 10;

  final CRMSupabaseService _supabase;

  SupabaseClient? get _client {
    if (_supabase.isInitialized) return _supabase.client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Pages owned by [userId], sorted by `position` ascending.
  Future<List<DashboardPage>> fetchPagesForUser(String userId) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('position', ascending: true);
      return (rows as List)
          .whereType<Map>()
          .map((m) => DashboardPage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[DashboardPagesService] fetchPagesForUser: $e');
      return const [];
    }
  }

  /// Create a new page seeded from one of:
  ///   - `seed: 'universal'` — copy the current global layout
  ///   - `seed: 'blank'` — empty grid
  ///   - `seed: 'page', sourcePageId: <id>` — duplicate an existing page
  Future<DashboardPage?> createPage({
    required String userId,
    required String createdBy,
    required String title,
    required String seed,
    String? sourcePageId,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      // Determine starting layout
      Map<String, dynamic> seedLayout = {'widgets': [], 'columns': 4};
      Map<String, dynamic> seedLayoutMobile = {'widgets': [], 'columns': 2};

      if (seed == 'universal') {
        final row = await client
            .from(_universalLayoutTable)
            .select('dashboard_layout, dashboard_layout_mobile')
            .limit(1)
            .maybeSingle();
        if (row != null) {
          final l = row['dashboard_layout'];
          final lm = row['dashboard_layout_mobile'];
          if (l is Map<String, dynamic>) seedLayout = l;
          if (lm is Map<String, dynamic>) seedLayoutMobile = lm;
        }
      } else if (seed == 'page' && sourcePageId != null) {
        final src = await client
            .from(_table)
            .select('layout, layout_mobile')
            .eq('id', sourcePageId)
            .maybeSingle();
        if (src != null) {
          final l = src['layout'];
          final lm = src['layout_mobile'];
          if (l is Map<String, dynamic>) seedLayout = l;
          if (lm is Map<String, dynamic>) seedLayoutMobile = lm;
        }
      }

      // Determine next position
      final existing = await client
          .from(_table)
          .select('position')
          .eq('user_id', userId)
          .order('position', ascending: false)
          .limit(1);
      int nextPos = 0;
      if (existing.isNotEmpty) {
        final p = (existing.first as Map)['position'];
        nextPos = (p is int ? p : int.tryParse(p?.toString() ?? '0') ?? 0) + 1;
      }

      // Enforce client-side cap
      final count = await client
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .count();
      if (count.count >= maxPagesPerUser) {
        debugPrint('[DashboardPagesService] createPage: user at cap ($maxPagesPerUser)');
        return null;
      }

      final inserted = await client
          .from(_table)
          .insert({
            'user_id': userId,
            'created_by': createdBy,
            'title': title,
            'position': nextPos,
            'layout': seedLayout,
            'layout_mobile': seedLayoutMobile,
          })
          .select()
          .single();
      return DashboardPage.fromJson(Map<String, dynamic>.from(inserted));
    } catch (e) {
      debugPrint('[DashboardPagesService] createPage: $e');
      return null;
    }
  }

  Future<bool> renamePage(String pageId, String title) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from(_table).update({'title': title}).eq('id', pageId);
      return true;
    } catch (e) {
      debugPrint('[DashboardPagesService] renamePage: $e');
      return false;
    }
  }

  Future<bool> savePageLayout({
    required String pageId,
    required DashboardConfig layout,
    required bool isMobile,
  }) async {
    final client = _client;
    if (client == null) return false;
    final column = isMobile ? 'layout_mobile' : 'layout';
    try {
      await client.from(_table).update({column: layout.toJson()}).eq('id', pageId);
      return true;
    } catch (e) {
      debugPrint('[DashboardPagesService] savePageLayout: $e');
      return false;
    }
  }

  Future<bool> deletePage(String pageId) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from(_table).delete().eq('id', pageId);
      return true;
    } catch (e) {
      debugPrint('[DashboardPagesService] deletePage: $e');
      return false;
    }
  }

  /// Reorders pages for a user. [orderedIds] is the new order; positions
  /// are written in sequence starting at 0.
  Future<bool> reorderPages(String userId, List<String> orderedIds) async {
    final client = _client;
    if (client == null) return false;
    try {
      for (var i = 0; i < orderedIds.length; i++) {
        await client
            .from(_table)
            .update({'position': i})
            .eq('id', orderedIds[i])
            .eq('user_id', userId);
      }
      return true;
    } catch (e) {
      debugPrint('[DashboardPagesService] reorderPages: $e');
      return false;
    }
  }
}
