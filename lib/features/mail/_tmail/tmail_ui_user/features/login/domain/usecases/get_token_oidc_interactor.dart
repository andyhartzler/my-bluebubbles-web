
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/features/mail/_tmail/model/account/authentication_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/account/personal_account.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/oidc_configuration.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_oidc.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/exceptions/login_exception.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/extensions/oidc_configuration_extensions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/repository/account_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/repository/authentication_oidc_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/state/get_token_oidc_state.dart';

class GetTokenOIDCInteractor {

  final AuthenticationOIDCRepository authenticationOIDCRepository;
  final AccountRepository _accountRepository;
  final CredentialRepository _credentialRepository;

  GetTokenOIDCInteractor(this._credentialRepository, this.authenticationOIDCRepository, this._accountRepository);

  Stream<Either<Failure, Success>> execute(Uri baseUri, OIDCConfiguration config) async* {
    try {
      yield Right<Failure, Success>(GetTokenOIDCLoading());
      final tokenOIDC = await authenticationOIDCRepository.getTokenOIDC(
        config.clientId,
        config.redirectUrl,
        config.discoveryUrl,
        config.scopes,
        loginHint: config.loginHint,
      );

      await Future.wait([
        _credentialRepository.saveBaseUrl(baseUri),
        authenticationOIDCRepository.persistTokenOIDC(tokenOIDC),
        authenticationOIDCRepository.persistOidcConfiguration(config),
      ]);

      await _accountRepository.setCurrentAccount(
        PersonalAccount(
          tokenOIDC.tokenIdHash,
          AuthenticationType.oidc,
          isSelected: true
        )
      );
      yield Right<Failure, Success>(GetTokenOIDCSuccess(
        tokenOIDC,
        config,
        baseUri,
      ));
    } on PlatformException catch (e) {
      logWarning('GetTokenOIDCInteractor::execute(): PlatformException ${e.message} - ${e.stacktrace}');
      if (NoSuitableBrowserForOIDCException.verifyException(e)) {
        yield Left<Failure, Success>(GetTokenOIDCFailure(NoSuitableBrowserForOIDCException()));
      } else {
        yield Left<Failure, Success>(GetTokenOIDCFailure(e));
      }
    } catch (e) {
      logWarning('GetTokenOIDCInteractor::execute(): $e');
      yield Left<Failure, Success>(GetTokenOIDCFailure(e));
    }
  }
}