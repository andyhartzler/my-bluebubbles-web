import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class GettingEntireMessageAsDocument extends LoadingState {}

class GetEntireMessageAsDocumentSuccess extends UIState {
  final String messageDocument;

  GetEntireMessageAsDocumentSuccess(this.messageDocument);

  @override
  List<Object?> get props => [messageDocument];
}

class GetEntireMessageAsDocumentFailure extends FeatureFailure {

  GetEntireMessageAsDocumentFailure({dynamic exception}) : super(exception: exception);
}