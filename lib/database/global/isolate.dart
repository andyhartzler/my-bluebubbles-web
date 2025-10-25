import 'dart:typed_data';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/utils/isolate_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:universal_io/io.dart';

Future<Image?> decodeIsolate(PlatformFile file) async {
  try {
    return decodeImage(file.bytes ?? await File(file.path!).readAsBytes())!;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> convertTiffToPng(PlatformFile file) async {
  Uint8List? bytes = file.bytes;

  if (bytes == null && file.path != null && !kIsWeb) {
    try {
      bytes = await File(file.path!).readAsBytes();
    } catch (_) {
      bytes = null;
    }
  }

  if (bytes == null) {
    return null;
  }

  final image = decodeImage(bytes);
  if (image == null) return null;

  if (kIsWeb || file.path == null) {
    return Uint8List.fromList(encodePng(image));
  }

  final receivePort = ReceivePort();
  await Isolate.spawn(unsupportedToPngIsolate, IsolateData(file, receivePort.sendPort));
  final result = await receivePort.first as Uint8List?;
  return result ?? Uint8List.fromList(encodePng(image));
}

void unsupportedToPngIsolate(IsolateData param) {
  try {
    final bytes = param.file.bytes ?? (kIsWeb ? null : File(param.file.path!).readAsBytesSync());
    if (bytes == null) {
      param.sendPort.send(null);
      return;
    }
    final image = decodeImage(bytes)!;
    final encoded = encodePng(image);
    param.sendPort.send(encoded);
  } catch (_) {
    param.sendPort.send(null);
  }
}

class IsolateData {
  final PlatformFile file;
  final SendPort sendPort;

  IsolateData(this.file, this.sendPort);
}