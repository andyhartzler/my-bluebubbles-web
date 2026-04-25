import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/repository/vacation_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/get_all_vacation_state.dart';

class GetAllVacationInteractor {
  final VacationRepository vacationRepository;

  GetAllVacationInteractor(this.vacationRepository);

  Stream<Either<Failure, Success>> execute(AccountId accountId) async* {
    try {
      yield Right<Failure, Success>(LoadingGetAllVacation());
      final listVacationResponse = await vacationRepository.getAllVacationResponse(accountId);
      yield Right<Failure, Success>(GetAllVacationSuccess(listVacationResponse));
    } catch (exception) {
      yield Left<Failure, Success>(GetAllVacationFailure(exception));
    }
  }
}