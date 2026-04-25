import 'package:bluebubbles/features/mail/_tmail/core/utils/app_logger.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';

class CacheExceptionThrower extends ExceptionThrower {

  @override
  throwException(dynamic error, dynamic stackTrace) {
    logError(
      'CacheExceptionThrower::throwException():error: $error',
      exception: error,
      stackTrace: stackTrace,
    );
    throw error;
  }
}