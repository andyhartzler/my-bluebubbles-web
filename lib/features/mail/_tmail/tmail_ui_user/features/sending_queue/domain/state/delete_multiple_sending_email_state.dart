
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class DeleteMultipleSendingEmailLoading extends UIState {}

class DeleteMultipleSendingEmailSuccess extends UIState {
  final List<String> sendingIds;

  DeleteMultipleSendingEmailSuccess(this.sendingIds);

  @override
  List<Object?> get props => [sendingIds];
}

class DeleteMultipleSendingEmailFailure extends FeatureFailure {

  DeleteMultipleSendingEmailFailure(dynamic exception) : super(exception: exception);
}