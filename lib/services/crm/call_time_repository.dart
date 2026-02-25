import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/call_time_list.dart';

import 'supabase_service.dart';

class CallTimeRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get isReady => CRMConfig.crmEnabled && _supabase.isInitialized;

  SupabaseClient get _client =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  /// Fetch all call time lists with summary counts
  Future<List<CallTimeList>> fetchLists({String? status}) async {
    if (!isReady) return [];

    var q = _client.from('call_time_lists').select();
    if (status != null) q = q.eq('status', status);
    final data = await q.order('created_at', ascending: false);

    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CallTimeList.fromJson)
        .toList();
  }

  /// Fetch a single list with all its items (joined with mec_donors)
  Future<CallTimeList?> fetchListWithItems(int listId) async {
    if (!isReady) return null;

    final data = await _client
        .from('call_time_lists')
        .select('*, call_time_list_items(*, mec_donors(*))')
        .eq('id', listId)
        .maybeSingle();

    if (data == null) return null;
    return CallTimeList.fromJson(data as Map<String, dynamic>);
  }

  /// Create a new call time list
  Future<CallTimeList?> createList({
    required String name,
    String? description,
    Map<String, dynamic>? filters,
    String? createdBy,
  }) async {
    if (!isReady) return null;

    final payload = {
      'name': name,
      'description': description,
      'status': 'active',
      'filters': filters,
      'created_by': createdBy,
      'total_items': 0,
      'total_called': 0,
      'total_pledged': 0,
    };

    final data = await _client
        .from('call_time_lists')
        .insert(payload)
        .select()
        .single();

    return CallTimeList.fromJson(data as Map<String, dynamic>);
  }

  /// Update list metadata
  Future<void> updateList(int listId, Map<String, dynamic> updates) async {
    if (!isReady) return;
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('call_time_lists').update(updates).eq('id', listId);
  }

  /// Delete a list and all its items (cascade)
  Future<void> deleteList(int listId) async {
    if (!isReady) return;
    // Items cascade-delete via FK
    await _client.from('call_time_lists').delete().eq('id', listId);
  }

  /// Add a donor to a call time list
  Future<CallTimeListItem?> addItem({
    required int listId,
    required int donorId,
    int priority = 0,
    double? suggestedAsk,
  }) async {
    if (!isReady) return null;

    final payload = {
      'list_id': listId,
      'donor_id': donorId,
      'priority': priority,
      'suggested_ask': suggestedAsk,
      'call_status': 'pending',
    };

    final data = await _client
        .from('call_time_list_items')
        .insert(payload)
        .select('*, mec_donors(*)')
        .single();

    await _refreshListCounts(listId);

    return CallTimeListItem.fromJson(data as Map<String, dynamic>);
  }

  /// Batch-add multiple donors to a list
  Future<void> addItems({
    required int listId,
    required List<int> donorIds,
    double? suggestedAsk,
  }) async {
    if (!isReady) return;

    final payloads = donorIds.map((id) => {
      'list_id': listId,
      'donor_id': id,
      'priority': 0,
      'suggested_ask': suggestedAsk,
      'call_status': 'pending',
    }).toList();

    await _client.from('call_time_list_items').insert(payloads);
    await _refreshListCounts(listId);
  }

  /// Update a call time list item (log call result)
  Future<void> updateItem(int itemId, {
    String? callStatus,
    String? callNotes,
    double? pledgedAmount,
    String? calledBy,
  }) async {
    if (!isReady) return;

    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (callStatus != null) {
      payload['call_status'] = callStatus;
      payload['called_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (callNotes != null) payload['call_notes'] = callNotes;
    if (pledgedAmount != null) payload['pledged_amount'] = pledgedAmount;
    if (calledBy != null) payload['called_by'] = calledBy;

    await _client.from('call_time_list_items').update(payload).eq('id', itemId);
  }

  /// Remove an item from a list
  Future<void> removeItem(int itemId, int listId) async {
    if (!isReady) return;
    await _client.from('call_time_list_items').delete().eq('id', itemId);
    await _refreshListCounts(listId);
  }

  /// Refresh the summary counts on a list
  Future<void> _refreshListCounts(int listId) async {
    final items = await _client
        .from('call_time_list_items')
        .select('call_status, pledged_amount')
        .eq('list_id', listId);

    final list = items as List<dynamic>;
    final totalItems = list.length;
    final totalCalled = list.where((i) {
      final status = (i as Map<String, dynamic>)['call_status'] as String?;
      return status != null && status != 'pending' && status != 'skipped';
    }).length;
    final totalPledged = list.fold<double>(0, (sum, i) {
      return sum + ((i as Map<String, dynamic>)['pledged_amount'] as num? ?? 0).toDouble();
    });

    await _client.from('call_time_lists').update({
      'total_items': totalItems,
      'total_called': totalCalled,
      'total_pledged': totalPledged,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', listId);
  }
}
