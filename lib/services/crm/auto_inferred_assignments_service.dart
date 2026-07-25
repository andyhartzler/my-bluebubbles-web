import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:bluebubbles/models/crm/assignment.dart';
import 'supabase_service.dart';

// ---- Endorsement ballot deadline rule --------------------------------------
// "Ballots close Sunday at midnight, US Central." Kept in ONE named constant
// plus two small helpers so a later pass (an actual alert/notification job)
// can lift the rule wholesale. America/Chicago is DST-aware through the
// `timezone` package, so no UTC offset is hardcoded anywhere.
const String kEndorsementVoteDeadlineZone = 'America/Chicago';

/// Resolve the Central [tz.Location]. main.dart runs tz.initializeTimeZones()
/// on EVERY platform (web included) before runApp, so the catch branch only
/// fires when this service is exercised outside the normal boot path (tests,
/// tooling). latest.dart carries full DST rules for America/Chicago, so no
/// fixed-offset fallback is ever needed.
tz.Location endorsementDeadlineLocation() {
  try {
    return tz.getLocation(kEndorsementVoteDeadlineZone);
  } on tz.LocationNotFoundException {
    tzdata.initializeTimeZones();
    return tz.getLocation(kEndorsementVoteDeadlineZone);
  }
}

/// The instant voting closes: midnight at the END of the next upcoming
/// Sunday, which is Monday 00:00 local. Expressed as the real boundary rather
/// than 11:59 PM so the promised cutoff and the stored [dueAt] a later alert
/// pass will alarm on are the same instant, with no silent one-minute buffer.
///
/// On a Sunday the deadline is TONIGHT and stays tonight right up to
/// midnight, then rolls to next week: past the boundary the weekday is Monday
/// and the next Sunday is six days out.
tz.TZDateTime nextEndorsementVoteDeadline(tz.TZDateTime centralNow) {
  final daysUntilSunday = (DateTime.sunday - centralNow.weekday) % 7;
  // TZDateTime normalizes the day overflow AND resolves the resulting wall
  // clock against DST, so this stays correct across spring-forward/fall-back
  // weeks where naive `now + Duration(days: n)` math drifts an hour.
  return tz.TZDateTime(centralNow.location, centralNow.year, centralNow.month,
      centralNow.day + daysUntilSunday + 1);
}

/// Plain-language deadline for the panel subtitle: "Due Sunday at midnight
/// Central", sharpening to tomorrow/tonight as it approaches and flipping to
/// "closed" once passed.
String endorsementDeadlinePhrase(tz.TZDateTime deadline, tz.TZDateTime now) {
  if (!now.isBefore(deadline)) {
    return 'Voting closed Sunday at midnight Central';
  }
  final today = tz.TZDateTime(now.location, now.year, now.month, now.day);
  // The deadline INSTANT lands on Monday 00:00; the day people vote on is the
  // Sunday it closes, so step back one day for the plain-language phrasing.
  final dueDay = tz.TZDateTime(
      now.location, deadline.year, deadline.month, deadline.day - 1);
  // Round rather than truncate: a spring-forward week makes the
  // midnight-to-midnight span 23 hours, which would otherwise floor to 0.
  final days = (dueDay.difference(today).inHours / 24).round();
  if (days <= 0) return 'Due tonight at midnight Central';
  if (days == 1) return 'Due tomorrow at midnight Central';
  return 'Due Sunday at midnight Central';
}

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

  /// Canonical endorsement questionnaire form. Keep in sync with
  /// `SlateController.endorsementFormId` / `endorsementSlug`
  /// (lib/features/forms/screens/endorsement_hub/slate_controller.dart, the
  /// source of truth); restated here so the home dashboard does not import
  /// the hub's controller stack.
  static const String _endorsementFormId =
      '945738f0-ff66-420f-8707-afb4a23ca58b';
  static const String _endorsementSlug = 'endorsement-questionnaire-2026';
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
  /// changes, pending event approvals, pending job approvals, the open
  /// endorsement ballot) appear. The endorsement ballot additionally gates
  /// on members.executive_committee because only execs can cast ballots.
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
          .select('id, name, updated_at')
          .eq('moyd_assigned_to', memberId);
      for (final r in (rows as List).whereType<Map>()) {
        final id = r['id']?.toString() ?? '';
        results.add(AutoInferredAssignment(
          key: 'candidate:$id',
          source: 'candidate',
          title: 'Candidate: ${r['name'] ?? 'Unnamed'}',
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
      // Live schema check 2026-07: legislation_bill_notes has `content`
      // (see LegislationService.addNote) — the previous select referenced
      // `committee_id` and `body`, neither of which exist, so this query
      // threw a PostgrestException on every load (FLUTTER-3).
      final rows = await client
          .from('legislation_bill_notes')
          .select('id, bill_id, content, created_at, mentioned_member_ids')
          .contains('mentioned_member_ids', [memberId])
          .order('created_at', ascending: false)
          .limit(20);
      for (final r in (rows as List).whereType<Map>()) {
        final body = (r['content'] as String?) ?? '';
        final billId = r['bill_id']?.toString() ?? '';
        results.add(AutoInferredAssignment(
          key: 'bill_mention:${r['id']}',
          source: 'bill_mention',
          title: 'You were mentioned on a bill',
          subtitle: body.length > 80 ? '${body.substring(0, 80)}…' : body,
          entityUrl: '/bills/$billId?note=${r['id']}',
          at: DateTime.tryParse(r['created_at']?.toString() ?? ''),
          entityKind: 'bill',
          entityId: billId,
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

    // 6. Endorsement ballot awaiting my vote (executive committee only).
    //
    // Reproduces the Endorsement HQ roster board's "needs my vote" count
    // (widgets/roster/roster_board.dart): the denominator is completed
    // questionnaire submissions, deduped exactly the way
    // FormsService.getSubmissions dedupes them, MINUS candidates decided in
    // endorsement_decisions; the numerator is how many of those have no
    // endorsement_votes row for the signed-in exec. Table and column names
    // verified against SupabaseDecisionRepository and
    // EndorsementVoteRepository under
    // lib/features/forms/screens/endorsement_hub/widgets/decisions/ (the
    // source of truth; never edited from here). Runs inside safe() so any
    // query failure degrades to "no item" rather than breaking the panel.
    if (isStaff) {
      await safe(() async {
        // Gate on the same signal the vote roster is seeded from
        // (EndorsementVoteRepository._seedExecRoster):
        // members.executive_committee. isStaff also admits non-exec committee
        // members, who cannot cast ballots, so the broader flag alone would
        // show them a to-do they cannot act on.
        final memberRow = await client
            .from('members')
            .select('executive_committee')
            .eq('id', memberId)
            .maybeSingle();
        if (memberRow == null || memberRow['executive_committee'] != true) {
          return;
        }

        // Completed questionnaire submissions for the endorsement form. The
        // status filter mirrors FormsService.getSubmissions: in_progress and
        // abandoned autosave drafts must never inflate the ballot.
        Future<List<Map<String, dynamic>>> submissionsFor(String formId) async {
          final rows = await client
              .from('form_submissions')
              .select('id, candidate_id, submitter_phone, data')
              .eq('form_id', formId)
              .inFilter('status', const [
                'submitted',
                'reviewed',
                'processed',
                'complete',
                'completed',
              ])
              .order('created_at', ascending: false);
          return (rows as List)
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList();
        }

        var submissions = await submissionsFor(_endorsementFormId);
        if (submissions.isEmpty) {
          // Slug fallback, same as SlateController.load(): the canonical id
          // constant can go stale if the form is ever recreated.
          final form = await client
              .from('form_schemas')
              .select('id')
              .eq('slug', _endorsementSlug)
              .maybeSingle();
          final fallbackId = form?['id']?.toString();
          if (fallbackId != null &&
              fallbackId.isNotEmpty &&
              fallbackId != _endorsementFormId) {
            submissions = await submissionsFor(fallbackId);
          }
        }
        if (submissions.isEmpty) return;

        // Dedup mirror of FormsService.getSubmissions: one person's duplicate
        // completed rows collapse to the MOST COMPLETE one (key on
        // candidate_id, then submitter_phone, then the row's own id), so this
        // count matches what the board actually lists. A raw SQL count would
        // over-count.
        int completeness(Map<String, dynamic> row) {
          final data = row['data'];
          if (data is! Map) return 0;
          return data.entries.where((e) {
            final v = e.value;
            if (v == null) return false;
            if (v is String) return v.trim().isNotEmpty;
            if (v is Iterable) return v.isNotEmpty;
            return true;
          }).length;
        }

        final best = <String, Map<String, dynamic>>{};
        for (final s in submissions) {
          final dedupKey =
              (s['candidate_id'] ?? s['submitter_phone'] ?? s['id']).toString();
          final existing = best[dedupKey];
          // Rows arrive newest-first, so on a completeness tie the newer row
          // wins; only a strictly-more-complete older row replaces it.
          if (existing == null || completeness(s) > completeness(existing)) {
            best[dedupKey] = s;
          }
        }
        final candidateIds =
            best.values.map((s) => s['id'].toString()).toSet();

        // Decided candidates leave the ballot. Partition by decision STATE,
        // not row existence (an 'undecided' row is still on the ballot),
        // mirroring widgets/roster/roster_board.dart. Deliberately NOT
        // wrapped in its own
        // try: if the decisions read fails, the throw aborts this whole
        // block via safe() and no item shows, because treating a failed read
        // as "nothing decided" would put every settled candidate back on the
        // ballot (the decision board guards against the same failure mode
        // with DecisionLoadState).
        final decisionRows = await client
            .from('endorsement_decisions')
            .select('candidate_id, state');
        for (final r in (decisionRows as List).whereType<Map>()) {
          final state = r['state']?.toString().trim().toLowerCase();
          if (state == 'endorse' || state == 'decline') {
            candidateIds.remove(r['candidate_id']?.toString());
          }
        }
        if (candidateIds.isEmpty) return;

        // My ballots: endorsement_votes keys voter_id on the auth uid, NOT
        // the members row id (EndorsementVoteRepository.load), and
        // candidate_id is the form_submissions.id uuid.
        final voteRows = await client
            .from('endorsement_votes')
            .select('candidate_id')
            .eq('voter_id', authUserId);
        final voted = <String>{
          for (final r in (voteRows as List).whereType<Map>())
            if (r['candidate_id'] != null) r['candidate_id'].toString(),
        };
        final awaiting =
            candidateIds.where((id) => !voted.contains(id)).length;
        // All caught up: the item disappears rather than read "0 of N".
        if (awaiting == 0) return;

        final central = endorsementDeadlineLocation();
        final centralNow = tz.TZDateTime.from(now.toUtc(), central);
        final deadline = nextEndorsementVoteDeadline(centralNow);
        final urgent =
            !centralNow.isBefore(deadline.subtract(const Duration(hours: 48)));

        results.add(AutoInferredAssignment(
          key: 'endorsement_vote:ballot',
          source: 'endorsement_vote',
          title: 'Vote on candidates',
          subtitle: '$awaiting of ${candidateIds.length} awaiting your vote'
              ' · ${endorsementDeadlinePhrase(deadline, centralNow)}',
          entityUrl: '/candidates?area=endorsement-hq',
          // Sort stamp, not a data timestamp: an open ballot is the most
          // actionable item on the board, so pin it to "now" and let the
          // newest-first sort keep it at the top.
          at: now,
          dueAt: deadline.toUtc(),
          priority: urgent ? 'urgent' : null,
          // No entityKind/entityId: the hub is opened by a source
          // special-case in the panel. There are no named routes, and the
          // Candidates page's Field/Endorsement HQ switcher is private local
          // state, so the panel pushes EndorsementHubScreen directly.
        ));
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
