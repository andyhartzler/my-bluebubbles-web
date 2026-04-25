import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/server_settings/server_settings/tmail_server_settings.dart';

class GettingServerSetting extends LoadingState {}

class GetServerSettingSuccess extends UIState {
  final TMailServerSettingOptions settingOption;

  GetServerSettingSuccess(this.settingOption);

  @override
  List<Object?> get props => [settingOption];
}

class GetServerSettingFailure extends FeatureFailure {
  GetServerSettingFailure(dynamic exception)
    : super(exception: exception);
}