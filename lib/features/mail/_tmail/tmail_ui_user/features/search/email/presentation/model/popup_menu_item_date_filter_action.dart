import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/model/popup_menu_item_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/model/search/email_receive_time_type.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

class PopupMenuItemDateFilterAction
    extends PopupMenuItemActionRequiredSelectedIcon<EmailReceiveTimeType> {
  final AppLocalizations appLocalizations;
  final ImagePaths imagePaths;

  PopupMenuItemDateFilterAction(
    super.action,
    super.selectedAction,
    this.appLocalizations,
    this.imagePaths,
  );

  @override
  String get actionName => action.getTitleByAppLocalizations(appLocalizations);

  @override
  String get selectedIcon => imagePaths.icFilterSelected;
}
