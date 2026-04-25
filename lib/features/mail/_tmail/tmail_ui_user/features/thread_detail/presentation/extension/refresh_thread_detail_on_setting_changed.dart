import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread_detail/presentation/action/thread_detail_ui_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread_detail/presentation/thread_detail_manager.dart';

extension RefreshThreadDetailOnSettingChanged on ThreadDetailManager {
  void refreshThreadDetailOnSettingChanged() {
    if (threadDetailWasEnabled != isThreadDetailEnabled) {
      threadDetailWasEnabled = isThreadDetailEnabled;
      if (PlatformInfo.isWeb &&
          mailboxDashBoardController.isEmailOpened) {
        mailboxDashBoardController.dispatchThreadDetailUIAction(
          ResyncThreadDetailWhenSettingChangedAction(),
        );
      } else {
        mailboxDashBoardController.selectedEmail.refresh();
        if (PlatformInfo.isMobile) {
          mailboxDashBoardController.dashboardRoute.refresh();
        }
      }
    }
  }
}