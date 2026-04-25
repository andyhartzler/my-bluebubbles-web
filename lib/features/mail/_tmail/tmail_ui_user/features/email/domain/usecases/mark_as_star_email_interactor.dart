import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/model.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/repository/email_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/state/mark_as_email_star_state.dart';

class MarkAsStarEmailInteractor {
  final EmailRepository emailRepository;

  MarkAsStarEmailInteractor(this.emailRepository);

  Stream<Either<Failure, Success>> execute(
    Session session,
    AccountId accountId,
    EmailId emailId,
    MarkStarAction markStarAction,
  ) async* {
    try {
      await emailRepository.markAsStar(
        session,
        accountId,
        [emailId],
        markStarAction,
      );
      yield Right(MarkAsStarEmailSuccess(markStarAction, emailId));
    } catch (e) {
      yield Left(MarkAsStarEmailFailure(markStarAction, exception: e));
    }
  }
}