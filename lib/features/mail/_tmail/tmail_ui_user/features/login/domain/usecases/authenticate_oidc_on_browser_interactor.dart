
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/oidc_configuration.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/extensions/oidc_configuration_extensions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/repository/authentication_oidc_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/state/authenticate_oidc_on_browser_state.dart';

class AuthenticateOidcOnBrowserInteractor {

  final AuthenticationOIDCRepository authenticationOIDCRepository;

  AuthenticateOidcOnBrowserInteractor(this.authenticationOIDCRepository);

  Stream<Either<Failure, Success>> execute(OIDCConfiguration config) async* {
    try {
      yield Right<Failure, Success>(AuthenticateOidcOnBrowserLoading());
      await authenticationOIDCRepository.authenticateOidcOnBrowser(
          config.clientId,
          config.redirectUrl,
          config.discoveryUrl,
          config.scopes);
      yield Right<Failure, Success>(AuthenticateOidcOnBrowserSuccess());
    } catch (e) {
      logWarning('AuthenticateOidcOnBrowserInteractor::execute(): $e');
      yield Left<Failure, Success>(AuthenticateOidcOnBrowserFailure(e));
    }
  }
}