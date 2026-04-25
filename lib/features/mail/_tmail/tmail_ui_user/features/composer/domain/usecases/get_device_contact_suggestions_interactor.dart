
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/model/autocomplete/auto_complete_pattern.dart';
import 'package:bluebubbles/features/mail/_tmail/model/contact/contact.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/domain/repository/contact_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/domain/state/get_device_contact_suggestions_state.dart';

class GetDeviceContactSuggestionsInteractor {
  final ContactRepository _contactRepository;

  GetDeviceContactSuggestionsInteractor(this._contactRepository);

  Future<Either<Failure, Success>> execute(AutoCompletePattern autoCompletePattern) async {
    try {
      final resultList = await _contactRepository.getContactSuggestions(autoCompletePattern);
      final listEmailAddress = resultList.map((contact) => contact.toEmailAddress()).toList();
      log('GetDeviceContactSuggestionsInteractor::execute:listEmailAddress: $listEmailAddress');
      return Right<Failure, Success>(GetDeviceContactSuggestionsSuccess(listEmailAddress));
    } catch (exception) {
      return Left<Failure, Success>(GetDeviceContactSuggestionsFailure(exception));
    }
  }
}