import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/widget/context_menu/context_menu_item_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/extensions/email_action_type_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

class ContextItemEmailAction
    extends ContextMenuItemActionRequiredIcon<EmailActionType> {
  final AppLocalizations appLocalizations;
  final ImagePaths imagePaths;

  ContextItemEmailAction(
    super.action,
    this.appLocalizations,
    this.imagePaths, {
    super.key,
    super.category,
  });

  @override
  String get actionIcon => action.getIcon(imagePaths);

  @override
  String get actionName => action.getTitle(appLocalizations);

  @override
  Color get actionIconColor => action.getContextMenuIconColor();

  @override
  Color get actionNameColor => action.getContextMenuTitleColor();
}
