import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/repository/search_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/state/get_stored_email_sort_order_state.dart';

class GetStoredEmailSortOrderInteractor {
  final SearchRepository _searchRepository;

  const GetStoredEmailSortOrderInteractor(this._searchRepository);

  Stream<Either<Failure, Success>> execute() async* {
    try {
      yield Right(GettingStoredEmailSortOrder());
      final emailSortOrderType = await _searchRepository.getStoredEmailSortOrder();
      yield Right(GetStoredEmailSortOrderSuccess(emailSortOrderType));
    } catch (exception) {
      yield Left(GetStoredEmailSortOrderFailure(exception));
    }
  }
}
