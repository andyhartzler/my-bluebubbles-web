import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';

class SearchingMoreState extends LoadingState {}

class SearchMoreEmailSuccess extends UIState {
  final List<PresentationEmail> emailList;

  SearchMoreEmailSuccess(this.emailList);

  @override
  List<Object> get props => [emailList];
}

class SearchMoreEmailFailure extends FeatureFailure {

  SearchMoreEmailFailure(dynamic exception) : super(exception: exception);
}