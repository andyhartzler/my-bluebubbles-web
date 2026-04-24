import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/assignment.dart';
import 'supabase_service.dart';

/// Synthesizes the "things waiting on me" panel from existing tables.
/// Read-only; each item deep-links to its source row in the CRM.
///
/// Triggered by the home screen on mount. Cached briefly to avoid
/// hammering the DB on tab-switch.
class AutoInferredAssignmentsService {
  AutoInferredAssignmentsService({CRMSupabaseService? supabaseService})
      : _supabase = supabaseService ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  static const Duration _cacheTtl = Duration(seconds: 30);
  DateTime? _cacheStamp;
  List<AutoInferredAssignment> _cache = const [];
  String? _cacheKey;

  SupabaseClient? get _client {
    if (_supabase.isInitialized) return _supabase.client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Returns merged auto-inferred items for [authUserId] / [memberId].
  /// `isStaff` controls whether staff-only inferences (pending profile
  /// changes, pending event approvals, pending job approvals) appear.
  Future<List<AutoInferredAssignment>> fetch({
    required String authUserId,
    required String memberId,
    required bool isStaff,
  }) async {
    final client = _client;
    if (client == null) return const [];

    final key = '$authUserId|$memberId|$isStaff';
    final now = DateTime.now();
    if (_cacheKey == key &&
        _cacheStamp != null &&
        now.difference(_cacheStamp!) < _cacheTtl) {
      return _cache;
    }

    final results = <AutoInferredAssignment>[];

    Future<void> safe(Future<void> Function() task) async {
      try {
        await task();
      } catch (e) {
        debugPrint('[AutoInferredAssignmentsService] task failed: $e');
      }
    }

    // 1. Candidates assigned to me
    await safe(() async {
      final rows = await client
          .from('candidates')
          .select('id, full_name, updated_at')
          .eq('moyd_assigned_to', memberId);
      for (final r in (rows as List).whereType<Map>()) {
        results.add(AutoInferredAssignment(
          key: 'candidate:${r['id']}',
          source: 'candidate',
          title: 'Candidate: ${r['full_name'] ?? 'Unnamed'}',
          subtitle: 'Assigned to you',
          entityUrl: '/candidates/${r['id']}',
          at: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
        ));
      }
    });

    // 2. Pending profile-change reviews (staff only)
    if (isStaff) {
      await safe(() async {
        final rows = await client
            .from('member_profile_changes')
            .select('id, member_id, created_at, status')
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(20);
        for (final r in (rows as List).whereType<Map>()) {
          results.add(AutoInferredAssignment(
            key: 'profile_change:${r['id']}',
            source: 'profile_change',
            title: 'Profile change pending review',
            subtitle: 'Member ${r['member_id']}',
            entityUrl: '/members/${r['member_id']}?changes=pending',
            at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
          ));
        }
      });
    }

    // 3. Pending member-submitted events (staff only)
    if (isStaff) {
      await safe(() async {
        final rows = await client
            .from('member_submitted_events')
            .select('id, title, event_date, approval_status, created_at')
            .eq('approval_status', 'pending')
            .order('created_at', ascending: false)
            .limit(20);
        for (final r in (rows as List).whereType<Map>()) {
          results.add(AutoInferredAssignment(
            key: 'event_pending:${r['id']}',
            source: 'event_pending',
            title: 'Event submission: ${r['title'] ?? 'Untitled'}',
            subtitle: 'Awaiting approval',
            entityUrl: '/events?tab=pending&id=${r['id']}',
            at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
          ));
        }
      });
    }

    // 4. Bill notes that mention me
    await safe(() async {
      final rows = await client
          .from('legislation_bill_notes')
          .select('id, bill_id, body, created_at, mentioned_member_ids')
          .contains('mentioned_member_ids', [memberId])
          .order('created_at', ascending: false)
          .limit(20);
      for (final r in (rows as List).whereType<Map>()) {
        final body = (r['body'] as String?) ?? '';
        results.add(AutoInferredAssignment(
          key: 'bill_mention:${r['id']}',
          source: 'bill_mention',
          title: 'You were mentioned on a bill',
          subtitle: body.length > 80 ? '${body.substring(0, 80)}…' : body,
          entityUrl: '/bills/${r['bill_id']}?note=${r['id']}',
          at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
        ));
      }
    });

    // 5. Pending job approvals (staff only)
    if (isStaff) {
      await safe(() async {
        final rows = await client
            .from('jobs')
            .select('id, title, created_at, approved_by')
            .filter('approved_by', 'is', null)
            .order('created_at', ascending: false)
            .limit(20);
        for (final r in (rows as List).whereType<Map>()) {
          results.add(AutoInferredAssignment(
            key: 'job_pending:${r['id']}',
            source: 'job_pending',
            title: 'Job approval pending: ${r['title'] ?? 'Untitled'}',
            subtitle: 'Awaiting approval',
            entityUrl: '/jobs?tab=pending&id=${r['id']}',
            at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
          ));
        }
      });
    }

    // Sort newest first
    results.sort((a, b) {
      final ta = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    _cache = List.unmodifiable(results);
    _cacheStamp = now;
    _cacheKey = key;
    return _cache;
  }

  void invalidate() {
    _cacheStamp = null;
    _cacheKey = null;
    _cache = const [];
  }
}
