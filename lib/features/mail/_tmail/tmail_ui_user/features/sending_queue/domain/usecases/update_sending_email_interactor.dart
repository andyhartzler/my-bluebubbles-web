import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/sending_queue/domain/model/sending_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/sending_queue/domain/repository/sending_queue_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/sending_queue/domain/state/update_sending_email_state.dart';

class UpdateSendingEmailInteractor {
  final SendingQueueRepository _sendingQueueRepository;

  UpdateSendingEmailInteractor(this._sendingQueueRepository);

  Stream<Either<Failure, Success>> execute(
    AccountId accountId,
    UserName userName,
    SendingEmail newSendingEmail
  ) async* {
    try {
      yield Right<Failure, Success>(UpdateSendingEmailLoading());
      final storedSendingEmail = await _sendingQueueRepository.updateSendingEmail(accountId, userName, newSendingEmail);
      yield Right<Failure, Success>(UpdateSendingEmailSuccess(storedSendingEmail));
    } catch (e) {
      yield Left<Failure, Success>(UpdateSendingEmailFailure(e));
    }
  }
}