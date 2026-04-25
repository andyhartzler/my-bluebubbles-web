import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/response/oidc_response.dart';

class CheckOIDCIsAvailableLoading extends LoadingState {}

class CheckOIDCIsAvailableSuccess extends UIState {
  final OIDCResponse oidcResponse;

  CheckOIDCIsAvailableSuccess(this.oidcResponse);

  @override
  List<Object> get props => [oidcResponse];
}

class CheckOIDCIsAvailableFailure extends FeatureFailure {

  CheckOIDCIsAvailableFailure(dynamic exception) : super(exception: exception);
}