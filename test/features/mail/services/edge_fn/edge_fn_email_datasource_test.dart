// Integration tests for EdgeFnEmailDataSource. The MailApiClient is fully
// mocked via mocktail; we assert that each EmailDataSource method routes
// through to the right MailApiClient call with the right body.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_part.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_value.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';

import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/mark_star_action.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/read_actions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/domain/model/email_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/move_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/move_to_mailbox_request.dart';

import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_email_datasource.dart';

import '_mock_mail_api_client.dart';

/// Build a minimal Session whose maps are empty. EdgeFnEmailDataSource
/// ignores Session contents — the value only has to be non-null.
Session _emptySession() => Session(
      const {},
      const {},
      const {},
      UserName('andrew@moyd.org'),
      Uri.parse('https://example.com/api'),
      Uri.parse('https://example.com/download'),
      Uri.parse('https://example.com/upload'),
      Uri.parse('https://example.com/event'),
      State('0'),
    );

AccountId _accountId() => AccountId(Id('acct-1'));

EmailId _emailId(String id) => EmailId(Id(id));

/// Build a small Email object that mirrors a tmail composer-built draft so
/// `EdgeFnEmailDataSource._parseEmail` has something to walk.
Email _composedEmail({
  String? subject = 'Hi',
  String htmlBody = '<p>Hello!</p>',
  String textBody = 'Hello!',
  List<String> to = const ['recipient@example.com'],
  List<String> cc = const [],
  List<String> bcc = const [],
  String? threadId,
  String? inReplyToId,
  Set<String>? referencesIds,
}) {
  final htmlPid = PartId('h0');
  final textPid = PartId('t0');
  return Email(
    threadId: threadId == null ? null : ThreadId(Id(threadId)),
    subject: subject,
    to: to.map((e) => EmailAddress(null, e)).toSet(),
    cc: cc.isEmpty ? null : cc.map((e) => EmailAddress(null, e)).toSet(),
    bcc: bcc.isEmpty ? null : bcc.map((e) => EmailAddress(null, e)).toSet(),
    htmlBody: {EmailBodyPart(partId: htmlPid)},
    textBody: {EmailBodyPart(partId: textPid)},
    bodyValues: {
      htmlPid: EmailBodyValue(
          value: htmlBody, isEncodingProblem: false, isTruncated: false),
      textPid: EmailBodyValue(
          value: textBody, isEncodingProblem: false, isTruncated: false),
    },
    inReplyTo: inReplyToId == null
        ? null
        : MessageIdsHeaderValue({inReplyToId}),
    references:
        referencesIds == null ? null : MessageIdsHeaderValue(referencesIds),
  );
}

/// The minimum-viable Gmail REST payload our JmapEmailBuilder needs to
/// produce a sensible Email when getMessage is stubbed.
Map<String, dynamic> _samplePayload({String id = 'msg-1'}) => {
      'id': id,
      'threadId': 'thr-$id',
      'snippet': 'Snippet for $id',
      'internalDate': '1700000000000',
      'labelIds': const ['INBOX'],
      'payload': {
        'mimeType': 'text/plain',
        'headers': [
          {'name': 'Subject', 'value': 'Subject for $id'},
          {'name': 'From', 'value': 'sender@example.com'},
          {'name': 'To', 'value': 'andrew@moyd.org'},
        ],
        'body': {
          'data': base64Url
              .encode(utf8.encode('Body for $id'))
              .replaceAll('=', ''),
        },
      },
    };

void main() {
  late MockMailApiClient api;
  late EdgeFnEmailDataSource ds;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    api = MockMailApiClient();
    ds = EdgeFnEmailDataSource(api: api);
  });

  group('getEmailContent', () {
    test('routes through getMessage and builds a JMAP Email', () async {
      when(() => api.getMessage('msg-1'))
          .thenAnswer((_) async => _samplePayload(id: 'msg-1'));

      final email = await ds.getEmailContent(
        _emptySession(),
        _accountId(),
        _emailId('msg-1'),
      );

      expect(email.id?.id.value, 'msg-1');
      expect(email.threadId?.id.value, 'thr-msg-1');
      expect(email.subject, 'Subject for msg-1');
      expect(email.from?.first.email, 'sender@example.com');
      expect(email.textBody?.length, 1);
      verify(() => api.getMessage('msg-1')).called(1);
    });
  });

  group('sendEmail', () {
    test('forwards to/cc/bcc/subject/bodies/threadId/inReplyTo to MailApiClient',
        () async {
      when(() => api.sendMessage(
            to: any(named: 'to'),
            cc: any(named: 'cc'),
            bcc: any(named: 'bcc'),
            subject: any(named: 'subject'),
            bodyText: any(named: 'bodyText'),
            bodyHtml: any(named: 'bodyHtml'),
            threadId: any(named: 'threadId'),
            inReplyTo: any(named: 'inReplyTo'),
            references: any(named: 'references'),
          )).thenAnswer((_) async => sendResult());

      final email = _composedEmail(
        subject: 'Reply',
        textBody: 'plain reply',
        htmlBody: '<p>html reply</p>',
        to: const ['a@example.com'],
        cc: const ['c@example.com'],
        bcc: const ['b@example.com'],
        threadId: 'thr-9',
        inReplyToId: '<m1@x>',
        referencesIds: {'<m0@x>', '<m1@x>'},
      );

      await ds.sendEmail(
        _emptySession(),
        _accountId(),
        EmailRequest(email: email, emailActionType: EmailActionType.compose),
      );

      // Verify exact equality on each named parameter; `references` is
      // internally a Set so it could land in either order — match with
      // a predicate matcher.
      verify(() => api.sendMessage(
            to: ['a@example.com'],
            cc: ['c@example.com'],
            bcc: ['b@example.com'],
            subject: 'Reply',
            bodyText: 'plain reply',
            bodyHtml: '<p>html reply</p>',
            threadId: 'thr-9',
            inReplyTo: '<m1@x>',
            references: any(
              named: 'references',
              that: predicate<List<String>>(
                  (r) => r.toSet().containsAll({'<m0@x>', '<m1@x>'}) &&
                      r.length == 2),
            ),
          )).called(1);
    });
  });

  group('saveEmailAsDrafts', () {
    test('calls createDraft and stamps the returned draftId/threadId', () async {
      when(() => api.createDraft(
            to: any(named: 'to'),
            cc: any(named: 'cc'),
            bcc: any(named: 'bcc'),
            subject: any(named: 'subject'),
            bodyText: any(named: 'bodyText'),
            bodyHtml: any(named: 'bodyHtml'),
            threadId: any(named: 'threadId'),
            inReplyTo: any(named: 'inReplyTo'),
            references: any(named: 'references'),
          )).thenAnswer((_) async => createDraftResult(
                draftId: 'srv-draft-7',
                threadId: 'srv-thread-7',
              ));

      final result = await ds.saveEmailAsDrafts(
        _emptySession(),
        _accountId(),
        _composedEmail(subject: 'Draft 1'),
      );

      expect(result.id?.id.value, 'srv-draft-7');
      expect(result.threadId?.id.value, 'srv-thread-7');
      verify(() => api.createDraft(
            to: any(named: 'to'),
            cc: any(named: 'cc'),
            bcc: any(named: 'bcc'),
            subject: 'Draft 1',
            bodyText: any(named: 'bodyText'),
            bodyHtml: any(named: 'bodyHtml'),
            threadId: any(named: 'threadId'),
            inReplyTo: any(named: 'inReplyTo'),
            references: any(named: 'references'),
          )).called(1);
    });
  });

  group('updateEmailDrafts', () {
    test('calls updateDraft with the old EmailId as draftId', () async {
      when(() => api.updateDraft(
            draftId: any(named: 'draftId'),
            to: any(named: 'to'),
            cc: any(named: 'cc'),
            bcc: any(named: 'bcc'),
            subject: any(named: 'subject'),
            bodyText: any(named: 'bodyText'),
            bodyHtml: any(named: 'bodyHtml'),
            threadId: any(named: 'threadId'),
            inReplyTo: any(named: 'inReplyTo'),
            references: any(named: 'references'),
          )).thenAnswer((_) async => updateDraftResult(
                draftId: 'old-draft-id',
                threadId: 'thread-after-update',
              ));

      final result = await ds.updateEmailDrafts(
        _emptySession(),
        _accountId(),
        _composedEmail(subject: 'Updated subject'),
        _emailId('old-draft-id'),
      );

      expect(result.id?.id.value, 'old-draft-id');
      expect(result.threadId?.id.value, 'thread-after-update');
      verify(() => api.updateDraft(
            draftId: 'old-draft-id',
            to: any(named: 'to'),
            cc: any(named: 'cc'),
            bcc: any(named: 'bcc'),
            subject: 'Updated subject',
            bodyText: any(named: 'bodyText'),
            bodyHtml: any(named: 'bodyHtml'),
            threadId: any(named: 'threadId'),
            inReplyTo: any(named: 'inReplyTo'),
            references: any(named: 'references'),
          )).called(1);
    });
  });

  group('markAsRead', () {
    test('markAsRead removes UNREAD label', () async {
      when(() => api.modifyMessages(
            messageIds: any(named: 'messageIds'),
            addLabelIds: any(named: 'addLabelIds'),
            removeLabelIds: any(named: 'removeLabelIds'),
          )).thenAnswer((_) async => mutationResult(mutated: const ['m1']));

      final result = await ds.markAsRead(
        _emptySession(),
        _accountId(),
        [_emailId('m1')],
        ReadActions.markAsRead,
      );

      expect(result.emailIdsSuccess.map((e) => e.id.value).toList(), ['m1']);
      verify(() => api.modifyMessages(
            messageIds: ['m1'],
            addLabelIds: null,
            removeLabelIds: ['UNREAD'],
          )).called(1);
    });

    test('markAsUnread adds UNREAD label', () async {
      when(() => api.modifyMessages(
            messageIds: any(named: 'messageIds'),
            addLabelIds: any(named: 'addLabelIds'),
            removeLabelIds: any(named: 'removeLabelIds'),
          )).thenAnswer((_) async => mutationResult(mutated: const ['m2']));

      await ds.markAsRead(
        _emptySession(),
        _accountId(),
        [_emailId('m2')],
        ReadActions.markAsUnread,
      );

      verify(() => api.modifyMessages(
            messageIds: ['m2'],
            addLabelIds: ['UNREAD'],
            removeLabelIds: null,
          )).called(1);
    });
  });

  group('markAsStar', () {
    test('markStar adds STARRED', () async {
      when(() => api.modifyMessages(
            messageIds: any(named: 'messageIds'),
            addLabelIds: any(named: 'addLabelIds'),
            removeLabelIds: any(named: 'removeLabelIds'),
          )).thenAnswer((_) async => mutationResult(mutated: const ['s1']));

      await ds.markAsStar(
        _emptySession(),
        _accountId(),
        [_emailId('s1')],
        MarkStarAction.markStar,
      );

      verify(() => api.modifyMessages(
            messageIds: ['s1'],
            addLabelIds: ['STARRED'],
            removeLabelIds: null,
          )).called(1);
    });

    test('unMarkStar removes STARRED', () async {
      when(() => api.modifyMessages(
            messageIds: any(named: 'messageIds'),
            addLabelIds: any(named: 'addLabelIds'),
            removeLabelIds: any(named: 'removeLabelIds'),
          )).thenAnswer((_) async => mutationResult(mutated: const ['s2']));

      await ds.markAsStar(
        _emptySession(),
        _accountId(),
        [_emailId('s2')],
        MarkStarAction.unMarkStar,
      );

      verify(() => api.modifyMessages(
            messageIds: ['s2'],
            addLabelIds: null,
            removeLabelIds: ['STARRED'],
          )).called(1);
    });
  });

  group('moveToMailbox', () {
    /// Fire a move with a single source mailbox -> destination, and capture
    /// the (add, remove) labels applied.
    Future<({List<String>? add, List<String>? remove})> _moveAndCapture(
        String destination) async {
      when(() => api.modifyMessages(
            messageIds: any(named: 'messageIds'),
            addLabelIds: any(named: 'addLabelIds'),
            removeLabelIds: any(named: 'removeLabelIds'),
          )).thenAnswer((_) async => mutationResult(mutated: const ['x']));

      await ds.moveToMailbox(
        _emptySession(),
        _accountId(),
        MoveToMailboxRequest(
          {
            MailboxId(Id('inbox')): [_emailId('x')],
          },
          MailboxId(Id(destination)),
          MoveAction.moving,
          EmailActionType.moveToMailbox,
        ),
      );

      final captured = verify(() => api.modifyMessages(
            messageIds: any(named: 'messageIds'),
            addLabelIds: captureAny(named: 'addLabelIds'),
            removeLabelIds: captureAny(named: 'removeLabelIds'),
          )).captured;
      // captured returns a flat list with [addLabelIds, removeLabelIds]
      // for the single call.
      return (
        add: captured[0] as List<String>?,
        remove: captured[1] as List<String>?,
      );
    }

    test('inbox destination adds INBOX, removes TRASH+SPAM', () async {
      final r = await _moveAndCapture('inbox');
      expect(r.add, ['INBOX']);
      expect(r.remove, ['TRASH', 'SPAM']);
    });

    test('trash destination adds TRASH, removes INBOX', () async {
      final r = await _moveAndCapture('trash');
      expect(r.add, ['TRASH']);
      expect(r.remove, ['INBOX']);
    });

    test('spam destination adds SPAM, removes INBOX', () async {
      final r = await _moveAndCapture('spam');
      expect(r.add, ['SPAM']);
      expect(r.remove, ['INBOX']);
    });
  });

  group('deleteEmailPermanently', () {
    test('returns true when message id appears in deleted set', () async {
      when(() => api.permanentlyDeleteMessages(
              messageIds: any(named: 'messageIds')))
          .thenAnswer((_) async => deleteResult(deleted: const ['del-1']));

      final ok = await ds.deleteEmailPermanently(
        _emptySession(),
        _accountId(),
        _emailId('del-1'),
      );

      expect(ok, true);
      verify(() => api.permanentlyDeleteMessages(messageIds: ['del-1']))
          .called(1);
    });

    test('returns false when message id was skipped/erored', () async {
      when(() => api.permanentlyDeleteMessages(
              messageIds: any(named: 'messageIds')))
          .thenAnswer((_) async => deleteResult(skipped: const ['del-2']));

      final ok = await ds.deleteEmailPermanently(
        _emptySession(),
        _accountId(),
        _emailId('del-2'),
      );

      expect(ok, false);
    });
  });

  group('unsubscribeMail', () {
    test('routes through MailApiClient.unsubscribe with the message id',
        () async {
      when(() => api.unsubscribe(messageId: any(named: 'messageId')))
          .thenAnswer((_) async => unsubscribeResult());

      await ds.unsubscribeMail(
        _emptySession(),
        _accountId(),
        _emailId('unsub-1'),
      );

      verify(() => api.unsubscribe(messageId: 'unsub-1')).called(1);
    });
  });
}
