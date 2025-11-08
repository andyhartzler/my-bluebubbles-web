import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';

/// Hydrates a [file_picker.PlatformFile] with in-memory bytes so it can be
/// consumed as the app's [PlatformFile].
Future<PlatformFile?> materializePickedPlatformFile(
  file_picker.PlatformFile file,
) async {
  Uint8List? resolvedBytes = file.bytes;
  Object? hydrationError;
  StackTrace? hydrationTrace;
  if (resolvedBytes == null || resolvedBytes.isEmpty) {
    final readResult = await _readFileBytes(file);
    resolvedBytes = readResult.bytes;
    hydrationError = readResult.error;
    hydrationTrace = readResult.stackTrace;
  }

  if (resolvedBytes == null || resolvedBytes.isEmpty) {
    final fallbackRead = await _readFileUsingFilePickerPlatform(file);
    if (fallbackRead.bytes != null && fallbackRead.bytes!.isNotEmpty) {
      resolvedBytes = fallbackRead.bytes;
    } else if (hydrationError == null) {
      hydrationError = fallbackRead.error;
      hydrationTrace = fallbackRead.stackTrace;
    }
  }

  if ((resolvedBytes == null || resolvedBytes.isEmpty) &&
      (file.path == null || file.path!.isEmpty)) {
    final message =
        'Failed to hydrate picked file "${file.name}". No bytes or fallback path available.';
    if (hydrationError != null) {
      Logger.error(
        message,
        error: hydrationError,
        trace: hydrationTrace,
      );
    } else {
      Logger.error(message);
    }
    return null;
  }

  return PlatformFile(
    path: file.path,
    name: file.name,
    size: file.size,
    bytes: resolvedBytes,
  );
}

Future<({Uint8List? bytes, Object? error, StackTrace? stackTrace})> _readFileBytes(
    file_picker.PlatformFile file) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  final xFile = file.xFile;
  if (xFile != null) {
    final attempts = kIsWeb ? 2 : 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final bytes = await xFile.readAsBytes();
        if (bytes.isNotEmpty) {
          return (bytes: bytes, error: null, stackTrace: null);
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (!kIsWeb) {
          break;
        }
      }

      if (!kIsWeb) {
        break;
      }

      // Give the browser a moment to populate the in-memory file bytes
      // before retrying.
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  if (!kIsWeb) {
    final stream = file.readStream;
    if (stream != null) {
      try {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in stream) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) {
          return (bytes: Uint8List.fromList(bytes), error: null, stackTrace: null);
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
  }

  return (bytes: null, error: lastError, stackTrace: lastStackTrace);
}

Future<({Uint8List? bytes, Object? error, StackTrace? stackTrace})>
    _readFileUsingFilePickerPlatform(file_picker.PlatformFile file) async {
  try {
    final dynamic platform = file_picker.FilePicker.platform;
    Object? lastError;
    StackTrace? lastStackTrace;

    Uint8List? asUint8List(dynamic value) {
      if (value is Uint8List) {
        return value;
      }
      if (value is List<int>) {
        return Uint8List.fromList(value);
      }
      return null;
    }

    final List<dynamic Function()> readAttempts = [
      () => platform.readFile(file: file),
      () => platform.readFile(file),
    ];

    for (final attempt in readAttempts) {
      try {
        dynamic result = attempt();
        if (result is Future) {
          result = await result;
        }
        final bytes = asUint8List(result);
        if (bytes != null) {
          return (bytes: bytes, error: null, stackTrace: null);
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (error is! NoSuchMethodError) {
          break;
        }
      }
    }

    return (bytes: null, error: lastError, stackTrace: lastStackTrace);
  } catch (error, stackTrace) {
    return (bytes: null, error: error, stackTrace: stackTrace);
  }
}
