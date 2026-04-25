import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/forward/forward/tmail_forward.dart';

class GetForwardSuccess extends UIState {
  final TMailForward forward;

  GetForwardSuccess(this.forward);

  @override
  List<Object?> get props => [forward];
}

class GetForwardFailure extends FeatureFailure {

  GetForwardFailure(dynamic exception) : super(exception: exception);
}