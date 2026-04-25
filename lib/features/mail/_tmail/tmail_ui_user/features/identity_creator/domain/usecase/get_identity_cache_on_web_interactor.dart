import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/identity_creator/domain/repository/identity_creator_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/identity_creator/domain/state/get_identity_cache_on_web_state.dart';

class GetIdentityCacheOnWebInteractor {
  GetIdentityCacheOnWebInteractor(this._identityCreatorRepository);

  final IdentityCreatorRepository _identityCreatorRepository;

  Stream<Either<Failure, Success>> execute(
    AccountId accountId,
    UserName userName
  ) async* {
    try {
      yield Right(GettingIdentityCacheOnWeb());
      final result = await _identityCreatorRepository.getIdentityCacheOnWeb(
        accountId,
        userName);
      
      yield Right(GetIdentityCacheOnWebSuccess(result));
    } catch (exception) {
      logWarning("$runtimeType::execute: $exception");
      yield Left(GetIdentityCacheOnWebFailure(exception: exception));
    }
  }
}