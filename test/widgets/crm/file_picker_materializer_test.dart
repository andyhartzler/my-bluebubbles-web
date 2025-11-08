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

    test('hydrates fallback selections via FilePicker platform readFile', () async {
      final fallbackBytes = Uint8List.fromList([42, 43, 44]);
      final fakePicker = _FakeFilePicker(fallbackBytes);

      file_picker.FilePicker? originalPlatform;
      var restoreOriginalPlatform = true;
      try {
        originalPlatform = file_picker.FilePicker.platform;
      } catch (_) {
        restoreOriginalPlatform = false;
      }

      file_picker.FilePicker.platform = fakePicker;
      addTearDown(() {
        if (restoreOriginalPlatform && originalPlatform != null) {
          file_picker.FilePicker.platform = originalPlatform!;
        }
      });

      final pickerFile = file_picker.PlatformFile(
        name: 'fallback.txt',
        size: fallbackBytes.length,
        path: 'does-not-exist.txt',
      );

      final result = await materializePickedPlatformFile(pickerFile);

      expect(fakePicker.readFileCallCount, equals(1));
      expect(result, isNotNull);
      expect(result!.bytes, isNotNull);
      expect(result.bytes, equals(fallbackBytes));
      expect(result.name, equals('fallback.txt'));
    });
  });
}

class _FakeFilePicker extends file_picker.FilePicker {
  _FakeFilePicker(this._bytes);

  final Uint8List? _bytes;
  int readFileCallCount = 0;

  Future<Uint8List?> readFile({required file_picker.PlatformFile file}) async {
    readFileCallCount++;
    return _bytes;
  }

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
    throw UnimplementedError();
  }

  @override
  Future<bool?> clearTemporaryFiles() async {
    throw UnimplementedError();
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    file_picker.FileType type = file_picker.FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    throw UnimplementedError();
  }
}
