import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/presentation_email_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension GetThreadDetailEmailMailboxContains on ThreadDetailController {
  PresentationMailbox? getThreadDetailEmailMailboxContains(
    PresentationEmail presentationEmail,
  ) {
    return presentationEmail.findMailboxContain(
      mailboxDashBoardController.mapMailboxById,
    );  
  }
}