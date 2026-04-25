import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class StoreLastTimeDismissedSpamReportLoading extends UIState {}

class StoreLastTimeDismissedSpamReportSuccess extends UIState {}

class StoreLastTimeDismissedSpamReportFailure extends FeatureFailure {

  StoreLastTimeDismissedSpamReportFailure(dynamic exception) : super(exception: exception);
}