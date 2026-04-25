import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class AuthenticateOidcOnBrowserLoading extends LoadingState {}

class AuthenticateOidcOnBrowserSuccess extends UIState {}

class AuthenticateOidcOnBrowserFailure extends FeatureFailure {

  AuthenticateOidcOnBrowserFailure(dynamic exception) : super(exception: exception);
}