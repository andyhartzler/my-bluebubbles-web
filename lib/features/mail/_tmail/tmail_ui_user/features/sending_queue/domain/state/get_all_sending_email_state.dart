
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/sending_queue/domain/model/sending_email.dart';

class GetAllSendingEmailLoading extends UIState {}

class GetAllSendingEmailSuccess extends UIState {

  final List<SendingEmail> sendingEmails;

  GetAllSendingEmailSuccess(this.sendingEmails);

  @override
  List<Object?> get props => [sendingEmails];
}

class GetAllSendingEmailFailure extends FeatureFailure {

  GetAllSendingEmailFailure(dynamic exception) : super(exception: exception);
}