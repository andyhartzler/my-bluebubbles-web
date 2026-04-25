
import 'package:flutter/cupertino.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

enum DestinationScreenType {
  destinationPicker,
  createNewMailbox;

  String getTitle(BuildContext context, String mailboxActionTitle) {
    switch(this) {
      case DestinationScreenType.destinationPicker:
        return mailboxActionTitle;
      case DestinationScreenType.createNewMailbox:
        return AppLocalizations.of(context).createNewFolder;
    }
  }
}