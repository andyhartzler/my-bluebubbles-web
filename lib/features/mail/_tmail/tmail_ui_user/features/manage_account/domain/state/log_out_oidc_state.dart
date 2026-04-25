
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class LogoutOidcSuccess extends UIState {}

class LogoutOidcFailure extends FeatureFailure {

  LogoutOidcFailure(dynamic exception) : super(exception: exception);
}