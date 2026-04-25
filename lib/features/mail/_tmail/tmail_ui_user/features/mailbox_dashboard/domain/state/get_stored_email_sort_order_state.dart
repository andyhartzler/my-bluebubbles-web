import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/model/search/email_sort_order_type.dart';

class GettingStoredEmailSortOrder extends LoadingState {}

class GetStoredEmailSortOrderSuccess extends UIState {
  final EmailSortOrderType emailSortOrderType;

  GetStoredEmailSortOrderSuccess(this.emailSortOrderType);

  @override
  List<Object?> get props => [emailSortOrderType];
}

class GetStoredEmailSortOrderFailure extends FeatureFailure {

  GetStoredEmailSortOrderFailure(dynamic exception) : super(exception: exception);
}