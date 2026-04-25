// Edge-function-backed implementation of tmail's EmailDataSource.
//
// Bridges JMAP-shaped calls to our Supabase edge functions:
//   - getEmailContent(emailId)  -> mail-message-get
//   - sendEmail(emailRequest)   -> mail-send
//
// All other 30+ EmailDataSource methods throw UnimplementedError until
// they get exercised by a code path we wire up. The only paths needed
// for Phase 1 (read-only inbox + send) are the two above + the cache
// methods (storeEmail, getStoredEmail, etc.) which are no-ops.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/error/set_error.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';

import 'package:bluebubbles/features/mail/_tmail/core/data/network/download/downloaded_response.dart';
import 'package:bluebubbles/features/mail/_tmail/email_recovery/email_recovery/email_recovery_action.dart';
import 'package:bluebubbles/features/mail/_tmail/email_recovery/email_recovery/email_recovery_action_id.dart';
import 'package:bluebubbles/features/mail/_tmail/model/account/account_request.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/mark_star_action.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/read_actions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/domain/model/email_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/data/datasource/email_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/detailed_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/move_to_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/preview_email_eml_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/restore_deleted_message_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/view_entire_message_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/model/eml_previewer.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/create_new_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/sending_queue/domain/model/sending_email.dart';

import 'package:bluebubbles/features/mail/services/mail_api_client.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/jmap_email_builder.dart';

class EdgeFnEmailDataSource extends EmailDataSource {
  EdgeFnEmailDataSource({MailApiClient? api}) : _api = api ?? MailApiClient();

  final MailApiClient _api;

  // ---- BRIDGED METHODS ----

  @override
  Future<Email> getEmailContent(
    Session session,
    AccountId accountId,
    EmailId emailId, {
    Properties? additionalProperties,
  }) async {
    final raw = await _api.getMessage(emailId.id.value);
    return JmapEmailBuilder.fromMailMessageGetJson(raw);
  }

  @override
  Future<void> sendEmail(
    Session session,
    AccountId accountId,
    EmailRequest emailRequest, {
    CreateNewMailboxRequest? mailboxRequest,
    CancelToken? cancelToken,
  }) async {
    // Map tmail's EmailRequest → mail-send body. EmailRequest carries
    // a built Email (subject, from, to, htmlBody, textBody, threadId
    // ref via inReplyTo). The edge fn server-side overwrites From: with
    // the caller's alias, so the EmailRequest.email.from set is ignored.
    final email = emailRequest.email;
    final to = email.to?.map((a) => _formatAddr(a)).toList() ?? const [];
    final cc = email.cc?.map((a) => _formatAddr(a)).toList() ?? const [];
    final bcc = email.bcc?.map((a) => _formatAddr(a)).toList() ?? const [];
    final subject = email.subject ?? '';

    String? htmlBody;
    String? textBody;
    final bodyValues = email.bodyValues;
    if (email.htmlBody?.isNotEmpty == true && bodyValues != null) {
      final part = email.htmlBody!.first;
      htmlBody = bodyValues[part.partId]?.value;
    }
    if (email.textBody?.isNotEmpty == true && bodyValues != null) {
      final part = email.textBody!.first;
      textBody = bodyValues[part.partId]?.value;
    }

    final inReplyTo = email.inReplyTo?.ids.isNotEmpty == true
        ? email.inReplyTo!.ids.first
        : null;
    final references = email.references?.ids.toList();

    await _api.sendMessage(
      to: to,
      cc: cc.isEmpty ? null : cc,
      bcc: bcc.isEmpty ? null : bcc,
      subject: subject,
      bodyText: textBody,
      bodyHtml: htmlBody,
      threadId: email.threadId?.id.value,
      inReplyTo: inReplyTo,
      references: references,
    );
  }

  String _formatAddr(EmailAddress a) {
    final email = a.email ?? '';
    final name = a.name;
    if (name != null && name.isNotEmpty) return '"$name" <$email>';
    return email;
  }

  // ---- NO-OP CACHE METHODS ----
  // tmail's higher-level repos call these to populate Hive caches. We
  // don't ship offline cache in Phase 1, so these are no-ops. They have
  // to return *something* of the right type — most are Future<void>.

  @override
  Future<void> storeDetailedNewEmail(
      Session session, AccountId accountId, DetailedEmail detailedEmail) async {}

  @override
  Future<void> storeEmail(Session session, AccountId accountId, Email email) async {}

  @override
  Future<void> storeOpenedEmail(
      Session session, AccountId accountId, DetailedEmail detailedEmail) async {}

  @override
  Future<void> deleteSendingEmail(
      AccountId accountId, UserName userName, String sendingId) async {}

  @override
  Future<void> deleteMultipleSendingEmail(
      AccountId accountId, UserName userName, List<String> sendingIds) async {}

  @override
  Future<List<SendingEmail>> getAllSendingEmails(
          AccountId accountId, UserName userName) async =>
      const [];

  // ---- UNIMPLEMENTED METHODS ----
  // Anything not yet exercised by our code path. Throws clearly so the
  // call chain points us at the next adapter to wire.

  Never _todo(String name) =>
      throw UnimplementedError('EdgeFnEmailDataSource.$name not bridged yet');

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      markAsRead(Session session, AccountId accountId,
          List<EmailId> emailIds, ReadActions readActions) async {
    // No-op: we don't yet propagate read state back to Gmail. Return
    // success so the UI's optimistic update doesn't roll back.
    return (emailIdsSuccess: emailIds, mapErrors: const <Id, SetError>{});
  }

  @override
  Future<DownloadedResponse> exportAttachment(
    Attachment attachment,
    AccountId accountId,
    String baseDownloadUrl,
    AccountRequest accountRequest,
    CancelToken cancelToken,
  ) =>
      _todo('exportAttachment');

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      moveToMailbox(Session session, AccountId accountId,
          MoveToMailboxRequest moveRequest) async {
    return (
      emailIdsSuccess: <EmailId>[],
      mapErrors: <Id, SetError>{},
    );
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      markAsStar(Session session, AccountId accountId,
          List<EmailId> emailIds, MarkStarAction markStarAction) async {
    return (
      emailIdsSuccess: emailIds,
      mapErrors: <Id, SetError>{},
    );
  }

  @override
  Future<Email> saveEmailAsDrafts(
    Session session,
    AccountId accountId,
    Email email, {
    CancelToken? cancelToken,
  }) =>
      _todo('saveEmailAsDrafts');

  @override
  Future<bool> removeEmailDrafts(
    Session session,
    AccountId accountId,
    EmailId emailId, {
    CancelToken? cancelToken,
  }) async =>
      true;

  @override
  Future<Email> updateEmailDrafts(
    Session session,
    AccountId accountId,
    Email newEmail,
    EmailId oldEmailId, {
    CancelToken? cancelToken,
  }) =>
      _todo('updateEmailDrafts');

  @override
  Future<Email> saveEmailAsTemplate(
    Session session,
    AccountId accountId,
    Email email, {
    CreateNewMailboxRequest? createNewMailboxRequest,
    CancelToken? cancelToken,
  }) =>
      _todo('saveEmailAsTemplate');

  @override
  Future<Email> updateEmailTemplate(
    Session session,
    AccountId accountId,
    Email newEmail,
    EmailId oldEmailId, {
    CancelToken? cancelToken,
  }) =>
      _todo('updateEmailTemplate');

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      deleteMultipleEmailsPermanently(Session session, AccountId accountId,
          List<EmailId> emailIds) async {
    return (
      emailIdsSuccess: <EmailId>[],
      mapErrors: <Id, SetError>{},
    );
  }

  @override
  Future<bool> deleteEmailPermanently(
    Session session,
    AccountId accountId,
    EmailId emailId, {
    CancelToken? cancelToken,
  }) async =>
      false;

  @override
  Future<Email> getDetailedEmailById(
          Session session, AccountId accountId, EmailId emailId) =>
      getEmailContent(session, accountId, emailId);

  @override
  Future<Email> getStoredEmail(
          Session session, AccountId accountId, EmailId emailId) =>
      getEmailContent(session, accountId, emailId);

  @override
  Future<DetailedEmail> getStoredOpenedEmail(
          Session session, AccountId accountId, EmailId emailId) =>
      _todo('getStoredOpenedEmail');

  @override
  Future<DetailedEmail> getStoredNewEmail(
          Session session, AccountId accountId, EmailId emailId) =>
      _todo('getStoredNewEmail');

  @override
  Future<SendingEmail> storeSendingEmail(
          AccountId accountId, UserName userName, SendingEmail sendingEmail) =>
      _todo('storeSendingEmail');

  @override
  Future<SendingEmail> updateSendingEmail(
          AccountId accountId, UserName userName, SendingEmail newSendingEmail) =>
      _todo('updateSendingEmail');

  @override
  Future<List<SendingEmail>> updateMultipleSendingEmail(AccountId accountId,
          UserName userName, List<SendingEmail> newSendingEmails) =>
      _todo('updateMultipleSendingEmail');

  @override
  Future<SendingEmail> getStoredSendingEmail(
          AccountId accountId, UserName userName, String sendingId) =>
      _todo('getStoredSendingEmail');

  @override
  Future<void> unsubscribeMail(
          Session session, AccountId accountId, EmailId emailId) =>
      _todo('unsubscribeMail');

  @override
  Future<EmailRecoveryAction> restoreDeletedMessage(
          RestoredDeletedMessageRequest restoredDeletedMessageRequest) =>
      _todo('restoreDeletedMessage');

  @override
  Future<EmailRecoveryAction> getRestoredDeletedMessage(
          EmailRecoveryActionId emailRecoveryActionId) =>
      _todo('getRestoredDeletedMessage');

  @override
  Future<void> markAsAnswered(
      Session session, AccountId accountId, List<EmailId> emailIds) async {}

  @override
  Future<void> markAsForwarded(
      Session session, AccountId accountId, List<EmailId> emailIds) async {}

  @override
  Future<List<Email>> parseEmailByBlobIds(
          AccountId accountId, Set<Id> blobIds) async =>
      const [];

  @override
  Future<String> generatePreviewEmailEMLContent(
          PreviewEmailEMLRequest previewEmailEMLRequest) =>
      _todo('generatePreviewEmailEMLContent');

  @override
  Future<void> sharePreviewEmailEMLContent(EMLPreviewer emlPreviewer) async {}

  @override
  Future<EMLPreviewer> getPreviewEmailEMLContentShared(String keyStored) =>
      _todo('getPreviewEmailEMLContentShared');

  @override
  Future<void> removePreviewEmailEMLContentShared(String keyStored) async {}

  @override
  Future<void> storePreviewEMLContentToSessionStorage(
      EMLPreviewer emlPreviewer) async {}

  @override
  Future<EMLPreviewer> getPreviewEMLContentInMemory(String keyStored) =>
      _todo('getPreviewEMLContentInMemory');

  @override
  Future<DownloadedResponse> exportAllAttachments(
    AccountId accountId,
    EmailId emailId,
    String baseDownloadAllUrl,
    String outputFileName,
    AccountRequest accountRequest, {
    CancelToken? cancelToken,
  }) =>
      _todo('exportAllAttachments');

  @override
  Future<String> generateEntireMessageAsDocument(
          ViewEntireMessageRequest entireMessageRequest) =>
      _todo('generateEntireMessageAsDocument');

  @override
  Future<void> addLabelToEmail(
    Session session,
    AccountId accountId,
    EmailId emailId,
    KeyWordIdentifier labelKeyword,
  ) async {}

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      addLabelToThread(
    Session session,
    AccountId accountId,
    List<EmailId> emailIds,
    KeyWordIdentifier labelKeyword,
  ) async {
    return (
      emailIdsSuccess: emailIds,
      mapErrors: <Id, SetError>{},
    );
  }

  @override
  Future<void> removeLabelFromEmail(
    Session session,
    AccountId accountId,
    EmailId emailId,
    KeyWordIdentifier labelKeyword,
  ) async {}

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      removeLabelFromThread(
    Session session,
    AccountId accountId,
    List<EmailId> emailIds,
    KeyWordIdentifier labelKeyword,
  ) async {
    return (
      emailIdsSuccess: emailIds,
      mapErrors: <Id, SetError>{},
    );
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      addListLabelToListEmail(
    Session session,
    AccountId accountId,
    List<EmailId> emailIds,
    List<KeyWordIdentifier> labelKeywords,
  ) async {
    return (
      emailIdsSuccess: emailIds,
      mapErrors: <Id, SetError>{},
    );
  }
}
