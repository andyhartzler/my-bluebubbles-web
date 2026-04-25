import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class EmptyThreadDetailException extends AppBaseException {
  const EmptyThreadDetailException([super.message]);

  @override
  String get exceptionName => 'EmptyThreadDetailException';
}
