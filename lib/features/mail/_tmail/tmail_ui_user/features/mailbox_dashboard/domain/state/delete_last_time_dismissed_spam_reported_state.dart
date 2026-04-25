import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class DeleteLastTimeDismissedSpamReportedLoading extends UIState {}

class DeleteLastTimeDismissedSpamReportedSuccess extends UIState {}

class DeleteLastTimeDismissedSpamReportedFailure extends FeatureFailure {

  DeleteLastTimeDismissedSpamReportedFailure(dynamic exception) : super(exception: exception);
}