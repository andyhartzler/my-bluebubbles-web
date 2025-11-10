import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/database/global/platform_file.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/foundation.dart';

import 'file_picker_materializer_web_fallback_stub.dart'
    if (dart.library.html) 'file_picker_materializer_web_fallback.dart'
        as web_fallback;

typedef WebFileHydrator = Future<Uint8List?> Function(
  file_picker.PlatformFile file, {
  file_picker.FilePickerResult? source,
});

@visibleForTesting
WebFileHydrator? debugOverrideWebFileHydrator;

/// Hydrates a [file_picker.PlatformFile] with in-memory bytes so it can be
/// consumed as the app's [PlatformFile].
Future<PlatformFile?> materializePickedPlatformFile(
  file_picker.PlatformFile file,
  {file_picker.FilePickerResult? source,}
) async {
  final resolvedPath = kIsWeb ? null : _resolveFallbackPath(file, source: source);
  Uint8List? resolvedBytes = file.bytes;
  Object? hydrationError;
  StackTrace? hydrationTrace;
  if (resolvedBytes == null || resolvedBytes.isEmpty) {
    final readResult = await _readFileBytes(file, source: source);
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

  if (resolvedBytes == null || resolvedBytes.isEmpty) {
    final webFallback = await _readFileUsingWebFallback(
      file,
      source: source,
    );
    if (webFallback.bytes != null && webFallback.bytes!.isNotEmpty) {
      resolvedBytes = webFallback.bytes;
    } else if (hydrationError == null) {
      hydrationError = webFallback.error;
      hydrationTrace = webFallback.stackTrace;
    }
  }

  if ((resolvedBytes == null || resolvedBytes.isEmpty) &&
      (resolvedPath == null || resolvedPath.isEmpty)) {
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
    path: resolvedPath,
    name: file.name,
    size: resolvedBytes?.length ?? file.size,
    bytes: resolvedBytes,
  );
}

Future<({Uint8List? bytes, Object? error, StackTrace? stackTrace})> _readFileBytes(
    file_picker.PlatformFile file,
    {file_picker.FilePickerResult? source}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  final candidates = _collectCandidates(file, source: source);

  final xFileResult = await _readBytesFromXFiles(candidates);
  if (xFileResult.bytes != null && xFileResult.bytes!.isNotEmpty) {
    return xFileResult;
  }
  lastError = xFileResult.error ?? lastError;
  lastStackTrace = xFileResult.stackTrace ?? lastStackTrace;

  for (final candidate in candidates) {
    final stream = candidate.readStream;
    if (stream == null) continue;
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isNotEmpty) {
        return (bytes: bytes, error: null, stackTrace: null);
      }
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
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

Future<({Uint8List? bytes, Object? error, StackTrace? stackTrace})>
    _readFileUsingWebFallback(
  file_picker.PlatformFile file, {
  file_picker.FilePickerResult? source,
}) async {
  if (!kIsWeb && debugOverrideWebFileHydrator == null) {
    return (bytes: null, error: null, stackTrace: null);
  }

  try {
    final reader = debugOverrideWebFileHydrator ?? web_fallback.readPickedFileBytes;
    final bytes = await reader(file, source: source);
    if (bytes != null && bytes.isNotEmpty) {
      return (bytes: bytes, error: null, stackTrace: null);
    }
  } catch (error, stackTrace) {
    return (bytes: null, error: error, stackTrace: stackTrace);
  }

  final dataUriBytes = _decodeDataUri(file.path) ?? _decodeDataUri(file.identifier);
  if (dataUriBytes != null && dataUriBytes.isNotEmpty) {
    return (bytes: dataUriBytes, error: null, stackTrace: null);
  }

  return (bytes: null, error: null, stackTrace: null);
}

List<file_picker.PlatformFile> _collectCandidates(
  file_picker.PlatformFile file, {
  file_picker.FilePickerResult? source,
}) {
  final candidates = <file_picker.PlatformFile>[file];
  if (source == null) {
    return candidates;
  }

  for (final candidate in source.files) {
    if (identical(candidate, file)) {
      continue;
    }
    final namesMatch = candidate.name == file.name;
    final sizesMatch = candidate.size == file.size ||
        candidate.size == 0 ||
        file.size == 0;
    if (namesMatch && sizesMatch) {
      candidates.add(candidate);
    }
  }

  return candidates;
}

Future<({Uint8List? bytes, Object? error, StackTrace? stackTrace})>
    _readBytesFromXFiles(List<file_picker.PlatformFile> candidates) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (final candidate in candidates) {
    try {
      if (kIsWeb && (candidate.bytes == null || candidate.bytes!.isEmpty)) {
        continue;
      }
      final xFile = candidate.xFile;
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

        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }

  return (bytes: null, error: lastError, stackTrace: lastStackTrace);
}

Uint8List? _decodeDataUri(String? uriString) {
  if (uriString == null || uriString.isEmpty) {
    return null;
  }

  try {
    final uri = Uri.parse(uriString);
    final data = uri.data;
    if (data == null) {
      return null;
    }
    return Uint8List.fromList(data.contentAsBytes());
  } catch (_) {
    return null;
  }
}

String? _resolveFallbackPath(
  file_picker.PlatformFile file, {
  file_picker.FilePickerResult? source,
}) {
  final path = file.path;
  if (path != null && path.isNotEmpty) {
    return path;
  }

  if (source == null) {
    return null;
  }

  for (final candidate in _collectCandidates(file, source: source)) {
    if (identical(candidate, file)) {
      continue;
    }
    final candidatePath = candidate.path;
    if (candidatePath == null || candidatePath.isEmpty) {
      continue;
    }
    return candidatePath;
  }

  return null;
}
