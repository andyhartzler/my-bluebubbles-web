import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/forward/forward/tmail_forward.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/update_forwarding_state.dart';

class AddRecipientsInForwardingSuccess extends UIState {
  final TMailForward forward;

  AddRecipientsInForwardingSuccess(this.forward);

  @override
  List<Object?> get props => [forward];
}

class AddRecipientsInForwardingSuccessWithSomeCaseFailure
    extends UpdateForwardingCompleteWithSomeCaseFailure {
  AddRecipientsInForwardingSuccessWithSomeCaseFailure(
    super.forward,
    super.exception,
  );
}

class AddRecipientsInForwardingFailure extends FeatureFailure {

  AddRecipientsInForwardingFailure(dynamic exception) : super(exception: exception);
}