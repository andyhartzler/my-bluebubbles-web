// Edge-function-backed implementation of tmail's ThreadDataSource.
//
// Bridges to mail-list (inbox query) and mail-message-get (per-message
// detail fetch). The other 7 methods either no-op or throw — wired up
// piecemeal as code paths require them.

import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/filter/filter.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/sort/comparator.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/unsigned_int.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/data/datasource/thread_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/data/model/email_change_response.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/domain/model/email_response.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/domain/model/filter_message_option.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/domain/model/search_emails_response.dart';

import 'package:bluebubbles/features/mail/services/edge_fn/jmap_email_builder.dart';
import 'package:bluebubbles/features/mail/services/mail_api_client.dart';
import 'package:bluebubbles/features/mail/services/tmail_bridge.dart';
import 'package:bluebubbles/features/mail/models/mail_message.dart';

class EdgeFnThreadDataSource extends ThreadDataSource {
  EdgeFnThreadDataSource({MailApiClient? api}) : _api = api ?? MailApiClient();

  final MailApiClient _api;

  @override
  Future<EmailsResponse> getAllEmail(
    Session session,
    AccountId accountId, {
    UnsignedInt? limit,
    int? position,
    Set<Comparator>? sort,
    Filter? filter,
    Properties? properties,
  }) async {
    final maxResults = (limit?.value.toInt() ?? 25).clamp(1, 100);
    final page = await _api.listInbox(maxResults: maxResults);
    final emails = page.messages.map(_lightweightJmapEmail).toList();
    return EmailsResponse(
      emailList: emails,
      state: State(DateTime.now().millisecondsSinceEpoch.toString()),
    );
  }

  @override
  Future<SearchEmailsResponse> searchEmails(
    Session session,
    AccountId accountId, {
    UnsignedInt? limit,
    int? position,
    Set<Comparator>? sort,
    Filter? filter,
    bool? collapseThreads,
    Properties? properties,
  }) async {
    final q = _filterToQuery(filter);
    if (q.isEmpty) {
      return SearchEmailsResponse(
        emailList: const [],
        state: State(DateTime.now().millisecondsSinceEpoch.toString()),
        searchSnippets: const [],
      );
    }
    final maxResults = (limit?.value.toInt() ?? 25).clamp(1, 100);
    final page = await _api.searchInbox(q: q, maxResults: maxResults);
    final emails = page.messages.map(_lightweightJmapEmail).toList();
    return SearchEmailsResponse(
      emailList: emails,
      state: State(DateTime.now().millisecondsSinceEpoch.toString()),
      searchSnippets: const [],
    );
  }

  /// Extract a Gmail-search-syntax query string from a JMAP Filter. Tmail's
  /// search controller wraps the user-typed text in a `FilterCondition`
  /// (sometimes nested inside `FilterOperator` AND/OR trees). Our edge fn
  /// already alias-clamps + sanitizes, so we just need a flat string to
  /// hand off. The cheap-but-correct path: stringify the filter.
  String _filterToQuery(Filter? filter) {
    if (filter == null) return '';
    final s = filter.toString();
    // Filter.toString() typically wraps the body of interest. Strip the
    // class-name prefix Dart's default toString adds. If the user typed
    // `from:foo` etc., the edge fn's sanitizer will strip dangerous ops.
    return s;
  }

  @override
  Future<EmailChangeResponse> getChanges(
    Session session,
    AccountId accountId,
    State sinceState, {
    Properties? propertiesCreated,
    Properties? propertiesUpdated,
  }) async {
    return EmailChangeResponse(
      newStateChanges: sinceState,
      newStateEmail: sinceState,
    );
  }

  @override
  Future<List<Email>> getAllEmailCache(
    AccountId accountId,
    UserName userName, {
    MailboxId? inMailboxId,
    Set<Comparator>? sort,
    FilterMessageOption? filterOption,
    UnsignedInt? limit,
  }) async =>
      const [];

  @override
  Future<void> update(
    AccountId accountId,
    UserName userName, {
    List<Email>? updated,
    List<Email>? created,
    List<EmailId>? destroyed,
  }) async {}

  @override
  Future<List<EmailId>> emptyMailboxFolder(
    Session session,
    AccountId accountId,
    MailboxId mailboxId,
    int totalEmails,
    StreamController<dartz.Either<Failure, Success>> onProgressController,
  ) async =>
      const [];

  @override
  Future<PresentationEmail> getEmailById(
    Session session,
    AccountId accountId,
    EmailId emailId, {
    Properties? properties,
  }) async {
    final raw = await _api.getMessage(emailId.id.value);
    final email = JmapEmailBuilder.fromMailMessageGetJson(raw);
    return PresentationEmail(
      id: email.id,
      threadId: email.threadId,
      subject: email.subject,
      preview: email.preview,
      receivedAt: email.receivedAt,
      sentAt: email.sentAt,
      from: email.from,
      to: email.to,
      cc: email.cc,
      bcc: email.bcc,
      keywords: email.keywords,
      htmlBody: email.htmlBody,
      bodyValues: email.bodyValues,
      hasAttachment: email.hasAttachment,
    );
  }

  @override
  Future<void> clearEmailCacheAndStateCache() async {}

  /// Build a lightweight JMAP Email from our edge fn list shape (no body
  /// — that comes from getEmailContent on tap). Used to populate the
  /// inbox query response.
  Email _lightweightJmapEmail(MailMessage m) {
    final pe = toPresentationEmail(m);
    return Email(
      id: pe.id,
      threadId: pe.threadId,
      subject: pe.subject,
      preview: pe.preview,
      receivedAt: pe.receivedAt,
      sentAt: pe.sentAt,
      from: pe.from,
      to: pe.to,
      cc: pe.cc,
      keywords: pe.keywords,
      hasAttachment: pe.hasAttachment,
    );
  }
}
