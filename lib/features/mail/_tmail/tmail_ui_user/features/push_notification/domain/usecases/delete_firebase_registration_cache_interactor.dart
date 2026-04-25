import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/domain/repository/fcm_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/domain/state/delete_firebase_registration_cache_state.dart';

class DeleteFirebaseRegistrationCacheInteractor {
  final FCMRepository _fcmRepository;

  DeleteFirebaseRegistrationCacheInteractor(this._fcmRepository);

  Stream<Either<Failure, Success>> execute() async* {
    try {
      yield Right<Failure, Success>(DeleteFirebaseRegistrationCacheLoading());
      await _fcmRepository.deleteFirebaseRegistrationCache();
      yield Right<Failure, Success>(DeleteFirebaseRegistrationCacheSuccess());
    } catch (e) {
      yield Left<Failure, Success>(DeleteFirebaseRegistrationCacheFailure(e));
    }
  }
}