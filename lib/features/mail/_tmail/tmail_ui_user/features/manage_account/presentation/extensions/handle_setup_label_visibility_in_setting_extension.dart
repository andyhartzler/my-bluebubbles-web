import 'package:bluebubbles/features/mail/_tmail/labels/utils/labels_constants.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/presentation/manage_account_dashboard_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/error/capability_validator.dart';

extension HandleSetupLabelVisibilityInSettingExtension
    on ManageAccountDashBoardController {
  bool get isLabelCapabilitySupported {
    if (accountId.value == null || sessionCurrent == null) return false;

    return LabelsConstants.labelsCapability.isSupported(
      sessionCurrent!,
      accountId.value!,
    );
  }
}
