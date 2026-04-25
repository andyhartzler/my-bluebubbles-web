import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SaveRecentLoginUsernameSuccess extends UIState {}

class SaveRecentLoginUsernameFailed extends FeatureFailure {

  SaveRecentLoginUsernameFailed(dynamic exception) : super(exception: exception);
}