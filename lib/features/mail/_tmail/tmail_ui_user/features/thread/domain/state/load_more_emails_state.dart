import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';

class LoadingMoreEmails extends LoadingState {}

class LoadMoreEmailsSuccess extends UIState {
  final List<PresentationEmail> emailList;

  LoadMoreEmailsSuccess(this.emailList);

  @override
  List<Object?> get props => [emailList];
}

class LoadMoreEmailsFailure extends FeatureFailure {

  LoadMoreEmailsFailure(dynamic exception) : super(exception: exception);
}