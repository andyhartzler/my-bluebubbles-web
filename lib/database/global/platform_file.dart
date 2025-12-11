import 'dart:typed_data';
import 'package:file_picker/file_picker.dart' as file_picker;

class PlatformFile {
  PlatformFile({
    this.path,
    required this.name,
    required this.size,
    this.bytes,
    this.identifier,
  });

  factory PlatformFile.fromMap(Map data, {Stream<List<int>>? readStream}) {
    return PlatformFile(
      name: data['name'],
      path: data['path'],
      bytes: data['bytes'],
      size: data['size'],
      identifier: data['identifier'],
    );
  }

  /// Creates a PlatformFile from a file_picker PlatformFile.
  factory PlatformFile.fromPicker(file_picker.PlatformFile pickerFile) {
    return PlatformFile(
      name: pickerFile.name,
      path: pickerFile.path,
      bytes: pickerFile.bytes,
      size: pickerFile.size,
      identifier: pickerFile.identifier,
    );
  }

  /// The absolute path for a cached copy of this file. It can be used to create a
  /// file instance with a descriptor for the given path.
  /// ```
  /// final File myFile = File(platformFile.path);
  /// ```
  /// On web this is always `null`. You should access `bytes` property instead.
  /// Read more about it [here](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ)
  String? path;

  /// File name including its extension.
  final String name;

  /// Byte data for this file. Particurlarly useful if you want to manipulate its data
  /// or easily upload to somewhere else.
  /// [Check here in the FAQ](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ) an example on how to use it to upload on web.
  final Uint8List? bytes;

  /// The file size in bytes.
  final int size;

  /// A unique identifier for this file (used on some platforms).
  final String? identifier;

  /// File extension for this file.
  String? get extension => name.split('.').last;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlatformFile &&
        other.path == path &&
        other.name == name &&
        other.bytes == bytes &&
        other.size == size;
  }

  @override
  int get hashCode {
    return path.hashCode ^ name.hashCode ^ bytes.hashCode ^ size.hashCode;
  }

  @override
  String toString() {
    return 'PlatformFile(path: $path, name: $name, bytes: $bytes, size: $size)';
  }
}
