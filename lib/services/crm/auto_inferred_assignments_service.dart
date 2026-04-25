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

  /// Resolves a `profile_pictures` jsonb (or `avatar_url`) into a fully
  /// qualified public URL. Handles three shapes:
  ///   1. Already a `https://...` or `http://...` URL → return as-is.
  ///   2. A bare filename (legacy schema, e.g. `<uuid>-instagram.jpeg`)
  ///      → resolve through `member-photos` storage bucket public URL.
  ///   3. A `profile_pictures` value can also be a list of
  ///      `{path, bucket, primary, ...}` objects (post-Nov-2025 schema)
  ///      — use the `primary: true` entry's path against its bucket.
  ///   4. Or a flat map `{instagram: '...', twitter: '...'}` (legacy).
  /// Returns null if nothing usable found.
  String? _resolveAvatarUrl(SupabaseClient client, Map<String, dynamic>? mem) {
    if (mem == null) return null;

    String? toPublicUrl(String value, {String defaultBucket = 'member-photos'}) {
      final v = value.trim();
      if (v.isEmpty) return null;
      if (v.startsWith('http://') || v.startsWith('https://')) return v;
      try {
        return client.storage.from(defaultBucket).getPublicUrl(v);
      } catch (_) {
        return null;
      }
    }

    // 1. avatar_url (user-uploaded headshot)
    final ax = (mem['avatar_url'] as String?)?.trim();
    if (ax != null && ax.isNotEmpty) {
      final resolved = toPublicUrl(ax);
      if (resolved != null) return resolved;
    }

    final pics = mem['profile_pictures'];

    // 3. Array form: [{path, bucket, primary, ...}, ...]
    if (pics is List) {
      Map<String, dynamic>? primary;
      for (final entry in pics) {
        if (entry is! Map) continue;
        final asMap = Map<String, dynamic>.from(entry);
        if (asMap['primary'] == true) {
          primary = asMap;
          break;
        }
        primary ??= asMap;
      }
      if (primary != null) {
        final path = (primary['path'] as String?) ?? (primary['url'] as String?);
        final bucket = (primary['bucket'] as String?) ?? 'member-photos';
        if (path != null && path.isNotEmpty) {
          if (path.startsWith('http://') || path.startsWith('https://')) {
            return path;
          }
          try {
            return client.storage.from(bucket).getPublicUrl(path);
          } catch (_) {
            // fall through
          }
        }
      }
    }

    // 4. Flat map form: {instagram: '...', twitter: '...'}
    if (pics is Map) {
      final asMap = Map<String, dynamic>.from(pics);
      for (final key in const ['instagram', 'twitter', 'linkedin', 'facebook']) {
        final v = asMap[key];
        if (v is String && v.trim().isNotEmpty) {
          return toPublicUrl(v);
        }
      }
    }

    return null;
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
        final id = r['id']?.toString() ?? '';
        results.add(AutoInferredAssignment(
          key: 'candidate:$id',
          source: 'candidate',
          title: 'Candidate: ${r['full_name'] ?? 'Unnamed'}',
          subtitle: 'Assigned to you',
          entityUrl: '/candidates/$id',
          at: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
          entityKind: 'candidate',
          entityId: id,
        ));
      }
    });

    // 2. Pending profile-change reviews (staff only)
    if (isStaff) {
      await safe(() async {
        final rows = await client
            .from('member_profile_changes')
            .select(
                'id, member_id, created_at, status, members:member_id(id, name, avatar_url, profile_pictures)')
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(20);
        for (final r in (rows as List).whereType<Map>()) {
          final memberJoin = r['members'];
          Map<String, dynamic>? mem;
          if (memberJoin is Map) {
            mem = Map<String, dynamic>.from(memberJoin);
          } else if (memberJoin is List && memberJoin.isNotEmpty && memberJoin.first is Map) {
            mem = Map<String, dynamic>.from(memberJoin.first as Map);
          }
          final name = (mem?['name'] as String?)?.trim();
          final resolvedAvatar = _resolveAvatarUrl(client, mem);
          final memberRowId = r['member_id']?.toString() ?? '';
          results.add(AutoInferredAssignment(
            key: 'profile_change:${r['id']}',
            source: 'profile_change',
            title: 'Profile change pending review',
            subtitle: (name != null && name.isNotEmpty) ? name : 'Member $memberRowId',
            entityUrl: '/members/$memberRowId?changes=pending',
            at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
            memberName: (name != null && name.isNotEmpty) ? name : null,
            memberAvatarUrl: resolvedAvatar,
            entityKind: 'member',
            entityId: memberRowId,
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
          final id = r['id']?.toString() ?? '';
          results.add(AutoInferredAssignment(
            key: 'event_pending:$id',
            source: 'event_pending',
            title: 'Event submission: ${r['title'] ?? 'Untitled'}',
            subtitle: 'Awaiting approval',
            entityUrl: '/events?tab=pending&id=$id',
            at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
            entityKind: 'event',
            entityId: id,
          ));
        }
      });
    }

    // 4. Bill notes that mention me
    await safe(() async {
      final rows = await client
          .from('legislation_bill_notes')
          .select('id, bill_id, committee_id, body, created_at, mentioned_member_ids')
          .contains('mentioned_member_ids', [memberId])
          .order('created_at', ascending: false)
          .limit(20);
      for (final r in (rows as List).whereType<Map>()) {
        final body = (r['body'] as String?) ?? '';
        final billId = r['bill_id']?.toString() ?? '';
        final committeeId = r['committee_id']?.toString();
        results.add(AutoInferredAssignment(
          key: 'bill_mention:${r['id']}',
          source: 'bill_mention',
          title: 'You were mentioned on a bill',
          subtitle: body.length > 80 ? '${body.substring(0, 80)}…' : body,
          entityUrl: '/bills/$billId?note=${r['id']}',
          at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
          entityKind: 'bill',
          entityId: billId,
          committeeId: committeeId,
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
          final id = r['id']?.toString() ?? '';
          results.add(AutoInferredAssignment(
            key: 'job_pending:$id',
            source: 'job_pending',
            title: 'Job approval pending: ${r['title'] ?? 'Untitled'}',
            subtitle: 'Awaiting approval',
            entityUrl: '/jobs?tab=pending&id=$id',
            at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
            entityKind: 'job',
            entityId: id,
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
