import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class DeleteSpamReportStateLoading extends UIState {}

class DeleteSpamReportStateSuccess extends UIState {}

class DeleteSpamReportStateFailure extends FeatureFailure {

  DeleteSpamReportStateFailure(dynamic exception) : super(exception: exception);
}