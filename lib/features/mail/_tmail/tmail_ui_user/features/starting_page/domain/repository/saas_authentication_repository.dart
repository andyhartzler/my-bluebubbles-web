import 'package:bluebubbles/features/mail/_tmail/model/oidc/oidc_configuration.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_oidc.dart';

abstract class SaasAuthenticationRepository {
  Future<TokenOIDC> signInTwakeWorkplace(OIDCConfiguration oidcConfiguration);

  Future<TokenOIDC> signUpTwakeWorkplace(OIDCConfiguration oidcConfiguration);
}