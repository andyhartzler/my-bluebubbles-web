import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        home: MemberDetailScreen(member: member),
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
        home: MemberDetailScreen(member: member),
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
}
