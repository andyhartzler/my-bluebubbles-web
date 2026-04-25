import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bluebubbles/features/mail/_tmail/model/upload/file_info.dart';

extension PlatformFileExtension on PlatformFile {
  FileInfo toFileInfo() => FileInfo(
    fileName: name,
    fileSize: size,
    filePath: PlatformInfo.isWeb ? '' : path ?? '',
    bytes: bytes,
  );
}