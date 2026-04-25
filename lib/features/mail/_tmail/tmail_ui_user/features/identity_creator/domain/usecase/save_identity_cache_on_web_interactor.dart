import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/identity_creator/domain/model/identity_cache.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/identity_creator/domain/repository/identity_creator_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/identity_creator/domain/state/save_identity_cache_on_web_state.dart';

class SaveIdentityCacheOnWebInteractor {
  SaveIdentityCacheOnWebInteractor(this._identityCreatorRepository);

  final IdentityCreatorRepository _identityCreatorRepository;

  Stream<Either<Failure, Success>> execute(
    AccountId accountId,
    UserName userName,
    {required IdentityCache identityCache}
  ) async* {
    try {
      yield Right(SavingIdentityCacheOnWeb());
      await _identityCreatorRepository.saveIdentityCacheOnWeb(
        accountId,
        userName,
        identityCache: identityCache);
      yield Right(SaveIdentityCacheOnWebSuccess());
    } catch (exception) {
      logWarning("$runtimeType::execute: $exception");
      yield Left(SaveIdentityCacheOnWebFailure(exception: exception));
    }
  }
}