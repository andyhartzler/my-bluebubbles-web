import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/labels/domain/model/label_changes_result.dart';

class GettingLabelChanges extends LoadingState {}

class GetLabelChangesSuccess extends UIState {
  final LabelChangesResult changesResult;

  GetLabelChangesSuccess(this.changesResult);

  @override
  List<Object> get props => [changesResult];
}

class GetLabelChangesFailure extends FeatureFailure {
  GetLabelChangesFailure(dynamic exception) : super(exception: exception);
}
