import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/repository/calendar_event_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/state/calendar_event_counter_accept_state.dart';

class AcceptCounterCalendarEventInteractor {
  AcceptCounterCalendarEventInteractor(this._calendarEventRepository);

  final CalendarEventRepository _calendarEventRepository;

  Stream<Either<Failure, Success>> execute(
    AccountId accountId,
    Set<Id> blobIds,
    EmailId emailId,
  ) async* {
    try {
      yield Right(CalendarEventCounterAccepting());
      final result = await _calendarEventRepository
        .acceptCounterEvent(accountId, blobIds);
      yield Right(CalendarEventCounterAccepted(result, emailId));
    } catch (e) {
      yield Left(CalendarEventCounterAcceptFailure(exception: e));
    }
  }
}