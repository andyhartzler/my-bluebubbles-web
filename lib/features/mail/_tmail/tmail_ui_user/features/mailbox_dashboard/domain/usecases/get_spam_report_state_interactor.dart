import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/repository/spam_report_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/state/get_spam_report_state.dart';

class GetSpamReportStateInteractor {
  final SpamReportRepository _spamReportRepository;

  GetSpamReportStateInteractor(this._spamReportRepository);

  Stream<Either<Failure, Success>> execute() async* {
    try {
      yield Right<Failure, Success>(GetSpamReportStateLoading());
      final spamReportState = await _spamReportRepository.getSpamReportState();
      yield Right<Failure, Success>(GetSpamReportStateSuccess(spamReportState));
    } catch (e) {
      yield Left<Failure, Success>(GetSpamReportStateFailure(e));
    }
  }
}