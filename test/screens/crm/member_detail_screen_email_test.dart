import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/email_thread.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_provider.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_tab.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/widgets/email_detail_screen.dart';
import 'package:bluebubbles/widgets/email_reply_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class FakeEmailHistoryProvider extends EmailHistoryProvider {
  FakeEmailHistoryProvider({
    required this.memberId,
    required this.entries,
    required this.threadMessages,
    required CRMSupabaseService supabaseService,
  }) : super(supabaseService: supabaseService);

  final String memberId;
  List<EmailHistoryEntry> entries;
  List<EmailMessage> threadMessages;

  @override
  EmailHistoryState stateForMember(String memberId) {
    if (memberId == this.memberId) {
      return EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: entries,
      );
    }
    return const EmailHistoryState(
      isLoading: false,
      hasLoaded: true,
      entries: [],
    );
  }

  @override
  Future<void> ensureLoaded(String memberId) async {}

  @override
  Future<void> refresh(String memberId) async {}

  @override
  Future<List<EmailMessage>> fetchThreadMessages({
    required String memberId,
    required String threadId,
  }) async {
    return threadMessages;
  }
}

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _MockPostgrestFilterBuilder extends Mock
    implements supabase.PostgrestFilterBuilder<dynamic> {}

typedef _OnValueCallback = dynamic Function(dynamic);

void main() {
  final supabaseService = CRMSupabaseService();

  setUpAll(() {
    registerFallbackValue<String>('');
    registerFallbackValue<bool>(false);
    registerFallbackValue<_OnValueCallback>((_) {});
    registerFallbackValue<Function>(() {});
  });

  setUp(() {
    supabaseService.debugSetInitialized(true);
  });

  tearDown(() {
    supabaseService.debugSetInitialized(false);
  });

  Member _buildMember({String? id, String? email}) {
    return Member(
      id: id ?? 'member-1',
      name: 'Test Member',
      email: email,
    );
  }

  testWidgets('email action is disabled when member has no email', (tester) async {
    final member = _buildMember(email: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => EmailHistoryProvider(supabaseService: supabaseService),
          child: MemberDetailScreen(member: member),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final emailButton = tester.widget<IconButton>(find.byTooltip('Send Email'));
    expect(emailButton.onPressed, isNull);
  });

  testWidgets('compose dialog enforces subject and HTML body', (tester) async {
    final member = _buildMember(email: 'test@example.com');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => EmailHistoryProvider(supabaseService: supabaseService),
          child: MemberDetailScreen(member: member),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Send Email'));
    await tester.pumpAndSettle();

    ElevatedButton sendButton() =>
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Send Email'));

    expect(sendButton().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('crm_email_subject_field')), 'Welcome');
    await tester.pump();
    expect(sendButton().onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('crm_email_html_field')), '<p>Hello!</p>');
    await tester.pump();

    expect(sendButton().onPressed, isNotNull);
  });

  testWidgets('tapping history entry opens reply flow and sends via handler',
      (tester) async {
    final member = _buildMember(email: 'member@example.com');
    final entry = EmailHistoryEntry(
      id: 'history-1',
      subject: 'Welcome to the movement',
      status: 'delivered',
      sentAt: DateTime.utc(2024, 1, 1),
      to: const ['member@example.com'],
      cc: const ['ally@example.com'],
      bcc: const [],
      threadId: 'thread-1',
      previewText: 'Preview',
    );

    final messages = <EmailMessage>[
      EmailMessage(
        id: 'message-1',
        sentAt: DateTime.utc(2024, 1, 1, 12),
        sender: const EmailParticipant(address: 'organizer@example.com'),
        to: const [EmailParticipant(address: 'member@example.com')],
        cc: const [],
        subject: 'Welcome to the movement',
        plainTextBody: 'Hello there',
        htmlBody: '<p>Hello there</p>',
        isOutgoing: true,
      ),
    ];

    final provider = FakeEmailHistoryProvider(
      memberId: member.id,
      entries: [entry],
      threadMessages: messages,
      supabaseService: supabaseService,
    );

    bool loaderCalled = false;
    bool sendCalled = false;
    String? capturedThreadId;
    EmailReplyData? capturedReply;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EmailHistoryProvider>.value(
          value: provider,
          child: Scaffold(
            body: EmailHistoryTab(
              memberId: member.id,
              memberName: member.name,
              loadThreadMessages: (memberId, threadId) async {
                loaderCalled = true;
                expect(memberId, member.id);
                expect(threadId, entry.threadId);
                return messages;
              },
              onSendReply: (threadId, data) async {
                sendCalled = true;
                capturedThreadId = threadId;
                capturedReply = data;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.text(entry.subject));
    await tester.pumpAndSettle();

    expect(loaderCalled, isTrue);
    expect(find.byType(EmailDetailScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Reply'));
    await tester.pumpAndSettle();

    expect(find.byType(EmailReplyDialog), findsOneWidget);

    final toField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'To'),
    );
    expect(toField.controller?.text, contains('member@example.com'));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Subject'),
      'Re: Welcome to the movement',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Message'),
      'Thanks for the update!',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Send reply'));
    await tester.pumpAndSettle();

    expect(sendCalled, isTrue);
    expect(capturedThreadId, entry.threadId);
    expect(capturedReply, isNotNull);
    expect(capturedReply!.to, contains('member@example.com'));
    expect(capturedReply!.body, 'Thanks for the update!');
    expect(capturedReply!.sendAsHtml, isTrue);
  });

  testWidgets('email_logs rows surface in email tab', (tester) async {
    final member = _buildMember(
      id: '123e4567-e89b-12d3-a456-426614174000',
      email: 'member@example.com',
    );
    final provider = EmailHistoryProvider(supabaseService: supabaseService);
    final mockClient = _MockSupabaseClient();
    final mockQuery = _MockPostgrestFilterBuilder();

    final sentRow = <String, dynamic>{
      'id': 'log-123',
      'subject': 'Welcome to the team',
      'sender': 'info@moyoungdemocrats.org',
      'recipient_emails': ['member@example.com'],
      'cc': ['ally@example.com'],
      'bcc': ['bcc@example.com'],
      'created_at': '2024-05-01T12:00:00Z',
      'status': 'delivered',
      'gmail_message_id': 'gmail-123',
      'gmail_thread_id': 'thread-456',
    };

    when(() => mockClient.from('email_logs')).thenReturn(mockQuery);
    when(() => mockQuery.select(any())).thenReturn(mockQuery);
    when(() => mockQuery.contains('member_ids', [member.id]))
        .thenReturn(mockQuery);
    when(() => mockQuery.order(
          any<String>(),
          ascending: any<bool>(named: 'ascending'),
          nullsFirst: any<bool>(named: 'nullsFirst'),
          referencedTable: any<String?>(named: 'referencedTable'),
        )).thenReturn(mockQuery);
    when(() => mockQuery.limit(
          200,
          referencedTable: any<String?>(named: 'referencedTable'),
        )).thenReturn(mockQuery);
    when(() => mockQuery.then<dynamic>(
              any<_OnValueCallback>(),
              onError: any<Function>(named: 'onError'),
            ))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments.first as _OnValueCallback;
      return Future.value(onValue(<String, dynamic>{'data': [sentRow]}));
    });

    final metadata = provider.debugCreateMemberMetadata(
      id: member.id,
      name: member.name,
      email: member.email,
    );

    final rawRows =
        await provider.debugFetchSentLogRows(mockClient, member.id, member: metadata);
    expect(rawRows, hasLength(1));
    verify(() => mockQuery.contains('member_ids', [member.id])).called(1);

    final normalized =
        provider.debugNormalizeHistoryRow(rawRows.first, member.id);
    final entry = EmailHistoryEntry.fromMap(normalized);

    provider.debugSetState(
      member.id,
      EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: [entry],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EmailHistoryProvider>.value(
          value: provider,
          child: EmailHistoryTab(
            memberId: member.id,
            memberName: member.name,
            loadThreadMessages: (_, __) async => const [],
            onSendReply: (_, __) async {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text(entry.subject), findsOneWidget);
    expect(find.textContaining('member@example.com'), findsWidgets);
  });

  testWidgets('email_inbox rows merge member_id and email filters', (tester) async {
    final member = _buildMember(
      id: 'member-merge',
      email: 'member@example.com',
    );
    final provider = EmailHistoryProvider(supabaseService: supabaseService);
    final mockClient = _MockSupabaseClient();
    final memberQuery = _MockPostgrestFilterBuilder();
    final emailQuery = _MockPostgrestFilterBuilder();
    int fromCalls = 0;

    when(() => mockClient.from('email_inbox')).thenAnswer((_) {
      return fromCalls++ == 0 ? memberQuery : emailQuery;
    });

    void setupCommonQuery(_MockPostgrestFilterBuilder builder) {
      when(() => builder.select(any())).thenReturn(builder);
      when(() => builder.order(
            any<String>(),
            ascending: any<bool>(named: 'ascending'),
            nullsFirst: any<bool>(named: 'nullsFirst'),
            referencedTable: any<String?>(named: 'referencedTable'),
          )).thenReturn(builder);
      when(() => builder.limit(
            200,
            referencedTable: any<String?>(named: 'referencedTable'),
          )).thenReturn(builder);
    }

    setupCommonQuery(memberQuery);
    setupCommonQuery(emailQuery);

    when(() => memberQuery.eq('member_id', member.id)).thenReturn(memberQuery);

    final memberRow = <String, dynamic>{
      'id': 'inbox-member',
      'subject': 'Message from lookup',
      'from_address': 'organizer@moyoungdemocrats.org',
      'to_address': 'member@example.com',
      'date': '2024-05-01T10:00:00Z',
      'direction': 'received',
    };

    when(() => memberQuery.then<dynamic>(
              any<_OnValueCallback>(),
              onError: any<Function>(named: 'onError'),
            ))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments.first as _OnValueCallback;
      return Future.value(onValue(<String, dynamic>{'data': [memberRow]}));
    });

    when(() => emailQuery.or(any())).thenReturn(emailQuery);

    final emailRow = <String, dynamic>{
      'id': 'inbox-email',
      'subject': 'Message from email filter',
      'from_address': 'ally@example.com',
      'to_address': 'member@example.com',
      'date': '2024-05-02T12:00:00Z',
      'direction': 'received',
    };

    when(() => emailQuery.then<dynamic>(
              any<_OnValueCallback>(),
              onError: any<Function>(named: 'onError'),
            ))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments.first as _OnValueCallback;
      return Future.value(onValue(<String, dynamic>{'data': [emailRow]}));
    });

    final metadata = provider.debugCreateMemberMetadata(
      id: member.id,
      name: member.name,
      email: member.email,
    );

    final inboxRows = await provider.debugFetchInboxRows(
      mockClient,
      member.id,
      member: metadata,
    );

    expect(inboxRows.map((row) => row['id']), containsAll(['inbox-member', 'inbox-email']));

    final entries = inboxRows
        .map((row) => provider.debugNormalizeHistoryRow(row, member.id, member: metadata))
        .map(EmailHistoryEntry.fromMap)
        .toList();

    provider.debugSetState(
      member.id,
      EmailHistoryState(
        isLoading: false,
        hasLoaded: true,
        entries: entries,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<EmailHistoryProvider>.value(
          value: provider,
          child: EmailHistoryTab(
            memberId: member.id,
            memberName: member.name,
            loadThreadMessages: (_, __) async => const [],
            onSendReply: (_, __) async {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Message from lookup'), findsOneWidget);
    expect(find.text('Message from email filter'), findsOneWidget);
  });

  test('sent log fallback queries by recipient emails when no member_ids present', () async {
    final member = _buildMember(email: 'member@example.com');
    final provider = EmailHistoryProvider(supabaseService: supabaseService);
    final mockClient = _MockSupabaseClient();
    final primaryQuery = _MockPostgrestFilterBuilder();
    final fallbackQuery = _MockPostgrestFilterBuilder();
    int fromCalls = 0;

    when(() => mockClient.from('email_logs')).thenAnswer((_) {
      return fromCalls++ == 0 ? primaryQuery : fallbackQuery;
    });

    when(() => primaryQuery.select(any())).thenReturn(primaryQuery);
    when(() => primaryQuery.contains('member_ids', [member.id])).thenReturn(primaryQuery);
    when(() => primaryQuery.order(
          any<String>(),
          ascending: any<bool>(named: 'ascending'),
          nullsFirst: any<bool>(named: 'nullsFirst'),
          referencedTable: any<String?>(named: 'referencedTable'),
        )).thenReturn(primaryQuery);
    when(() => primaryQuery.limit(
          200,
          referencedTable: any<String?>(named: 'referencedTable'),
        )).thenReturn(primaryQuery);
    when(() => primaryQuery.then<dynamic>(
              any<_OnValueCallback>(),
              onError: any<Function>(named: 'onError'),
            ))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments.first as _OnValueCallback;
      return Future.value(onValue(const <String, dynamic>{'data': []}));
    });

    final fallbackRow = <String, dynamic>{
      'id': 'log-999',
      'subject': 'Follow up',
      'sender': 'info@moyoungdemocrats.org',
      'recipient_emails': ['member@example.com'],
      'cc': ['cc@example.com'],
      'bcc': [],
      'created_at': '2024-05-02T08:00:00Z',
      'status': 'sent',
    };

    when(() => fallbackQuery.select(any())).thenReturn(fallbackQuery);
    when(() => fallbackQuery.order(
          any<String>(),
          ascending: any<bool>(named: 'ascending'),
          nullsFirst: any<bool>(named: 'nullsFirst'),
          referencedTable: any<String?>(named: 'referencedTable'),
        )).thenReturn(fallbackQuery);
    when(() => fallbackQuery.limit(
          200,
          referencedTable: any<String?>(named: 'referencedTable'),
        )).thenReturn(fallbackQuery);
    when(() => fallbackQuery.or(any())).thenReturn(fallbackQuery);
    when(() => fallbackQuery.then<dynamic>(
              any<_OnValueCallback>(),
              onError: any<Function>(named: 'onError'),
            ))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments.first as _OnValueCallback;
      return Future.value(onValue(<String, dynamic>{'data': [fallbackRow]}));
    });

    final metadata = provider.debugCreateMemberMetadata(
      id: member.id,
      name: member.name,
      email: member.email,
    );

    final rows =
        await provider.debugFetchSentLogRows(mockClient, member.id, member: metadata);

    expect(rows, hasLength(1));
    verify(() =>
            fallbackQuery.or(contains('recipient_emails.cs.{"member@example.com"}')))
        .called(1);
    verifyNever(() => fallbackQuery.filter(any(), any(), any()));

    final normalized = provider.debugNormalizeHistoryRow(rows.first, member.id);
    final entry = EmailHistoryEntry.fromMap(normalized);
    expect(entry.to, contains('member@example.com'));
    expect(entry.cc, contains('cc@example.com'));
  });

  test('inbox fallback filter uses literal wildcards for member emails', () {
    final provider = EmailHistoryProvider(supabaseService: supabaseService);

    final filter = provider.debugBuildInboxEmailFilter(
      const ['Member@Example.com'],
    );

    expect(filter, isNotNull);
    expect(filter, contains('from_address.ilike.member@example.com'));
    expect(filter, contains('to_address.ilike.%member@example.com%'));
    expect(filter, isNot(contains('%25member@example.com%25')));
  });

  test('email mapper handles Supabase schema with participants and timestamps', () {
    final provider = EmailHistoryProvider(supabaseService: supabaseService);

    final row = <String, dynamic>{
      'id': 'row-1',
      'message_id': 'gmail-123',
      'from_email': 'Organizer <info@moyoungdemocrats.org>',
      'to_emails': ['member@example.com', 'Ally <ally@example.com>'],
      'cc_emails': ['helper@example.com'],
      'bcc_emails': ['BCC Person <bcc@example.com>'],
      'subject': 'Welcome',
      'body_text': 'Plain message',
      'body_html': '<p>Plain message</p>',
      'snippet': 'Preview text',
      'received_at': '2024-01-01T12:00:00Z',
      'direction': 'outbound',
    };

    final message = provider.debugMapEmailMessage(row);

    expect(message.id, 'gmail-123');
    expect(message.sentAt, DateTime.utc(2024, 1, 1, 12).toLocal());
    expect(message.isOutgoing, isTrue);
    expect(message.sender.address, 'info@moyoungdemocrats.org');
    expect(message.sender.displayName, 'Organizer');
    expect(
      message.to.map((p) => p.address).toSet(),
      equals({'member@example.com', 'ally@example.com'}),
    );
    expect(
      message.cc.map((p) => p.address).toSet(),
      equals({'helper@example.com', 'bcc@example.com'}),
    );
    expect(message.plainTextBody, 'Plain message');
    expect(message.htmlBody, '<p>Plain message</p>');
  });

  test('history entry resolves singular address and date fields', () {
    final map = <String, dynamic>{
      'id': 'entry-1',
      'subject': 'Update',
      'status': 'sent',
      'email_type': 'received',
      'threadId': 'gmail-thread-123',
      'to_address': 'member@example.com',
      'recipient_emails': ['member@example.com', 'ally@example.com'],
      'cc_address': 'helper@example.com',
      'bcc_address': 'ally@example.com',
      'date': '2024-02-01T15:30:00Z',
      'preview_text': 'Preview',
    };

    final entry = EmailHistoryEntry.fromMap(map);

    expect(entry.id, 'entry-1');
    expect(entry.sentAt, DateTime.utc(2024, 2, 1, 15, 30).toLocal());
    expect(entry.status, 'received');
    expect(entry.to, equals(['member@example.com', 'ally@example.com']));
    expect(entry.cc, contains('helper@example.com'));
    expect(entry.bcc, contains('ally@example.com'));
    expect(entry.threadId, 'gmail-thread-123');
  });

  test('history entry parses member_email_history view payload', () {
    final map = <String, dynamic>{
      'email_id': 'log-42',
      'subject': 'GOTV Reminder',
      'direction': 'outbound',
      'message_state': 'sent',
      'sent_at': '2024-03-01T18:15:00Z',
      'to_emails': ['member@example.com'],
      'body_html': '<p>See you soon!</p>',
      'message_id': 'gmail-42',
      'thread_id': 'thread-abc',
    };

    final entry = EmailHistoryEntry.fromMap(map);

    expect(entry.id, 'log-42');
    expect(entry.status, 'sent');
    expect(entry.sentAt, DateTime.utc(2024, 3, 1, 18, 15).toLocal());
    expect(entry.to, equals(['member@example.com']));
    expect(entry.previewText, 'See you soon!');
    expect(entry.threadId, 'thread-abc');
  });

  test('history entry leaves cc/bcc empty when fields are missing', () {
    final map = <String, dynamic>{
      'email_id': 'log-99',
      'subject': 'Hello there',
      'to_emails': ['member@example.com'],
    };

    final entry = EmailHistoryEntry.fromMap(map);

    expect(entry.cc, isEmpty);
    expect(entry.bcc, isEmpty);
  });

  test('history entry ignores null recipients in Supabase payloads', () {
    final map = <String, dynamic>{
      'email_id': 'log-314',
      'subject': 'Null defense',
      'status': 'sent',
      'recipient_emails': ['member@example.com', null, ''],
      'cc': [null, 'helper@example.com'],
      'bcc': [null],
      'created_at': '2024-04-01T00:00:00Z',
    };

    final entry = EmailHistoryEntry.fromMap(map);

    expect(entry.to, equals(['member@example.com']));
    expect(entry.cc, equals(['helper@example.com']));
    expect(entry.bcc, isEmpty);
  });
}
