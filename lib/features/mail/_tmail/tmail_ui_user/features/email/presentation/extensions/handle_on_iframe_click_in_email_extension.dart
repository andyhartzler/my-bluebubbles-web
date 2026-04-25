import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/controller/single_email_controller.dart';

extension HandleOnIframeClickInEmailExtension on SingleEmailController {
  void handleOnIFrameClick() {
    log('$runtimeType::handleOnIFrameClick');
    if (LinkOverlayManager.instance.hasActiveOverlays) {
      LinkOverlayManager.instance.hideAll();
    }
  }
}
