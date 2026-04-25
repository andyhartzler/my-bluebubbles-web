import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/app_linagora_ecosystem.dart';

class LoadingAppGridLinagraEcosystem extends LoadingState {}

class GetAppGridLinagraEcosystemSuccess extends UIState {

  final List<AppLinagoraEcosystem> listAppLinagoraEcosystem;

  GetAppGridLinagraEcosystemSuccess(this.listAppLinagoraEcosystem);

  @override
  List<Object> get props => [listAppLinagoraEcosystem];
}

class GetAppGridLinagraEcosystemFailure extends FeatureFailure {

  GetAppGridLinagraEcosystemFailure(dynamic exception) : super(exception: exception);
}