import 'dart:typed_data';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:bluebubbles/screens/crm/member_detail/email_history_provider.dart';
import 'package:bluebubbles/screens/crm/member_detail_screen.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeBrowserFilePicker extends file_picker.FilePicker {
  _FakeBrowserFilePicker(this._files);

  final List<file_picker.PlatformFile> _files;
  int pickFilesCallCount = 0;

  @override
  Future<file_picker.FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    file_picker.FileType type = file_picker.FileType.any,
    List<String>? allowedExtensions,
    Function(file_picker.FilePickerStatus p1)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    pickFilesCallCount++;
    return file_picker.FilePickerResult(_files);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemberDetailScreen file picking', () {
    testWidgets('adds pending report files when using web fallback hydration',
        (tester) async {
      final member = Member(id: 'member-1', name: 'Test Member');

      final supabaseService = CRMSupabaseService();
      supabaseService.debugSetInitialized(true);
      addTearDown(() {
        supabaseService.debugSetInitialized(false);
      });

      final hydratedBytes = Uint8List.fromList([7, 8, 9]);
      debugOverrideWebFileHydrator = (
        file_picker.PlatformFile _, {
        file_picker.FilePickerResult? source,
      }) async => hydratedBytes;
      addTearDown(() => debugOverrideWebFileHydrator = null);

      final fakePicker = _FakeBrowserFilePicker([
        file_picker.PlatformFile(
          name: 'browser-only.txt',
          size: hydratedBytes.length,
        ),
      ]);

      file_picker.FilePicker? originalPlatform;
      var restoreOriginal = true;
      try {
        originalPlatform = file_picker.FilePicker.platform;
      } catch (_) {
        restoreOriginal = false;
      }
      file_picker.FilePicker.platform = fakePicker;
      addTearDown(() {
        if (restoreOriginal && originalPlatform != null) {
          file_picker.FilePicker.platform = originalPlatform!;
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => EmailHistoryProvider(supabaseService: supabaseService),
            child: Scaffold(
              body: MemberDetailScreen(member: member),
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Add Files'));
      await tester.pumpAndSettle();

      expect(fakePicker.pickFilesCallCount, 1);
      expect(find.text('browser-only.txt'), findsOneWidget);
    });
  });
}
