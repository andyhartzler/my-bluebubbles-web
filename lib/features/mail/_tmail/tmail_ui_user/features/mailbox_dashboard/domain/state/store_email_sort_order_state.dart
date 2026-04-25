import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class StoringEmailSortOrder extends LoadingState {}

class StoreEmailSortOrderSuccess extends UIState {}

class StoreEmailSortOrderFailure extends FeatureFailure {

  StoreEmailSortOrderFailure(dynamic exception) : super(exception: exception);
}