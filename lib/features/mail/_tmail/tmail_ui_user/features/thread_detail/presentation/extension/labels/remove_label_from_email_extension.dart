import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/labels.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/action/email_ui_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread_detail/presentation/thread_detail_controller.dart';

extension RemoveLabelFromEmailExtension on ThreadDetailController {
  void removeLabelFromEmail(EmailId emailId, Label label) {
    mailboxDashBoardController.dispatchEmailUIAction(
      RemoveLabelFromEmailAction(emailId, label),
    );
  }
}
