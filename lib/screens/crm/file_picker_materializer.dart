import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';

/// Hydrates a [file_picker.PlatformFile] with in-memory bytes so it can be
/// consumed as the app's [PlatformFile].
Future<PlatformFile?> materializePickedPlatformFile(
  file_picker.PlatformFile file,
) async {
  Uint8List? resolvedBytes = file.bytes;
  if (resolvedBytes == null || resolvedBytes.isEmpty) {
    resolvedBytes = await _readFileBytes(file);
  }

  if ((resolvedBytes == null || resolvedBytes.isEmpty) &&
      (file.path == null || file.path!.isEmpty)) {
    return null;
  }

  return PlatformFile(
    path: file.path,
    name: file.name,
    size: file.size,
    bytes: resolvedBytes,
  );
}

Future<Uint8List?> _readFileBytes(file_picker.PlatformFile file) async {
  final xFile = file.xFile;
  if (xFile != null) {
    try {
      final bytes = await xFile.readAsBytes();
      if (bytes.isNotEmpty) {
        return bytes;
      }
    } catch (_) {
      // Ignored so we can fall back to the stream implementation below.
    }
  }

  final stream = file.readStream;
  if (stream != null) {
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isNotEmpty) {
        return Uint8List.fromList(bytes);
      }
    } catch (_) {
      // Ignore so that callers receive a null result rather than an error.
    }
  }

  return null;
}
