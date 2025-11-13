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
import 'package:provider/provider.dart';

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

void main() {
  final supabaseService = CRMSupabaseService();

  setUp(() {
    supabaseService.debugSetInitialized(true);
  });

  tearDown(() {
    supabaseService.debugSetInitialized(false);
  });

  Member _buildMember({String? email}) {
    return Member(
      id: 'member-1',
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
    expect(capturedReply!.body, 'Thanks for the update!');
    expect(capturedReply!.sendAsHtml, isTrue);
  });

  test('email mapper handles Supabase schema with participants and timestamps', () {
    final provider = EmailHistoryProvider(supabaseService: supabaseService);

    final row = <String, dynamic>{
      'id': 'row-1',
      'gmail_message_id': 'gmail-123',
      'from_address': 'Organizer <info@moyoungdemocrats.org>',
      'to_address': 'member@example.com, Ally <ally@example.com>',
      'cc_address': 'helper@example.com',
      'bcc_address': 'BCC Person <bcc@example.com>',
      'subject': 'Welcome',
      'body_text': 'Plain message',
      'body_html': '<p>Plain message</p>',
      'snippet': 'Preview text',
      'date': '2024-01-01T12:00:00Z',
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
      'to_address': 'member@example.com',
      'cc_address': 'helper@example.com',
      'bcc_address': 'ally@example.com',
      'date': '2024-02-01T15:30:00Z',
      'preview_text': 'Preview',
    };

    final entry = EmailHistoryEntry.fromMap(map);

    expect(entry.id, 'entry-1');
    expect(entry.sentAt, DateTime.utc(2024, 2, 1, 15, 30).toLocal());
    expect(entry.status, 'received');
    expect(entry.to, equals(['member@example.com']));
    expect(entry.cc, contains('helper@example.com'));
    expect(entry.bcc, contains('ally@example.com'));
  });
}
