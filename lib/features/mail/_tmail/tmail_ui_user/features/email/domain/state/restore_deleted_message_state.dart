import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/email_recovery/email_recovery/email_recovery_action.dart';

class RestoreDeletedMessageLoading extends LoadingState {}

class RestoreDeletedMessageSuccess extends UIState {
  final EmailRecoveryAction emailRecoveryAction;
  
  RestoreDeletedMessageSuccess(this.emailRecoveryAction);

  @override
  List<Object?> get props => [emailRecoveryAction];
}

class RestoreDeletedMessageFailure extends FeatureFailure {
  RestoreDeletedMessageFailure(dynamic exception) : super(exception: exception);
}