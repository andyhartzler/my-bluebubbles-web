// Unit tests for JmapEmailBuilder.fromMailMessageGetJson.
//
// The builder converts the Gmail REST shape returned by mail-message-get
// into a JMAP `Email`. The MIME tree walk is the trickiest part — these
// tests cover the five payload shapes we hit in production (plain-only,
// html-only, multipart/alternative, multipart/mixed with attachments,
// and a degenerate "no headers" payload).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';

import 'package:bluebubbles/features/mail/services/edge_fn/jmap_email_builder.dart';

/// Encodes a string as Gmail-style base64url (alphabet `-_`, no padding).
String _b64url(String s) {
  return base64Url.encode(utf8.encode(s)).replaceAll('=', '');
}

Map<String, dynamic> _header(String name, String value) =>
    {'name': name, 'value': value};

void main() {
  group('JmapEmailBuilder.fromMailMessageGetJson', () {
    test('text/plain only payload', () {
      final raw = <String, dynamic>{
        'id': 'msg1',
        'threadId': 'thr1',
        'snippet': 'Hello world snippet',
        'internalDate': '1700000000000',
        'labelIds': const ['INBOX', 'UNREAD'],
        'payload': {
          'mimeType': 'text/plain',
          'headers': [
            _header('Subject', 'Plain subject'),
            _header('From', '"Andrew" <andrew@moyd.org>'),
            _header('To', 'recipient@example.com'),
          ],
          'body': {'data': _b64url('Hello, plain text body!')},
        },
      };

      final email = JmapEmailBuilder.fromMailMessageGetJson(raw);

      expect(email.id?.id.value, 'msg1');
      expect(email.threadId?.id.value, 'thr1');
      expect(email.subject, 'Plain subject');
      expect(email.preview, 'Hello world snippet');
      expect(email.from?.length, 1);
      expect(email.from!.first.email, 'andrew@moyd.org');
      expect(email.from!.first.name, 'Andrew');
      expect(email.to?.length, 1);
      expect(email.to!.first.email, 'recipient@example.com');
      expect(email.cc, isNull);
      expect(email.htmlBody, isNull);
      expect(email.textBody, isNotNull);
      expect(email.textBody!.length, 1);
      expect(email.bodyValues, isNotNull);
      // The text part should resolve to our plaintext body.
      final partId = email.textBody!.first.partId!;
      expect(email.bodyValues![partId]!.value, 'Hello, plain text body!');
      // UNREAD label means $seen should NOT be set.
      expect(email.keywords?[KeyWordIdentifier.emailSeen], isNull);
      expect(email.keywords?[KeyWordIdentifier.emailFlagged], isNull);
      expect(email.hasAttachment, false);
    });

    test('text/html only payload sets STARRED keyword and read flag', () {
      final raw = <String, dynamic>{
        'id': 'msg2',
        'threadId': 'thr2',
        'snippet': 'HTML snippet',
        'internalDate': '1700000000000',
        // No UNREAD => $seen=true. STARRED => $flagged=true.
        'labelIds': const ['INBOX', 'STARRED'],
        'payload': {
          'mimeType': 'text/html',
          'headers': [
            _header('Subject', 'HTML subject'),
            _header('From', 'sender@example.com'),
            _header('To', '"R" <r@example.com>'),
            _header('Cc', 'cc1@example.com, cc2@example.com'),
          ],
          'body': {'data': _b64url('<p>Body</p>')},
        },
      };

      final email = JmapEmailBuilder.fromMailMessageGetJson(raw);

      expect(email.subject, 'HTML subject');
      expect(email.htmlBody, isNotNull);
      expect(email.htmlBody!.length, 1);
      expect(email.textBody, isNull);
      final pid = email.htmlBody!.first.partId!;
      expect(email.bodyValues![pid]!.value, '<p>Body</p>');
      expect(email.cc?.length, 2);
      expect(
        email.cc!.map((a) => a.email).toSet(),
        {'cc1@example.com', 'cc2@example.com'},
      );
      // No UNREAD => seen=true; STARRED present => flagged=true.
      expect(email.keywords?[KeyWordIdentifier.emailSeen], true);
      expect(email.keywords?[KeyWordIdentifier.emailFlagged], true);
    });

    test('multipart/alternative carries both text and html bodies', () {
      final raw = <String, dynamic>{
        'id': 'msg3',
        'threadId': 'thr3',
        'snippet': 'Alt snippet',
        'internalDate': '1700000000000',
        'labelIds': const ['INBOX'],
        'payload': {
          'mimeType': 'multipart/alternative',
          'headers': [_header('Subject', 'Alt subject')],
          'parts': [
            {
              'mimeType': 'text/plain',
              'body': {'data': _b64url('plain copy')},
            },
            {
              'mimeType': 'text/html',
              'body': {'data': _b64url('<p>html copy</p>')},
            },
          ],
        },
      };

      final email = JmapEmailBuilder.fromMailMessageGetJson(raw);

      expect(email.textBody, isNotNull);
      expect(email.htmlBody, isNotNull);
      expect(email.textBody!.length, 1);
      expect(email.htmlBody!.length, 1);

      final textPid = email.textBody!.first.partId!;
      final htmlPid = email.htmlBody!.first.partId!;
      expect(email.bodyValues![textPid]!.value, 'plain copy');
      expect(email.bodyValues![htmlPid]!.value, '<p>html copy</p>');
    });

    test('multipart/mixed with attachment exposes text body + hasAttachment', () {
      final raw = <String, dynamic>{
        'id': 'msg4',
        'threadId': 'thr4',
        'snippet': 'Mixed snippet',
        'internalDate': '1700000000000',
        // HAS_ATTACHMENT is the Gmail label that drives hasAttachment.
        'labelIds': const ['INBOX', 'HAS_ATTACHMENT'],
        'payload': {
          'mimeType': 'multipart/mixed',
          'headers': [_header('Subject', 'With attachment')],
          'parts': [
            {
              'mimeType': 'multipart/alternative',
              'parts': [
                {
                  'mimeType': 'text/plain',
                  'body': {'data': _b64url('see attachment')},
                },
                {
                  'mimeType': 'text/html',
                  'body': {'data': _b64url('<p>see attachment</p>')},
                },
              ],
            },
            {
              // Attachments expose `attachmentId` instead of `data` — the
              // walker should not fabricate a body value for them.
              'mimeType': 'application/pdf',
              'filename': 'invoice.pdf',
              'body': {'attachmentId': 'att-xyz', 'size': 12345},
            },
          ],
        },
      };

      final email = JmapEmailBuilder.fromMailMessageGetJson(raw);

      expect(email.subject, 'With attachment');
      expect(email.hasAttachment, true);
      expect(email.textBody?.length, 1);
      expect(email.htmlBody?.length, 1);
      // bodyValues should have exactly two entries (text + html); the
      // attachment part is skipped because it has no `data`.
      expect(email.bodyValues!.length, 2);
    });

    test('payload missing subject + headers degrades cleanly', () {
      final raw = <String, dynamic>{
        'id': 'msg5',
        'threadId': 'thr5',
        // No snippet — preview should fall back to ''.
        'labelIds': const <String>[],
        'payload': {
          // No headers list, no body data.
          'mimeType': 'text/plain',
        },
      };

      final email = JmapEmailBuilder.fromMailMessageGetJson(raw);

      expect(email.id?.id.value, 'msg5');
      expect(email.threadId?.id.value, 'thr5');
      expect(email.subject, isNull);
      expect(email.preview, '');
      expect(email.from, isNull);
      expect(email.to, isNull);
      expect(email.htmlBody, isNull);
      expect(email.textBody, isNull);
      expect(email.bodyValues, isNull);
      // No UNREAD label => seen=true; keywords should still build.
      expect(email.keywords?[KeyWordIdentifier.emailSeen], true);
    });
  });
}
