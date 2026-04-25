import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/localizations/app_localizations.dart';

enum ConfigurationTabType {
  vacation;

  String getTitle(BuildContext context) {
    switch(this) {
      case ConfigurationTabType.vacation:
        return AppLocalizations.of(context).vacation;
    }
  }
}