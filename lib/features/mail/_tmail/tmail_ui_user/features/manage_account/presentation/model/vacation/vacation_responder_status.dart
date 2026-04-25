
import 'package:flutter/widgets.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

enum VacationResponderStatus {
  activated,
  deactivated;

  String getTitle(BuildContext context) {
    switch(this) {
      case VacationResponderStatus.activated:
        return AppLocalizations.of(context).activated;
      case VacationResponderStatus.deactivated:
        return AppLocalizations.of(context).deactivated;
    }
  }
}