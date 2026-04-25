import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';

class AuthenticationUserLoading extends LoadingState {}

class AuthenticationUserSuccess extends UIState {
  final UserName userName;

  AuthenticationUserSuccess(this.userName);

  @override
  List<Object> get props => [userName];
}

class AuthenticationUserFailure extends FeatureFailure {

  AuthenticationUserFailure(dynamic exception) : super(exception: exception);
}