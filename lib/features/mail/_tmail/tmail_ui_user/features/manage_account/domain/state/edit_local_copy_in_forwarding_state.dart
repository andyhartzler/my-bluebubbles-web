import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/forward/forward/tmail_forward.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/update_forwarding_state.dart';

class EditLocalCopyInForwardingSuccess extends UIState {
  final TMailForward forward;

  EditLocalCopyInForwardingSuccess(this.forward);

  @override
  List<Object?> get props => [forward];
}

class EditLocalCopyInForwardingSuccessWithSomeCaseFailure
    extends UpdateForwardingCompleteWithSomeCaseFailure {
  EditLocalCopyInForwardingSuccessWithSomeCaseFailure(
    super.forward,
    super.exception,
  );
}

class EditLocalCopyInForwardingFailure extends FeatureFailure {

  EditLocalCopyInForwardingFailure(dynamic exception) : super(exception: exception);
}