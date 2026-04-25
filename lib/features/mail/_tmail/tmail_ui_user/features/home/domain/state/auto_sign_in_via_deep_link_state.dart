import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/oidc_configuration.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_oidc.dart';

class AutoSignInViaDeepLinkLoading extends LoadingState {}

class AutoSignInViaDeepLinkSuccess extends Success {
  final TokenOIDC tokenOIDC;
  final Uri baseUri;
  final OIDCConfiguration oidcConfiguration;

  AutoSignInViaDeepLinkSuccess(this.tokenOIDC, this.baseUri, this.oidcConfiguration);

  @override
  List<Object> get props => [tokenOIDC, baseUri, oidcConfiguration];
}

class AutoSignInViaDeepLinkFailure extends FeatureFailure {
  AutoSignInViaDeepLinkFailure(dynamic exception) : super(exception: exception);
}