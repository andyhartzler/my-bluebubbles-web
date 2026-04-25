import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';

class QuickSearchEmailSuccess extends UIState {
  final List<PresentationEmail> emailList;

  QuickSearchEmailSuccess(this.emailList);

  @override
  List<Object> get props => [emailList];
}

class QuickSearchEmailFailure extends FeatureFailure {

  QuickSearchEmailFailure(dynamic exception) : super(exception: exception);
}