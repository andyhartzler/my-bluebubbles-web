import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/forward/forward/tmail_forward.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/update_forwarding_state.dart';

class StartDeleteRecipientInForwarding extends UIState {}

class DeleteRecipientInForwardingSuccess extends UIState {
  final TMailForward forward;

  DeleteRecipientInForwardingSuccess(this.forward);

  @override
  List<Object?> get props => [forward];
}

class DeleteRecipientInForwardingSuccessWithSomeCaseFailure
    extends UpdateForwardingCompleteWithSomeCaseFailure {
  DeleteRecipientInForwardingSuccessWithSomeCaseFailure(
    super.forward,
    super.exception,
  );
}

class DeleteRecipientInForwardingFailure extends FeatureFailure {

  DeleteRecipientInForwardingFailure(dynamic exception) : super(exception: exception);
}