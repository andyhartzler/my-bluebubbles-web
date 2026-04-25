import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/model/label.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/extensions/presentation_email_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/labels/presentation/widgets/label_item_context_menu.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/labels/presentation/widgets/label_list_context_menu.dart';

mixin LabelSubMenuMixin {
  Widget? buildLabelSubmenuForEmail({
    required EmailActionType actionType,
    required ImagePaths imagePaths,
    required PresentationEmail presentationEmail,
    required List<Label>? labels,
    required OnSelectLabelAction onSelectLabelAction,
    required OnCreateANewLabelAction onCreateANewLabelAction,
  }) {
    if (actionType == EmailActionType.labelAs) {
      final listLabels = labels ?? [];
      final emailLabels = presentationEmail.getLabelList(listLabels);
      return LabelListContextMenu(
        labelList: listLabels,
        emailLabels: emailLabels,
        imagePaths: imagePaths,
        onSelectLabelAction: onSelectLabelAction,
        onCreateANewLabelAction: onCreateANewLabelAction,
      );
    }
    return null;
  }

  bool shouldHandleAction(EmailActionType action) {
    if (action != EmailActionType.labelAs) {
      return true;
    }
    return PlatformInfo.isWebTouchDevice || PlatformInfo.isMobile;
  }
}
