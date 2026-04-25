import 'dart:ui';

import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/preferences/ai_scribe_config.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/preferences/preferences_config.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/preferences/preferences_setting.dart';

abstract class ManageAccountDataSource {
  Future<void> persistLanguage(Locale localeCurrent);

  Future<PreferencesSetting> toggleLocalSettingsState(PreferencesConfig preferencesConfig);

  Future<PreferencesSetting> getLocalSettings();

  Future<AIScribeConfig> getAiScribeConfigLocalSettings();

  Future<bool> getLabelSettingState();
}
