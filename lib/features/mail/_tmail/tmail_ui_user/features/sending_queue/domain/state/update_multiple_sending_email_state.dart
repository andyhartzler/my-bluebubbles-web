
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/sending_queue/domain/model/sending_email.dart';

class UpdateMultipleSendingEmailLoading extends UIState {}

class UpdateMultipleSendingEmailAllSuccess extends UIState {
  final List<SendingEmail> newSendingEmails;

  UpdateMultipleSendingEmailAllSuccess(this.newSendingEmails);

  @override
  List<Object?> get props => [newSendingEmails];
}

class UpdateMultipleSendingEmailHasSomeSuccess extends UIState {
  final List<SendingEmail> newSendingEmails;

  UpdateMultipleSendingEmailHasSomeSuccess(this.newSendingEmails);

  @override
  List<Object?> get props => [newSendingEmails];
}

class UpdateMultipleSendingEmailAllFailure extends FeatureFailure {

  UpdateMultipleSendingEmailAllFailure(dynamic exception) : super(exception: exception);
}

class UpdateMultipleSendingEmailFailure extends FeatureFailure {

  UpdateMultipleSendingEmailFailure(dynamic exception) : super(exception: exception);
}