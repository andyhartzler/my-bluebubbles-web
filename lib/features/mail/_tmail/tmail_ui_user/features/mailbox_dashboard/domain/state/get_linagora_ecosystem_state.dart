import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem.dart';

class GettingLinagoraEcosystem extends LoadingState {}

class GetLinagoraEcosystemSuccess extends Success {
  final LinagoraEcosystem linagoraEcosystem;

  GetLinagoraEcosystemSuccess(this.linagoraEcosystem);

  @override
  List<Object?> get props => [linagoraEcosystem];
}

class GetLinagoraEcosystemFailure extends Failure {
  final Object exception;

  GetLinagoraEcosystemFailure(this.exception);

  @override
  List<Object?> get props => [exception];
}