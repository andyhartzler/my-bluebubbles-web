import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class UnknownUriException extends AppBaseException {
  const UnknownUriException([super.message]);

  @override
  String get exceptionName => 'UnknownUriException';
}