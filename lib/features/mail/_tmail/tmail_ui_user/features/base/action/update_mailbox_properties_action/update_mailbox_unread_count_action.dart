import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/action/update_mailbox_properties_action/update_mailbox_properties_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/presentation/model/mailbox_tree.dart';

class UpdateMailboxUnreadCountAction extends UpdateMailboxPropertiesAction {
  const UpdateMailboxUnreadCountAction({
    required super.mailboxTrees,
    required super.mailboxId,
    required this.unreadChanges,
  });

  final int unreadChanges;

  @override
  bool updateProperty(MailboxTree mailboxTree) {
    return mailboxTree.updateMailboxUnreadCountById(mailboxId, unreadChanges);
  }
}