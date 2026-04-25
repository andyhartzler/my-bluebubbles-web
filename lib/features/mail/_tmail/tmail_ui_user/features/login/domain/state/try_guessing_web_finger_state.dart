import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/response/oidc_response.dart';

class TryingGuessingWebFinger extends LoadingState {}

class TryGuessingWebFingerSuccess extends UIState {
  TryGuessingWebFingerSuccess(this.oidcResponse);

  final OIDCResponse oidcResponse;

  @override
  List<Object?> get props => [oidcResponse];
}

class TryGuessingWebFingerFailure extends FeatureFailure {
  TryGuessingWebFingerFailure({super.exception});
}