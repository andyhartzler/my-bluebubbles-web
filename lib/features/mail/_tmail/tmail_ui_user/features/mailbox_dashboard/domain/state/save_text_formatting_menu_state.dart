import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SavingTextFormattingMenuState extends LoadingState {}

class SaveTextFormattingMenuStateSuccess extends UIState {
  final bool isDisplayed;

  SaveTextFormattingMenuStateSuccess(this.isDisplayed);

  @override
  List<Object?> get props => [isDisplayed];
}

class SaveTextFormattingMenuStateFailure extends FeatureFailure {
  SaveTextFormattingMenuStateFailure(dynamic exception) : super(exception: exception);
}
