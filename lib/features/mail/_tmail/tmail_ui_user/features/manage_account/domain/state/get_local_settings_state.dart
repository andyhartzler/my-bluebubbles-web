import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/preferences/preferences_setting.dart';

class GettingLocalSettingsState extends LoadingState {}

class GetLocalSettingsSuccess extends UIState {
  GetLocalSettingsSuccess(this.preferencesSetting);

  final PreferencesSetting preferencesSetting;

  @override
  List<Object?> get props => [preferencesSetting];
}

class GetLocalSettingsFailure extends FeatureFailure {
  GetLocalSettingsFailure({super.exception});
}