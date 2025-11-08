import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/screens/crm/file_picker_materializer.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('materializePickedPlatformFile', () {
    test('hydrates xFile selections for pending report files', () async {
      final rawBytes = Uint8List.fromList([1, 2, 3, 4]);
      final pickerFile = file_picker.PlatformFile(
        name: 'report.pdf',
        size: rawBytes.length,
        xFile: XFile.fromData(rawBytes, name: 'report.pdf'),
      );

      final result = await materializePickedPlatformFile(pickerFile);

      expect(result, isNotNull);
      expect(result!.bytes, isNotNull);
      expect(result.bytes, equals(rawBytes));
      expect(result.name, equals('report.pdf'));
    });

    test('hydrates readStream selections for profile photo uploads', () async {
      final rawBytes = Uint8List.fromList([5, 6, 7, 8, 9]);
      final pickerFile = file_picker.PlatformFile(
        name: 'avatar.png',
        size: rawBytes.length,
        readStream: Stream<List<int>>.fromIterable([
          rawBytes.sublist(0, 2),
          rawBytes.sublist(2),
        ]),
      );

      final result = await materializePickedPlatformFile(pickerFile);

      expect(result, isNotNull);
      expect(result!.bytes, isNotNull);
      expect(result.bytes, equals(rawBytes));
      expect(result.name, equals('avatar.png'));
    });
  });
}
