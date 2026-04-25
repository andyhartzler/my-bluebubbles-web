// Integration tests for EdgeFnThreadDataSource. Mocks MailApiClient and
// asserts that listInbox, searchInbox, and getMessage are wired correctly,
// plus the JMAP filter -> Gmail-syntax query translation in searchEmails.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/filter/filter.dart';
import 'package:jmap_dart_client/jmap/core/filter/filter_operator.dart';
import 'package:jmap_dart_client/jmap/core/filter/operator/logic_filter_operator.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_filter_condition.dart';

import 'package:bluebubbles/features/mail/models/mail_message.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_thread_datasource.dart';

import '_mock_mail_api_client.dart';

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

MailMessage _msg(String id) => MailMessage(
      id: id,
      threadId: 'thr-$id',
      from: 'sender@example.com',
      to: const ['andrew@moyd.org'],
      cc: const [],
      subject: 'Subject for $id',
      snippet: 'Snippet for $id',
      internalDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      labels: const ['INBOX'],
    );

Map<String, dynamic> _samplePayload(String id) => {
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
  late EdgeFnThreadDataSource ds;

  setUp(() {
    api = MockMailApiClient();
    ds = EdgeFnThreadDataSource(api: api);
  });

  group('getAllEmail', () {
    test('calls listInbox and converts MailMessage to lightweight Email',
        () async {
      when(() => api.listInbox(
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
            q: any(named: 'q'),
          )).thenAnswer((_) async => listPage(
                messages: [_msg('a'), _msg('b')],
              ));

      final response = await ds.getAllEmail(_emptySession(), _accountId());

      expect(response.emailList?.length, 2);
      expect(response.emailList!.first.id?.id.value, 'a');
      expect(response.emailList!.first.threadId?.id.value, 'thr-a');
      verify(() => api.listInbox(
            maxResults: 25,
            pageToken: any(named: 'pageToken'),
            q: any(named: 'q'),
          )).called(1);
    });
  });

  group('searchEmails', () {
    test(
        'EmailFilterCondition with text/subject/from emits Gmail operator '
        'syntax', () async {
      when(() => api.searchInbox(
            q: any(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).thenAnswer((_) async => listPage(messages: [_msg('s1')]));

      final filter = EmailFilterCondition(
        text: 'budget',
        subject: 'Q4 plan',
        from: 'andrew@moyd.org',
      );

      final response = await ds.searchEmails(
        _emptySession(),
        _accountId(),
        filter: filter,
      );

      expect(response.emailList?.length, 1);
      final captured = verify(() => api.searchInbox(
            q: captureAny(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).captured;
      final q = captured.single as String;
      // Subject + from contain spaces and so should be quoted.
      expect(q.contains('budget'), true);
      expect(q.contains('subject:"Q4 plan"'), true);
      expect(q.contains('from:andrew@moyd.org'), true);
    });

    test('EmailFilterCondition with hasAttachment emits has:attachment',
        () async {
      when(() => api.searchInbox(
            q: any(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).thenAnswer((_) async => listPage());

      await ds.searchEmails(
        _emptySession(),
        _accountId(),
        filter: EmailFilterCondition(hasAttachment: true),
      );

      final captured = verify(() => api.searchInbox(
            q: captureAny(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).captured;
      expect(captured.single, 'has:attachment');
    });

    test('FilterOperator.OR composes parts with " OR " and parens', () async {
      when(() => api.searchInbox(
            q: any(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).thenAnswer((_) async => listPage());

      final op = LogicFilterOperator(
        Operator.OR,
        <Filter>{
          EmailFilterCondition(from: 'a@a'),
          EmailFilterCondition(from: 'b@b'),
        },
      );

      await ds.searchEmails(_emptySession(), _accountId(), filter: op);

      final captured = verify(() => api.searchInbox(
            q: captureAny(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).captured;
      final q = captured.single as String;
      expect(q.startsWith('('), true);
      expect(q.endsWith(')'), true);
      expect(q.contains(' OR '), true);
      expect(q.contains('from:a@a'), true);
      expect(q.contains('from:b@b'), true);
    });

    test('FilterOperator.AND joins parts with a single space', () async {
      when(() => api.searchInbox(
            q: any(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).thenAnswer((_) async => listPage());

      final op = LogicFilterOperator(
        Operator.AND,
        <Filter>{
          EmailFilterCondition(from: 'a@a'),
          EmailFilterCondition(subject: 'Hi'),
        },
      );

      await ds.searchEmails(_emptySession(), _accountId(), filter: op);

      final captured = verify(() => api.searchInbox(
            q: captureAny(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          )).captured;
      final q = captured.single as String;
      // AND just space-joins; no parens or 'OR'.
      expect(q.contains(' OR '), false);
      expect(q.contains('from:a@a'), true);
      expect(q.contains('subject:Hi'), true);
    });

    test('empty filter (no fields populated) returns empty response without '
        'calling the API', () async {
      // Filter with all-null fields should produce an empty query and so
      // short-circuit before hitting searchInbox.
      final filter = EmailFilterCondition();

      final response = await ds.searchEmails(
        _emptySession(),
        _accountId(),
        filter: filter,
      );

      expect(response.emailList, isEmpty);
      verifyNever(() => api.searchInbox(
            q: any(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          ));
    });

    test('null filter returns empty response without calling the API',
        () async {
      final response = await ds.searchEmails(_emptySession(), _accountId());
      expect(response.emailList, isEmpty);
      verifyNever(() => api.searchInbox(
            q: any(named: 'q'),
            maxResults: any(named: 'maxResults'),
            pageToken: any(named: 'pageToken'),
          ));
    });
  });

  group('getEmailById', () {
    test('routes through getMessage and returns a PresentationEmail',
        () async {
      when(() => api.getMessage('msg-z'))
          .thenAnswer((_) async => _samplePayload('msg-z'));

      final pe = await ds.getEmailById(
        _emptySession(),
        _accountId(),
        EmailId(Id('msg-z')),
      );

      expect(pe.id?.id.value, 'msg-z');
      expect(pe.threadId?.id.value, 'thr-msg-z');
      expect(pe.subject, 'Subject for msg-z');
      verify(() => api.getMessage('msg-z')).called(1);
    });
  });
}
