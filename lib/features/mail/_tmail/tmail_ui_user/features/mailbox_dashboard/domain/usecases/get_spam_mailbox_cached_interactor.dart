
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/exceptions/spam_report_exception.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/repository/spam_report_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/state/get_spam_mailbox_cached_state.dart';

class GetSpamMailboxCachedInteractor {
  static const int spamReportBannerDisplayIntervalInHours = 24;

  final SpamReportRepository _spamReportRepository;

  GetSpamMailboxCachedInteractor(this._spamReportRepository);

   Stream<Either<Failure, Success>> execute(AccountId accountId, UserName userName) async* {
    try {
      yield Right<Failure, Success>(GetSpamMailboxCachedLoading());
      if (await _validateIntervalToShowBanner()) {
        final spamMailbox = await _spamReportRepository.getSpamMailboxCached(accountId, userName);
        final countUnreadSpamMailbox = spamMailbox.unreadEmails?.value.value.toInt() ?? 0;
        if (countUnreadSpamMailbox > 0) {
          yield Right<Failure, Success>(GetSpamMailboxCachedSuccess(spamMailbox));
        } else {
          yield Left<Failure, Success>(
            GetSpamMailboxCachedFailure(NoUnreadSpamEmailsException()),
          );
        }
      } else {
        yield Left<Failure, Success>(
          GetSpamMailboxCachedFailure(SpamDismissCooldownActiveException()),
        );
      }
    } catch (e) {
      yield Left<Failure, Success>(GetSpamMailboxCachedFailure(e));
    }
  }

  Future<bool> _validateIntervalToShowBanner() async {
    final lastTimeDismissedMs = await _spamReportRepository
        .getLastTimeDismissedSpamReportedMilliseconds();

    if (lastTimeDismissedMs <= 0) {
      return true;
    }

    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeDismissedMs);
    final now = DateTime.now();
    final elapsed = now.difference(lastTime);
    if (elapsed.isNegative) {
      if (elapsed.abs() < const Duration(days: 1)) return false;
      return true;
    }
    final isIntervalElapsed =
        elapsed.inHours >= spamReportBannerDisplayIntervalInHours;

    return isIntervalElapsed;
  }
}
