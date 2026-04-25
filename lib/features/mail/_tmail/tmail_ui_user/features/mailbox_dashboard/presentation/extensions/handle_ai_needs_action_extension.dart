import 'package:scribe/scribe/ai/presentation/utils/ai_scribe_constants.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/error/capability_validator.dart';

extension HandleAiNeedsActionExtension on MailboxDashBoardController {
  bool get isAiCapabilitySupported {
    final currentAccountId = accountId.value;
    final currentSession = sessionCurrent;

    if (currentAccountId == null || currentSession == null) {
      return false;
    }

    return AiScribeConstants.aiCapability.isSupported(
      currentSession,
      currentAccountId,
    );
  }

  bool get isAINeedsActionEnabled =>
      isAINeedsActionSettingEnabled.value && isAiCapabilitySupported;
}
