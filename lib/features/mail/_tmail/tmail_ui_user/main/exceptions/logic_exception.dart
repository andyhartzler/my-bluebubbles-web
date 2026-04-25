import 'package:bluebubbles/features/mail/_tmail/core/domain/exceptions/app_base_exception.dart';

class InteractorNotInitialized extends AppBaseException {
  const InteractorNotInitialized([super.message]);

  @override
  String get exceptionName => 'InteractorNotInitialized';
}