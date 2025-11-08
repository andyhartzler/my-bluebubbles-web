import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as file_picker;

Future<Uint8List?> readPickedFileBytes(
  file_picker.PlatformFile file, {
  file_picker.FilePickerResult? source,
}) async {
  final urls = <String>{};
  final path = file.path;
  if (path != null && path.isNotEmpty) {
    urls.add(path);
  }
  final identifier = file.identifier;
  if (identifier != null && identifier.isNotEmpty) {
    urls.add(identifier);
  }

  for (final url in urls) {
    final bytes = await _readFromBlobUrl(url);
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }
  }

  return null;
}

Future<Uint8List?> _readFromBlobUrl(String url) async {
  try {
    final response = await html.HttpRequest.request(
      url,
      responseType: 'blob',
    );
    final blob = response.response as html.Blob?;
    if (blob == null) {
      return null;
    }

    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();
    reader.onError.listen((_) {
      completer.completeError(reader.error ?? StateError('Failed to read blob'));
    });
    reader.onLoadEnd.listen((_) {
      final buffer = reader.result as ByteBuffer?;
      completer.complete(buffer?.asUint8List());
    });
    reader.readAsArrayBuffer(blob);
    final bytes = await completer.future;
    return bytes;
  } catch (_) {
    return null;
  }
}
