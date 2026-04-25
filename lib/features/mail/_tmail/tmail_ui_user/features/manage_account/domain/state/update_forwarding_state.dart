import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/forward/forward/tmail_forward.dart';

class UpdateForwardingCompleteWithSomeCaseFailure extends FeatureFailure {
  final TMailForward forward;

  UpdateForwardingCompleteWithSomeCaseFailure(this.forward, dynamic exception)
      : super(exception: exception);

  @override
  List<Object?> get props => [forward, ...super.props];
}
