
import 'dart:io';

import 'package:bluebubbles/features/mail/_tmail/model/upload/file_info.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/extensions/file_extension.dart';

extension SharedMediaFileExtension on SharedMediaFile {
  File toFile() => File(path);

  FileInfo toFileInfo({bool? isShared}) =>
    toFile().toFileInfo(
      isInline: type == SharedMediaType.image,
      isShared: isShared,
    );
}