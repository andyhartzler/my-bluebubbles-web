
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

extension HandleDrawerChangedExtension on MailboxDashBoardController {
  void handleDrawerChanged(bool isOpen) {
    log('HandleDrawerChangedExtension::handleDrawerChanged: isOpen = $isOpen');
    isDrawerOpened.value = isOpen;
  }
}