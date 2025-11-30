import 'package:bluebubbles/features/campaigns/email_builder/models/email_component.dart';
import 'package:bluebubbles/features/campaigns/email_builder/models/email_document.dart';
import 'package:bluebubbles/features/campaigns/email_builder/providers/email_builder_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EmailBuilderProvider', () {
    late EmailBuilderProvider provider;

    setUp(() {
      provider = EmailBuilderProvider();
    });

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-key',
      );
    });

    test('supports loading existing design then undo/redo history', () {
      final initial = EmailDocument(
        sections: [
          EmailSection(
            id: 'section-1',
            columns: [
              EmailColumn(id: 'col-1', components: const []),
            ],
          ),
        ],
      );

      provider.loadDocument(initial);
      expect(provider.document.sections, hasLength(1));
      expect(provider.canUndo, isFalse);
      expect(provider.canRedo, isFalse);

      provider.addSection();
      expect(provider.document.sections, hasLength(2));
      expect(provider.canUndo, isTrue);

      provider.undo();
      expect(provider.document.sections, hasLength(1));
      expect(provider.canRedo, isTrue);

      provider.redo();
      expect(provider.document.sections, hasLength(2));
    });

    test('tracks selection and preview state for HTML preview flow', () {
      provider.togglePreviewMode();
      expect(provider.isPreviewMode, isTrue);

      provider.setPreviewDevice('mobile');
      expect(provider.previewDevice, 'mobile');

      provider.setZoomLevel(1.5);
      expect(provider.zoomLevel, 1.5);

      provider.selectSection('section-1');
      provider.selectComponent('component-1');
      expect(provider.selectedSectionId, 'section-1');
      expect(provider.selectedComponentId, 'component-1');

      provider.clearSelection();
      expect(provider.selectedSectionId, isNull);
      expect(provider.selectedComponentId, isNull);
    });
  });
}
