import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class CanNotGetRootIsolateToken extends AppBaseException {
  const CanNotGetRootIsolateToken([super.message]);

  @override
  String get exceptionName => 'CanNotGetRootIsolateToken';
}
