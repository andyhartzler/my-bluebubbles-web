import 'package:bluebubbles/features/mail/_tmail/model/mailbox/expand_mode.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/presentation/mailbox_visibility/mailbox_visibility_controller.dart';

extension ToggleExpandFoldersExtension on MailboxVisibilityController {
  void toggleExpandFolders() {
    final currentExpand = foldersExpandMode.value;
    if (currentExpand == ExpandMode.COLLAPSE) {
      foldersExpandMode.value = ExpandMode.EXPAND;
    } else {
      foldersExpandMode.value = ExpandMode.COLLAPSE;
    }
  }
}
