import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/presentation_email_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

extension GetMailboxContainExtension on MailboxDashBoardController {
  PresentationMailbox? getMailboxContain(PresentationEmail email) {
    if (selectedMailbox.value == null) {
      return email.findMailboxContain(mapMailboxById);
    } else {
      return searchController.isSearchEmailRunning
        ? email.findMailboxContain(mapMailboxById)
        : selectedMailbox.value;
    }
  }
}