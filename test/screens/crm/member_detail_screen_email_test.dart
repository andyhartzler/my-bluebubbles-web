import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_provider.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final supabaseService = CRMSupabaseService();

  Future<({int status, dynamic data})> Function(String, {Map<String, dynamic>? body})
      _successInvoker({
    required String memberId,
    required List<Map<String, dynamic>> emails,
    void Function()? onCalled,
  }) {
    return (name, {body}) async {
      expect(name, 'get-member-emails');
      expect(body, isA<Map<String, dynamic>>());
      expect(body?['member_id'], memberId);
      onCalled?.call();
      return (status: 200, data: <String, dynamic>{'emails': emails});
    };
  }

  Future<({int status, dynamic data})> Function(String, {Map<String, dynamic>? body})
      _errorInvoker(String message, {int status = 500, void Function()? onCalled}) {
    return (name, {body}) async {
      expect(name, 'get-member-emails');
      onCalled?.call();
      return (status: status, data: <String, dynamic>{'error': message});
    };
  }

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

  testWidgets('email history tab renders data from edge function', (tester) async {
    final member = _buildMember(email: 'test@example.com');

    final emails = [
      <String, dynamic>{
        'id': 'email-1',
        'subject': 'Welcome Series',
        'sent_at': '2024-06-15T12:00:00Z',
        'to_addresses': ['test@example.com'],
        'cc_addresses': ['cc@example.com'],
        'bcc_addresses': [],
        'message_state': 'delivered',
        'snippet': 'Preview text',
      },
    ];

    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => EmailHistoryProvider(
            supabaseService: supabaseService,
            functionInvoker: _successInvoker(
              memberId: member.id,
              emails: emails,
              onCalled: () => invoked = true,
            ),
          ),
          child: MemberDetailScreen(member: member),
        ),
      ),
    );

    await tester.tap(find.text('Emails'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Series'), findsOneWidget);
    expect(find.text('Preview text'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
    expect(invoked, isTrue);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('email history tab surfaces edge function errors', (tester) async {
    final member = _buildMember(email: 'test@example.com');

    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => EmailHistoryProvider(
            supabaseService: supabaseService,
            functionInvoker: _errorInvoker(
              'Function failed to execute',
              onCalled: () => invoked = true,
            ),
          ),
          child: MemberDetailScreen(member: member),
        ),
      ),
    );

    await tester.tap(find.text('Emails'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load email history'), findsOneWidget);
    expect(find.text('Function failed to execute'), findsOneWidget);
    expect(invoked, isTrue);
  });
}
