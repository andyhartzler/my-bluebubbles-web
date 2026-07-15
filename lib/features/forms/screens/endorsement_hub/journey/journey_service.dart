import 'package:flutter/foundation.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

import '../../../models/form_submission.dart';
import 'journey_models.dart';

/// Reads the journey data captured by the public form: every submission row
/// for the endorsement form (all statuses), the form_drafts autosaves, and
/// the form_analytics / form_field_analytics event streams.
class JourneyService {
  final _client = CRMSupabaseService().client;

  /// The identity/prefill keys that don't count as "real answers".
  static const _identityKeys = {
    'name', 'full_name', 'first_name', 'last_name', 'preferred_name',
    'email', 'email_address', 'phone', 'phone_number',
    'zip_code', 'zipcode', 'postal_code',
  };

  static String _phone10(String? phone) {
    if (phone == null) return '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
  }

  static int _answeredCount(Map<String, dynamic> data, {String? prefix}) {
    var n = 0;
    data.forEach((k, v) {
      if (prefix != null && !k.startsWith(prefix)) return;
      if (prefix == null && _identityKeys.contains(k.toLowerCase())) return;
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      if (v is List && v.isEmpty) return;
      n++;
    });
    return n;
  }

  /// Every candidate journey for [formId], deduped to one entry per person
  /// (by phone; rows without a phone stand alone). The best row per person:
  /// truly finished first, then the one with the most answers.
  Future<List<JourneyEntry>> loadEntries(String formId, String slug) async {
    final rows = await _client
        .from('form_submissions')
        .select('''
          *,
          members:member_id (id, name, email, phone, phone_e164, profile_pictures),
          subscribers:subscriber_id (id, name, email, phone, phone_e164)
        ''')
        .eq('form_id', formId)
        .order('created_at', ascending: false);

    List<Map<String, dynamic>> drafts = const [];
    try {
      drafts = List<Map<String, dynamic>>.from(await _client
          .from('form_drafts')
          .select('phone_key, page, data, updated_at')
          .eq('form_slug', slug));
    } catch (e) {
      // Drafts are enrichment, not required; the tab still works without them.
      debugPrint('JourneyService: drafts unavailable: $e');
    }
    final draftByPhone = <String, Map<String, dynamic>>{};
    for (final d in drafts) {
      draftByPhone[_phone10(d['phone_key'] as String?)] = d;
    }

    // Group rows by person (phone) and keep the best row per person.
    final byKey = <String, List<FormSubmission>>{};
    for (final json in (rows as List)) {
      final s = FormSubmission.fromJson(json as Map<String, dynamic>);
      final key = _phone10(s.submitterPhone).isNotEmpty
          ? _phone10(s.submitterPhone)
          : s.id;
      byKey.putIfAbsent(key, () => []).add(s);
    }

    final now = DateTime.now();
    final entries = <JourneyEntry>[];
    byKey.forEach((key, group) {
      bool finished(FormSubmission s) {
        final d = s.data;
        return _present(d['certify']) && _present(d['signature']);
      }

      group.sort((a, b) {
        final fa = finished(a) ? 1 : 0;
        final fb = finished(b) ? 1 : 0;
        if (fa != fb) return fb - fa;
        final ca = _answeredCount(a.data);
        final cb = _answeredCount(b.data);
        if (ca != cb) return cb - ca;
        return b.createdAt.compareTo(a.createdAt);
      });
      final best = group.first;

      final draft = draftByPhone[_phone10(best.submitterPhone)];
      final draftData = (draft?['data'] as Map<String, dynamic>?) ?? const {};
      final merged = {...draftData, ...best.data};

      entries.add(JourneyEntry(
        submission: best,
        draftPage: draft?['page'] as int?,
        draftUpdatedAt: draft?['updated_at'] != null
            ? DateTime.tryParse(draft!['updated_at'] as String)
            : null,
        policyAnswers: _answeredCount(merged, prefix: 'pos_'),
        totalAnswers: _answeredCount(merged),
        trulyFinished: finished(best) ||
            (_present(merged['certify']) && _present(merged['signature'])),
      ));
    });

    entries.sort((a, b) {
      // LIVE first, then most-recent activity.
      final sa = a.statusAt(now) == JourneyStatus.liveNow ? 0 : 1;
      final sb = b.statusAt(now) == JourneyStatus.liveNow ? 0 : 1;
      if (sa != sb) return sa - sb;
      return b.lastActivity.compareTo(a.lastActivity);
    });
    return entries;
  }

  static bool _present(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is bool) return v;
    return true;
  }

  /// The chronological timeline for one candidate: analytics events plus
  /// grouped field-answer blocks and the thank-you email marker.
  Future<List<JourneyEvent>> loadTimeline(JourneyEntry entry) async {
    final s = entry.submission;
    final events = <JourneyEvent>[];

    List analytics = const [];
    try {
      analytics = await _client
          .from('form_analytics')
          .select('event_type, timestamp, referrer, user_agent, metadata')
          .eq('submission_id', s.id)
          .order('timestamp');
    } catch (e) {
      debugPrint('JourneyService: analytics unavailable: $e');
    }

    for (final row in analytics) {
      final m = row as Map<String, dynamic>;
      final t = DateTime.tryParse(m['timestamp'] as String? ?? '');
      if (t == null) continue;
      switch (m['event_type'] as String?) {
        case 'view':
          events.add(JourneyEvent(
            time: t,
            kind: JourneyEventKind.view,
            title: 'Opened the form',
            detail: _deviceDetail(m),
          ));
          break;
        case 'phone_entered':
          events.add(JourneyEvent(
            time: t,
            kind: JourneyEventKind.phoneEntered,
            title: 'Entered phone number',
          ));
          break;
        case 'identity_found':
          events.add(JourneyEvent(
            time: t,
            kind: JourneyEventKind.identityFound,
            title: 'Identity recognized',
            detail: (m['metadata'] as Map?)?['source']?.toString(),
          ));
          break;
        case 'abandon':
          events.add(JourneyEvent(
            time: t,
            kind: JourneyEventKind.abandoned,
            title: 'Session marked abandoned',
            detail: 'Usually the phone going to another app, not a real exit',
          ));
          break;
        case 'submit':
          events.add(JourneyEvent(
            time: t,
            kind: JourneyEventKind.submitted,
            title: 'Submitted the questionnaire',
          ));
          break;
      }
    }

    // Field-level saves, grouped into answer blocks split on >15 min gaps.
    List fields = const [];
    try {
      fields = await _client
          .from('form_field_analytics')
          .select('field_id, timestamp')
          .eq('submission_id', s.id)
          .order('timestamp');
    } catch (e) {
      debugPrint('JourneyService: field analytics unavailable: $e');
    }
    DateTime? blockStart;
    DateTime? blockEnd;
    var blockCount = 0;
    void flushBlock() {
      if (blockStart == null || blockCount == 0) return;
      events.add(JourneyEvent(
        time: blockStart!,
        endTime: blockEnd,
        kind: JourneyEventKind.fieldsAnswered,
        title: 'Answered $blockCount question${blockCount == 1 ? '' : 's'}',
      ));
      blockStart = null;
      blockEnd = null;
      blockCount = 0;
    }

    for (final row in fields) {
      final t = DateTime.tryParse(
          (row as Map<String, dynamic>)['timestamp'] as String? ?? '');
      if (t == null) continue;
      if (blockEnd != null &&
          t.difference(blockEnd!) > const Duration(minutes: 15)) {
        flushBlock();
      }
      blockStart ??= t;
      blockEnd = t;
      blockCount++;
    }
    flushBlock();

    if (s.thankyouSentAt != null) {
      events.add(JourneyEvent(
        time: s.thankyouSentAt!,
        kind: JourneyEventKind.thankYouSent,
        title: 'Thank-you email sent',
      ));
    }

    events.sort((a, b) => a.time.compareTo(b.time));

    // An answer block right after an abandon means they were still going or
    // came back: annotate the resume for the reviewer.
    final annotated = <JourneyEvent>[];
    for (var i = 0; i < events.length; i++) {
      annotated.add(events[i]);
      if (events[i].kind == JourneyEventKind.abandoned &&
          i + 1 < events.length &&
          events[i + 1].kind == JourneyEventKind.fieldsAnswered) {
        annotated.add(JourneyEvent(
          time: events[i + 1].time,
          kind: JourneyEventKind.resumed,
          title: 'Kept going',
        ));
      }
    }
    return annotated;
  }

  static String? _deviceDetail(Map<String, dynamic> m) {
    final ua = m['user_agent'] as String? ?? '';
    final ref = m['referrer'] as String? ?? '';
    String device = '';
    if (ua.contains('iPhone')) {
      device = 'iPhone';
    } else if (ua.contains('Android')) {
      device = 'Android';
    } else if (ua.contains('Windows')) {
      device = 'Windows';
    } else if (ua.contains('Macintosh')) {
      device = 'Mac';
    }
    final via = ref.isNotEmpty && !ref.contains('moyoungdemocrats.org')
        ? 'via $ref'
        : '';
    final parts = [device, via].where((x) => x.isNotEmpty).join(' ');
    return parts.isEmpty ? null : parts;
  }
}
