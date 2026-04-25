import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SaveRecentLoginUrlSuccess extends UIState {}

class SaveRecentLoginUrlFailed extends FeatureFailure {

  SaveRecentLoginUrlFailed(dynamic exception) : super(exception: exception);
}