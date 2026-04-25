import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/model/label.dart';

class DeletingALabel extends LoadingState {}

class DeleteALabelSuccess extends UIState {
  final Label deletedLabel;

  DeleteALabelSuccess(this.deletedLabel);

  @override
  List<Object> get props => [deletedLabel];
}

class DeleteALabelFailure extends FeatureFailure {
  DeleteALabelFailure(dynamic exception) : super(exception: exception);
}
