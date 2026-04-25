
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/data/extensions/mailbox_cache_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/data/model/mailbox_cache.dart';

extension ListMailboxCacheExtension on List<MailboxCache> {
  List<Mailbox> toMailboxList() => map((mailboxCache) => mailboxCache.toMailbox()).toList();
}