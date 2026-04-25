import 'dart:async';

import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/network_connection/presentation/network_connection_controller.dart'
  if (dart.library.html) 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/network_connection/presentation/web_network_connection_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/exceptions/remote/network_exception.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/exceptions/thrower/remote_exception_thrower.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/route_navigation.dart';

class SendEmailExceptionThrower extends RemoteExceptionThrower {
  @override
  FutureOr<void> throwException(error, stackTrace) async {
    logError(
      'SendEmailExceptionThrower::throwException():error: $error | stackTrace: $stackTrace',
      exception: error,
      stackTrace: stackTrace,
    );
    final networkConnectionController = getBinding<NetworkConnectionController>();
    final realtimeNetworkConnectionStatus = await networkConnectionController?.hasInternetConnection();
    if (realtimeNetworkConnectionStatus == false) {
      logError('SendEmailExceptionThrower::throwException(): No realtime network connection');
      throw const NoNetworkError();
    } else {
      handleDioError(error);
    }
  }
}