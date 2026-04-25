import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class RefreshingAllMailbox extends LoadingState {}

class RefreshAllMailboxSuccess extends UIState {}

class RefreshAllMailboxFailure extends FeatureFailure {

  RefreshAllMailboxFailure({dynamic exception}) : super(exception: exception);
}