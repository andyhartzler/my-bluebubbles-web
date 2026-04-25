import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class PickFileCanceledException extends AppBaseException {
  const PickFileCanceledException([super.message]);

  @override
  String get exceptionName => 'PickFileCanceledException';
}
