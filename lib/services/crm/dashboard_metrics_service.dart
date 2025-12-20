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
