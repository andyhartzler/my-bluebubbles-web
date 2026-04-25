import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';

class SearchingState extends LoadingState {}

class RefreshingSearchState extends LoadingState {}

class SearchEmailSuccess extends UIState {
  final List<PresentationEmail> emailList;

  SearchEmailSuccess(this.emailList);

  @override
  List<Object> get props => [emailList];
}

class SearchEmailFailure extends FeatureFailure {

  SearchEmailFailure(dynamic exception, {super.onRetry}) : super(exception: exception);
}