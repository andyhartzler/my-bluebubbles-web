import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class UnsupportedCharsetException extends AppBaseException {
  const UnsupportedCharsetException([super.message]);

  @override
  String get exceptionName => 'UnsupportedCharsetException';
}

class NullCharsetException extends AppBaseException {
  const NullCharsetException([super.message]);

  @override
  String get exceptionName => 'NullCharsetException';
}
