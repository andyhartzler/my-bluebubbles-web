import 'package:bluebubbles/models/crm/quick_link.dart';
import 'package:bluebubbles/screens/dashboard/widgets/quick_links_dialog.dart';
import 'package:bluebubbles/services/crm/quick_links_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubQuickLinksRepository extends QuickLinksRepository {
  _StubQuickLinksRepository(this.links);

  final List<QuickLink> links;

  @override
  Future<List<QuickLink>> fetchQuickLinks({Duration signedUrlTTL = const Duration(hours: 6)}) async {
    return links;
  }
}

void main() {
  group('QuickLinksPanel', () {
    testWidgets('renders quick links grouped by category', (tester) async {
      final repository = _StubQuickLinksRepository([
        QuickLink(
          id: '1',
          title: 'Field Script',
          category: 'Guides',
          description: 'Door knocking script',
          externalUrl: 'https://example.com/script',
          storageBucket: null,
          storagePath: null,
          fileName: null,
          contentType: null,
          fileSize: null,
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 2),
          signedUrl: null,
          signedUrlExpiresAt: null,
        ),
        QuickLink(
          id: '2',
          title: 'Member Roster',
          category: 'Documents',
          description: 'Latest roster export',
          externalUrl: null,
          storageBucket: QuickLinksRepository.storageBucket,
          storagePath: 'files/roster.xlsx',
          fileName: 'roster.xlsx',
          contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileSize: 2048,
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 2),
          signedUrl: 'https://example.com/roster',
          signedUrlExpiresAt: DateTime.utc(2024, 1, 3),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickLinksPanel(repository: repository),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Guides'), findsOneWidget);
      expect(find.text('Member Roster'), findsOneWidget);
      expect(find.text('Field Script'), findsOneWidget);
      expect(find.text('Door knocking script'), findsOneWidget);
    });

    testWidgets('shows empty state when no quick links exist', (tester) async {
      final repository = _StubQuickLinksRepository(const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickLinksPanel(repository: repository),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No quick links yet'), findsOneWidget);
      expect(find.text('Create your first quick link to share files and resources with the team.'),
          findsOneWidget);
    });
  });
}
