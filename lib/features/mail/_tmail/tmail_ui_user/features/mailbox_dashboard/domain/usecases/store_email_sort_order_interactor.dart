import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/repository/search_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/state/store_email_sort_order_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/model/search/email_sort_order_type.dart';

class StoreEmailSortOrderInteractor {
  final SearchRepository _searchRepository;

  const StoreEmailSortOrderInteractor(this._searchRepository);

  Stream<Either<Failure, Success>> execute(
    EmailSortOrderType sortOrderType,
  ) async* {
    try {
      yield Right(StoringEmailSortOrder());
      await _searchRepository.storeEmailSortOrder(sortOrderType);
      yield Right(StoreEmailSortOrderSuccess());
    } catch (exception) {
      yield Left(StoreEmailSortOrderFailure(exception));
    }
  }
}
