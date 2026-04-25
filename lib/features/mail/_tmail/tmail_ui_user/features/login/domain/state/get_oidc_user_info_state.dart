import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/response/oidc_user_info.dart';

class GettingOidcUserInfo extends LoadingState {}

class GetOidcUserInfoSuccess extends UIState {
  final OidcUserInfo oidcUserInfo;

  GetOidcUserInfoSuccess(this.oidcUserInfo);

  @override
  List<Object> get props => [oidcUserInfo];
}

class GetOidcUserInfoFailure extends FeatureFailure {
  GetOidcUserInfoFailure(dynamic exception) : super(exception: exception);
}
