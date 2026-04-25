import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/preferences/preferences_setting.dart';

class UpdatingLocalSettingsState extends LoadingState {}

class UpdateLocalSettingsSuccess extends UIState {
  final PreferencesSetting preferencesSetting;

  UpdateLocalSettingsSuccess(this.preferencesSetting);

  @override
  List<Object?> get props => [preferencesSetting];
}

class UpdateLocalSettingsFailure extends FeatureFailure {
  UpdateLocalSettingsFailure({super.exception});
}