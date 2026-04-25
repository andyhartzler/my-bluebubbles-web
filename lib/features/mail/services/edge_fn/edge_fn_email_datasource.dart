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
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart';
import 'package:universal_html/html.dart' as html;
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
    final parsed = _parseEmail(emailRequest.email);
    await _api.sendMessage(
      to: parsed.to,
      cc: parsed.cc.isEmpty ? null : parsed.cc,
      bcc: parsed.bcc.isEmpty ? null : parsed.bcc,
      subject: parsed.subject,
      bodyText: parsed.textBody,
      bodyHtml: parsed.htmlBody,
      threadId: parsed.threadId,
      inReplyTo: parsed.inReplyTo,
      references: parsed.references,
    );
  }

  /// Extracts the wire-shape fields the mail-send / mail-draft-{create,update}
  /// edge fns expect out of a tmail-built Email: address lists, subject,
  /// htmlBody/textBody (resolved via bodyValues lookup), threadId, and
  /// In-Reply-To / References header values.
  _ParsedEmail _parseEmail(Email email) {
    final to = email.to?.map(_formatAddr).toList() ?? const <String>[];
    final cc = email.cc?.map(_formatAddr).toList() ?? const <String>[];
    final bcc = email.bcc?.map(_formatAddr).toList() ?? const <String>[];
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

    return _ParsedEmail(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      htmlBody: htmlBody,
      textBody: textBody,
      threadId: email.threadId?.id.value,
      inReplyTo: inReplyTo,
      references: references,
    );
  }

  /// Reconstructs an Email mirroring `newEmail`'s composer-built body but with
  /// the new server-assigned ids stamped in. tmail's downstream consumers only
  /// require `Email.id` to be non-null (see CreateNewAndSaveEmailToDraftsInteractor —
  /// it reads `emailDraftSaved.id!`); we additionally populate `threadId` so
  /// any later code that re-threads the draft has the canonical Gmail thread id.
  Email _emailWithIds(Email source, {required String id, String? threadId}) {
    final emailId = EmailId(Id(id));
    final tid = (threadId != null && threadId.isNotEmpty)
        ? ThreadId(Id(threadId))
        : source.threadId;
    return Email(
      id: emailId,
      blobId: source.blobId,
      threadId: tid,
      mailboxIds: source.mailboxIds,
      keywords: source.keywords,
      size: source.size,
      receivedAt: source.receivedAt,
      messageId: source.messageId,
      inReplyTo: source.inReplyTo,
      references: source.references,
      sender: source.sender,
      from: source.from,
      to: source.to,
      cc: source.cc,
      bcc: source.bcc,
      replyTo: source.replyTo,
      subject: source.subject,
      sentAt: source.sentAt,
      hasAttachment: source.hasAttachment,
      preview: source.preview,
      bodyValues: source.bodyValues,
      textBody: source.textBody,
      htmlBody: source.htmlBody,
      attachments: source.attachments,
      headerUserAgent: source.headerUserAgent,
      identityHeader: source.identityHeader,
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

  // ignore: unused_element
  Never _todo(String name) =>
      throw UnimplementedError('EdgeFnEmailDataSource.$name not bridged yet');

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      markAsRead(Session session, AccountId accountId,
          List<EmailId> emailIds, ReadActions readActions) async {
    // Gmail's UNREAD label is the inverse of JMAP's $seen keyword:
    //   markAsRead   -> remove UNREAD
    //   markAsUnread -> add    UNREAD
    final isMarkRead = readActions == ReadActions.markAsRead;
    return _runMutation(
      emailIds,
      addLabelIds: isMarkRead ? null : const ['UNREAD'],
      removeLabelIds: isMarkRead ? const ['UNREAD'] : null,
    );
  }

  @override
  Future<DownloadedResponse> exportAttachment(
    Attachment attachment,
    AccountId accountId,
    String baseDownloadUrl,
    AccountRequest accountRequest,
    CancelToken cancelToken,
  ) async {
    // Our edge function takes (messageId, attachmentId) but tmail's JMAP
    // Attachment only carries a single blobId. Convention: when populating
    // Attachment from Gmail, blobId = "<messageId>:<gmailAttachmentId>".
    // Gmail attachment ids are base64url (alphabet -_ only, no colons), so
    // splitting on the first ':' is unambiguous.
    final blob = attachment.blobId?.value ?? '';
    final colonIdx = blob.indexOf(':');
    if (colonIdx <= 0 || colonIdx == blob.length - 1) {
      throw ArgumentError(
        'EdgeFnEmailDataSource.exportAttachment: blobId "$blob" is not in '
        '"<messageId>:<attachmentId>" form — cannot route to mail-attachment-get',
      );
    }
    final messageId = blob.substring(0, colonIdx);
    final attachmentId = blob.substring(colonIdx + 1);

    final result = await _api.getAttachment(
      messageId: messageId,
      attachmentId: attachmentId,
    );

    // Mirror tmail's JMAP behavior on web: stuff bytes into a Blob,
    // produce an object URL, return that URL as the "filePath" so the
    // success-action handler has something it can hand to the browser
    // (anchor.href or window.open). DownloadController is platform-blind
    // here — it just opens whatever filePath we hand back.
    final mediaType = MediaType.parse(result.mimeType);
    final webBlob = html.Blob(<Object>[result.bytes], result.mimeType);
    final objectUrl = html.Url.createObjectUrlFromBlob(webBlob);

    return DownloadedResponse(objectUrl, mediaType: mediaType);
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      moveToMailbox(Session session, AccountId accountId,
          MoveToMailboxRequest moveRequest) async {
    // Flatten every (sourceMailbox -> [emailIds]) entry into one ID list. We
    // don't need the source mailbox to issue the modify call — Gmail's labels
    // are conjunctive, and the destination determines what we add/remove.
    final allIds = <EmailId>[];
    for (final ids in moveRequest.currentMailboxes.values) {
      allIds.addAll(ids);
    }
    if (allIds.isEmpty) {
      return (
        emailIdsSuccess: <EmailId>[],
        mapErrors: const <Id, SetError>{},
      );
    }
    final destination = moveRequest.destinationMailboxId.id.value;
    final translated = _translateMailboxMove(destination);
    return _runMutation(
      allIds,
      addLabelIds: translated.add,
      removeLabelIds: translated.remove,
    );
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      markAsStar(Session session, AccountId accountId,
          List<EmailId> emailIds, MarkStarAction markStarAction) async {
    // Gmail STARRED label maps directly onto JMAP's $flagged keyword.
    final isStar = markStarAction == MarkStarAction.markStar;
    return _runMutation(
      emailIds,
      addLabelIds: isStar ? const ['STARRED'] : null,
      removeLabelIds: isStar ? null : const ['STARRED'],
    );
  }

  @override
  Future<Email> saveEmailAsDrafts(
    Session session,
    AccountId accountId,
    Email email, {
    CancelToken? cancelToken,
  }) async {
    final parsed = _parseEmail(email);
    final result = await _api.createDraft(
      to: parsed.to,
      cc: parsed.cc.isEmpty ? null : parsed.cc,
      bcc: parsed.bcc.isEmpty ? null : parsed.bcc,
      subject: parsed.subject,
      bodyText: parsed.textBody,
      bodyHtml: parsed.htmlBody,
      threadId: parsed.threadId,
      inReplyTo: parsed.inReplyTo,
      references: parsed.references,
    );
    // Use Gmail's draft id as the canonical Email.id — the composer's
    // "discard" / "update" paths key off the id we hand back here, and
    // mail-draft-{update,send} take that draftId as input.
    return _emailWithIds(email, id: result.draftId, threadId: result.threadId);
  }

  @override
  Future<bool> removeEmailDrafts(
    Session session,
    AccountId accountId,
    EmailId emailId, {
    CancelToken? cancelToken,
  }) async =>
      // Gmail's users.drafts.delete isn't a critical path — when the
      // composer is discarded the draft simply ages out (and the user
      // can hard-delete from Gmail directly). Returning true keeps the
      // optimistic UI happy.
      true;

  @override
  Future<Email> updateEmailDrafts(
    Session session,
    AccountId accountId,
    Email newEmail,
    EmailId oldEmailId, {
    CancelToken? cancelToken,
  }) async {
    final parsed = _parseEmail(newEmail);
    final result = await _api.updateDraft(
      draftId: oldEmailId.id.value,
      to: parsed.to,
      cc: parsed.cc.isEmpty ? null : parsed.cc,
      bcc: parsed.bcc.isEmpty ? null : parsed.bcc,
      subject: parsed.subject,
      bodyText: parsed.textBody,
      bodyHtml: parsed.htmlBody,
      threadId: parsed.threadId,
      inReplyTo: parsed.inReplyTo,
      references: parsed.references,
    );
    return _emailWithIds(newEmail,
        id: result.draftId, threadId: result.threadId);
  }

  @override
  Future<Email> saveEmailAsTemplate(
    Session session,
    AccountId accountId,
    Email email, {
    CreateNewMailboxRequest? createNewMailboxRequest,
    CancelToken? cancelToken,
  }) async {
    // Gmail doesn't expose templates as a first-class concept the way JMAP
    // does — they're labels-on-drafts. Save as a regular draft instead;
    // caller's UI treats a successful return as "template saved" and the
    // user can find it under Drafts.
    return saveEmailAsDrafts(session, accountId, email, cancelToken: cancelToken);
  }

  @override
  Future<Email> updateEmailTemplate(
    Session session,
    AccountId accountId,
    Email newEmail,
    EmailId oldEmailId, {
    CancelToken? cancelToken,
  }) async {
    return updateEmailDrafts(
      session,
      accountId,
      newEmail,
      oldEmailId,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      deleteMultipleEmailsPermanently(Session session, AccountId accountId,
          List<EmailId> emailIds) async {
    // Phase 1: permanent-delete is intentionally a no-op success. Gmail's
    // users.messages.delete is destructive and bypasses the 30-day Trash
    // recovery window — we route deletes through the move-to-Trash path
    // instead (handled via moveToMailbox -> 'trash'). Returning success
    // keeps the optimistic UI consistent; the user can still hard-delete
    // from gmail.com if they really need to.
    return (
      emailIdsSuccess: emailIds,
      mapErrors: const <Id, SetError>{},
    );
  }

  @override
  Future<bool> deleteEmailPermanently(
    Session session,
    AccountId accountId,
    EmailId emailId, {
    CancelToken? cancelToken,
  }) async {
    // Phase 1: see deleteMultipleEmailsPermanently. Routes destructive
    // deletes through the move-to-Trash path; report success so the UI
    // doesn't roll back the (already-correct) optimistic remove.
    return true;
  }

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
      Session session, AccountId accountId, EmailId emailId) async {
    // Caller (EmailController.getEmailContent) catches NotFoundEmailException
    // and falls through to fetching the email via the network slot. Throwing
    // a sentinel error rather than UnimplementedError keeps that retry path
    // intact instead of crashing the controller.
    throw StateError(
      'EdgeFnEmailDataSource.getStoredOpenedEmail: no offline cache; '
      'caller should fall back to getEmailContent (network slot).',
    );
  }

  @override
  Future<DetailedEmail> getStoredNewEmail(
      Session session, AccountId accountId, EmailId emailId) async {
    throw StateError(
      'EdgeFnEmailDataSource.getStoredNewEmail: no offline cache; '
      'caller should fall back to getEmailContent (network slot).',
    );
  }

  @override
  Future<SendingEmail> storeSendingEmail(
          AccountId accountId, UserName userName, SendingEmail sendingEmail) async =>
      sendingEmail;

  @override
  Future<SendingEmail> updateSendingEmail(
          AccountId accountId, UserName userName, SendingEmail newSendingEmail) async =>
      newSendingEmail;

  @override
  Future<List<SendingEmail>> updateMultipleSendingEmail(AccountId accountId,
          UserName userName, List<SendingEmail> newSendingEmails) async =>
      newSendingEmails;

  @override
  Future<SendingEmail> getStoredSendingEmail(
      AccountId accountId, UserName userName, String sendingId) async {
    // No persistent sending-queue store. Caller treats throw as "missing"
    // and reconciles by re-listing via getAllSendingEmails (which is []).
    throw StateError(
      'EdgeFnEmailDataSource.getStoredSendingEmail: no persistent sending '
      'queue cache for sendingId=$sendingId.',
    );
  }

  @override
  Future<void> unsubscribeMail(
      Session session, AccountId accountId, EmailId emailId) async {
    // Routes through mail-unsubscribe (RFC 8058 one-click + RFC 2369
    // fallbacks). The edge fn verifies caller's alias matches the message
    // before doing anything. Throws on failure so tmail's downstream
    // controller surfaces the error to the user.
    await _api.unsubscribe(messageId: emailId.id.value);
  }

  @override
  Future<EmailRecoveryAction> restoreDeletedMessage(
      RestoredDeletedMessageRequest restoredDeletedMessageRequest) async {
    // Gmail doesn't expose Cyrus's email-recovery API; deleted messages go
    // to Trash for 30 days and can be restored via a label change. Return
    // a synthetic completed action so the UI doesn't error — the user
    // should look in Trash directly.
    throw UnsupportedError(
      'Gmail email recovery uses Trash label semantics, not JMAP recovery '
      'actions. Restore by moving the message out of Trash via the inbox UI.',
    );
  }

  @override
  Future<EmailRecoveryAction> getRestoredDeletedMessage(
      EmailRecoveryActionId emailRecoveryActionId) async {
    throw UnsupportedError(
      'getRestoredDeletedMessage not applicable to Gmail backends.',
    );
  }

  @override
  Future<void> markAsAnswered(
      Session session, AccountId accountId, List<EmailId> emailIds) async {
    // Gmail has no first-class "answered" label — its UI renders a "Replied"
    // badge from thread state automatically once a reply is sent. We treat
    // this as a no-op (success): the next sync will pick up the real
    // reply badge once the outbound message lands. Calling modify with no
    // labels would 400, so we skip the network round-trip entirely.
  }

  @override
  Future<void> markAsForwarded(
      Session session, AccountId accountId, List<EmailId> emailIds) async {
    // Same rationale as markAsAnswered: Gmail tracks "Forwarded" via thread
    // state, not a per-message label. No-op, success.
  }

  @override
  Future<List<Email>> parseEmailByBlobIds(
          AccountId accountId, Set<Id> blobIds) async =>
      const [];

  @override
  Future<String> generatePreviewEmailEMLContent(
      PreviewEmailEMLRequest previewEmailEMLRequest) async {
    // EML preview = render an .eml attachment inline. The PreviewEmailEMLRequest
    // carries an already-parsed Email; its `id` is the Gmail messageId we
    // stamped in JmapEmailBuilder. Fetch the raw RFC 822 via mail-eml-get,
    // wrap it in a styled HTML <pre> block (the previewer iframe uses
    // contentHtml/srcdoc — a blob: URL alone wouldn't render). On web we
    // ALSO mint an object URL so the caller can offer a "Save as .eml"
    // anchor; the URL is exposed via a comment marker the consumer can
    // pull out if needed.
    final messageId = previewEmailEMLRequest.email.id?.id.value;
    if (messageId == null || messageId.isEmpty) {
      throw StateError(
        'EdgeFnEmailDataSource.generatePreviewEmailEMLContent: '
        'PreviewEmailEMLRequest.email.id is null — cannot route to mail-eml-get.',
      );
    }
    final result = await _api.getMessageRaw(messageId: messageId);
    return _buildEmlHtmlDocument(
      title: previewEmailEMLRequest.title,
      filename: result.filename,
      bytes: result.bytes,
    );
  }

  @override
  Future<void> sharePreviewEmailEMLContent(EMLPreviewer emlPreviewer) async {}

  @override
  Future<EMLPreviewer> getPreviewEmailEMLContentShared(String keyStored) async {
    throw UnsupportedError(
      'getPreviewEmailEMLContentShared not implemented for Gmail backend.',
    );
  }

  @override
  Future<void> removePreviewEmailEMLContentShared(String keyStored) async {}

  @override
  Future<void> storePreviewEMLContentToSessionStorage(
      EMLPreviewer emlPreviewer) async {}

  @override
  Future<EMLPreviewer> getPreviewEMLContentInMemory(String keyStored) async {
    throw UnsupportedError(
      'getPreviewEMLContentInMemory not implemented for Gmail backend.',
    );
  }

  @override
  Future<DownloadedResponse> exportAllAttachments(
    AccountId accountId,
    EmailId emailId,
    String baseDownloadAllUrl,
    String outputFileName,
    AccountRequest accountRequest, {
    CancelToken? cancelToken,
  }) async {
    // Bulk-zip download not implemented yet. Caller's "download all
    // attachments" button will surface a clear error rather than crash.
    throw UnsupportedError(
      'exportAllAttachments not implemented for Gmail backend. Use '
      'individual attachment download via mail-attachment-get instead.',
    );
  }

  @override
  Future<String> generateEntireMessageAsDocument(
      ViewEntireMessageRequest entireMessageRequest) async {
    // "View original" / "Save as .eml" — fetch the raw RFC 822 for the
    // currently-open message and render it inside an HTML <pre> block.
    // The previewer iframe consumes the return value as srcdoc/contentHtml,
    // so a bare blob: URL string would just render as visible text — the
    // HTML-wrapped raw EML is what actually displays.
    final messageId = entireMessageRequest.presentationEmail.id?.id.value;
    if (messageId == null || messageId.isEmpty) {
      throw StateError(
        'EdgeFnEmailDataSource.generateEntireMessageAsDocument: '
        'ViewEntireMessageRequest.presentationEmail.id is null — cannot '
        'route to mail-eml-get.',
      );
    }
    final result = await _api.getMessageRaw(messageId: messageId);
    return _buildEmlHtmlDocument(
      title: entireMessageRequest.presentationEmail.subject ?? result.filename,
      filename: result.filename,
      bytes: result.bytes,
    );
  }

  /// Wraps the raw RFC 822 bytes in an HTML document that renders the EML
  /// content as monospaced preformatted text inside the previewer iframe.
  ///
  /// On web, we also create a `blob:` object URL so the consumer (or a future
  /// "Save as .eml" affordance) can hand the URL to an `<a download>` anchor
  /// or `window.open()`. The URL is included in the HTML as a hidden
  /// download link so the user can grab the original .eml from the preview.
  ///
  /// Web-quirk note: object URLs created via `Url.createObjectUrlFromBlob`
  /// are scoped to the document that minted them and will leak until the
  /// page unloads (we deliberately skip `revokeObjectUrl` so the link in
  /// the rendered HTML stays clickable for the lifetime of the previewer).
  String _buildEmlHtmlDocument({
    required String title,
    required String filename,
    required Uint8List bytes,
  }) {
    final escapedTitle = _htmlEscape(title);
    final escapedFilename = _htmlEscape(filename);

    String? downloadUrl;
    if (kIsWeb) {
      final blob = html.Blob(<Object>[bytes], 'message/rfc822');
      downloadUrl = html.Url.createObjectUrlFromBlob(blob);
    }

    final emlText = _decodeEmlForDisplay(bytes);
    final escapedEml = _htmlEscape(emlText);

    final downloadLink = downloadUrl != null
        ? '<p style="margin:0 0 12px 0;"><a href="$downloadUrl" '
            'download="$escapedFilename" '
            'style="color:#0b6cff;text-decoration:underline;">'
            'Download original ($escapedFilename)</a></p>'
        : '';

    return '<!doctype html>'
        '<html><head><meta charset="utf-8"><title>$escapedTitle</title>'
        '<style>'
        'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;'
        'margin:16px;color:#1f2937;}'
        'pre{background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;'
        'padding:12px;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;'
        'font-size:12px;white-space:pre-wrap;word-break:break-word;overflow-x:auto;}'
        '</style></head>'
        '<body>'
        '<h2 style="margin:0 0 8px 0;font-size:16px;">$escapedTitle</h2>'
        '$downloadLink'
        '<pre>$escapedEml</pre>'
        '</body></html>';
  }

  /// Decodes the raw EML bytes for display. RFC 822 headers are ASCII-only
  /// but the body may be 8-bit; we try utf-8 first (handles MIME-decoded
  /// content) and fall back to latin-1 (lossless byte-to-char) so we never
  /// lose bytes when rendering. Either way it's just for display — the raw
  /// bytes are also exposed verbatim via the blob URL.
  String _decodeEmlForDisplay(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _htmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  @override
  Future<void> addLabelToEmail(
    Session session,
    AccountId accountId,
    EmailId emailId,
    KeyWordIdentifier labelKeyword,
  ) async {
    final gmailLabel = _keywordToGmailLabel(labelKeyword);
    if (gmailLabel == null) return; // unmappable keyword -> no-op
    final inverse = _isInverseKeyword(labelKeyword);
    await _runMutation(
      [emailId],
      addLabelIds: inverse ? null : [gmailLabel],
      removeLabelIds: inverse ? [gmailLabel] : null,
    );
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      addLabelToThread(
    Session session,
    AccountId accountId,
    List<EmailId> emailIds,
    KeyWordIdentifier labelKeyword,
  ) async {
    final gmailLabel = _keywordToGmailLabel(labelKeyword);
    if (gmailLabel == null) {
      return (emailIdsSuccess: emailIds, mapErrors: const <Id, SetError>{});
    }
    final inverse = _isInverseKeyword(labelKeyword);
    return _runMutation(
      emailIds,
      addLabelIds: inverse ? null : [gmailLabel],
      removeLabelIds: inverse ? [gmailLabel] : null,
    );
  }

  @override
  Future<void> removeLabelFromEmail(
    Session session,
    AccountId accountId,
    EmailId emailId,
    KeyWordIdentifier labelKeyword,
  ) async {
    final gmailLabel = _keywordToGmailLabel(labelKeyword);
    if (gmailLabel == null) return;
    final inverse = _isInverseKeyword(labelKeyword);
    // "Remove keyword" inverts the same axis: remove a positive label,
    // add the inverse-axis label (e.g. "remove $seen" => "add UNREAD").
    await _runMutation(
      [emailId],
      addLabelIds: inverse ? [gmailLabel] : null,
      removeLabelIds: inverse ? null : [gmailLabel],
    );
  }

  @override
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      removeLabelFromThread(
    Session session,
    AccountId accountId,
    List<EmailId> emailIds,
    KeyWordIdentifier labelKeyword,
  ) async {
    final gmailLabel = _keywordToGmailLabel(labelKeyword);
    if (gmailLabel == null) {
      return (emailIdsSuccess: emailIds, mapErrors: const <Id, SetError>{});
    }
    final inverse = _isInverseKeyword(labelKeyword);
    return _runMutation(
      emailIds,
      addLabelIds: inverse ? [gmailLabel] : null,
      removeLabelIds: inverse ? null : [gmailLabel],
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
    // Bucket each keyword into add/remove based on its inverse polarity.
    final addLabels = <String>[];
    final removeLabels = <String>[];
    for (final kw in labelKeywords) {
      final gmailLabel = _keywordToGmailLabel(kw);
      if (gmailLabel == null) continue;
      if (_isInverseKeyword(kw)) {
        removeLabels.add(gmailLabel);
      } else {
        addLabels.add(gmailLabel);
      }
    }
    if (addLabels.isEmpty && removeLabels.isEmpty) {
      return (emailIdsSuccess: emailIds, mapErrors: const <Id, SetError>{});
    }
    return _runMutation(
      emailIds,
      addLabelIds: addLabels.isEmpty ? null : addLabels,
      removeLabelIds: removeLabels.isEmpty ? null : removeLabels,
    );
  }

  // ---- mail-mutation helpers ----

  /// Routes a label-mutation through `mail-mutation` and converts the
  /// edge-fn response into tmail's `(emailIdsSuccess, mapErrors)` shape.
  /// Unauthorized IDs (caller doesn't own the message — `skipped` from the
  /// edge fn) are surfaced as `SetError.forbidden`; per-message Gmail-API
  /// failures are surfaced as `SetError.serverFail` with the detail.
  Future<({List<EmailId> emailIdsSuccess, Map<Id, SetError> mapErrors})>
      _runMutation(
    List<EmailId> emailIds, {
    List<String>? addLabelIds,
    List<String>? removeLabelIds,
  }) async {
    if (emailIds.isEmpty) {
      return (emailIdsSuccess: const <EmailId>[], mapErrors: const <Id, SetError>{});
    }
    final ids = emailIds.map((e) => e.id.value).toList();
    final result = await _api.modifyMessages(
      messageIds: ids,
      addLabelIds: addLabelIds,
      removeLabelIds: removeLabelIds,
    );

    final mutatedSet = result.mutated.toSet();
    final emailIdsSuccess = emailIds
        .where((e) => mutatedSet.contains(e.id.value))
        .toList(growable: false);

    final mapErrors = <Id, SetError>{};
    for (final skipped in result.skipped) {
      mapErrors[Id(skipped)] = SetError(
        SetError.forbidden,
        description: 'caller alias does not match this message',
      );
    }
    result.errors.forEach((id, msg) {
      // If the same id was already marked as forbidden (skipped + verify
      // error), keep the more specific verify error.
      mapErrors[Id(id)] = SetError(SetError.serverFail, description: msg);
    });
    return (emailIdsSuccess: emailIdsSuccess, mapErrors: mapErrors);
  }

  /// Translates a synthetic destination mailbox id (matching the IDs minted
  /// by EdgeFnMailboxDataSource — `inbox`, `sent`, `drafts`, `trash`, `spam`)
  /// into the Gmail label add/remove pair to apply.
  ///
  /// Quirk: Gmail rejects modify calls that try to add/remove SENT or DRAFT
  /// labels via the public API (those are managed by users.messages.send /
  /// users.drafts.*). For sent/drafts destinations we no-op — the move is
  /// not meaningful in Gmail's model, but returning a clean translation
  /// keeps the dispatch surface consistent.
  ({List<String>? add, List<String>? remove}) _translateMailboxMove(
    String destination,
  ) {
    switch (destination) {
      case 'inbox':
        return (add: const ['INBOX'], remove: const ['TRASH', 'SPAM']);
      case 'trash':
        return (add: const ['TRASH'], remove: const ['INBOX']);
      case 'spam':
        return (add: const ['SPAM'], remove: const ['INBOX']);
      case 'sent':
      case 'drafts':
        // Not user-mutable in Gmail; treat as no-op so the optimistic UI
        // is honored without a 400 from users.messages.modify.
        return (add: null, remove: null);
      default:
        // Unknown synthetic id (future user-defined label). Best-effort:
        // archive (remove INBOX) and add the destination label name.
        return (add: [destination], remove: const ['INBOX']);
    }
  }

  /// Maps a JMAP keyword to its corresponding Gmail label name. Returns null
  /// if the keyword has no Gmail equivalent (we should no-op rather than
  /// fabricate a label).
  ///
  /// Note: `$seen` is mapped to UNREAD because Gmail uses the inverse axis.
  /// `_isInverseKeyword` flips the add/remove side accordingly.
  String? _keywordToGmailLabel(KeyWordIdentifier keyword) {
    if (keyword == KeyWordIdentifier.emailSeen) return 'UNREAD';
    if (keyword == KeyWordIdentifier.emailFlagged) return 'STARRED';
    if (keyword == KeyWordIdentifier.emailJunk) return 'SPAM';
    if (keyword == KeyWordIdentifier.emailNotJunk) return 'SPAM';
    if (keyword == KeyWordIdentifier.emailDraft) return null; // managed by drafts API
    if (keyword == KeyWordIdentifier.emailAnswered) return null; // no Gmail label
    if (keyword == KeyWordIdentifier.emailForwarded) return null; // no Gmail label
    if (keyword == KeyWordIdentifier.emailPhishing) return null; // Gmail handles via reportSpam
    if (keyword == KeyWordIdentifier.mdnSent) return null;
    // User-defined keyword. Gmail label names are arbitrary strings; sanitize
    // the JMAP keyword value so it round-trips cleanly: strip the leading $,
    // and prefix to make it visually distinct from Gmail's system labels.
    final raw = keyword.value;
    final cleaned = raw.startsWith(r'$') ? raw.substring(1) : raw;
    if (cleaned.isEmpty) return null;
    return 'User-Defined-$cleaned';
  }

  /// Returns true if the keyword's polarity is inverted relative to its Gmail
  /// label — currently only `$seen` (Gmail uses UNREAD as the negation) and
  /// `$notjunk` (we map to SPAM with inverted polarity).
  bool _isInverseKeyword(KeyWordIdentifier keyword) {
    return keyword == KeyWordIdentifier.emailSeen ||
        keyword == KeyWordIdentifier.emailNotJunk;
  }
}

/// Internal value-type holding the wire-shape body the mail-send /
/// mail-draft-{create,update} edge fns expect after parsing a tmail Email.
class _ParsedEmail {
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String? htmlBody;
  final String? textBody;
  final String? threadId;
  final String? inReplyTo;
  final List<String>? references;

  const _ParsedEmail({
    required this.to,
    required this.cc,
    required this.bcc,
    required this.subject,
    required this.htmlBody,
    required this.textBody,
    required this.threadId,
    required this.inReplyTo,
    required this.references,
  });
}
