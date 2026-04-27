// Edge-function-backed implementation of tmail's ThreadDataSource.
//
// Bridges to mail-list (inbox query) and mail-message-get (per-message
// detail fetch). The other 7 methods either no-op or throw — wired up
// piecemeal as code paths require them.

import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/filter/filter.dart';
import 'package:jmap_dart_client/jmap/core/filter/filter_operator.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/sort/comparator.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/unsigned_int.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_filter_condition.dart';
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
    // Convert tmail's filter (inMailbox, before, search terms) into a Gmail
    // query string. Without this, every folder + pagination cursor was
    // ignored — Inbox/Sent/Drafts/Trash all rendered the same INBOX list.
    final q = _filterToQuery(filter).trim();
    final page = await _api.listInbox(
      maxResults: maxResults,
      q: q.isNotEmpty ? q : null,
    );
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
    final q = _filterToQuery(filter).trim();
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

  /// Converts a tmail JMAP [Filter] tree into a Gmail-style search query
  /// string for the `mail-search` edge function. Tmail's search controller
  /// builds either a single [EmailFilterCondition] or a [LogicFilterOperator]
  /// (AND/OR/NOT) wrapping nested conditions — see
  /// `search_email_filter.dart#mappingToEmailFilterCondition`. We walk the
  /// tree, emit Gmail operators (from:, to:, cc:, bcc:, subject:, has:, is:),
  /// and concatenate. The plain `text` and `body` fields fall through as
  /// bare tokens so Gmail's full-text matcher handles them.
  String _filterToQuery(Filter? filter) {
    if (filter == null) return '';
    if (filter is EmailFilterCondition) {
      return _conditionToTokens(filter).join(' ');
    }
    if (filter is FilterOperator) {
      return _operatorToQuery(filter);
    }
    return '';
  }

  String _operatorToQuery(FilterOperator op) {
    final parts = op.conditions
        .map((c) {
          if (c is EmailFilterCondition) {
            return _conditionToTokens(c).join(' ').trim();
          }
          if (c is FilterOperator) {
            return _operatorToQuery(c);
          }
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    switch (op.operator) {
      case Operator.AND:
        return parts.length == 1 ? parts.first : parts.join(' ');
      case Operator.OR:
        return parts.length == 1
            ? parts.first
            : '(${parts.join(' OR ')})';
      case Operator.NOT:
        return parts.map((p) => '-($p)').join(' ');
    }
  }

  /// Maps each populated field on an [EmailFilterCondition] to a Gmail
  /// search operator. Fields tmail uses but Gmail can't express (JMAP
  /// keyword IDs other than $seen) are dropped.
  ///
  /// Mailbox filtering: tmail passes the synthetic mailbox id
  /// (inbox/sent/drafts/trash/spam) as `inMailbox`. We map to Gmail's
  /// `in:` operator. Without this every folder showed the same INBOX list.
  ///
  /// Pagination cursor: tmail's load-more sends `before: lastEmail.receivedAt`
  /// (a UTCDate) on subsequent fetches. Gmail accepts `before:YYYY/MM/DD`
  /// (or unix epoch). We emit the latter for sub-day precision.
  List<String> _conditionToTokens(EmailFilterCondition c) {
    final tokens = <String>[];

    // Folder. The synthetic mailbox id is one of our 5 well-known values
    // (see EdgeFnMailboxDataSource._syntheticMailboxes). Map to Gmail `in:`.
    final mbId = c.inMailbox?.id.value;
    if (mbId != null) {
      switch (mbId) {
        case 'inbox':
          tokens.add('in:inbox');
          break;
        case 'sent':
          tokens.add('in:sent');
          break;
        case 'drafts':
          tokens.add('in:drafts');
          break;
        case 'trash':
          tokens.add('in:trash');
          break;
        case 'spam':
          tokens.add('in:spam');
          break;
      }
    }

    // Pagination cursor. tmail emits `before` as receivedAt of the last
    // email rendered. Gmail accepts unix-seconds for sub-day precision.
    final before = c.before?.value;
    if (before != null) {
      final epochSecs = before.millisecondsSinceEpoch ~/ 1000;
      tokens.add('before:$epochSecs');
    }

    final text = c.text?.trim();
    if (text != null && text.isNotEmpty) tokens.add(text);
    final body = c.body?.trim();
    if (body != null && body.isNotEmpty) tokens.add(body);
    final subject = c.subject?.trim();
    if (subject != null && subject.isNotEmpty) {
      tokens.add('subject:${_quoteIfNeeded(subject)}');
    }
    final from = c.from?.trim();
    if (from != null && from.isNotEmpty) {
      tokens.add('from:${_quoteIfNeeded(from)}');
    }
    final to = c.to?.trim();
    if (to != null && to.isNotEmpty) {
      tokens.add('to:${_quoteIfNeeded(to)}');
    }
    final cc = c.cc?.trim();
    if (cc != null && cc.isNotEmpty) {
      tokens.add('cc:${_quoteIfNeeded(cc)}');
    }
    final bcc = c.bcc?.trim();
    if (bcc != null && bcc.isNotEmpty) {
      tokens.add('bcc:${_quoteIfNeeded(bcc)}');
    }
    if (c.hasAttachment == true) tokens.add('has:attachment');
    // tmail encodes "unread" via notKeyword: $seen — translate to is:unread.
    if (c.notKeyword == r'$seen') tokens.add('is:unread');
    if (c.hasKeyword == r'$flagged') tokens.add('is:starred');
    return tokens;
  }

  String _quoteIfNeeded(String value) {
    if (value.contains(' ') || value.contains(':')) {
      // Escape any embedded quotes, then wrap.
      final escaped = value.replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return value;
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
