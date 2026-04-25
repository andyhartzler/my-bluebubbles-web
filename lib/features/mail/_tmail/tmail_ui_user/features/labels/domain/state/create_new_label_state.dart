import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/model/label.dart';

class CreatingNewLabel extends LoadingState {}

class CreateNewLabelSuccess extends UIState {
  final Label newLabel;

  CreateNewLabelSuccess(this.newLabel);

  @override
  List<Object> get props => [newLabel];
}

class CreateNewLabelFailure extends FeatureFailure {
  CreateNewLabelFailure(dynamic exception) : super(exception: exception);
}
