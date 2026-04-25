import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/controller/single_email_controller.dart';

extension HandleMailActionByShortcutActionExtension on SingleEmailController {
  void handleMailActionByShortcutAction({
    required EmailActionType actionType,
    required PresentationEmail email,
  }) {
    log('$runtimeType::handleMailActionByShortcutAction:🔥Email action type: $actionType');
    handleEmailAction(email, actionType);
  }
}