import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/presentation_mailbox_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/domain/model/filter_message_option.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/presentation/model/context_item_filter_message_option_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/presentation/thread_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/route_navigation.dart';

extension HandleSelectMessageFilterExtension on ThreadController {
  void handleSelectMessageFilter(
    BuildContext context,
    FilterMessageOption selectedOption,
  ) {
    final contextMenuActions = [
      FilterMessageOption.attachments,
      if (selectedMailbox?.isActionRequired != true)
        FilterMessageOption.unread,
      if (selectedMailbox?.isFavorite != true)
        FilterMessageOption.starred,
    ].map((filter) {
      return ContextItemFilterMessageOptionAction(
        filter,
        selectedOption,
        AppLocalizations.of(context),
        imagePaths,
        key: '${filter.name}_filter',
      );
    }).toList();

    openBottomSheetContextMenuAction(
      context: context,
      itemActions: contextMenuActions,
      onContextMenuActionClick: (action) {
        popBack();
        filterMessagesAction(action.action);
      },
    );
  }
}
