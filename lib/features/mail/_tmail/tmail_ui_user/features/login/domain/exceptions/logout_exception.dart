import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class UserCancelledLogoutOIDCFlowException extends AppBaseException {
  UserCancelledLogoutOIDCFlowException([super.message]);

  @override
  String get exceptionName => 'UserCancelledLogoutOIDCFlowException';
}
