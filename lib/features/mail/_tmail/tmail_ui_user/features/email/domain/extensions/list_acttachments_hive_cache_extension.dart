import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/extensions/attachment_hive_cache_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/offline_mode/model/attachment_hive_cache.dart';

extension ListAttachmentsHiveCacheExtension on List<AttachmentHiveCache> {
  List<Attachment> toAttachment() => map((attachmentHiveCache) => attachmentHiveCache.toAttachment()).toList();
}