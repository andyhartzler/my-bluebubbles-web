import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/domain/model/spam_report_state.dart';

class StoreSpamReportStateLoading extends UIState {}

class StoreSpamReportStateSuccess extends UIState {
  final SpamReportState spamReportState;
  
  StoreSpamReportStateSuccess(this.spamReportState);

  @override
  List<Object> get props => [spamReportState];
}

class StoreSpamReportStateFailure extends FeatureFailure {

  StoreSpamReportStateFailure(dynamic exception) : super(exception: exception);
}