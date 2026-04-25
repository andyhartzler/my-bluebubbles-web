import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/identities/identity.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/public_asset/domain/repository/public_asset_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/public_asset/domain/state/remove_identity_from_public_assets_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/public_asset/presentation/public_asset_controller.dart';

class RemoveIdentityFromPublicAssetsInteractor {
  RemoveIdentityFromPublicAssetsInteractor(this._publicAssetRepository);

  final PublicAssetRepository _publicAssetRepository;

  Stream<Either<Failure, Success>> execute(
    Session session,
    AccountId accountId,
    {
      required IdentityId identityId,
      required List<PublicAssetId> publicAssetIds
    }
  ) async* {
    try {
      yield Right(RemovingIdentityFromPublicAssetsState());
      await _publicAssetRepository.partialUpdatePublicAssets(
        session,
        accountId,
        mapPublicAssetIdToUpdatingIdentityIds: Map.fromEntries(publicAssetIds.map(
          (publicAssetId) => MapEntry(publicAssetId, {identityId: null}),
        ))
      );
      yield Right(RemoveIdentityFromPublicAssetsSuccessState(identityId: identityId));
    } catch (exception) {
      yield Left(RemoveIdentityFromPublicAssetsFailureState(
        exception: exception,
        identityId: identityId));
    }
  }
}