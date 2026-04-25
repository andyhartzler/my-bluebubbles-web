import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';

class UpdatingTemplateEmail extends LoadingState {}

class UpdateTemplateEmailSuccess extends UIState {
  UpdateTemplateEmailSuccess(this.emailId);

  final EmailId emailId;

  @override
  List<Object> get props => [emailId];
}

class UpdateTemplateEmailFailure extends FeatureFailure {
  UpdateTemplateEmailFailure({super.exception});
}