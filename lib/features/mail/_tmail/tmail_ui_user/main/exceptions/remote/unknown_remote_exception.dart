import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/exceptions/remote/remote_exception.dart';

class UnknownRemoteException extends RemoteException {

  final Object? error;

  const UnknownRemoteException({
    super.code,
    super.message,
    this.error,
  });

  @override
  String get exceptionName => 'UnknownRemoteException';

  @override
  List<Object?> get props => [...super.props, error];
}
