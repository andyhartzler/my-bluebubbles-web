import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:file_picker/file_picker.dart' as file_picker;

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
    final bytes = await xFile.readAsBytes();
    if (bytes.isNotEmpty) {
      return bytes;
    }
  }

  final stream = file.readStream;
  if (stream != null) {
    final builder = BytesBuilder(copy: false);
    final accumulator = await stream.fold<BytesBuilder>(
      builder,
      (previous, data) => previous..add(data),
    );
    final bytes = accumulator.takeBytes();
    if (bytes.isNotEmpty) {
      return Uint8List.fromList(bytes);
    }
  }

  return null;
}
