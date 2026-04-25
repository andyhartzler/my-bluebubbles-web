import 'package:bluebubbles/features/mail/_tmail/core/presentation/resources/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/widget/context_menu/context_menu_item_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/presentation/model/mailbox_actions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

class ContextMenuItemMailboxAction
    extends ContextMenuItemActionRequiredIcon<MailboxActions> {
  final AppLocalizations appLocalizations;
  final ImagePaths imagePaths;

  ContextMenuItemMailboxAction(
    super.action,
    this.appLocalizations,
    this.imagePaths,
  );

  @override
  String get actionIcon => action.getContextMenuIcon(imagePaths);

  @override
  String get actionName => action.getContextMenuTitle(appLocalizations);

  @override
  Color get actionIconColor => action.getContextMenuIconColor();

  @override
  Color get actionNameColor => action.getContextMenuTitleColor();
}
