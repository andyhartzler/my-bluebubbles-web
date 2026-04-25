import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/exceptions/calendar_event_exceptions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/repository/calendar_event_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/state/parse_calendar_event_state.dart';

class ParseCalendarEventInteractor {
  final CalendarEventRepository _calendarEventRepository;

  ParseCalendarEventInteractor(this._calendarEventRepository);

  Stream<Either<Failure, Success>> execute(
    AccountId accountId,
    Set<Id> blobIds,
    TransformConfiguration transformConfiguration,
  ) async* {
    try {
      yield Right(ParseCalendarEventLoading());

      final listBlobCalendarEvent = await _calendarEventRepository.parse(accountId, blobIds);
      final listBlobCalendarEventWithTransformedDescription = await _calendarEventRepository.transformCalendarEventDescription(
        listBlobCalendarEvent,
        transformConfiguration,
      );

      if (listBlobCalendarEventWithTransformedDescription.isNotEmpty) {
        yield Right(ParseCalendarEventSuccess(listBlobCalendarEventWithTransformedDescription));
      } else {
        yield Left(ParseCalendarEventFailure(NotFoundCalendarEventException()));
      }
    } catch (e) {
      yield Left(ParseCalendarEventFailure(e));
    }
  }
}