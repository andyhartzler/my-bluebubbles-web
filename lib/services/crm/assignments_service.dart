import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/assignment.dart';
import 'supabase_service.dart';

/// CRUD + realtime for `public.assignments`.
class AssignmentsService {
  AssignmentsService({CRMSupabaseService? supabaseService})
      : _supabase = supabaseService ?? CRMSupabaseService();

  static const String _table = 'assignments';

  final CRMSupabaseService _supabase;

  SupabaseClient? get _client {
    if (_supabase.isInitialized) return _supabase.client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Items assigned TO the current user (incoming work).
  Future<List<Assignment>> fetchAssignedToMe(String userId) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('assigned_to', userId)
          .order('updated_at', ascending: false);
      return _parseList(rows);
    } catch (e) {
      debugPrint('[AssignmentsService] fetchAssignedToMe: $e');
      return const [];
    }
  }

  /// Items the current user has assigned TO others (outgoing work).
  Future<List<Assignment>> fetchAssignedByMe(String userId) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('assigned_by', userId)
          .order('updated_at', ascending: false);
      return _parseList(rows);
    } catch (e) {
      debugPrint('[AssignmentsService] fetchAssignedByMe: $e');
      return const [];
    }
  }

  /// Superadmin-only path: fetch all open assignments for any user.
  Future<List<Assignment>> fetchForUser(String targetUserId) async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('assigned_to', targetUserId)
          .order('updated_at', ascending: false);
      return _parseList(rows);
    } catch (e) {
      debugPrint('[AssignmentsService] fetchForUser: $e');
      return const [];
    }
  }

  Future<Assignment?> create({
    required String assignedTo,
    required String assignedBy,
    required String title,
    String? note,
    String? entityType,
    String? entityId,
    String? entityUrl,
    String? priority,
    DateTime? dueDate,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final inserted = await client
          .from(_table)
          .insert({
            'assigned_to': assignedTo,
            'assigned_by': assignedBy,
            'title': title,
            'note': note,
            'entity_type': entityType,
            'entity_id': entityId,
            'entity_url': entityUrl,
            'priority': priority,
            'due_date': dueDate?.toIso8601String().split('T').first,
          })
          .select()
          .single();
      return Assignment.fromJson(Map<String, dynamic>.from(inserted));
    } catch (e) {
      debugPrint('[AssignmentsService] create: $e');
      return null;
    }
  }

  Future<bool> update(Assignment assignment) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client
          .from(_table)
          .update(assignment.toUpdate())
          .eq('id', assignment.id);
      return true;
    } catch (e) {
      debugPrint('[AssignmentsService] update: $e');
      return false;
    }
  }

  Future<bool> setStatus(String assignmentId, String status) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from(_table).update({'status': status}).eq('id', assignmentId);
      return true;
    } catch (e) {
      debugPrint('[AssignmentsService] setStatus: $e');
      return false;
    }
  }

  Future<bool> delete(String assignmentId) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from(_table).delete().eq('id', assignmentId);
      return true;
    } catch (e) {
      debugPrint('[AssignmentsService] delete: $e');
      return false;
    }
  }

  /// Realtime stream of all rows where the user is the assignee.
  /// The stream returns the full filtered result set on every change.
  Stream<List<Assignment>>? watchAssignedToMe(String userId) {
    final client = _client;
    if (client == null) return null;
    return client
        .from(_table)
        .stream(primaryKey: const ['id'])
        .eq('assigned_to', userId)
        .order('updated_at')
        .map(_parseList);
  }

  List<Assignment> _parseList(dynamic rows) {
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((m) => Assignment.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
