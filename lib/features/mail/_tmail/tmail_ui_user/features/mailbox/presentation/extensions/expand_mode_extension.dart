
import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/expand_mode.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

extension ExpandModeExtension on ExpandMode {
  bool get isExpanded => this == ExpandMode.EXPAND;

  ExpandMode toggle() => isExpanded ? ExpandMode.COLLAPSE : ExpandMode.EXPAND;

  String getIcon(ImagePaths imagePaths, bool isDirectionRTL) {
    if (isExpanded) {
      return imagePaths.icArrowBottom;
    } else {
      return isDirectionRTL ? imagePaths.icArrowLeft : imagePaths.icArrowRight;
    }
  }

  String getTooltipMessage(AppLocalizations appLocalizations) {
    if (isExpanded) {
      return appLocalizations.collapse;
    } else {
      return appLocalizations.expand;
    }
  }
}