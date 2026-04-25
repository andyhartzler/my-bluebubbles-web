// Shared mock for MailApiClient used by the EdgeFn datasource integration
// tests. The real MailApiClient does Supabase edge-function calls, so we
// replace it wholesale with a mocktail mock; each datasource test stubs
// only the methods it exercises.

import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';

import 'package:bluebubbles/features/mail/services/mail_api_client.dart';
import 'package:bluebubbles/features/mail/models/mail_message.dart';

class MockMailApiClient extends Mock implements MailApiClient {}

/// Convenience constructors for record-typed return values used by
/// `mocktail.thenAnswer`. Records have to be constructed positionally,
/// which gets noisy when repeated across many tests.
({String gmailMessageId, String threadId, String rfc822MessageId}) sendResult({
  String gmailMessageId = 'sent-msg-1',
  String threadId = 'sent-thread-1',
  String rfc822MessageId = '<sent-1@example.com>',
}) =>
    (
      gmailMessageId: gmailMessageId,
      threadId: threadId,
      rfc822MessageId: rfc822MessageId,
    );

({String draftId, String gmailMessageId, String threadId, String rfc822MessageId})
    createDraftResult({
  String draftId = 'draft-1',
  String gmailMessageId = 'draft-msg-1',
  String threadId = 'draft-thread-1',
  String rfc822MessageId = '<draft-1@example.com>',
}) =>
        (
          draftId: draftId,
          gmailMessageId: gmailMessageId,
          threadId: threadId,
          rfc822MessageId: rfc822MessageId,
        );

({String draftId, String gmailMessageId, String threadId}) updateDraftResult({
  String draftId = 'draft-2',
  String gmailMessageId = 'draft-msg-2',
  String threadId = 'draft-thread-2',
}) =>
    (
      draftId: draftId,
      gmailMessageId: gmailMessageId,
      threadId: threadId,
    );

({List<String> mutated, List<String> skipped, Map<String, String> errors})
    mutationResult({
  List<String>? mutated,
  List<String>? skipped,
  Map<String, String>? errors,
}) =>
        (
          mutated: mutated ?? const <String>[],
          skipped: skipped ?? const <String>[],
          errors: errors ?? const <String, String>{},
        );

({List<String> deleted, List<String> skipped, Map<String, String> errors})
    deleteResult({
  List<String>? deleted,
  List<String>? skipped,
  Map<String, String>? errors,
}) =>
        (
          deleted: deleted ?? const <String>[],
          skipped: skipped ?? const <String>[],
          errors: errors ?? const <String, String>{},
        );

({String method, String url}) unsubscribeResult({
  String method = 'one-click-post',
  String url = 'https://example.com/unsub',
}) =>
    (method: method, url: url);

({Uint8List bytes, String mimeType, String filename}) attachmentResult({
  Uint8List? bytes,
  String mimeType = 'application/octet-stream',
  String filename = 'file.bin',
}) =>
    (bytes: bytes ?? Uint8List(0), mimeType: mimeType, filename: filename);

MailListPage listPage({
  List<MailMessage>? messages,
  String? nextPageToken,
}) =>
    MailListPage(
      messages: messages ?? const <MailMessage>[],
      nextPageToken: nextPageToken,
    );
