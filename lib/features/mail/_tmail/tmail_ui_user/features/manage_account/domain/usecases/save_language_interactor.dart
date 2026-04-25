import 'dart:ui';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/repository/manage_account_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/save_language_state.dart';

class SaveLanguageInteractor {
  final ManageAccountRepository manageAccountRepository;

  SaveLanguageInteractor(this.manageAccountRepository);

  Stream<Either<Failure, Success>> execute(Locale localeCurrent) async* {
    try {
      yield Right(SavingLanguage());
      await manageAccountRepository.persistLanguage(localeCurrent);
      yield Right(SaveLanguageSuccess(localeCurrent));
    } catch (exception) {
      yield Left(SaveLanguageFailure(exception));
    }
  }
}