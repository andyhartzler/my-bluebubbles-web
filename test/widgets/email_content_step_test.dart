import 'package:bluebubbles/features/campaigns/providers/campaign_wizard_provider.dart';
import 'package:bluebubbles/features/campaigns/wizard/widgets/email_content_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
    );
  });

  testWidgets('shows HTML preview when design is loaded', (tester) async {
    final provider = CampaignWizardProvider();
    provider.updateEmailContent(
      htmlContent: '<p>Preview ready</p>',
      designJson: const {'id': 'design-1'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const Scaffold(body: EmailContentStep()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Email Content Ready'), findsOneWidget);
    expect(find.textContaining('Preview ready'), findsOneWidget);
    expect(find.text('Edit Design'), findsOneWidget);
  });
}
