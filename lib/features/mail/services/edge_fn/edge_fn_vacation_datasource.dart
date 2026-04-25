// Edge-function-backed implementation of tmail's VacationDataSource.
//
// MOYD CRM Phase 6 vacation auto-responder. See:
//   supabase/migrations/20260425_08_mail_vacation_prefs.sql
//
// Why this is NOT wired to Gmail's vacation responder:
//   Gmail's `users.settings.vacation` is per-mailbox, but our shared
//   crm@moyoungdemocrats.org seat carries N exec aliases. Flipping the
//   seat-level vacation responder would auto-reply for *every* alias,
//   which is not what individual execs want. Instead we persist their
//   prefs here and a future mail-pubsub-receiver enhancement will fire
//   per-alias auto-responses via the mail-send edge function when an
//   incoming message arrives during the active period.
//
// Trust boundary: the mail_vacation_prefs RLS policy (mvp_self) keys on
// auth.uid() so a caller can only read/write their own row. We do NOT
// pass user_id from Dart — Postgres enforces it via auth.uid() in the
// policy USING/WITH CHECK clause. A caller cannot poke another exec's
// vacation responder by spoofing user_id in the upsert payload, because
// the policy's WITH CHECK would reject the write.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/utc_date.dart';
import 'package:jmap_dart_client/jmap/mail/vacation/vacation_id.dart';
import 'package:jmap_dart_client/jmap/mail/vacation/vacation_response.dart';

import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/data/datasource/vacation_data_source.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class EdgeFnVacationDataSource extends VacationDataSource {
  EdgeFnVacationDataSource({CRMSupabaseService? supabase})
      : _supabase = supabase ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  static const String _table = 'mail_vacation_prefs';

  /// JMAP convention: the vacation object id is the literal `singleton`.
  /// We don't actually round-trip it as a JMAP id (the row is keyed by
  /// user_id in Supabase) but we surface it on the response so tmail's
  /// view layer treats it as a valid existing object.
  static final VacationId _singletonId = VacationId.singleton();

  /// Build a disabled-default response when no row exists yet.
  VacationResponse _emptyResponse() {
    return VacationResponse(
      id: _singletonId,
      isEnabled: false,
      fromDate: null,
      toDate: null,
      subject: null,
      textBody: null,
      htmlBody: null,
    );
  }

  /// Map a Supabase row to a JMAP VacationResponse.
  /// Column → field mapping:
  ///   user_id     → (omitted; row identity is `singleton` per JMAP)
  ///   is_enabled  → isEnabled
  ///   from_date   → fromDate (date → midnight UTC)
  ///   to_date     → toDate   (date → midnight UTC)
  ///   subject     → subject
  ///   text_body   → textBody
  ///   html_body   → htmlBody
  ///   updated_at  → (not surfaced; tmail has no field for it)
  VacationResponse _rowToResponse(Map<String, dynamic> row) {
    return VacationResponse(
      id: _singletonId,
      isEnabled: (row['is_enabled'] as bool?) ?? false,
      fromDate: _parseDate(row['from_date']),
      toDate: _parseDate(row['to_date']),
      subject: row['subject'] as String?,
      textBody: row['text_body'] as String?,
      htmlBody: row['html_body'] as String?,
    );
  }

  /// Convert a Postgres `date` (string YYYY-MM-DD or null) into a
  /// JMAP UTCDate at midnight UTC. tmail's vacation_view treats these
  /// as date-only inputs, so the time-of-day is incidental.
  UTCDate? _parseDate(Object? raw) {
    if (raw == null) return null;
    final str = raw.toString();
    if (str.isEmpty) return null;
    try {
      // DateTime.parse on YYYY-MM-DD yields local-midnight; force UTC.
      final local = DateTime.parse(str);
      return UTCDate(DateTime.utc(local.year, local.month, local.day));
    } catch (e) {
      debugPrint('[EdgeFnVacationDataSource] Failed to parse date "$str": $e');
      return null;
    }
  }

  /// Convert a JMAP UTCDate (or null) to a Postgres `date` string.
  String? _formatDate(UTCDate? d) {
    if (d == null) return null;
    final v = d.value.toUtc();
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final day = v.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Future<List<VacationResponse>> getAllVacationResponse(
    AccountId accountId,
  ) async {
    if (!_supabase.isInitialized) {
      return [_emptyResponse()];
    }
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) {
      return [_emptyResponse()];
    }

    try {
      final row = await _supabase.client
          .from(_table)
          .select(
              'is_enabled, from_date, to_date, subject, text_body, html_body')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        // No prefs row yet → the user has never opened the vacation UI.
        // Surface a disabled default so the form renders cleanly.
        return [_emptyResponse()];
      }
      return [_rowToResponse(row)];
    } catch (e) {
      debugPrint('[EdgeFnVacationDataSource] getAllVacationResponse failed: $e');
      // Fail soft: don't block the manage-account screen on a transient
      // read error. The user will see "disabled" and can retry by
      // saving their prefs.
      return [_emptyResponse()];
    }
  }

  @override
  Future<List<VacationResponse>> updateVacation(
    AccountId accountId,
    VacationResponse vacationResponse,
  ) async {
    if (!_supabase.isInitialized) {
      throw StateError(
        'EdgeFnVacationDataSource: Supabase is not initialized; cannot save vacation prefs',
      );
    }
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'EdgeFnVacationDataSource: no authenticated user; cannot save vacation prefs',
      );
    }

    // Trust boundary note: we *do* pass user_id in the upsert payload
    // but the RLS policy's WITH CHECK rejects it unless it equals
    // auth.uid(). Even if a malicious client hand-crafted a different
    // user_id, Postgres would 403 the write.
    final payload = <String, dynamic>{
      'user_id': userId,
      'is_enabled': vacationResponse.isEnabled ?? false,
      'from_date': _formatDate(vacationResponse.fromDate),
      'to_date': _formatDate(vacationResponse.toDate),
      'subject': vacationResponse.subject,
      'text_body': vacationResponse.textBody,
      'html_body': vacationResponse.htmlBody,
    };

    final updated = await _supabase.client
        .from(_table)
        .upsert(payload, onConflict: 'user_id')
        .select(
            'is_enabled, from_date, to_date, subject, text_body, html_body')
        .single();

    return [_rowToResponse(updated)];
  }
}
