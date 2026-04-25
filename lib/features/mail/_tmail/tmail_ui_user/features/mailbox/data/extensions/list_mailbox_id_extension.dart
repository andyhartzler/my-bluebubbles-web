
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/account_id_extensions.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/mailbox_id_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/caching/utils/cache_utils.dart';

extension ListMailboxIdExtension on List<MailboxId> {
  List<String> toCacheKeyList(AccountId accountId, UserName userName) =>
    map((id) => TupleKey(id.asString, accountId.asString, userName.value).encodeKey).toList();
}