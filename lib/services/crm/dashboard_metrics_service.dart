import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/crm/dashboard_metrics.dart';
import 'supabase_service.dart';

/// Service for fetching pre-calculated dashboard metrics from the crm_dashboard_metrics table.
/// The table uses a single-row pattern with database triggers for real-time updates.
class DashboardMetricsService {
  final CRMSupabaseService _crmService = CRMSupabaseService();

  /// Get the Supabase client for read operations
  SupabaseClient? get _client {
    if (!_crmService.isInitialized) return null;
    return _crmService.hasServiceRole
        ? _crmService.privilegedClient
        : Supabase.instance.client;
  }

  /// Fetch the singleton dashboard metrics row
  Future<DashboardMetrics?> fetchMetrics() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('crm_dashboard_metrics')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return DashboardMetrics.fromJson(response);
    } catch (e) {
      print('[DashboardMetricsService] Error fetching metrics: $e');
      return null;
    }
  }

  /// Fetch the saved dashboard layout configuration
  Future<Map<String, dynamic>?> fetchDashboardLayout() async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('crm_dashboard_metrics')
          .select('dashboard_layout')
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      final layout = response['dashboard_layout'];
      if (layout == null) return null;
      return layout is Map<String, dynamic> ? layout : null;
    } catch (e) {
      print('[DashboardMetricsService] Error fetching dashboard layout: $e');
      return null;
    }
  }

  /// Save the dashboard layout configuration
  Future<bool> saveDashboardLayout(Map<String, dynamic> layout) async {
    final client = _client;
    if (client == null) return false;

    try {
      // Get the ID of the first row
      final existingRow = await client
          .from('crm_dashboard_metrics')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existingRow == null) {
        // No row exists - this shouldn't happen but handle it
        print('[DashboardMetricsService] No metrics row found to update layout');
        return false;
      }

      // Update the dashboard_layout column
      await client
          .from('crm_dashboard_metrics')
          .update({'dashboard_layout': layout})
          .eq('id', existingRow['id']);

      return true;
    } catch (e) {
      print('[DashboardMetricsService] Error saving dashboard layout: $e');
      return false;
    }
  }

  /// Fetch the saved mobile dashboard layout configuration
  Future<Map<String, dynamic>?> fetchDashboardLayoutMobile() async {
    final client = _client;
    if (client == null) {
      print('[DashboardMetricsService] fetchDashboardLayoutMobile: client is null');
      return null;
    }

    try {
      print('[DashboardMetricsService] fetchDashboardLayoutMobile: Fetching from database...');

      final response = await client
          .from('crm_dashboard_metrics')
          .select('dashboard_layout_mobile')
          .limit(1)
          .maybeSingle();

      if (response == null) {
        print('[DashboardMetricsService] fetchDashboardLayoutMobile: No row found');
        return null;
      }

      final layout = response['dashboard_layout_mobile'];
      if (layout == null) {
        print('[DashboardMetricsService] fetchDashboardLayoutMobile: Layout is null (not set yet)');
        return null;
      }

      final widgetCount = (layout is Map) ? (layout['widgets'] as List?)?.length ?? 0 : 0;
      print('[DashboardMetricsService] fetchDashboardLayoutMobile: Loaded layout with $widgetCount widgets');

      return layout is Map<String, dynamic> ? layout : null;
    } catch (e) {
      print('[DashboardMetricsService] Error fetching mobile dashboard layout: $e');
      return null;
    }
  }

  /// Save the mobile dashboard layout configuration
  Future<bool> saveDashboardLayoutMobile(Map<String, dynamic> layout) async {
    final client = _client;
    if (client == null) {
      print('[DashboardMetricsService] saveDashboardLayoutMobile: client is null');
      return false;
    }

    try {
      print('[DashboardMetricsService] saveDashboardLayoutMobile: Fetching existing row...');

      // Get the ID of the first row
      final existingRow = await client
          .from('crm_dashboard_metrics')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existingRow == null) {
        print('[DashboardMetricsService] No metrics row found to update mobile layout');
        return false;
      }

      final rowId = existingRow['id'];
      print('[DashboardMetricsService] saveDashboardLayoutMobile: Updating row $rowId with ${layout['widgets']?.length ?? 0} widgets');

      // Update the dashboard_layout_mobile column
      await client
          .from('crm_dashboard_metrics')
          .update({'dashboard_layout_mobile': layout})
          .eq('id', rowId);

      print('[DashboardMetricsService] saveDashboardLayoutMobile: Update completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('[DashboardMetricsService] Error saving mobile dashboard layout: $e');
      print('[DashboardMetricsService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Watch the dashboard metrics for real-time updates
  Stream<DashboardMetrics?> watchMetrics() {
    final client = _client;
    if (client == null) {
      return Stream.value(null);
    }

    return client
        .from('crm_dashboard_metrics')
        .stream(primaryKey: ['id'])
        .map((data) {
          if (data.isEmpty) return null;
          return DashboardMetrics.fromJson(data.first);
        });
  }

  /// Check if the metrics table exists and has data
  Future<bool> hasMetrics() async {
    final client = _client;
    if (client == null) return false;

    try {
      final response = await client
          .from('crm_dashboard_metrics')
          .select('id')
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('[DashboardMetricsService] Error checking metrics table: $e');
      return false;
    }
  }
}
