import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class ThreadDetailOverloadException extends AppBaseException {
  ThreadDetailOverloadException([super.message]);

  @override
  String get exceptionName => 'ThreadDetailOverloadException';
}
